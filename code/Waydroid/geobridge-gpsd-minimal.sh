#!/bin/sh
# GPS Bridge: gpsd -> Waydroid LocationService
# Streams GPS data from gpsd to Android apps in Waydroid

SCRIPT_NAME=$(basename "$0")

log(){ printf "%s %s\n" "[$(date -Iseconds)]" "$*"; }
err(){ log "ERROR: $*" >&2; }

# Detect adb device
detect_adb(){
  ADB_DEV=""
  if command -v adb >/dev/null 2>&1; then
    ADB_DEV=$(adb devices 2>/dev/null | awk 'NR>1 && $2=="device" {print $1; exit}') || ADB_DEV=""
    if [ -n "$ADB_DEV" ]; then
      log "Using adb device: $ADB_DEV"
    else
      log "No adb device found; will use 'sudo waydroid shell'"
    fi
  else
    log "adb not installed; will use 'sudo waydroid shell'"
  fi
}

# Check required commands
check_requirements(){
  if ! command -v gpspipe >/dev/null 2>&1; then
    err "gpspipe missing. Install gpsd-clients package"
    return 1
  fi
  if ! command -v jq >/dev/null 2>&1; then
    err "jq missing. Install jq package"
    return 1
  fi
  if ! command -v waydroid >/dev/null 2>&1; then
    err "waydroid missing. Install waydroid"
    return 1
  fi
  
  # Check Waydroid status
  WAYSTAT=$(waydroid status 2>/dev/null | tr '[:upper:]' '[:lower:]')
  if ! echo "$WAYSTAT" | grep -q "running"; then
    err "Waydroid container not running"
    err "Start with: sudo waydroid container start && waydroid session start"
    return 1
  fi
  
  log "Waydroid container is running"
  return 0
}

# Try to connect adb to Waydroid
connect_adb_to_waydroid(){
  if command -v adb >/dev/null 2>&1 && [ -z "$ADB_DEV" ]; then
    WAY_IP=$(waydroid status | awk -F: '/[Ii][Pp] address/ {gsub(/^[ \t]+/,"",$2); print $2; exit}')
    if [ -n "$WAY_IP" ]; then
      log "Detected Waydroid IP: $WAY_IP"
      adb connect "$WAY_IP:58526" >/dev/null 2>&1 || adb connect "$WAY_IP:5555" >/dev/null 2>&1
      detect_adb
    fi
  fi
}

# Main execution
if ! check_requirements; then
  exit 1
fi

detect_adb
connect_adb_to_waydroid

log "Starting GPS bridge (gpsd -> Waydroid). Press Ctrl-C to stop."
trap "log 'Stopping bridge'; exit 0" INT TERM

# Stream GPS data
gpspipe -w | while IFS= read -r line; do
  vals=$(echo "$line" | jq -r 'select(.class=="TPV") | "\(.lat) \(.lon) \(.alt)"' 2>/dev/null)
  
  if [ -n "$vals" ] && [ "$vals" != "null null null" ]; then
    lat=$(echo "$vals" | awk '{print $1}')
    lon=$(echo "$vals" | awk '{print $2}')
    alt=$(echo "$vals" | awk '{print $3}')
    
    if [ -z "$lat" ] || [ -z "$lon" ] || [ "$lat" = "null" ] || [ "$lon" = "null" ]; then
      continue
    fi
    
    AMCMD="am start-foreground-service --user 0 -n io.appium.settings/.LocationService --es longitude '$lon' --es latitude '$lat' --es altitude '$alt'"
    
    if [ -n "$ADB_DEV" ]; then
      adb -s "$ADB_DEV" shell $AMCMD >/dev/null 2>&1 || err "Failed to send location via adb"
    else
      sudo waydroid shell "$AMCMD" >/dev/null 2>&1 || err "Failed to send location via waydroid shell"
    fi
    
    log "Location updated: $lat,$lon,$alt"
  fi
done