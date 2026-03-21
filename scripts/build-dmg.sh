#!/bin/bash
set -euo pipefail

# ============================================================================
# NewsDigest — Build & DMG Packaging Script
# ============================================================================
# Run this on macOS with Xcode installed:
#   chmod +x scripts/build-dmg.sh
#   ./scripts/build-dmg.sh
#
# Output: build/NewsDigest.dmg (ready to distribute)
# ============================================================================

APP_NAME="NewsDigest"
BUNDLE_ID="com.newsdigest.app"
SCHEME="NewsDigest"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"
DMG_NAME="${APP_NAME}"
DMG_PATH="${BUILD_DIR}/${DMG_NAME}.dmg"
DMG_TEMP="${BUILD_DIR}/${DMG_NAME}-temp.dmg"
VOL_NAME="${APP_NAME}"
DMG_SIZE="150m"
BACKGROUND_IMG="${PROJECT_DIR}/scripts/dmg-background.png"

echo "╔══════════════════════════════════════════════════════╗"
echo "║  NewsDigest — Build & Package                       ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# ── Step 0: Check prerequisites ──────────────────────────────────────────────
echo "→ Checking prerequisites..."

if ! command -v xcodebuild &>/dev/null; then
    echo "✗ Error: Xcode or Xcode Command Line Tools not found."
    echo "  Install from: https://developer.apple.com/xcode/"
    exit 1
fi

XCODE_VERSION=$(xcodebuild -version | head -1)
echo "  ✓ ${XCODE_VERSION}"

if ! command -v hdiutil &>/dev/null; then
    echo "✗ Error: hdiutil not found. Are you running macOS?"
    exit 1
fi
echo "  ✓ hdiutil available"
echo ""

# ── Step 1: Clean previous builds ───────────────────────────────────────────
echo "→ Cleaning previous builds..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"
echo "  ✓ Build directory cleaned"
echo ""

# ── Step 2: Build the app ───────────────────────────────────────────────────
echo "→ Building ${APP_NAME} (Release)..."
echo "  This may take a minute..."

xcodebuild \
    -project "${PROJECT_DIR}/${APP_NAME}.xcodeproj" \
    -scheme "${SCHEME}" \
    -configuration Release \
    -derivedDataPath "${BUILD_DIR}/derived" \
    -archivePath "${BUILD_DIR}/${APP_NAME}.xcarchive" \
    archive \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    2>&1 | while IFS= read -r line; do
        # Show only meaningful lines
        if [[ "$line" == *"Build Succeeded"* ]]; then
            echo "  ✓ Build succeeded"
        elif [[ "$line" == *"error:"* ]]; then
            echo "  ✗ $line"
        elif [[ "$line" == *"warning:"* ]]; then
            echo "  ⚠ $line"
        fi
    done

# Export the app from the archive
echo "→ Exporting app from archive..."

# Create export options plist
EXPORT_OPTIONS="${BUILD_DIR}/export-options.plist"
cat > "${EXPORT_OPTIONS}" << 'EXPORTPLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>destination</key>
    <string>export</string>
</dict>
</plist>
EXPORTPLIST

# Try archive export first; fall back to copying from DerivedData
if [ -d "${BUILD_DIR}/${APP_NAME}.xcarchive" ]; then
    xcodebuild -exportArchive \
        -archivePath "${BUILD_DIR}/${APP_NAME}.xcarchive" \
        -exportPath "${BUILD_DIR}/export" \
        -exportOptionsPlist "${EXPORT_OPTIONS}" \
        2>/dev/null && \
    cp -R "${BUILD_DIR}/export/${APP_NAME}.app" "${APP_PATH}" || true
fi

# Fallback: find the .app in DerivedData
if [ ! -d "${APP_PATH}" ]; then
    echo "  → Locating built app in DerivedData..."
    BUILT_APP=$(find "${BUILD_DIR}/derived" -name "${APP_NAME}.app" -type d | head -1)
    if [ -z "${BUILT_APP}" ]; then
        echo "  ✗ Error: Could not find built ${APP_NAME}.app"
        echo "    Try building manually in Xcode first."
        exit 1
    fi
    cp -R "${BUILT_APP}" "${APP_PATH}"
fi

echo "  ✓ App exported: ${APP_PATH}"
echo ""

# ── Step 3: Verify the app ──────────────────────────────────────────────────
echo "→ Verifying app bundle..."
if [ ! -f "${APP_PATH}/Contents/MacOS/${APP_NAME}" ]; then
    echo "  ✗ Error: App bundle is malformed (no executable found)"
    exit 1
fi
APP_VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "${APP_PATH}/Contents/Info.plist" 2>/dev/null || echo "1.0")
echo "  ✓ ${APP_NAME} v${APP_VERSION}"
echo ""

# ── Step 4: Create DMG ──────────────────────────────────────────────────────
echo "→ Creating DMG installer..."

# Create a staging directory for the DMG contents
DMG_STAGING="${BUILD_DIR}/dmg-staging"
rm -rf "${DMG_STAGING}"
mkdir -p "${DMG_STAGING}"

# Copy the app
cp -R "${APP_PATH}" "${DMG_STAGING}/"

# Create symlink to /Applications
ln -s /Applications "${DMG_STAGING}/Applications"

# Copy background image if it exists
if [ -f "${BACKGROUND_IMG}" ]; then
    mkdir -p "${DMG_STAGING}/.background"
    cp "${BACKGROUND_IMG}" "${DMG_STAGING}/.background/background.png"
fi

# Remove any existing DMG
rm -f "${DMG_TEMP}" "${DMG_PATH}"

# Create a temporary read/write DMG
echo "  → Creating disk image..."
hdiutil create \
    -srcfolder "${DMG_STAGING}" \
    -volname "${VOL_NAME}" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    -size "${DMG_SIZE}" \
    "${DMG_TEMP}" \
    -quiet

# Mount the temp DMG to customize it
echo "  → Customizing DMG layout..."
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "${DMG_TEMP}" | \
    egrep '^/dev/' | sed 1q | awk '{print $1}')

sleep 2

# Use AppleScript to set the DMG window layout
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

# Set permissions and detach
chmod -Rf go-w "/Volumes/${VOL_NAME}"
hdiutil detach "${DEVICE}" -quiet

# Convert to compressed, read-only DMG
echo "  → Compressing DMG..."
hdiutil convert "${DMG_TEMP}" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "${DMG_PATH}" \
    -quiet

# Clean up temp DMG
rm -f "${DMG_TEMP}"

echo "  ✓ DMG created: ${DMG_PATH}"
echo ""

# ── Step 5: Verify DMG ──────────────────────────────────────────────────────
DMG_SIZE_HUMAN=$(du -h "${DMG_PATH}" | cut -f1)
echo "→ Verification..."
echo "  ✓ DMG size: ${DMG_SIZE_HUMAN}"

# Verify DMG can be mounted
hdiutil verify "${DMG_PATH}" -quiet 2>/dev/null && \
    echo "  ✓ DMG integrity verified" || \
    echo "  ⚠ DMG verification skipped"

echo ""

# ── Step 6: Optional code signing ────────────────────────────────────────────
# Uncomment the following to sign the DMG with your Developer ID:
#
# SIGNING_IDENTITY="Developer ID Application: Your Name (TEAM_ID)"
# echo "→ Signing DMG..."
# codesign --sign "${SIGNING_IDENTITY}" --verbose "${DMG_PATH}"
# echo "  ✓ DMG signed"
#
# To notarize (required for Gatekeeper on macOS 10.15+):
# xcrun notarytool submit "${DMG_PATH}" \
#     --apple-id "your@email.com" \
#     --team-id "YOUR_TEAM_ID" \
#     --password "@keychain:AC_PASSWORD" \
#     --wait
# xcrun stapler staple "${DMG_PATH}"

# ── Done ─────────────────────────────────────────────────────────────────────
echo "╔══════════════════════════════════════════════════════╗"
echo "║  ✓ Build complete!                                  ║"
echo "╠══════════════════════════════════════════════════════╣"
echo "║  DMG:  build/NewsDigest.dmg                         ║"
echo "║  App:  build/NewsDigest.app                         ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "To install: Double-click the DMG and drag NewsDigest"
echo "            to your Applications folder."
echo ""
