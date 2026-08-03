import AppKit
import CopyDraftUI

/// Cycle de vie de l'agent CopyDraft.
///
/// L'application n'a ni icône de Dock ni fenêtre au lancement : elle vit dans la barre
/// de menus (`LSUIElement`, politique d'activation `.accessory`).
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItemController = StatusItemController()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}
