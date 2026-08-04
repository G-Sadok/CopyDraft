import AppKit
import CopyDraftCore
import CopyDraftUI
import OSLog

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
    let settings: SettingsWindowController
    let onboarding: OnboardingWindowController
    let toasts = ToastPresenter()
    let about = AboutPanel()

    /// Journal de démarrage. Une erreur ici prive l'application de tout ce qu'elle promet :
    /// elle doit être lisible dans la Console, jamais avalée par un `try?`.
    static let log = Logger(subsystem: AppInfo.bundleIdentifier, category: "startup")

    init?(preferences: Preferences = Preferences()) {
        let stack: HistoryStack
        do {
            stack = try HistoryStack.make(preferences: preferences)
        } catch {
            Self.log.error("démarrage impossible — \(String(describing: error), privacy: .public)")
            return nil
        }

        self.preferences = preferences
        paths = stack.paths
        cipher = stack.cipher
        store = stack.store

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
        settings = SettingsWindowController(
            preferences: preferences, store: store, shortcuts: shortcuts
        )
        onboarding = OnboardingWindowController(permission: permission)
    }

    /// Branche les services entre eux, puis démarre capture, raccourcis et surveillance
    /// de l'autorisation.
    func start() {
        // Une seule langue pour les chaînes et les formateurs (FR-44).
        L.setLanguage(preferences.language)

        wirePopup()
        wireStatusItem()
        wireShortcuts()
        wireWindows()

        permission.start()
        capture.start()

        Task { await store.restore() }

        showOnboardingIfNeeded()
    }

    func stop() {
        // Les fichiers annexes de SQLite n'existent qu'après la première écriture : c'est
        // à l'extinction qu'on est sûr de les trouver.
        HistoryDatabase.restrictPermissions(at: paths.databaseURL)

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
                onClearAll: { [weak self] in self?.clearAll() },
                onContentHeight: { [weak self] height in
                    self?.popup.applyContentHeight(height)
                }
            )
        )

        // Habillage constant autour de la liste : champ de recherche, pied, marges et,
        // le cas échéant, bandeau de pause.
        popup.chromeHeight = { [weak self] in
            guard let self else { return 0 }
            return CD.Metric.searchHeight + CD.Metric.footerHeight
                + 4 * CD.Space.x1_5
                + (self.preferences.captureEnabled ? 0 : CD.Metric.searchHeight + CD.Space.x1_5)
        }

        // Hauteur recalculée à chaque ouverture et à chaque frappe : la liste change, la
        // popup suit, sans jamais dépasser 60 % de l'écran (FR-20).
        popup.preferredHeight = { [weak self] in
            guard let self else { return CD.Metric.popupHeightMin }
            let items = self.popupModel.visibleItems
            return CellHeightEstimator.popupHeight(
                for: items,
                pinnedCount: items.filter(\.pinned).count,
                visibleRows: self.preferences.visibleRows,
                visibleFrame: PopupController.visibleFrame(containing: NSEvent.mouseLocation),
                showsPauseBanner: !self.preferences.captureEnabled
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
            },
            pinned: { [weak self] _ in self?.toasts.showPinned() }
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
        statusItem.isAccessibilityGranted = { [weak self] in self?.permission.isGranted ?? true }
        statusItem.onRequestAccessibility = { [weak self] in self?.onboarding.show() }
        statusItem.onOpenSettings = { [weak self] in self?.openSettings() }
        statusItem.onAbout = { [weak self] in self?.about.show() }
        statusItem.onClearAll = { [weak self] in self?.clearAll() }
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

    /// Décide s'il faut ouvrir l'onboarding, et seulement alors (FR-47).
    ///
    /// Trois cas, et trois seulement :
    /// - **premier lancement** : l'utilisateur n'a jamais vu l'écran ;
    /// - **révocation** : l'autorisation était accordée, elle ne l'est plus ;
    /// - jamais autrement. Un utilisateur qui a répondu « Plus tard » ne doit pas retrouver
    ///   la même fenêtre à chaque démarrage — c'est ce harcèlement qu'on corrige ici.
    ///
    /// L'état est relu juste avant de décider : au lancement, l'autorisation met parfois un
    /// instant à être connue du système, et un écran affiché sur cette lecture prématurée
    /// donnerait à croire qu'une autorisation pourtant accordée n'a pas été prise en compte.
    private func showOnboardingIfNeeded() {
        permission.refresh()
        let granted = permission.isGranted

        if granted {
            preferences.accessibilityWasGranted = true
            return
        }

        let revoked = preferences.accessibilityWasGranted
        guard !preferences.hasCompletedOnboarding || revoked else { return }

        preferences.accessibilityWasGranted = false
        onboarding.show()
    }

    private func wireWindows() {
        settings.onClearAll = { [weak self] in self?.clearAll() }
        settings.onOpenAccessibilitySettings = {
            AccessibilityPermissionMonitor.openSystemSettings()
        }

        onboarding.onFinished = { [weak self] in
            self?.preferences.hasCompletedOnboarding = true
        }
        onboarding.onOpenSettings = { [weak self] in self?.openSettings() }

        // Une autorisation révoquée ramène l'onboarding : sans elle, le collage se replie
        // et l'utilisateur doit le savoir (FR-47, S-4.1).
        permission.onChange = { [weak self] granted in
            guard let self else { return }
            self.preferences.accessibilityWasGranted = granted

            // Une révocation en cours d'usage mérite l'écran : le collage vient de se replier
            // sous les doigts de l'utilisateur, il faut le lui dire.
            if !granted, self.preferences.hasCompletedOnboarding {
                self.onboarding.show()
            }
            // Autorisation accordée pendant que l'écran est ouvert : il a fait son office.
            if granted, self.onboarding.isVisible {
                self.preferences.hasCompletedOnboarding = true
            }
        }
    }

    // MARK: Actions

    /// Colle un élément : le contenu complet est relu ici, jamais conservé en mémoire (ADR-4).
    private func pasteItem(_ item: ClipItem, plainTextOnly: Bool) {
        let target = popup.pasteTarget
        popup.hide(reason: .selection)

        Task { [weak self] in
            guard let self, let content = await self.store.content(for: item.id) else { return }
            let outcome = await self.paste.paste(
                content, into: target, plainTextOnly: plainTextOnly
            )
            // Le toast dit ce qui s'est réellement passé, collage ou simple copie (FR-35).
            self.toasts.show(outcome)
        }
    }

    private func openSettings() {
        settings.show()
    }

    /// Vide l'historique, après la confirmation du §9 avec son décompte explicite.
    private func clearAll() {
        let result = ClearAllAlert.run(
            itemCount: store.items.count,
            pinnedCount: store.items.filter(\.pinned).count
        )
        guard result.confirmed else { return }

        preferences.clearAllKeepsPinned = result.keepsPinned
        Task { [weak self] in
            await self?.store.clearAll(keepingPinned: result.keepsPinned)
        }
    }

    private func copyItem(_ item: ClipItem) {
        Task { [weak self] in
            guard let self, let content = await self.store.content(for: item.id) else { return }
            self.paste.copy(content)
        }
    }
}
