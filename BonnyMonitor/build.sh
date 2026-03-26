#!/bin/bash
# Build and run BonnyMonitor
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"

mkdir -p "$BUILD_DIR"

echo "Building BonnyMonitor..."
cd "$SCRIPT_DIR"
xcodebuild -project BonnyMonitor.xcodeproj -scheme BonnyMonitor -configuration Debug build 2>&1 | grep -E "BUILD|error:" || true

# Find the built app
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/BonnyMonitor-*/Build/Products/Debug -name "BonnyMonitor.app" -maxdepth 1 2>/dev/null | head -1)

if [ -z "$APP_PATH" ]; then
    echo "ERROR: Build failed — BonnyMonitor.app not found"
    exit 1
fi

# Copy to local build dir
cp -R "$APP_PATH" "$BUILD_DIR/"
echo "App copied to $BUILD_DIR/BonnyMonitor.app"

# Kill existing instance if running
pkill -f "BonnyMonitor.app/Contents/MacOS/BonnyMonitor" 2>/dev/null || true
sleep 1

# Launch
echo "Launching BonnyMonitor..."
open "$BUILD_DIR/BonnyMonitor.app"
echo "Done. Check your menubar for the Bonny icon."
