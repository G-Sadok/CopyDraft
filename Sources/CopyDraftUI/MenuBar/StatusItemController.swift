import AppKit

/// Icône de CopyDraft dans la barre de menus et menu qui lui est attaché.
///
/// Squelette de la story S-0.1 : icône provisoire et menu réduit à « Quitter ».
/// Le glyphe définitif (18 × 18, *template image*, état de pause à 40 %) et le menu
/// d'accès rapide complet arrivent avec l'epic E5.
@MainActor
public final class StatusItemController {
    private let statusItem: NSStatusItem

    public init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        configureButton()
        statusItem.menu = makeMenu()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        let image = NSImage(
            systemSymbolName: "doc.on.clipboard",
            accessibilityDescription: L.t("statusItem.accessibilityLabel")
        )
        image?.isTemplate = true
        button.image = image
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        let quit = NSMenuItem(
            title: L.t("menu.quit"),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quit.target = NSApp
        menu.addItem(quit)
        return menu
    }
}
