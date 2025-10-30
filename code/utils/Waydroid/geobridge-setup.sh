#!/bin/sh
# Setup script for Waydroid GPS Bridge
# This script provides step-by-step instructions and executes required commands

APPURL="https://github.com/appium/io.appium.settings/releases/download/v5.12.14/settings_apk-debug.apk"
APK_TMP="/tmp/appium_settings.apk"

log(){ printf "\n[INFO] %s\n" "$*"; }
err(){ printf "\n[ERROR] %s\n" "$*" >&2; }
step(){ printf "\n========== STEP: %s ==========\n" "$*"; }
manual(){ printf "[MANUAL] %s\n" "$*"; }

# Function to pause and wait for user
pause(){
  printf "\nPress Enter to continue..."
  read _
}

step "1. Checking System Requirements"
log "Checking for required packages..."

MISSING_PKGS=""
for cmd in wget jq gpspipe waydroid; do
  if ! command -v $cmd >/dev/null 2>&1; then
    case $cmd in
      gpspipe) MISSING_PKGS="$MISSING_PKGS gpsd-clients" ;;
      *) MISSING_PKGS="$MISSING_PKGS $cmd" ;;
    esac
  fi
done

if [ -n "$MISSING_PKGS" ]; then
  err "Missing packages:$MISSING_PKGS"
  manual "Install with: sudo apt install$MISSING_PKGS"
  manual "Or equivalent for your distribution"
  exit 1
fi
log "All required packages found ✓"

step "2. Starting Waydroid Container"
log "Checking Waydroid status..."

if ! waydroid status 2>/dev/null | grep -qi "running"; then
  manual "Waydroid container is not running"
  manual "Execute these commands:"
  echo "  sudo waydroid container start"
  echo "  waydroid session start"
  manual "Then run this script again"
  exit 1
fi
log "Waydroid container is running ✓"

step "3. Downloading Appium Settings APK"
log "Downloading from: $APPURL"
if wget -O "$APK_TMP" "$APPURL"; then
  log "Downloaded successfully to $APK_TMP ✓"
else
  err "Download failed"
  exit 1
fi

step "4. Installing APK to Waydroid"
log "Attempting installation..."

if waydroid app install "$APK_TMP" 2>/dev/null; then
  log "Installed via waydroid ✓"
else
  manual "Waydroid install failed. Trying adb..."
  if command -v adb >/dev/null 2>&1; then
    # Try to connect to Waydroid
    WAY_IP=$(waydroid status | awk -F: '/[Ii][Pp] address/ {gsub(/^[ \t]+/,"",$2); print $2; exit}')
    if [ -n "$WAY_IP" ]; then
      log "Connecting adb to $WAY_IP"
      adb connect "$WAY_IP:58526" 2>/dev/null || adb connect "$WAY_IP:5555" 2>/dev/null
      
      if adb install -r "$APK_TMP" 2>/dev/null; then
        log "Installed via adb ✓"
      else
        err "Installation failed"
        manual "Try manually: adb install -r $APK_TMP"
      fi
    fi
  else
    manual "Install adb for better compatibility: sudo apt install adb"
  fi
fi

step "5. Configuring Android Permissions"
log "Setting up mock location permissions..."

# Detect how to run shell commands
if command -v adb >/dev/null 2>&1 && adb devices | grep -q "device$"; then
  SHELL_CMD="adb shell"
  log "Using adb shell"
else
  SHELL_CMD="sudo waydroid shell"
  log "Using waydroid shell (requires sudo)"
fi

manual "Executing permission commands..."
echo ""
echo "# Enable hidden API access:"
echo "$SHELL_CMD settings put global hidden_api_policy 1"
$SHELL_CMD "settings put global hidden_api_policy 1" 2>/dev/null && log "Hidden API enabled ✓"

echo ""
echo "# Allow mock location for Appium:"
echo "$SHELL_CMD appops set io.appium.settings android:mock_location allow"
$SHELL_CMD "appops set io.appium.settings android:mock_location allow" 2>/dev/null && log "Mock location allowed ✓"

echo ""
echo "# Grant location permission:"
echo "$SHELL_CMD pm grant io.appium.settings android.permission.ACCESS_FINE_LOCATION"
$SHELL_CMD "pm grant io.appium.settings android.permission.ACCESS_FINE_LOCATION" 2>/dev/null && log "Location permission granted ✓"

step "6. Verification"
log "Checking if Appium Settings is installed..."
if $SHELL_CMD "pm list packages | grep io.appium.settings" 2>/dev/null; then
  log "Package io.appium.settings is installed ✓"
else
  err "Package not found. Installation may have failed."
fi

step "Setup Complete!"
echo ""
manual "Next steps:"
echo "1. Ensure gpsd is running with your GPS device and run the bridge: geobridge-gpsd.sh"
echo ""
log "The GPS bridge will stream location from gpsd to Android apps in Waydroid"

# Cleanup
rm -f "$APK_TMP" 2>/dev/null