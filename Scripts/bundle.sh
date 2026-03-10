#!/bin/bash
set -e

APP_NAME="FloatTimer"
BUILD_DIR=".build"
BUNDLE_DIR="${BUILD_DIR}/${APP_NAME}.app"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Build with workarounds for CLT/Swift version mismatch
echo "Building ${APP_NAME}..."
swiftc \
  -O \
  -o "${BUILD_DIR}/${APP_NAME}" \
  -sdk "$(xcrun --show-sdk-path)" \
  -target arm64-apple-macosx13.0 \
  -Xfrontend -disable-deserialization-safety \
  -vfsoverlay "${SCRIPT_DIR}/fix-modulemap/vfs-overlay.yaml" \
  -Xcc -ivfsoverlay -Xcc "${SCRIPT_DIR}/fix-modulemap/vfs-overlay.yaml" \
  Sources/FloatTimer/main.swift \
  Sources/FloatTimer/AppDelegate.swift \
  Sources/FloatTimer/TimerEngine.swift \
  Sources/FloatTimer/TimerOverlayPanel.swift \
  Sources/FloatTimer/StatusBarController.swift \
  Sources/FloatTimer/HotKeyManager.swift \
  Sources/FloatTimer/Preferences.swift \
  Sources/FloatTimer/PreferencesWindow.swift

# Create bundle structure
rm -rf "${BUNDLE_DIR}"
mkdir -p "${BUNDLE_DIR}/Contents/MacOS"
mkdir -p "${BUNDLE_DIR}/Contents/Resources"

# Copy executable
cp "${BUILD_DIR}/${APP_NAME}" "${BUNDLE_DIR}/Contents/MacOS/${APP_NAME}"

# Write Info.plist
cat > "${BUNDLE_DIR}/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>FloatTimer</string>
    <key>CFBundleIdentifier</key>
    <string>com.floattimer.app</string>
    <key>CFBundleName</key>
    <string>FloatTimer</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo ""
echo "Build successful!"
echo "Bundle created at: ${BUNDLE_DIR}"
echo "Run with: open ${BUNDLE_DIR}"
