#!/bin/bash
set -euo pipefail

APP_NAME="FloatTimer"
VERSION="${1:-1.2.0}"
BUILD_DIR=".build/release"
BUNDLE_DIR="${BUILD_DIR}/${APP_NAME}.app"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_DIR="${BUILD_DIR}/dmg-staging"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "=== Building ${APP_NAME} v${VERSION} ==="

# Clean
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# ── Detect build method ──────────────────────────────────────
# On GitHub Actions (or any system with working Xcode/SPM), use swift build.
# Locally, fall back to swiftc with VFS overlay workarounds.

SOURCES=(
  Sources/FloatTimer/main.swift
  Sources/FloatTimer/AppDelegate.swift
  Sources/FloatTimer/TimerEngine.swift
  Sources/FloatTimer/TimerOverlayPanel.swift
  Sources/FloatTimer/StatusBarController.swift
  Sources/FloatTimer/HotKeyManager.swift
  Sources/FloatTimer/Preferences.swift
  Sources/FloatTimer/PreferencesWindow.swift
)

# Always use swiftc directly for reliable cross-environment builds.
# -swift-version 5 avoids Swift 6 strict concurrency errors on CI.

EXTRA_FLAGS=()

# Local workaround: VFS overlay for CLT modulemap conflict
if [ -f "${SCRIPT_DIR}/fix-modulemap/vfs-overlay.yaml" ]; then
  # Check if the overlay is actually needed (CLT vs Xcode)
  if [ -d "/Library/Developer/CommandLineTools" ] && ! xcode-select -p 2>/dev/null | grep -q "Xcode.app"; then
    EXTRA_FLAGS+=(
      -Xfrontend -disable-deserialization-safety
      -vfsoverlay "${SCRIPT_DIR}/fix-modulemap/vfs-overlay.yaml"
      -Xcc -ivfsoverlay -Xcc "${SCRIPT_DIR}/fix-modulemap/vfs-overlay.yaml"
    )
  fi
fi

echo "Building with swiftc..."
swiftc \
  -O \
  -swift-version 5 \
  -o "${BUILD_DIR}/${APP_NAME}" \
  -sdk "$(xcrun --show-sdk-path)" \
  -target arm64-apple-macosx13.0 \
  "${EXTRA_FLAGS[@]}" \
  "${SOURCES[@]}"

BINARY="${BUILD_DIR}/${APP_NAME}"

echo "Binary built at: ${BINARY}"

# ── Create .app bundle ───────────────────────────────────────
echo "Creating app bundle..."
rm -rf "${BUNDLE_DIR}"
mkdir -p "${BUNDLE_DIR}/Contents/MacOS"
mkdir -p "${BUNDLE_DIR}/Contents/Resources"

cp "${BINARY}" "${BUNDLE_DIR}/Contents/MacOS/${APP_NAME}"

# Copy app icon if it exists
if [ -f "${SCRIPT_DIR}/Resources/AppIcon.icns" ]; then
    cp "${SCRIPT_DIR}/Resources/AppIcon.icns" "${BUNDLE_DIR}/Contents/Resources/AppIcon.icns"
    echo "App icon copied."
fi

cat > "${BUNDLE_DIR}/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.floattimer.app</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>FloatTimer</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
</dict>
</plist>
PLIST

# ── Ad-hoc code sign ────────────────────────────────────────
echo "Code signing (ad-hoc)..."
codesign --force --deep --sign - "${BUNDLE_DIR}"

# Verify
codesign --verify --verbose "${BUNDLE_DIR}" && echo "Code signature valid."

# ── Create DMG ───────────────────────────────────────────────
echo "Creating DMG..."
rm -rf "${DMG_DIR}"
mkdir -p "${DMG_DIR}"
cp -R "${BUNDLE_DIR}" "${DMG_DIR}/"
ln -s /Applications "${DMG_DIR}/Applications"

hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder "${DMG_DIR}" \
  -ov \
  -format UDZO \
  "${BUILD_DIR}/${DMG_NAME}"

rm -rf "${DMG_DIR}"

echo ""
echo "=== Release build complete ==="
echo "App bundle: ${BUNDLE_DIR}"
echo "DMG:        ${BUILD_DIR}/${DMG_NAME}"
echo ""
echo "To install: open the DMG, drag FloatTimer to Applications."
