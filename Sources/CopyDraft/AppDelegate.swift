import AppKit
import CopyDraftCore
import CopyDraftUI

/// Cycle de vie de l'agent CopyDraft.
///
/// L'application n'a ni icône de Dock ni fenêtre au lancement : elle vit dans la barre
/// de menus (`LSUIElement`, politique d'activation `.accessory`).
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?
    private var historyStore: HistoryStore?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let preferences = Preferences()
        guard let store = Self.makeHistoryStore(preferences: preferences) else {
            NSApp.terminate(nil)
            return
        }
        historyStore = store
        statusItemController = StatusItemController(store: store, preferences: preferences)
        Task { await store.restore() }
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    /// Assemble l'historique persistant : dossiers, clé de chiffrement, base, images.
    ///
    /// Raccordement minimal de l'epic E5 — l'assemblage complet de l'application (capture,
    /// popup, réglages) revient aux epics suivants.
    private static func makeHistoryStore(preferences: Preferences) -> HistoryStore? {
        guard let paths = try? AppPaths.standard().createDirectories(),
            let key = try? KeyStore().loadOrCreate(),
            let queue = try? HistoryDatabase.open(at: paths.databaseURL)
        else { return nil }

        let cipher = Cipher(key: key)
        return HistoryStore(
            repository: HistoryRepository(queue: queue, cipher: cipher),
            imageStore: ImageStore(paths: paths, cipher: cipher),
            preferences: preferences
        )
    }
}
