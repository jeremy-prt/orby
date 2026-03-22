type Lang = 'en' | 'fr' | 'es' | 'de'

const translations: Record<string, Record<Lang, string>> = {
  // Header
  'nav.features': { en: 'Features', fr: 'Fonctionnalités', es: 'Funciones', de: 'Funktionen' },
  'nav.shortcuts': { en: 'Shortcuts', fr: 'Raccourcis', es: 'Atajos', de: 'Tastaturkürzel' },
  'nav.download': { en: 'Download', fr: 'Télécharger', es: 'Descargar', de: 'Herunterladen' },
  'nav.changelog': { en: 'Changelog', fr: 'Changelog', es: 'Changelog', de: 'Changelog' },

  // Hero
  'hero.badge': { en: 'macOS 15+ · Free · Open Source', fr: 'macOS 15+ · Gratuit · Open Source', es: 'macOS 15+ · Gratis · Open Source', de: 'macOS 15+ · Kostenlos · Open Source' },
  'hero.title1': { en: 'Capture your screen,', fr: 'Capturez votre écran,', es: 'Captura tu pantalla,', de: 'Erfassen Sie Ihren Bildschirm,' },
  'hero.title2': { en: 'beautifully.', fr: 'élégamment.', es: 'con estilo.', de: 'wunderbar.' },
  'hero.subtitle': {
    en: 'A lightweight screenshot tool for macOS. Capture, annotate, extract text and beautify, all in one click.',
    fr: 'Un outil de capture d\'écran léger pour macOS. Capturez, annotez, extrayez du texte et embellissez, en un clic.',
    es: 'Una herramienta ligera de capturas para macOS. Captura, anota, extrae texto y embellece, en un clic.',
    de: 'Ein leichtes Screenshot-Tool für macOS. Erfassen, kommentieren, Text extrahieren und verschönern, mit einem Klick.'
  },
  'hero.cta': { en: 'Download for macOS', fr: 'Télécharger pour macOS', es: 'Descargar para macOS', de: 'Für macOS herunterladen' },
  'hero.github': { en: 'View on GitHub', fr: 'Voir sur GitHub', es: 'Ver en GitHub', de: 'Auf GitHub ansehen' },
  'hero.setup': { en: 'How to install', fr: 'Comment installer', es: 'Cómo instalar', de: 'Wie installieren' },

  // Setup page
  'setup.title': { en: 'Setup Guide', fr: 'Guide d\'installation', es: 'Guía de instalación', de: 'Installationsanleitung' },
  'setup.back': { en: 'Back', fr: 'Retour', es: 'Volver', de: 'Zurück' },
  'setup.step1.title': { en: 'Download & Install', fr: 'Télécharger et installer', es: 'Descargar e instalar', de: 'Herunterladen & Installieren' },
  'setup.step1.desc': { en: 'Download the DMG, open it, and drag Orby into your Applications folder.', fr: 'Téléchargez le DMG, ouvrez-le et glissez Orby dans votre dossier Applications.', es: 'Descarga el DMG, ábrelo y arrastra Orby a tu carpeta Aplicaciones.', de: 'Laden Sie die DMG herunter, öffnen Sie sie und ziehen Sie Orby in Ihren Anwendungsordner.' },
  'setup.step2.title': { en: 'Allow the app', fr: 'Autoriser l\'app', es: 'Permitir la app', de: 'App zulassen' },
  'setup.step2.desc': { en: 'On first launch, macOS blocks the app because it\'s not signed by Apple.', fr: 'Au premier lancement, macOS bloque l\'app car elle n\'est pas signée par Apple.', es: 'Al primer inicio, macOS bloquea la app porque no está firmada por Apple.', de: 'Beim ersten Start blockiert macOS die App, da sie nicht von Apple signiert ist.' },
  'setup.step2.steps': {
    en: '1. Double-click the app, macOS shows a warning\n2. Open System Settings → Privacy & Security\n3. At the bottom, click Open Anyway\n4. Enter your password',
    fr: '1. Double-cliquez sur l\'app, macOS affiche un avertissement\n2. Ouvrez Réglages Système → Confidentialité et sécurité\n3. En bas, cliquez Ouvrir quand même\n4. Entrez votre mot de passe',
    es: '1. Haz doble clic en la app, macOS muestra una advertencia\n2. Abre Ajustes del Sistema → Privacidad y seguridad\n3. Abajo, haz clic en Abrir de todos modos\n4. Introduce tu contraseña',
    de: '1. Doppelklicken Sie auf die App, macOS zeigt eine Warnung\n2. Öffnen Sie Systemeinstellungen → Datenschutz & Sicherheit\n3. Klicken Sie unten auf Öffnen\n4. Geben Sie Ihr Passwort ein'
  },
  'setup.step2.hint': { en: 'This is only needed once. After that the app opens normally.', fr: 'C\'est nécessaire une seule fois. Ensuite l\'app s\'ouvre normalement.', es: 'Solo es necesario una vez. Después la app se abre normalmente.', de: 'Dies ist nur einmal erforderlich. Danach öffnet sich die App normal.' },
  'setup.step2.note': { en: 'This is an open-source project by an independent developer. Apple Developer certification costs $99/year, which is why the app isn\'t signed.', fr: 'Ce projet est open source, développé par un développeur indépendant. La certification Apple Developer coûte 99$/an, c\'est pourquoi l\'app n\'est pas signée.', es: 'Este proyecto es open source, desarrollado por un desarrollador independiente. La certificación Apple Developer cuesta 99$/año, por eso la app no está firmada.', de: 'Dies ist ein Open-Source-Projekt eines unabhängigen Entwicklers. Die Apple Developer-Zertifizierung kostet 99 $/Jahr, daher ist die App nicht signiert.' },
  'setup.step2.terminal': { en: 'Terminal alternative:', fr: 'Alternative Terminal :', es: 'Alternativa Terminal:', de: 'Terminal-Alternative:' },
  'setup.step3.title': { en: 'Grant Screen Recording', fr: 'Autoriser l\'enregistrement d\'écran', es: 'Permitir grabación de pantalla', de: 'Bildschirmaufnahme zulassen' },
  'setup.step3.desc': { en: 'On your first capture, macOS will ask you to grant Screen Recording permission.', fr: 'Lors de votre première capture, macOS vous demandera d\'autoriser l\'enregistrement d\'écran.', es: 'En tu primera captura, macOS te pedirá permiso de grabación de pantalla.', de: 'Bei Ihrer ersten Erfassung fordert macOS Sie auf, die Berechtigung für die Bildschirmaufnahme zu erteilen.' },
  'setup.step3.steps': {
    en: '1. A popup appears, click Open System Settings\n2. Find Orby and check the box\n3. macOS asks to quit and reopen, accept\n4. The app restarts and captures work',
    fr: '1. Une popup apparaît, cliquez Ouvrir les Réglages Système\n2. Trouvez Orby et cochez la case\n3. macOS demande de quitter et ré-ouvrir, acceptez\n4. L\'app redémarre et les captures fonctionnent',
    es: '1. Aparece una ventana, haz clic en Abrir Ajustes del Sistema\n2. Busca Orby y marca la casilla\n3. macOS pide cerrar y reabrir, acepta\n4. La app se reinicia y las capturas funcionan',
    de: '1. Ein Popup-Fenster wird angezeigt, klicken Sie auf Systemeinstellungen öffnen\n2. Suchen Sie Orby und aktivieren Sie das Kontrollkästchen\n3. macOS fragt zum Beenden und erneuten Öffnen auf, akzeptieren Sie\n4. Die App startet neu und Erfassungen funktionieren'
  },
  'setup.step4.title': { en: 'Set up your shortcuts', fr: 'Configurer vos raccourcis', es: 'Configurar tus atajos', de: 'Richten Sie Ihre Verknüpfungen ein' },
  'setup.step4.desc': { en: 'Click the menu bar icon → Settings → Shortcuts. Set your hotkeys for full screen, area, window and OCR capture.', fr: 'Cliquez sur l\'icône dans la barre de menu → Réglages → Raccourcis. Définissez vos raccourcis.', es: 'Haz clic en el icono de la barra de menús → Ajustes → Atajos. Configura tus atajos.', de: 'Klicken Sie auf das Menüleistensymbol → Einstellungen → Tastaturkürzel. Legen Sie Ihre Hotkeys fest.' },
  'setup.step5.title': { en: 'You\'re set!', fr: 'C\'est prêt !', es: '¡Listo!', de: 'Fertig!' },
  'setup.step5.desc': { en: 'Use your shortcuts to capture. The preview appears with Copy, Edit and Save options.', fr: 'Utilisez vos raccourcis pour capturer. La preview apparaît avec les options Copier, Éditer et Sauvegarder.', es: 'Usa tus atajos para capturar. La vista previa aparece con opciones de Copiar, Editar y Guardar.', de: 'Verwenden Sie Ihre Verknüpfungen zum Erfassen. Die Vorschau wird mit den Optionen Kopieren, Bearbeiten und Speichern angezeigt.' },
  'setup.build.title': { en: 'Build from source', fr: 'Compiler depuis les sources', es: 'Compilar desde el código', de: 'Aus dem Quellcode erstellen' },
  'setup.build.desc': { en: 'If you prefer to build it yourself:', fr: 'Si vous préférez le compiler vous-même :', es: 'Si prefieres compilarlo tú mismo:', de: 'Wenn Sie es selbst erstellen möchten:' },
  'setup.build.requires': { en: 'Requires macOS 15+ and Swift 6.2.', fr: 'Nécessite macOS 15+ et Swift 6.2.', es: 'Requiere macOS 15+ y Swift 6.2.', de: 'Erfordert macOS 15+ und Swift 6.2.' },

  // Features grid
  'features.title': { en: 'Everything you need', fr: 'Tout ce qu\'il vous faut', es: 'Todo lo que necesitas', de: 'Alles, was Sie brauchen' },
  'features.subtitle': { en: 'Powerful features, zero complexity.', fr: 'Des fonctionnalités puissantes, sans complexité.', es: 'Funciones potentes, sin complejidad.', de: 'Leistungsstarke Funktionen, null Komplexität.' },

  'feature.capture.title': { en: 'Quick capture', fr: 'Capture rapide', es: 'Captura rápida', de: 'Schnelle Erfassung' },
  'feature.capture.desc': { en: 'Full screen, area, or window with configurable global hotkeys.', fr: 'Plein écran, zone ou fenêtre avec raccourcis globaux configurables.', es: 'Pantalla completa, zona o ventana con atajos globales configurables.', de: 'Vollbild, Bereich oder Fenster mit konfigurierbaren globalen Hotkeys.' },
  'feature.ocr.title': { en: 'Built-in OCR', fr: 'OCR intégré', es: 'OCR integrado', de: 'Integrierte OCR' },
  'feature.ocr.desc': { en: 'Extract text from any area of your screen. Offline, instant.', fr: 'Extrayez le texte de n\'importe quelle zone. Hors-ligne, instantané.', es: 'Extrae texto de cualquier zona de tu pantalla. Sin conexión, instantáneo.', de: 'Extrahieren Sie Text aus jedem Bereich des Bildschirms. Offline, sofort.' },
  'feature.preview.title': { en: 'Floating preview', fr: 'Preview flottante', es: 'Vista previa flotante', de: 'Schwebende Vorschau' },
  'feature.preview.desc': { en: 'Copy, edit, save or drag & drop right from the preview.', fr: 'Copiez, éditez, sauvegardez ou glissez-déposez depuis la preview.', es: 'Copia, edita, guarda o arrastra desde la vista previa.', de: 'Kopieren, bearbeiten, speichern oder Ziehen & Ablegen direkt aus der Vorschau.' },
  'feature.editor.title': { en: 'Full editor', fr: 'Éditeur complet', es: 'Editor completo', de: 'Vollständiger Editor' },
  'feature.editor.desc': { en: '11 tools: arrows, text, blur, numbered steps, freehand draw & more.', fr: '11 outils : flèches, texte, flou, numéros, dessin libre et plus.', es: '11 herramientas: flechas, texto, desenfoque, números, dibujo libre y más.', de: '11 Tools: Pfeile, Text, Unschärfe, nummerierte Schritte, Freihandzeichnen und mehr.' },
  'feature.background.title': { en: 'Backgrounds', fr: 'Arrière-plans', es: 'Fondos', de: 'Hintergründe' },
  'feature.background.desc': { en: 'Gradient or solid backgrounds with padding, corners & shadow.', fr: 'Dégradés ou couleurs unies avec padding, coins arrondis et ombre.', es: 'Fondos degradados o sólidos con padding, esquinas redondeadas y sombra.', de: 'Verlaufs- oder Volltonhintergründe mit Abstand, Ecken und Schatten.' },
  'feature.history.title': { en: 'Capture history', fr: 'Historique', es: 'Historial', de: 'Erfassungsverlauf' },
  'feature.history.desc': { en: 'Browse, re-edit, copy, or drag recent captures.', fr: 'Parcourez, ré-éditez, copiez ou glissez vos captures récentes.', es: 'Navega, reedita, copia o arrastra tus capturas recientes.', de: 'Durchsuchen, erneut bearbeiten, kopieren oder ziehen Sie kürzliche Erfassungen.' },
  'feature.update.title': { en: 'Auto-update', fr: 'Mise à jour auto', es: 'Actualización auto', de: 'Automatische Aktualisierung' },
  'feature.update.desc': { en: 'Built-in Sparkle updater. Always stay on the latest version.', fr: 'Mise à jour intégrée via Sparkle. Toujours à jour.', es: 'Actualización integrada con Sparkle. Siempre al día.', de: 'Integrierter Sparkle-Updater. Bleiben Sie immer auf dem neuesten Stand.' },
  'feature.bilingual.title': { en: 'Multilingual', fr: 'Multilingue', es: 'Multilingüe', de: 'Mehrsprachig' },
  'feature.bilingual.desc': { en: 'Full French, English and Spanish interface. Follows your system language.', fr: 'Interface complète en français, anglais et espagnol. Suit la langue système.', es: 'Interfaz completa en francés, inglés y español. Sigue el idioma del sistema.', de: 'Vollständige französische, englische, spanische und deutsche Oberfläche. Folgt Ihrer Systemsprache.' },

  // Feature sections
  'section.capture.title': { en: 'Capture in a flash', fr: 'Capturez en un éclair', es: 'Captura en un instante', de: 'Erfassen Sie im Handumdrehen' },
  'section.capture.desc': { en: 'Full screen, area or window, with a floating preview that lets you copy, edit, save or drag & drop instantly.', fr: 'Plein écran, zone ou fenêtre, avec une preview flottante pour copier, éditer, sauvegarder ou glisser-déposer instantanément.', es: 'Pantalla completa, zona o ventana, con una vista previa flotante para copiar, editar, guardar o arrastrar al instante.', de: 'Vollbild, Bereich oder Fenster mit schwebender Vorschau zum sofortigen Kopieren, Bearbeiten, Speichern oder Ziehen und Ablegen.' },
  'section.editor.title': { en: 'Annotate with precision', fr: 'Annotez avec précision', es: 'Anota con precisión', de: 'Kommentieren Sie präzise' },
  'section.editor.desc': { en: 'Arrows, text, blur, numbered steps, freehand draw and more. Everything you need to communicate visually.', fr: 'Flèches, texte, flou, numéros, dessin libre et plus. Tout pour communiquer visuellement.', es: 'Flechas, texto, desenfoque, números, dibujo libre y más. Todo para comunicar visualmente.', de: 'Pfeile, Text, Unschärfe, nummerierte Schritte, Freihandzeichnen und mehr. Alles, was Sie zur visuellen Kommunikation benötigen.' },
  'section.ocr.title': { en: 'Built-in text recognition', fr: 'Reconnaissance de texte intégrée', es: 'Reconocimiento de texto integrado', de: 'Integrierte Texterkennung' },
  'section.ocr.desc': { en: 'Select any area, Orby extracts the text instantly and copies it to your clipboard. Offline, powered by Apple Vision.', fr: 'Sélectionnez une zone, Orby extrait le texte instantanément et le copie dans votre presse-papier. Hors-ligne, propulsé par Apple Vision.', es: 'Selecciona cualquier zona, Orby extrae el texto al instante y lo copia al portapapeles. Sin conexión, con Apple Vision.', de: 'Wählen Sie einen Bereich, Orby extrahiert den Text sofort und kopiert ihn in die Zwischenablage. Offline, mit Apple Vision.' },
  'section.background.title': { en: 'Beautiful backgrounds', fr: 'De beaux arrière-plans', es: 'Fondos elegantes', de: 'Wunderschöne Hintergründe' },
  'section.background.desc': { en: 'Add gradient backgrounds, padding, rounded corners and shadows. Make your screenshots shine like the pros.', fr: 'Ajoutez des dégradés, du padding, des coins arrondis et des ombres. Comme les pros.', es: 'Añade fondos degradados, padding, esquinas redondeadas y sombras. Como los profesionales.', de: 'Fügen Sie Verlaufshintergründe, Abstand, abgerundete Ecken und Schatten hinzu. Lassen Sie Ihre Screenshots wie die Profis glänzen.' },
  'section.share.title': { en: 'Share anywhere', fr: 'Partagez partout', es: 'Comparte en cualquier lugar', de: 'Teilen Sie überall' },
  'section.share.desc': { en: 'AirDrop, Messages, Mail or save anywhere with ⌘S. Your screenshots, your way.', fr: 'AirDrop, Messages, Mail ou sauvegardez où vous voulez avec ⌘S.', es: 'AirDrop, Mensajes, Mail o guarda donde quieras con ⌘S.', de: 'AirDrop, Nachrichten, Mail oder überall mit ⌘S speichern. Ihre Screenshots, Ihre Art.' },

  // Shortcuts
  'shortcuts.title': { en: 'Keyboard first', fr: 'Le clavier avant tout', es: 'El teclado primero', de: 'Tastatur zuerst' },
  'shortcuts.subtitle': { en: 'Every tool, one keystroke away.', fr: 'Chaque outil, à une touche.', es: 'Cada herramienta, a una tecla.', de: 'Jedes Tool nur einen Tastenanschlag entfernt.' },
  'shortcuts.tools': { en: 'Editor tools', fr: 'Outils éditeur', es: 'Herramientas del editor', de: 'Editorwerkzeuge' },
  'shortcuts.actions': { en: 'Actions', fr: 'Actions', es: 'Acciones', de: 'Aktionen' },

  // CTA
  'cta.title1': { en: 'Ready to try', fr: 'Prêt à essayer', es: '¿Listo para probar', de: 'Bereit zum Ausprobieren' },
  'cta.title2': { en: 'Orby', fr: 'Orby', es: 'Orby', de: 'Orby' },
  'cta.subtitle': { en: 'Free forever. Open source. No account needed.', fr: 'Gratuit pour toujours. Open source. Aucun compte requis.', es: 'Gratis para siempre. Open source. Sin cuenta necesaria.', de: 'Für immer kostenlos. Open Source. Kein Konto erforderlich.' },
  'cta.download': { en: 'Download for macOS', fr: 'Télécharger pour macOS', es: 'Descargar para macOS', de: 'Für macOS herunterladen' },
  'cta.github': { en: 'View source on GitHub', fr: 'Voir le code sur GitHub', es: 'Ver código en GitHub', de: 'Quellcode auf GitHub ansehen' },
  'cta.requires': { en: 'Requires macOS 15 (Sequoia) or later', fr: 'Nécessite macOS 15 (Sequoia) ou ultérieur', es: 'Requiere macOS 15 (Sequoia) o posterior', de: 'Erfordert macOS 15 (Sequoia) oder höher' },

  // Changelog page
  'changelog.title': { en: 'Changelog', fr: 'Historique des versions', es: 'Registro de cambios', de: 'Änderungsprotokoll' },
  'changelog.subtitle': { en: 'Latest updates and improvements.', fr: 'Dernières mises à jour et améliorations.', es: 'Últimas actualizaciones y mejoras.', de: 'Neueste Updates und Verbesserungen.' },
  'changelog.loading': { en: 'Loading releases...', fr: 'Chargement des versions...', es: 'Cargando versiones...', de: 'Versionen werden geladen...' },
  'changelog.showMore': { en: 'Read more', fr: 'Lire plus', es: 'Leer más', de: 'Mehr lesen' },
  'changelog.showLess': { en: 'Read less', fr: 'Lire moins', es: 'Leer menos', de: 'Weniger lesen' },
  'changelog.showAll': { en: 'See all releases', fr: 'Voir toutes les versions', es: 'Ver todas las versiones', de: 'Alle Versionen anzeigen' },
  'changelog.hideAll': { en: 'Show less', fr: 'Réduire', es: 'Reducir', de: 'Weniger anzeigen' },
  'changelog.noReleases': { en: 'No releases found', fr: 'Aucune version trouvée', es: 'No se encontraron versiones', de: 'Keine Versionen gefunden' },

  // Footer
  'footer.made': { en: 'Made by', fr: 'Créé par', es: 'Hecho por', de: 'Erstellt von' },
}

const langs: { code: Lang; label: string }[] = [
  { code: 'en', label: 'English' },
  { code: 'fr', label: 'Français' },
  { code: 'es', label: 'Español' },
  { code: 'de', label: 'Deutsch' },
]

const currentLang = ref<Lang>('en')

export function useI18n() {
  function t(key: string): string {
    return translations[key]?.[currentLang.value] ?? key
  }

  function setLang(lang: Lang) {
    currentLang.value = lang
    if (import.meta.client) {
      localStorage.setItem('lang', lang)
    }
  }

  // Priority: URL param > localStorage > browser detection
  if (import.meta.client) {
    const urlLang = new URLSearchParams(window.location.search).get('lang')
    if (urlLang === 'fr' || urlLang === 'en' || urlLang === 'es' || urlLang === 'de') {
      currentLang.value = urlLang
      localStorage.setItem('lang', urlLang)
    } else if (localStorage.getItem('lang')) {
      currentLang.value = (localStorage.getItem('lang') as Lang)
    } else {
      const browserLang = navigator.language.toLowerCase()
      if (browserLang.startsWith('fr')) currentLang.value = 'fr'
      else if (browserLang.startsWith('es')) currentLang.value = 'es'
      else if (browserLang.startsWith('de')) currentLang.value = 'de'
      else currentLang.value = 'en'
    }
  }

  return { t, lang: currentLang, langs, setLang }
}
