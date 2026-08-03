import AppKit
import CopyDraftCore
import CopyDraftUI

/// Assemblage de l'application : un seul endroit où les services se connaissent.
///
/// L'ordre du montage suit celui de `docs/architecture.md` §5 : réglages → chiffrement →
/// base → historique → capture → interface. Tout ce qui peut échouer au démarrage (dossier
/// illisible, Trousseau indisponible) est traité comme une réinitialisation, jamais comme un
/// plantage : l'utilisateur retrouve une application vide plutôt qu'aucune application.
@MainActor
final class ServiceContainer {
    let preferences: Preferences
    let paths: AppPaths
    let cipher: Cipher
    let store: HistoryStore
    let monitor: ClipboardMonitor
    let capture: CaptureCoordinator
    let permission: AccessibilityPermissionMonitor
    let paste: PasteService
    let shortcuts: ShortcutService
    let popup: PopupController
    let popupModel: PopupViewModel
    let statusItem: StatusItemController

    init?(preferences: Preferences = Preferences()) {
        guard let paths = try? AppPaths.standard().createDirectories(),
            let key = try? KeyStore().loadOrCreate(),
            let queue = try? HistoryDatabase.open(at: paths.databaseURL)
        else { return nil }

        self.preferences = preferences
        self.paths = paths
        cipher = Cipher(key: key)

        store = HistoryStore(
            repository: HistoryRepository(queue: queue, cipher: cipher),
            imageStore: ImageStore(paths: paths, cipher: cipher),
            preferences: preferences
        )

        monitor = ClipboardMonitor(preferences: preferences)
        capture = CaptureCoordinator(
            monitor: monitor, store: store, preferences: preferences, cipher: cipher
        )

        permission = AccessibilityPermissionMonitor()
        paste = PasteService()
        shortcuts = ShortcutService()

        popupModel = PopupViewModel(store: store, preferences: preferences)
        popup = PopupController(preferences: preferences)
        statusItem = StatusItemController(store: store, preferences: preferences)
    }

    /// Branche les services entre eux, puis démarre capture, raccourcis et surveillance
    /// de l'autorisation.
    func start() {
        // Une seule langue pour les chaînes et les formateurs (FR-44).
        L.setLanguage(preferences.language)

        wirePopup()
        wireStatusItem()
        wireShortcuts()

        permission.start()
        capture.start()

        Task { await store.restore() }
    }

    func stop() {
        capture.stop()
        permission.stop()
        popup.hide()
    }

    // MARK: Branchements

    private func wirePopup() {
        popup.setContent(
            PopupView(
                model: popupModel,
                store: store,
                preferences: preferences,
                onResumeCapture: { [weak self] in
                    guard let self else { return }
                    self.preferences.captureEnabled.toggle()
                },
                onOpenSettings: { [weak self] in self?.openSettings() },
                onClearAll: { [weak self] in self?.clearAll() }
            )
        )

        // Hauteur recalculée à chaque ouverture et à chaque frappe : la liste change, la
        // popup suit, sans jamais dépasser 60 % de l'écran (FR-20).
        popup.preferredHeight = { [weak self] in
            guard let self else { return CD.Metric.popupHeightMin }
            let items = self.popupModel.visibleItems
            return PopupPositioner().height(
                itemCount: items.count,
                visibleRows: self.preferences.visibleRows,
                twoLineCount: items.filter(\.isTwoLine).count,
                visibleFrame: PopupController.visibleFrame(containing: NSEvent.mouseLocation)
            )
        }

        popupModel.actions = PopupViewModel.Actions(
            paste: { [weak self] item, plainTextOnly in
                self?.pasteItem(item, plainTextOnly: plainTextOnly)
            },
            copy: { [weak self] item in
                self?.copyItem(item)
            },
            dismiss: { [weak self] in
                self?.popup.hide(reason: .escape)
            },
            excludeApp: { [weak self] source in
                guard let self, let bundleIdentifier = source.bundleIdentifier else { return }
                self.preferences.excludedBundleIdentifiers.append(bundleIdentifier)
            }
        )

        popup.onCommand = { [weak self] command in
            self?.popupModel.handle(command) ?? false
        }
        popup.setSearchEmptyProvider { [weak self] in
            self?.popupModel.query.isEmpty ?? true
        }
        popup.statusItemFrame = { [weak self] in
            self?.statusItem.statusItemFrame
        }
        popup.onDismiss = { [weak self] _ in
            self?.popupModel.prepareForDisplay()
        }
    }

    private func wireStatusItem() {
        statusItem.onOpenPopup = { [weak self] underStatusItem in
            guard let self else { return }
            self.popupModel.prepareForDisplay()
            underStatusItem ? self.popup.showUnderStatusItem() : self.popup.show()
        }
        statusItem.onPaste = { [weak self] id in
            guard let self, let item = self.store.items.first(where: { $0.id == id }) else { return }
            self.pasteItem(item, plainTextOnly: false)
        }
    }

    private func wireShortcuts() {
        shortcuts.onOpenPopup = { [weak self] in
            guard let self else { return }
            if self.popup.isVisible {
                self.popup.hide()
            } else {
                self.popupModel.prepareForDisplay()
                self.popup.show()
            }
        }
        shortcuts.onOpenPopupPlainText = { [weak self] in
            guard let self else { return }
            self.popupModel.prepareForDisplay()
            self.popup.show()
        }
        shortcuts.start()
    }

    // MARK: Actions

    /// Colle un élément : le contenu complet est relu ici, jamais conservé en mémoire (ADR-4).
    private func pasteItem(_ item: ClipItem, plainTextOnly: Bool) {
        let target = popup.pasteTarget
        popup.hide(reason: .selection)

        Task { [weak self] in
            guard let self, let content = await self.store.content(for: item.id) else { return }
            _ = await self.paste.paste(content, into: target, plainTextOnly: plainTextOnly)
        }
    }

    /// Ouvre les réglages. Branché par l'epic E6.
    private func openSettings() {}

    /// Vide l'historique après confirmation. Branché par l'epic E7 (§9).
    private func clearAll() {
        Task { [weak self] in
            guard let self else { return }
            await self.store.clearAll(keepingPinned: self.preferences.clearAllKeepsPinned)
        }
    }

    private func copyItem(_ item: ClipItem) {
        Task { [weak self] in
            guard let self, let content = await self.store.content(for: item.id) else { return }
            self.paste.copy(content)
        }
    }
}
