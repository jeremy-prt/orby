#!/bin/bash
set -euo pipefail

APP_NAME="Orby"
BUILD_DIR=".build"
APP_BUNDLE="$BUILD_DIR/app/$APP_NAME.app"
DMG_OUTPUT="$BUILD_DIR/Orby.dmg"
BG_IMAGE="Resources/dmg-bg.png"

# Step 1: Build the app
echo "Building app..."
bash build-app.sh

# Step 1.5: Sign with stable certificate so TCC permissions persist across Sparkle updates
# (ad-hoc signing resets Screen Recording permission on every update)
echo "Signing for distribution..."
codesign --force --deep -s "Orby Dev" "$APP_BUNDLE"

# Step 2: DMG background
# Uses Resources/dmg-bg.png (drag to install arrow)

# Step 3: Create DMG
echo "Creating DMG..."
rm -f "$DMG_OUTPUT"

if command -v create-dmg &> /dev/null; then
    CREATE_DMG_ARGS=(
        --volname "$APP_NAME"
        --window-pos 200 120
        --window-size 600 400
        --icon-size 128
        --icon "$APP_NAME.app" 150 200
        --app-drop-link 450 200
        --hide-extension "$APP_NAME.app"
        --no-internet-enable
    )

    if [ -f "$BG_IMAGE" ]; then
        CREATE_DMG_ARGS+=(--background "$BG_IMAGE")
    fi

    create-dmg "${CREATE_DMG_ARGS[@]}" "$DMG_OUTPUT" "$APP_BUNDLE" || true
else
    echo "create-dmg not found. Install with: brew install create-dmg"
    echo "Creating simple DMG with hdiutil..."
    STAGING="$BUILD_DIR/dmg-staging"
    rm -rf "$STAGING"
    mkdir -p "$STAGING"
    cp -R "$APP_BUNDLE" "$STAGING/"
    ln -s /Applications "$STAGING/Applications"
    hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -ov -format UDZO "$DMG_OUTPUT"
    rm -rf "$STAGING"
fi

if [ -f "$DMG_OUTPUT" ]; then
    echo ""
    echo "DMG created: $DMG_OUTPUT"
    echo "  open $DMG_OUTPUT"

    # Sign with Sparkle EdDSA for auto-update
    if [ -f "Frameworks/sign_update" ]; then
        echo ""
        echo "Sparkle EdDSA signature:"
        ./Frameworks/sign_update "$DMG_OUTPUT"
        echo ""
        echo "Copy the sparkle:edSignature and length into website/public/appcast.xml"
    fi
else
    echo "ERROR: DMG creation failed"
    exit 1
fi
