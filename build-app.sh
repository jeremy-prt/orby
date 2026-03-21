#!/bin/bash
set -euo pipefail

APP_NAME="Orby"
BUNDLE_ID="com.local.Orby"
BUILD_DIR=".build/app"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "Building..."
swift build -c release 2>&1

echo "Creating app bundle..."
rm -rf "$BUILD_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
mkdir -p "$APP_BUNDLE/Contents/Frameworks"

# Copy binary
cp .build/release/Orby "$APP_BUNDLE/Contents/MacOS/Orby"

# Copy Sparkle framework
if [ -d "Frameworks/Sparkle.framework" ]; then
    cp -R Frameworks/Sparkle.framework "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"
fi

# Copy icons
if [ -f "Resources/AppIcon.icns" ]; then
    cp Resources/AppIcon.icns "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi
if [ -f "Resources/menubar-icon.png" ]; then
    cp Resources/menubar-icon.png "$APP_BUNDLE/Contents/Resources/menubar-icon.png"
fi

# Create Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.local.Orby</string>
    <key>CFBundleName</key>
    <string>Orby</string>
    <key>CFBundleDisplayName</key>
    <string>Orby</string>
    <key>CFBundleVersion</key>
    <string>2</string>
    <key>CFBundleShortVersionString</key>
    <string>1.1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>Orby</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>SUPublicEDKey</key>
    <string>4NnmxyV0FR0GIFCf0hShB1k4vSkYsl5D55knxLeopgQ=</string>
    <key>SUFeedURL</key>
    <string>https://jeremy-prt.github.io/orby/appcast.xml</string>
    <key>SUScheduledCheckInterval</key>
    <integer>86400</integer>
</dict>
</plist>
PLIST

# Sign with stable dev certificate (preserves TCC permissions across rebuilds)
codesign --force --deep -s "Orby Dev" "$APP_BUNDLE" 2>/dev/null || codesign --force --deep -s - "$APP_BUNDLE"

INSTALLED="/Applications/$APP_NAME.app"
if [ -d "$INSTALLED" ]; then
    echo "Updating installed app..."
    pkill -f "$APP_NAME" 2>/dev/null || true
    sleep 0.5
    cp "$APP_BUNDLE/Contents/MacOS/Orby" "$INSTALLED/Contents/MacOS/Orby"
    cp "$APP_BUNDLE/Contents/Info.plist" "$INSTALLED/Contents/Info.plist"
    mkdir -p "$INSTALLED/Contents/Frameworks"
    rm -rf "$INSTALLED/Contents/Frameworks/Sparkle.framework"
    cp -R "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework" "$INSTALLED/Contents/Frameworks/Sparkle.framework" 2>/dev/null || true
    codesign --force --deep -s "Orby Dev" "$INSTALLED" 2>/dev/null || codesign --force --deep -s - "$INSTALLED"
    xattr -cr "$INSTALLED" 2>/dev/null || true
    echo "Updated. Relaunching..."
    open "$INSTALLED"
else
    echo ""
    echo "First install: copying to /Applications..."
    cp -R "$APP_BUNDLE" /Applications/
    xattr -cr "$INSTALLED" 2>/dev/null || true
    echo "Installed. Launching..."
    open "$INSTALLED"
fi
