#!/bin/bash
set -euo pipefail

APP_NAME="Screenshot Mini"
BUNDLE_ID="com.local.ScreenshotMini"
BUILD_DIR=".build/app"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "Building..."
swift build -c release 2>&1

echo "Creating app bundle..."
rm -rf "$BUILD_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary
cp .build/release/ScreenshotMini "$APP_BUNDLE/Contents/MacOS/ScreenshotMini"

# Create Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.local.ScreenshotMini</string>
    <key>CFBundleName</key>
    <string>Screenshot Mini</string>
    <key>CFBundleDisplayName</key>
    <string>Screenshot Mini</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>ScreenshotMini</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>26.0</string>
    <key>NSScreenCaptureUsageDescription</key>
    <string>Screenshot Mini needs screen recording permission to capture screenshots.</string>
</dict>
</plist>
PLIST

# Create entitlements (needed for ScreenCaptureKit)
cat > "$BUILD_DIR/entitlements.plist" << 'ENTITLEMENTS'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
</dict>
</plist>
ENTITLEMENTS

# Ad-hoc code sign with entitlements
codesign --force --deep --entitlements "$BUILD_DIR/entitlements.plist" -s - "$APP_BUNDLE" 2>/dev/null || true

echo ""
echo "App bundle created at: $APP_BUNDLE"
echo ""
echo "To install:"
echo "  cp -R \"$APP_BUNDLE\" /Applications/"
echo ""
echo "To run directly:"
echo "  open \"$APP_BUNDLE\""
