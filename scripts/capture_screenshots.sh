#!/usr/bin/env bash
set -euo pipefail

APP_ID="com.example.retaliation"
PROJ_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SS_DIR="$PROJ_DIR/screenshots"
mkdir -p "$SS_DIR"

pick_device() {
  local booted
  booted=$(xcrun simctl list devices | awk '/Booted/ {print $NF}' | tr -d '()' | head -n1 || true)
  if [[ -n "$booted" ]]; then
    echo "$booted"
    return 0
  fi
  local udid
  udid=$(xcrun simctl list devices | awk '/iPhone 15 Pro \(/ {print $NF}' | tr -d '()' | head -n1 || true)
  if [[ -z "$udid" ]]; then
    udid=$(xcrun simctl list devices | awk '/iPhone 16 Pro \(/ {print $NF}' | tr -d '()' | head -n1 || true)
  fi
  if [[ -z "$udid" ]]; then
    echo "No suitable simulator found" >&2
    exit 1
  fi
  xcrun simctl boot "$udid" || true
  echo "$udid"
}

build_install_launch() {
  local defines="$1"; shift
  local outfile="$1"; shift
  echo "Building with defines: $defines"
  (cd "$PROJ_DIR" && flutter build ios --simulator $defines)
  local appPath="$PROJ_DIR/build/ios/iphonesimulator/Runner.app"
  xcrun simctl install booted "$appPath" || true
  xcrun simctl terminate booted "$APP_ID" || true
  xcrun simctl launch booted "$APP_ID" || true
  sleep 3
  xcrun simctl io booted screenshot "$SS_DIR/$outfile"
}

DEVICE=$(pick_device)
echo "Using simulator: $DEVICE"

# Menu
build_install_launch "" "menu.png"

# Level select from menu
build_install_launch "--dart-define=START_SCREEN=level_select" "level_select.png"

# In-game HUD (first level)
build_install_launch "--dart-define=START_LEVEL=assets/levels/level1.json" "ingame.png"

# Win overlay (force)
build_install_launch "--dart-define=START_LEVEL=assets/levels/level1.json --dart-define=FORCE_OVERLAY=win" "win.png"

# Lose overlay (force)
build_install_launch "--dart-define=START_LEVEL=assets/levels/level1.json --dart-define=FORCE_OVERLAY=lose" "lose.png"

echo "Screenshots saved to $SS_DIR"

