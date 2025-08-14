#!/bin/sh
# Improved bridge gpsd -> waydroid io.appium.settings LocationService
# Added checks, helpful messages and flexible use of `sudo waydroid shell` when adb isn't available.
# Requirements: adb (optional), waydroid, gpspipe (from gpsd), jq, wget

APPURL="https://github.com/appium/io.appium.settings/releases/download/v5.12.14/settings_apk-debug.apk"
APK_TMP="/tmp/appium.apk"
SCRIPT_NAME=$(basename "$0")

log(){ printf "%s %s\n" "[$(date -Iseconds)]" "$*"; }
err(){ log "ERROR: $*" >&2; }

# run_shell <command>
# if adb device is present we use adb -s <dev> shell <cmd>
# otherwise we fall back to `sudo waydroid shell` which the user requested
run_shell(){
  if [ -n "$ADB_DEV" ]; then
    adb -s "$ADB_DEV" shell "$@"
  else
    # use waydroid shell as a fallback (the user asked for this)
    sudo waydroid shell "$@"
  fi
}

check_cmd(){
  if ! command -v "$1" >/dev/null 2>&1; then
    err "required command '$1' not found. Install it and re-run."
    return 1
  fi
  return 0
}

# detect adb device (first "device" state)
detect_adb(){
  ADB_DEV=""
  if command -v adb >/dev/null 2>&1; then
    ADB_DEV=$(adb devices 2>/dev/null | awk 'NR>1 && $2=="device" {print $1; exit}') || ADB_DEV=""
    if [ -n "$ADB_DEV" ]; then
      log "Using adb device: $ADB_DEV"
    else
      log "No adb device found; will use 'sudo waydroid shell' for shell commands."
    fi
  else
    log "adb not installed; will use 'sudo waydroid shell' for shell commands."
  fi
}

# check environment
check_env(){
  check_cmd wget || return 1
  check_cmd jq || return 1
  check_cmd gpspipe || { err "gpspipe (gpsd-client) missing; install gpsd/gpsd-clients."; return 1; }
  check_cmd waydroid || { err "waydroid command missing."; return 1; }
  # adb is optional; we won't fail if absent
  detect_adb

  # ensure waydroid container running (case-insensitive)
  WAYSTAT=$(waydroid status 2>/dev/null || true)
  WAYSTAT_LOWER=$(printf "%s" "$WAYSTAT" | tr '[:upper:]' '[:lower:]')
  if printf "%s" "$WAYSTAT_LOWER" | grep -q "running"; then
    log "Waydroid container is running."
  else
    err "Waydroid container does not look running. Start it: 'sudo waydroid container start' and 'waydroid session start'"
    return 1
  fi

  # try to auto-detect Waydroid IP and offer to connect adb to it if adb exists but no device found
  if command -v adb >/dev/null 2>&1 && [ -z "$ADB_DEV" ]; then
    # extract IP line (case-insensitive match)
    WAY_IP=$(printf "%s" "$WAYSTAT" | awk -F: '/[Ii][Pp] address/ {gsub(/^[     ]+/,"",$2); print $2; exit}') || WAY_IP=""
    if [ -n "$WAY_IP" ]; then
      log "Detected Waydroid IP: $WAY_IP"
      # try connecting adb to common mapped port 58526 first, then 5555
      if adb connect "$WAY_IP:58526" >/dev/null 2>&1; then
        log "Attempted adb connect to $WAY_IP:58526"
      elif adb connect "$WAY_IP:5555" >/dev/null 2>&1; then
        log "Attempted adb connect to $WAY_IP:5555"
      fi
      # re-detect adb device
      detect_adb
    fi
  fi

  return 0
}

if [ "$1" = "--init" ]; then
  log "Init mode: download APK and install into Waydroid, then grant permissions."
  check_cmd wget || exit 1
  log "Downloading $APPURL to $APK_TMP"
  if ! wget -q -O "$APK_TMP" "$APPURL"; then
    err "Failed to download APK"; exit 2
  fi
  log "Downloaded APK to $APK_TMP"

  detect_adb

  # attempt waydroid install first (preferred)
  log "Installing APK into Waydroid (preferred: waydroid app install)"
  if waydroid app install "$APK_TMP" >/dev/null 2>&1; then
    log "Installed APK with 'waydroid app install'."
  else
    log "'waydroid app install' failed or not available. Trying adb install if adb device present."
    if [ -n "$ADB_DEV" ]; then
      log "Installing via adb to $ADB_DEV"
      if ! adb -s "$ADB_DEV" install -r "$APK_TMP" >/dev/null 2>&1; then
        err "adb install failed. Check 'adb devices' and run the install manually."
        exit 3
      fi
      log "Installed APK via adb."
    else
      err "Could not install APK: neither waydroid install worked nor adb device available. Ensure Waydroid session is running and adb can connect."
      exit 4
    fi
  fi

  # re-detect package presence before applying appops
  detect_adb

  log "Applying Android settings and permissions (using shell: ${ADB_DEV:-waydroid shell})"
  # use run_shell helper
  if ! run_shell "settings put global hidden_api_policy 1" >/dev/null 2>&1; then
    err "Failed to set hidden_api_policy. You may need to run this manually later."
  else
    log "hidden_api_policy set."
  fi

  if ! run_shell "appops set io.appium.settings android:mock_location allow" >/dev/null 2>&1; then
    err "Failed to set appops mock_location. You may need to run this manually."
  else
    log "appops mock_location allowed for io.appium.settings."
  fi

  if ! run_shell "pm grant io.appium.settings android.permission.ACCESS_FINE_LOCATION" >/dev/null 2>&1; then
    err "Failed to grant ACCESS_FINE_LOCATION; maybe package not yet installed. Verify with 'pm list packages'."
  else
    log "Granted ACCESS_FINE_LOCATION to io.appium.settings."
  fi

  log "Initialization complete. Verify package is installed:"
  run_shell "pm list packages | grep io.appium.settings || true"
  exit 0
fi

# non-init run: check environment
if ! check_env; then
  err "Environment checks failed. Fix the errors above and re-run with --init first."
  exit 1
fi

log "Starting gpsd -> Waydroid bridge. Press Ctrl-C to stop."

# trap SIGINT to exit cleanly
trap "log 'Stopping bridge'; exit 0" INT TERM

# stream TPV objects from gpspipe
gpspipe -w | while IFS= read -r line; do
  vals=$(echo "$line" | jq -r 'select(.class=="TPV") | "\(.lat) \(.lon) \(.alt)"' 2>/dev/null)
  if [ -n "$vals" ] && [ "$vals" != "null null null" ]; then
    lat=$(echo "$vals" | awk '{print $1}')
    lon=$(echo "$vals" | awk '{print $2}')
    alt=$(echo "$vals" | awk '{print $3}')

    # sanity checks
    if [ -z "$lat" ] || [ -z "$lon" ] || [ "$lat" = "null" ] || [ "$lon" = "null" ]; then
      continue
    fi

    # build the am command; note careful quoting
    AMCMD="am start-foreground-service --user 0 -n io.appium.settings/.LocationService --es longitude '$lon' --es latitude '$lat' --es altitude '$alt'"

    # execute via adb if present else via sudo waydroid shell
    if [ -n "$ADB_DEV" ]; then
      adb -s "$ADB_DEV" shell $AMCMD >/dev/null 2>&1 || err "Failed to send location via adb"
    else
      sudo waydroid shell "$AMCMD" >/dev/null 2>&1 || err "Failed to send location via waydroid shell"
    fi

    log "Location updated: $lat,$lon,$alt"
  fi
done