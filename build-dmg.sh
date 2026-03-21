#!/bin/bash
set -euo pipefail

APP_NAME="Orby"
BUILD_DIR=".build"
APP_BUNDLE="$BUILD_DIR/app/$APP_NAME.app"
DMG_OUTPUT="$BUILD_DIR/Orby.dmg"
BG_IMAGE="$BUILD_DIR/dmg-bg.png"

# Step 1: Build the app
echo "Building app..."
bash build-app.sh

# Step 1.5: Re-sign with ad-hoc for distribution (users don't have our dev certificate)
echo "Re-signing for distribution (ad-hoc)..."
codesign --force --deep -s - "$APP_BUNDLE"

# Step 2: Generate DMG background if not exists
if [ ! -f "$BG_IMAGE" ]; then
    echo "Generating DMG background..."
    python3 -c "
from PIL import Image, ImageDraw, ImageFont
import sys

try:
    w, h = 600, 400
    img = Image.new('RGBA', (w*2, h*2), (250, 249, 247, 255))
    draw = ImageDraw.Draw(img)
    # Arrow from app icon to Applications
    draw.text((w-40, h+40), '→', fill=(180,180,180,255))
    img.save('$BG_IMAGE')
except:
    # Fallback: just create a simple bg
    pass
" 2>/dev/null || echo "  (bg generation skipped, using default)"
fi

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
        echo "Copy the sparkle:edSignature and length into docs/appcast.xml"
    fi
else
    echo "ERROR: DMG creation failed"
    exit 1
fi
