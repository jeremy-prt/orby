# Screenshot Mini

App macOS menu bar de capture d'ecran, inspiree de CleanShot X en plus simple.

## Stack

- **Swift 6.2** / **SwiftUI** / **macOS 15+** (Sequoia)
- **Swift Package Manager** (pas de projet Xcode)
- App menu bar (`NSStatusItem`) sans fenetre principale (`LSUIElement = true`)
- Hotkey global via **Carbon** (`RegisterEventHotKey`) — supporte multi-raccourcis
- Capture via `/usr/sbin/screencapture -x` (CLI systeme)
- OCR via **Vision** framework (`VNRecognizeTextRequest`) — natif, pas de dependance
- Build dev : `bash build-app.sh` → compile, signe avec certificat dev, met a jour `/Applications/`
- Build distribution : `bash build-dmg.sh` → compile, re-signe en ad-hoc, cree le `.dmg`

## Architecture

39 fichiers dans 8 sous-repertoires :

```
Sources/ScreenshotMini/
├── App/
│   ├── ScreenshotMiniApp.swift    # @main, AppDelegate, menu bar, routing des hotkeys
│   └── Constants.swift            # brandPurple (#9F01A0)
├── Editor/
│   ├── EditorWindow.swift         # NSWindow + NSToolbar unifiedCompact, traffic lights alignment
│   ├── EditorView.swift           # Canvas, toolbar SwiftUI, gestes (draw/move/resize/rotate/crop/zoom), undo, copy/paste, option-drag, background
│   ├── AnnotationToolbar.swift    # Floating toolbar : color picker, thickness slider, fill/arrow/blur style
│   ├── AnnotationView.swift       # Rendu Canvas : rect/circle/line/freehand, 4 styles fleche, Bezier, texte, blur preview
│   ├── BackgroundPanel.swift      # Panel config background : onglets degrade/uni, sliders espacement/coins, toggle ombre
│   ├── BlurRegionView.swift       # Rendu live blur CIFilter (gaussian/pixelate) sur region de l'image
│   ├── FreehandPreview.swift      # Preview du trait pendant le dessin libre
│   ├── SelectionOverlay.swift     # HoverOverlay + SelectionOverlay (handles, rotation)
│   ├── TextEditingOverlay.swift   # MultilineTextField (NSViewRepresentable) + overlay edition texte
│   ├── CropViews.swift            # CropToolbar (apply/cancel) + CropMask (eoFill)
│   ├── ScrollWheelView.swift      # ScrollWheelView (NSViewRepresentable), ZoomIndicator
│   ├── ToolbarButton.swift        # ToolbarButton avec tooltip + shortcut
│   ├── DragMeButton.swift         # Bouton drag & drop image depuis l'editeur (ferme la fenetre apres drop)
│   └── ShareButton.swift          # Bouton share (NSSharingServicePicker) ancre au bouton via NSViewRepresentable
├── History/
│   ├── HistoryView.swift          # Grille captures avec hover blur+glass (style ThumbnailView), edit/copy/save/delete
│   └── HistoryWindow.swift        # NSPanel flottant pour l'historique
├── Models/
│   ├── AnnotationModel.swift      # Annotation struct, AnnotationShape, ArrowStyle, BlurStyle, ResizeHandle (.rotating), hit test, resize, rotate, move, duplicate
│   ├── AnnotationHistory.swift    # AnnotationHistory (undo/redo stack)
│   ├── BackgroundConfig.swift     # BackgroundType, BackgroundConfig, gradientPresets, solidColorPresets, Color(hex:)
│   ├── HistoryManager.swift       # HistoryEntry (Codable), HistoryManager (JSON + thumbnails + full images, max 12, clean on launch)
│   ├── ImageHelpers.swift         # flattenAnnotations, cropImage, CanvasInteraction
│   └── ImageSaveService.swift     # saveImage, normalizeImageDPI, uniqueDragFilename, DateFormatter
├── Services/
│   ├── HotkeyManager.swift        # Multi-hotkeys Carbon (fullscreen/area/OCR), HotkeySlot, UCKeyTranslate AZERTY
│   ├── ScreenCaptureService.swift  # screencapture CLI (fullscreen/area/OCR), post-capture actions, son
│   └── ToastManager.swift         # Toast capsule adaptatif light/dark, slide-down animation
├── Settings/
│   ├── SettingsView.swift         # Shell 4 onglets
│   ├── GeneralTab.swift           # Theme (System/Light/Dark), menu bar, son, langue, OCR langue
│   ├── ShortcutsTab.swift         # Onglet Raccourcis
│   ├── CaptureTab.swift           # Actions post-capture, export Retina/Standard, preview position/stack/delay
│   ├── SaveTab.swift              # Format image (PNG/JPEG/TIFF), dossier destination
│   ├── SettingsModels.swift       # Modeles partagés settings (ImageFormat, ScreenPosition…)
│   └── LaunchAtLoginToggle.swift  # Toggle launch at login
├── Thumbnail/
│   ├── ThumbnailPanel.swift       # Coordinateur preview flottante, auto-dismiss, position, export Retina
│   ├── ThumbnailNSPanel.swift     # NSPanel custom (drag source sendEvent)
│   ├── ThumbnailView.swift        # SwiftUI view de la preview
│   └── WindowDragHandle.swift     # Handle drag pour pin
└── Localization/
    └── Localization.swift         # L10n — strings FR/EN
Resources/
├── AppIcon.icns               # Icone app
├── menubar-icon.png           # Icone menu bar (template noir)
├── icon.png                   # Logo source
docs/                          # Landing page + guide install
```

## Fonctionnalites

- **Capture plein ecran** — raccourci global configurable
- **Capture de zone** — selection a la souris, raccourci global
- **Capture de fenetre** — clic sur une fenetre (screencapture -w), raccourci global
- **OCR (capture texte)** — selection zone → Vision reconnaît le texte → copie clipboard + toast
- **Preview flottante** apres capture :
  - Hover = blur + glass + boutons (Edit pill centre, Copy icone bas-gauche, Save icone bas-droite, Pin/Close coins haut)
  - Drag & drop image vers Finder/navigateur (via ThumbnailNSPanel.sendEvent)
  - Swipe trackpad pour fermer (scroll monitor)
  - Pin = deplace via handle 3 dots, decalage visuel du stack
  - Multi-captures empilables ou mode single (configurable)
  - Auto-dismiss configurable (3-60s), pause au hover
  - Position configurable (4 coins)
  - Tooltips custom avec delai 1s
  - Curseur force arrow via global mouse monitor (empeche cursor bleed-through)
- **Editeur** :
  - Outils : curseur/select (V), crop (C), rectangle (R), ellipse (O), ligne (L), fleche (A), texte (T), dessin libre (D), flou (B), numero (N), background (F)
  - Raccourcis clavier : V/C/R/O/L/A/T/D/B/N/F/Esc
  - 4 styles de fleche : outline, thin, filled (gros), double (↔)
  - Fleches courbees avec point de controle Bezier (drag du midpoint handle)
  - Color picker compact : cercle unique → popover preset 8 couleurs + custom
  - Slider epaisseur en forme de triangle
  - Fill modes : outline / semi-transparent / solide (pour rect/circle)
  - Crop avec undo complet (restaure image et annotations precedentes)
  - Rotation des annotations : handle au-dessus du bounding box, curseur fleche circulaire custom
  - Toolbar flottante proprietes annotations (top-right)
  - Toolbar flottante confirmation crop (top-right)
  - Dark mode, toolbar alignee avec traffic lights via NSToolbar unifiedCompact
  - Undo/redo : ⌘Z / ⌘⇧Z, delete annotation : ⌫, deplacer : fleches clavier, copy : ⌘C, paste : ⌘V, save-as : ⌘S (NSSavePanel)
  - Outil texte : cliquer pour placer, editer inline, mode background + plain, multiline (Shift+Enter), resize en direct, clic sur annotation selectionnee → re-edition
  - Outil flou : gaussian blur + pixelate via CIFilter, preview en temps reel, slider rayon
  - Outil background : fond degrade (18 presets) ou couleur unie (12 + custom picker), padding %, coins arrondis %, ombre optionnelle. Preview live dans l'editeur (scaleEffect), export via renderWithBackground (NSImage)
  - Outil numero (N) : cercles numerotes auto-incrementes (1, 2, 3...), couleur et taille configurables, click to place
  - Bouton share : NSSharingServicePicker natif (AirDrop, Messages, Mail, etc.), ancre au bouton toolbar
- **Historique des captures** :
  - NSPanel flottant avec grille de thumbnails (style ThumbnailView : blur + glass au hover)
  - Boutons hover : Edit (centre), Copy (bas-gauche), Save (bas-droite), Delete (haut-droite)
  - Max 12 captures, images completes + thumbnails dans ~/Library/Application Support/ScreenshotMini/history/
  - Clean complet au relancement de l'app
  - Accessible via menu bar + raccourci global configurable
  - Drag & drop depuis l'historique vers Finder/navigateur/apps
  - Dessin libre lisse (quadCurve mid-points)
  - Copy/paste annotations : ⌘C / ⌘V (offset +20,+20, pastes successifs cascadent)
  - Option-drag duplicate : ⌥+drag duplique l'annotation (comme Figma)
  - Drag & drop depuis l'editeur (DragMeButton, la fenetre se ferme apres le drop)
  - Zoom : pinch trackpad, ⌘+ / ⌘- / ⌘0, ⌘+scroll, indicateur % dans la toolbar, scroll pour panner quand zoom > 1
- **Toast** : capsule adaptative light/dark, animation slide-down entree, position centree en haut d'ecran
- **Son** de capture (optionnel, son systeme macOS natif)
- **Actions post-capture** configurables : afficher preview, copier clipboard, sauvegarder, ouvrir editeur
- **Format d'image** : PNG, JPEG, TIFF (configurable)
- **Export resolution** : Retina 2x (defaut) ou Standard 1x — reglage dans l'onglet Capture
- **Theme** : System / Light / Dark — reglage dans l'onglet General, applique a l'app entiere
- **Bilingue** FR/EN — interface, tooltips, menu, reglages, langue OCR configurable separement
- **Menu bar** — icone custom template, masquable (auto-ouvre settings si masquee)
- **Couleur brand** : violet #9F01A0 (`brandPurple`) utilise dans settings et editeur

## Build & Dev

```bash
cd /Users/jeremy/Documents/code/2025/projets_pro/ScreenshotMini
bash build-app.sh   # compile + signe certificat dev + update /Applications + relance
bash build-dmg.sh   # compile + re-signe ad-hoc + cree .dmg pour distribution
```

## Code signing

**Dev (build-app.sh)** :
- Signe avec le certificat local **"ScreenshotMini Dev"** (racine auto-signee, Keychain session)
- Signature stable entre les builds → permissions TCC (Screen Recording) persistent
- Ne PAS revenir a `-s -` (ad-hoc) pour le dev sinon TCC redemande a chaque rebuild

**Distribution (build-dmg.sh)** :
- Re-signe en ad-hoc (`-s -`) apres le build
- Les utilisateurs n'ont pas le certificat dev → ad-hoc suffit
- Ils devront faire "Open Anyway" dans System Settings + autoriser Screen Recording une fois

## Points importants

- On utilise `screencapture` CLI et PAS ScreenCaptureKit pour eviter les popups de permission
- `waitUntilExit()` du Process est dans un `DispatchQueue.global` pour ne pas bloquer le main thread
- Les settings utilisent `@AppStorage` / `UserDefaults`
- Le drag & drop image est gere au niveau `ThumbnailNSPanel.sendEvent` (pas de gesture recognizer, pas de NSViewRepresentable) pour coexister avec les boutons SwiftUI
- Le drag & drop depuis l'editeur est gere par `DragMeButton` ; la fenetre se ferme apres le drop
- Le swipe dismiss utilise `NSEvent.addLocalMonitorForEvents(.scrollWheel)`
- Le curseur arrow est force via `NSEvent.addGlobalMonitorForEvents(.mouseMoved)`
- Les raccourcis clavier utilisent `UCKeyTranslate` pour supporter AZERTY et autres layouts
- L'icone menu bar est un PNG template (`isTemplate = true`) → macOS adapte la couleur au theme
- Le crop undo pousse dans `imageUndoStack: [(NSImage, [Annotation])]` ; `history.undo()` a priorite, sinon pop imageUndoStack
- La toolbar editeur utilise NSToolbar unifiedCompact vide pour aligner les traffic lights ; padding gauche 70pt dans la toolbar SwiftUI
- L'outil flou utilise CIFilter (CIGaussianBlur / CIPixellate) sur la region selectionnee de l'image source, avec preview temps reel
- Copy/paste annotations (⌘C/⌘V) : clipboard interne `@State`, paste avec offset +20,+20, pastes successifs cascadent
- Option-drag duplicate : `NSEvent.modifierFlags.contains(.option)` au debut du drag, cree une copie via `Annotation.duplicate()`
- Rotation : handle `.rotating` au-dessus du bounding box (position tournee avec l'annotation), curseur fleche circulaire custom (`rotateCursor` dessine en code)
- Zoom : `MagnifyGesture` pour pinch trackpad, `ScrollWheelView` pour pan (quand zoom > 1) et ⌘+scroll pour zoomer, boutons toolbar + raccourcis ⌘+/⌘-/⌘0 via hidden Buttons
- Toast : `ToastView` (capsule, fond adaptatif light/dark selon `appTheme`), animation slide-down entree + fade-out 0.3s apres 2.5s
- Export Retina : `exportRetina` UserDefaults bool → `normalizeImageDPI()` pour downscale 1x ; s'applique au save (ThumbnailPanel, ImageHelpers) et au copy (EditorView)
- Theme : `appTheme` UserDefaults string ("system"/"light"/"dark") → `applyTheme()` dans GeneralTab ; lu aussi par ToastManager pour la couleur du toast
- Background tool : preview via `scaleEffect(bgShrink)` sur le canvas interne (dw/dh stables, annotations ne bougent pas), background gradient/couleur dans un ZStack parent de taille dw x dh. Export via `renderWithBackground()` qui utilise `NSImage(size:flipped:drawingHandler:)`. `canvasPoint` combine `bgShrink * zoomLevel` en un seul effectiveZoom

## TODO

- [x] Outil Texte dans l'editeur (placer, editer inline, multiline, re-edition au clic)
- [x] Outil Dessin libre (main levee)
- [x] 4 styles de fleche (outline/thin/filled/double)
- [x] Fleches courbees avec Bezier
- [x] Crop avec undo
- [x] Color picker compact (cercle + popover)
- [x] Slider epaisseur triangle
- [x] Fill modes (outline/semi/solid)
- [x] Dark mode editeur
- [x] Toolbar alignee avec traffic lights
- [x] Raccourcis clavier editeur (V/C/R/O/L/A/T/D/B/Esc)
- [x] Outil Flou (gaussian + pixelate, CIFilter, preview temps reel, slider rayon)
- [x] Ameliorations texte (mode background + plain, resize en direct, pas de duplication)
- [x] Ameliorations fleches (4 styles, courbes Bezier)
- [x] Slider epaisseur triangle custom
- [x] Persistance couleur (UserDefaults)
- [x] Copy/paste annotations (⌘C/⌘V)
- [x] Option-drag duplicate (⌥+drag, comme Figma)
- [x] Rotation des annotations (handle + curseur circulaire custom)
- [x] Zoom (pinch, ⌘+/⌘-/⌘0, ⌘+scroll, indicateur %, pan)
- [x] Toast adaptatif light/dark (capsule, slide animation)
- [x] Export Retina 2x / Standard 1x (reglage Capture tab)
- [x] Theme System/Light/Dark (reglage General tab)
- [x] Drag & drop depuis l'editeur (DragMeButton)
- [x] Background tool (degrade/uni, padding, coins arrondis, ombre, preview live + export)
- [x] Bouton Share dans l'editeur (NSSharingServicePicker)
- [x] Capture de fenetre (screencapture -w, raccourci configurable)
- [x] Historique des captures (NSPanel, grille thumbnails, max 12, clean on launch, drag & drop)
- [x] Annotations numerotees (cercles 1, 2, 3... click to place)
- [x] ⌘S save-as dialog (NSSavePanel)
- [ ] Curseurs de resize specifiques par handle (↔ ↕ etc.) — actuellement crosshair generique
- [ ] Refaire AppIcon.icns avec le logo app fond violet
