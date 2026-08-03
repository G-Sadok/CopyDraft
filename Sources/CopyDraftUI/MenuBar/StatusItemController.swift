import AppKit
import CopyDraftCore
import Observation

// MARK: - Icône et menu de la barre de menus (§6)

/// Présence de CopyDraft dans la barre de menus.
///
/// L'application est un agent (FR-39) : cet objet est sa seule surface permanente. Il tient
/// l'icône et ses deux états, et transforme un clic en menu ou en popup. Il n'exécute
/// lui-même que ce qui lui appartient — la bascule de pause et la fin de l'application ;
/// tout le reste part vers l'assemblage par des fermetures, pour qu'aucune fenêtre ne soit
/// construite ici.
@MainActor
public final class StatusItemController {
    // MARK: Raccordement

    /// Ouvrir la popup. `underStatusItem` est vrai pour un ⌥-clic : la popup doit alors
    /// s'afficher sous l'icône, quelle que soit la position configurée (FR-41).
    public var onOpenPopup: ((_ underStatusItem: Bool) -> Void)?
    /// Coller un élément choisi dans le menu, exactement comme depuis la popup.
    public var onPaste: ((UUID) -> Void)?
    public var onOpenSettings: (() -> Void)?
    /// Ouvre la confirmation « Tout effacer » du §9 — jamais l'effacement direct (FR-12).
    public var onClearAll: (() -> Void)?
    public var onAbout: (() -> Void)?

    /// Cadre de l'icône en coordonnées écran, pour la position « sous la barre de menus ».
    ///
    /// `nil` tant que l'élément de statut n'a pas de fenêtre — au tout début du lancement, ou
    /// si la barre de menus est saturée et l'a masqué.
    public var statusItemFrame: CGRect? {
        guard let button = statusItem.button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    // MARK: État

    private let statusItem: NSStatusItem
    private let store: HistoryStore
    private let preferences: Preferences
    private let builder = QuickMenuBuilder()

    private var isPaused: Bool { !preferences.captureEnabled }

    public init(store: HistoryStore, preferences: Preferences) {
        self.store = store
        self.preferences = preferences
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        configureButton()
        updateIcon()
        observeCapture()
    }

    // MARK: Icône

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(handleClick)
        // Le menu n'est pas attaché en permanence : il faut voir passer le clic pour
        // distinguer un ⌥-clic d'un clic simple.
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func updateIcon() {
        statusItem.button?.image = StatusItemIcon.image(paused: isPaused)
    }

    /// Suit `captureEnabled` pour atténuer l'icône dès que la capture est suspendue.
    ///
    /// `withObservationTracking` ne notifie qu'une fois : la ré-inscription au tour suivant
    /// est ce qui rend l'observation durable. Le saut par `Task` laisse la valeur être écrite
    /// avant d'être relue.
    private func observeCapture() {
        withObservationTracking {
            _ = preferences.captureEnabled
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.updateIcon()
                self.observeCapture()
            }
        }
    }

    // MARK: Clic

    @objc private func handleClick() {
        let isAlternate = NSApp.currentEvent?.modifierFlags.contains(.option) ?? false
        if isAlternate {
            onOpenPopup?(true)
        } else {
            showMenu()
        }
    }

    private func showMenu() {
        let menu = makeMenu()
        // Attaché le temps du clic seulement : reposé, l'élément de statut doit rendre la
        // main à `handleClick`.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    // MARK: Menu

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.minimumWidth = CD.Metric.menuWidth

        for item in builder.items(from: store.items, isPaused: isPaused) {
            menu.addItem(makeMenuItem(item))
        }

        #if DEBUG
            menu.addItem(.separator())
            let gallery = NSMenuItem(
                title: "Galerie de tokens",  // outil de développement, non localisé
                action: #selector(showTokenGallery),
                keyEquivalent: ""
            )
            gallery.target = self
            menu.addItem(gallery)
        #endif

        return menu
    }

    private func makeMenuItem(_ item: QuickMenuItem) -> NSMenuItem {
        switch item.action {
        case .separator:
            return .separator()
        case .sectionHeader:
            return .sectionHeader(title: item.title)
        default:
            break
        }

        let menuItem = NSMenuItem(
            title: item.title,
            action: #selector(performAction),
            keyEquivalent: item.keyEquivalent
        )
        menuItem.keyEquivalentModifierMask = item.modifiers
        menuItem.target = self
        menuItem.isEnabled = item.isEnabled
        menuItem.representedObject = item.action
        return menuItem
    }

    @objc private func performAction(_ sender: NSMenuItem) {
        guard let action = sender.representedObject as? QuickMenuItem.Action else { return }
        switch action {
        case .paste(let id):
            onPaste?(id)
        case .openPopup:
            onOpenPopup?(false)
        case .togglePause:
            preferences.captureEnabled.toggle()
        case .clearAll:
            onClearAll?()
        case .openSettings:
            onOpenSettings?()
        case .about:
            onAbout?()
        case .quit:
            NSApp.terminate(nil)
        case .separator, .sectionHeader:
            break
        }
    }

    #if DEBUG
        private let tokenGallery = TokenGalleryWindowController()

        @objc private func showTokenGallery() {
            tokenGallery.show()
        }
    #endif
}
