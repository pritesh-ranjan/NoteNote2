#!/bin/bash
set -e

echo "🔨 Building NoteNote for Mac..."
swift build -c release

APP_NAME="NoteNote"
BUNDLE_DIR="${APP_NAME}.app"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "📦 Creating macOS App Bundle: ${BUNDLE_DIR}..."
rm -rf "${BUNDLE_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Copy binary
cp ".build/release/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

# Copy Info.plist and AppIcon
cp "Resources/Info.plist" "${CONTENTS_DIR}/Info.plist"
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
fi

# PkgInfo
echo -n "APPL????" > "${CONTENTS_DIR}/PkgInfo"

# Ad-hoc sign with consistent bundle identifier and stable designated requirement for TCC persistence across rebuilds and restarts
codesign -s - --force --deep -i "com.priteshranjan.NoteNote" -r='designated => identifier "com.priteshranjan.NoteNote"' "${BUNDLE_DIR}" 2>/dev/null || codesign -s - --force --deep "${BUNDLE_DIR}" || true

# Register with macOS LaunchServices so system permissions (TCC) recognize the bundle
if [ -x "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister" ]; then
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "${BUNDLE_DIR}" 2>/dev/null || true
fi

echo "✅ Successfully built and registered ${BUNDLE_DIR}!"
echo "👉 You can run it now with: open ${BUNDLE_DIR}"
