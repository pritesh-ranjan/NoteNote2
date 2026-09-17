#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
PROJECT_ROOT="$(dirname "$DIR")"
cd "$PROJECT_ROOT"

APP_NAME="NoteNote"
DMG_NAME="${APP_NAME}.dmg"
VOL_NAME="${APP_NAME}"
TEMP_DMG="temp_${APP_NAME}.dmg"
STAGING_DIR=".dmg_staging"

echo "======================================"
echo "🚀 Building ${APP_NAME} macOS Installer"
echo "======================================"

# 1. Build the app bundle
./scripts/build_app.sh

# 2. Clean previous artifacts
echo "🧹 Cleaning previous staging & temporary files..."
rm -rf "${STAGING_DIR}"
rm -f "${TEMP_DMG}" "${DMG_NAME}"
mkdir -p "${STAGING_DIR}"

# 3. Populate staging directory
echo "📂 Staging files for DMG..."
cp -R "${APP_NAME}.app" "${STAGING_DIR}/"
ln -s /Applications "${STAGING_DIR}/Applications"

# Set volume icon if available
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "${STAGING_DIR}/.VolumeIcon.icns"
fi

# 4. Create DMG Image
if [ -n "$CI" ]; then
    echo "⚡ Running in CI runner: creating compressed DMG directly from staging..."
    hdiutil create -ov -srcfolder "${STAGING_DIR}" -volname "${VOL_NAME}" -format UDZO -imagekey zlib-level=9 "${DMG_NAME}"
    rm -rf "${STAGING_DIR}"
else
    # 4. Create initial read-write disk image
    echo "💿 Creating read-write disk image..."
    SIZE_KB=$(du -sk "${STAGING_DIR}" | cut -f1)
    DMG_SIZE_MB=$(( (SIZE_KB / 1024) + 40 ))
    if [ "$DMG_SIZE_MB" -lt 50 ]; then
        DMG_SIZE_MB=50
    fi
    
    hdiutil create -srcfolder "${STAGING_DIR}" -volname "${VOL_NAME}" -fs HFS+ \
            -fsargs "-c c=64,a=16,e=16" -format UDRW -size "${DMG_SIZE_MB}m" "${TEMP_DMG}"
    
    # 5. Mount the disk image to configure Finder layout
    echo "🎨 Mounting disk image to configure Finder layout..."
    MOUNT_OUTPUT=$(hdiutil attach -readwrite -noverify -noautoopen "${TEMP_DMG}")
    DEVICE=$(echo "${MOUNT_OUTPUT}" | grep -E '^/dev/' | sed 1q | awk '{print $1}')
    MOUNT_DIR=$(echo "${MOUNT_OUTPUT}" | grep '/Volumes/' | sed -E 's/.*(\/Volumes\/.*)/\1/')
    
    echo "Mounted on ${DEVICE} at ${MOUNT_DIR}"
    
    # Set volume icon attribute if icns present
    if [ -f "${MOUNT_DIR}/.VolumeIcon.icns" ]; then
        SetFile -c icnC "${MOUNT_DIR}/.VolumeIcon.icns" 2>/dev/null || true
        SetFile -a C "${MOUNT_DIR}" 2>/dev/null || true
    fi
    
    # 6. Use AppleScript to set Finder window layout (interactive macOS only)
    echo "📐 Configuring Finder window presentation..."
    osascript <<EOF || true
tell application "Finder"
    tell disk "${VOL_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 200, 960, 580}
        set viewOptions to the icon view options of container window
        set icon size of viewOptions to 110
        set text size of viewOptions to 12
        set arrangement of viewOptions to not arranged
        set position of item "${APP_NAME}.app" of container window to {150, 180}
        set position of item "Applications" of container window to {410, 180}
        close
        open
        update without registering applications
        delay 1
    end tell
end tell
EOF
    
    # Ensure all changes are written
    sync
    
    echo "📤 Unmounting temporary image..."
    sleep 1
    hdiutil detach "${DEVICE}" -force 2>/dev/null || hdiutil detach "${MOUNT_DIR}" -force 2>/dev/null || (sleep 2 && hdiutil detach "${DEVICE}" -force 2>/dev/null) || true
    
    # 7. Convert to compressed, final read-only DMG
    echo "🗜️ Compressing to final DMG: ${DMG_NAME}..."
    hdiutil convert "${TEMP_DMG}" -format UDZO -imagekey zlib-level=9 -o "${DMG_NAME}"
    
    # Clean up temporary files
    rm -f "${TEMP_DMG}"
    rm -rf "${STAGING_DIR}"
fi

# 8. Sign the DMG
echo "🔏 Signing DMG..."
codesign -s - --force "${DMG_NAME}" 2>/dev/null || true

echo "======================================"
echo "🎉 SUCCESS: ${DMG_NAME} created!"
echo "Size: $(du -h "${DMG_NAME}" | cut -f1)"
echo "Path: ${PROJECT_ROOT}/${DMG_NAME}"
echo "======================================"
