# Editeur — Problemes a resoudre

## Problemes actuels

### 1. Handles de selection clippes
Les handles de selection (resize, rotation) sont clippes quand une annotation est pres du bord de l'image. Sur une petite capture de zone, le handle de rotation (au-dessus de l'annotation) est invisible car coupe par le bord du Canvas.

### 2. Fluidite du trace
Le trace des annotations (rectangles, etc.) doit etre parfaitement fluide, sans lag ni saccade. Toute modification du canvas (frame etendu, offset, position) a cause des regressions de performance — NE PAS retenter ces approches.

### 3. Annotations non pixelisees
Les annotations doivent rester nettes a tout niveau de zoom (zoom vectoriel deja en place).

### 4. Zoom vers curseur
Le zoom (⌘+scroll, pinch trackpad) doit zoomer vers la position du curseur, pas vers le centre. Deja implemente avec la formule en 4 etapes :
1. Convertir curseur en coordonnees image AVANT zoom
2. Appliquer le nouveau zoom
3. Calculer ou ce point se retrouve APRES zoom
4. Ajuster panOffset pour compenser la difference

## Contraintes techniques decouverte (NE PAS refaire ces erreurs)

- SwiftUI `Canvas` clippe TOUJOURS a son propre frame — pas de contournement
- `.frame()` sur un ZStack ne clippe PAS, seul `.clipped()` clippe
- Le `.clipped()` du layout principal est necessaire pour la toolbar
- **ECHEC** : Canvas oversized + `.offset()` → panning parasite, padding asymetrique
- **ECHEC** : Canvas oversized + `.position()` → lag, layout thrashing
- **ECHEC** : Canvas dynamique (recalcul overflow a chaque frame) → instabilite coordonnees, lag
- **ECHEC** : Wrapper ZStack avec frame etendu → layout cascade, performance degradee

## Ce qu'on veut

1. Handles de selection/rotation TOUJOURS visibles, meme sur une petite capture
2. Trace des annotations parfaitement fluide (zero lag)
3. Annotations tracees EXACTEMENT ou est le curseur (zero shift)
4. Zoom vers curseur precis
5. Pas de panning parasite quand on trace/deplace une annotation
6. Plus tard : annotations depassant l'image visibles + exportees avec fond dominant

## Approche recommandee : Handles en SwiftUI views (pas Canvas)

Sortir les handles du Canvas et les rendre comme des vues SwiftUI normales positionnees dans le GeometryReader.

### Pourquoi :
- Les vues SwiftUI (Rectangle, Circle) avec `.position()` ne sont PAS clippees par le `.frame()` parent
- Seul `.clipped()` clippe (et il est sur la vue canvas, pas sur le GeometryReader)
- Les handles sont purement visuels (`.allowsHitTesting(false)`) — le hit testing se fait deja dans `handleAt()` en coordonnees base
- On ne touche PAS au Canvas des annotations ni au systeme de coordonnees

### Comment :
1. `SelectionOverlay` et `HoverOverlay` : remplacer le Canvas par des vues SwiftUI (Rectangle stroke, Circle pour rotation) positionnees en coordonnees viewport
2. Les handles vont dans un layer SEPARE, hors du ZStack `.frame(width: dw, height: dh)`, directement dans le GeometryReader
3. Positions : `annotationCoord * zoomLevel + ox + panOffset` (coordonnees viewport)
4. L'annotation Canvas reste a `dw x dh` — aucun changement

## Projets open source a analyser

IMPORTANT : Utiliser le skill `mgrep` (`mgrep --store mixedbread/web search --web --answer "query"`) pour les recherches.

- https://github.com/sadopc/ScreenCapture — Capture d'ecran macOS
- https://github.com/flameshot-org/flameshot — Capture + annotations, Qt/C++
- https://github.com/KartikLabhshetwar/better-shot — Screenshot tool

Analyser comment ces projets gerent le rendu des handles/annotations au bord de l'image.

## Architecture editeur (refactoree en extensions)

- `EditorView.swift` — Struct + @State + body (raccourcis clavier)
- `EditorCanvas.swift` — Layout canvas (GeometryReader, ZStack, image, annotations, overlays)
- `EditorGestures.swift` — canvasPoint(), handleDrag/Tap, updateCursor
- `EditorActions.swift` — zoom, undo, crop, clipboard, tool selection, annotation setters
- `EditorToolbar.swift` — Toolbar superieure
- `SelectionOverlay.swift` — HoverOverlay + SelectionOverlay (dans Canvas, A MIGRER vers SwiftUI views)
- `AnnotationView.swift` — Rendu Canvas des annotations
- `AnnotationModel.swift` — Struct Annotation, hit test, resize, rotate

## Systeme de coordonnees (NE PAS CASSER)

```
baseDw = imgWidth * fitScale   // coordonnees base pour les annotations
baseDh = imgHeight * fitScale
dw = baseDw * zoomLevel        // taille rendue avec zoom
dh = baseDh * zoomLevel
ox = (geoWidth - dw) / 2       // centrage dans le viewport
oy = (geoHeight - dh) / 2
```

- Annotations stockees en base coords (0..baseDw, 0..baseDh)
- Canvas les multiplie par zoomLevel pour le rendu
- `canvasPoint()` convertit screen → base en divisant par zoomLevel
- Ce systeme fonctionne parfaitement — NE PAS le modifier
