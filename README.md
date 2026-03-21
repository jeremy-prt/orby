# Orby

<p align="center">
  <img src="docs/screenshot.jpeg" width="600" alt="Orby">
</p>

A lightweight macOS menu bar screenshot app — simple, fast, free.

Available in **English** and **French**.

## Features

### Capture
- **Full screen capture** — Configurable global hotkey
- **Area capture** — Select a zone with your mouse
- **Window capture** — Click on a window to capture it
- **OCR text capture** — Select a zone, extract text to clipboard (Vision framework, offline)

### Floating Preview
- Hover to reveal actions: Edit, Copy, Save, Pin, Close
- Drag & drop to Finder, browser, or any app
- Swipe trackpad to dismiss
- Pin to keep on screen, stackable or single mode
- Auto-dismiss with configurable delay (3–60s)
- Configurable position (4 corners)

### Editor
- **11 tools**: Select (V), Crop (C), Rectangle (R), Ellipse (O), Line (L), Arrow (A), Text (T), Freehand draw (D), Blur (B), Numbered annotations (N), Background (F)
- **Arrows**: 4 styles (outline, thin, filled, double) + Bézier curves with control point
- **Text**: Click to place, inline editing, background/plain mode, multiline (Shift+Enter)
- **Blur**: Gaussian blur or pixelate via CIFilter, real-time preview
- **Numbered annotations**: Auto-incrementing numbered circles (1, 2, 3…)
- **Background**: 18 gradient presets + 12 solid colors + custom picker, padding, rounded corners, shadow
- **Color picker**: Compact circle with 8 preset colors + custom
- **Fill modes**: Outline / semi-transparent / solid
- **Rotation**: Drag handle above bounding box
- **Crop**: With full undo (restores image + annotations)
- **Copy/paste annotations**: ⌘C / ⌘V with cascading offset
- **Option-drag duplicate**: ⌥+drag to clone (like Figma)
- **Zoom**: Pinch trackpad, ⌘+/⌘-/⌘0, ⌘+scroll, pan when zoomed
- **Save as**: ⌘S opens NSSavePanel to choose location
- **Share**: System share sheet (AirDrop, Messages, Mail, Notes…)
- **Drag & drop**: Export from editor toolbar
- **Undo/redo**: ⌘Z / ⌘⇧Z

### Capture History
- Floating panel with thumbnail grid
- Hover to reveal actions: Edit, Copy, Save, Delete
- Drag & drop from history to any app
- Max 12 captures, cleaned on app restart
- Accessible via menu bar + configurable hotkey

### Settings
- **General**: Theme (System/Light/Dark), menu bar icon, capture sound, language, OCR language
- **Shortcuts**: Full screen, area, window, OCR, history hotkeys
- **Capture**: After-capture actions, export Retina 2x or Standard 1x, preview position/stacking/delay
- **Save**: Image format (PNG/JPEG/TIFF), destination folder
- **About**: Version info, links, check for updates

### Other
- **Auto-update** via Sparkle — checks for new versions automatically
- **Bilingual** — Full French and English interface
- **Theme** — System / Light / Dark
- **Export resolution** — Retina 2x (default) or Standard 1x
- **Brand color** — Purple #9F01A0

## Download

Grab the latest `.dmg` from the [Releases](https://github.com/jeremy-prt/orby/releases) page.

Or visit the [landing page](https://jeremy-prt.github.io/orby/) for more info.

## Install

1. Open the `.dmg` and drag the app to `/Applications`
2. Double-click the app — macOS will block it
3. Go to **System Settings → Privacy & Security** → click **Open Anyway**
4. Grant **Screen Recording** permission when prompted

> **Why is this needed?** This is an open-source project by an independent developer. The app is not signed with an Apple Developer certificate ($99/year), so macOS blocks it on first launch. The app is fully safe — you can review the source code yourself.

> **Terminal alternative:** `xattr -cr /Applications/Orby.app`

## Build from source

Requires **macOS 15+** and **Swift 6.2**.

```bash
git clone git@github.com:jeremy-prt/orby.git
cd orby
bash build-app.sh      # Build + install to /Applications
# bash build-dmg.sh    # Build .dmg for distribution (requires create-dmg)
```

## Keyboard shortcuts

Configure in **Settings → Shortcuts**:

| Action | Default |
|--------|---------|
| Full screen capture | *(set in settings)* |
| Area capture | *(set in settings)* |
| Window capture | *(set in settings)* |
| OCR text capture | *(set in settings)* |
| Capture history | *(set in settings)* |

**Editor shortcuts:**

| Key | Tool |
|-----|------|
| V | Select | C | Crop | R | Rectangle | O | Ellipse |
| L | Line | A | Arrow | T | Text | D | Draw |
| B | Blur | N | Number | F | Background | Esc | Deselect |
| ⌘Z | Undo | ⌘⇧Z | Redo | ⌫ | Delete | ⌘S | Save as |
| ⌘C | Copy annotation | ⌘V | Paste annotation |
| ⌘+/⌘- | Zoom in/out | ⌘0 | Reset zoom |

## License

[MIT](LICENSE)

Made by [Jeremy Perret](https://github.com/jeremy-prt)
