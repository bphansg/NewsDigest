#!/bin/bash
set -euo pipefail

# ============================================================================
# create-dmg.sh — Package an existing .app into a DMG installer
# ============================================================================
# Usage:
#   ./scripts/create-dmg.sh [path/to/App.app]
#
# If no .app path is given, looks for build/NewsDigest.app
# Output: build/NewsDigest.dmg
# ============================================================================

APP_NAME="NewsDigest"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
APP_PATH="${1:-${BUILD_DIR}/${APP_NAME}.app}"
DMG_PATH="${BUILD_DIR}/${APP_NAME}.dmg"
DMG_TEMP="${BUILD_DIR}/${APP_NAME}-temp.dmg"
VOL_NAME="${APP_NAME}"
DMG_SIZE="150m"
BACKGROUND_IMG="${SCRIPT_DIR}/dmg-background.png"

# Verify app exists
if [ ! -d "${APP_PATH}" ]; then
    echo "✗ Error: ${APP_PATH} not found."
    echo "  Build first with: make build"
    exit 1
fi

echo "╔══════════════════════════════════════════════════════╗"
echo "║  NewsDigest — DMG Packager                          ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "  App:  ${APP_PATH}"
echo ""

mkdir -p "${BUILD_DIR}"

# ── Create staging directory ─────────────────────────────────────────────────
echo "→ Preparing DMG contents..."
DMG_STAGING="${BUILD_DIR}/dmg-staging"
rm -rf "${DMG_STAGING}"
mkdir -p "${DMG_STAGING}"

# Copy the app
cp -R "${APP_PATH}" "${DMG_STAGING}/"

# Create symlink to /Applications
ln -s /Applications "${DMG_STAGING}/Applications"

# Copy background image
if [ -f "${BACKGROUND_IMG}" ]; then
    mkdir -p "${DMG_STAGING}/.background"
    cp "${BACKGROUND_IMG}" "${DMG_STAGING}/.background/background.png"
    echo "  ✓ Background image added"
fi

# ── Create temp DMG ──────────────────────────────────────────────────────────
echo "→ Creating disk image..."
rm -f "${DMG_TEMP}" "${DMG_PATH}"

hdiutil create \
    -srcfolder "${DMG_STAGING}" \
    -volname "${VOL_NAME}" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    -size "${DMG_SIZE}" \
    "${DMG_TEMP}" \
    -quiet

# ── Mount and customize layout ───────────────────────────────────────────────
echo "→ Customizing DMG layout..."
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "${DMG_TEMP}" | \
    egrep '^/dev/' | sed 1q | awk '{print $1}')

sleep 2

# AppleScript to set icon positions and window size
osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "${VOL_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 640, 440}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 96
        set text size of viewOptions to 13
        try
            set background picture of viewOptions to file ".background:background.png"
        end try
        -- Position app icon on the left, Applications on the right
        set position of item "${APP_NAME}.app" of container window to {140, 180}
        set position of item "Applications" of container window to {400, 180}
        close
        open
        update without registering applications
        delay 2
        close
    end tell
end tell
APPLESCRIPT

sync
sync

chmod -Rf go-w "/Volumes/${VOL_NAME}"
hdiutil detach "${DEVICE}" -quiet

# ── Convert to compressed read-only DMG ──────────────────────────────────────
echo "→ Compressing (read-only)..."
hdiutil convert "${DMG_TEMP}" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "${DMG_PATH}" \
    -quiet

rm -f "${DMG_TEMP}"
rm -rf "${DMG_STAGING}"

# ── Verify ───────────────────────────────────────────────────────────────────
DMG_SIZE_HUMAN=$(du -h "${DMG_PATH}" | cut -f1)
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  ✓ DMG created successfully!                        ║"
echo "╠══════════════════════════════════════════════════════╣"
printf "║  %-51s ║\n" "File: build/${APP_NAME}.dmg"
printf "║  %-51s ║\n" "Size: ${DMG_SIZE_HUMAN}"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "To install: Double-click ${APP_NAME}.dmg, then drag"
echo "            ${APP_NAME} to your Applications folder."
echo ""
