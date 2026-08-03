import AppKit
import CopyDraftCore
import CopyDraftUI

/// Cycle de vie de l'agent CopyDraft.
///
/// L'application n'a ni icône de Dock ni fenêtre au lancement : elle vit dans la barre
/// de menus (`LSUIElement`, politique d'activation `.accessory`). Tout l'assemblage est
/// délégué à `ServiceContainer` ; ce délégué ne gère que le démarrage et l'extinction.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var services: ServiceContainer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let services = ServiceContainer() else {
            // Ni dossier de données ni clé : sans eux, rien de ce que promet l'application
            // ne peut fonctionner, et continuer donnerait une capture qui ne garde rien.
            NSApp.terminate(nil)
            return
        }

        self.services = services
        services.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        services?.stop()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}
