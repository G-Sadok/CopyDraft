import AppKit
import CopyDraftCore
import SwiftUI

/// Fenêtre de réglages : 480 pt de large, hauteur variable selon l'onglet, non
/// redimensionnable, cinq onglets en barre d'outils (FR-43, §7).
///
/// La grammaire est celle des Réglages système : le titre de la fenêtre suit l'onglet actif,
/// la barre d'outils sert de barre d'onglets, et la hauteur s'ajuste au contenu — c'est le
/// contenu SwiftUI qui la dicte, jamais une constante par onglet.
///
/// Tout réglage s'applique immédiatement : cette fenêtre n'a ni bouton « Appliquer », ni
/// bouton « Annuler » (FR-46).
@MainActor
public final class SettingsWindowController {
    /// Ouvre le volet Accessibilité des Réglages système. À défaut, CopyDraft l'ouvre
    /// lui-même.
    public var onOpenAccessibilitySettings: (() -> Void)?
    /// Déclenche « Tout effacer… » — la confirmation du §9 appartient à l'appelant.
    public var onClearAll: (() -> Void)?

    private let preferences: Preferences
    private let store: HistoryStore
    private let shortcuts: ShortcutService
    private let launchAtLogin: LaunchAtLoginController
    private let excluded: ExcludedApplicationsModel
    private let permission: AccessibilityPermissionMonitor

    private var window: NSWindow?
    private var hosting: NSHostingController<SettingsRootView>?
    private var proxy: Proxy?
    private var tab: SettingsTab = .general

    public init(preferences: Preferences, store: HistoryStore, shortcuts: ShortcutService) {
        self.preferences = preferences
        self.store = store
        self.shortcuts = shortcuts
        self.launchAtLogin = LaunchAtLoginController()
        self.excluded = ExcludedApplicationsModel(preferences: preferences)
        self.permission = AccessibilityPermissionMonitor()
    }

    /// Affiche la fenêtre sur l'onglet demandé, en la créant au premier appel.
    public func show(tab: SettingsTab = .general) {
        // L'état réel des éléments d'ouverture peut avoir changé hors de CopyDraft.
        launchAtLogin.synchronize(with: preferences)
        permission.refresh()
        permission.start()

        let window = window ?? makeWindow()
        select(tab)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Onglet affiché — exposé pour les tests et pour rouvrir la fenêtre là où on l'a laissée.
    public var currentTab: SettingsTab { tab }

    // MARK: Construction

    private func makeWindow() -> NSWindow {
        let hosting = NSHostingController(rootView: rootView(for: tab))
        // La fenêtre prend la taille de son contenu : la hauteur suit l'onglet (§7).
        hosting.sizingOptions = [.preferredContentSize]

        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()

        let proxy = Proxy(controller: self)
        window.delegate = proxy

        let toolbar = NSToolbar(identifier: "settings")
        toolbar.delegate = proxy
        toolbar.displayMode = .iconAndLabel
        toolbar.allowsUserCustomization = false
        window.toolbar = toolbar
        window.toolbarStyle = .preference

        self.hosting = hosting
        self.proxy = proxy
        self.window = window
        return window
    }

    private func rootView(for tab: SettingsTab) -> SettingsRootView {
        SettingsRootView(
            tab: tab,
            preferences: preferences,
            store: store,
            launchAtLogin: launchAtLogin,
            excluded: excluded,
            permission: permission,
            shortcuts: shortcuts,
            onOpenAccessibilitySettings: { [weak self] in
                guard let self else { return }
                if let handler = onOpenAccessibilitySettings {
                    handler()
                } else {
                    AccessibilityPermissionMonitor.openSystemSettings()
                }
            },
            onClearAll: { [weak self] in self?.onClearAll?() }
        )
    }

    fileprivate func select(_ tab: SettingsTab) {
        self.tab = tab
        hosting?.rootView = rootView(for: tab)
        window?.title = tab.title
        window?.toolbar?.selectedItemIdentifier = tab.itemIdentifier
    }

    fileprivate func windowDidClose() {
        // Le sondage de la permission n'a pas à tourner quand la fenêtre est fermée.
        permission.stop()
    }

    // MARK: Barre d'outils et cycle de vie

    /// Délégué AppKit de la fenêtre et de sa barre d'outils.
    ///
    /// Séparé du contrôleur pour que celui-ci reste un objet Swift ordinaire : `NSToolbar` et
    /// `NSWindow` exigent un `NSObject`, pas leur propriétaire.
    private final class Proxy: NSObject, NSToolbarDelegate, NSWindowDelegate {
        private weak var controller: SettingsWindowController?

        init(controller: SettingsWindowController) {
            self.controller = controller
        }

        func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
            SettingsTab.allCases.map(\.itemIdentifier)
        }

        func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
            toolbarDefaultItemIdentifiers(toolbar)
        }

        func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
            toolbarDefaultItemIdentifiers(toolbar)
        }

        func toolbar(
            _ toolbar: NSToolbar,
            itemForItemIdentifier identifier: NSToolbarItem.Identifier,
            willBeInsertedIntoToolbar flag: Bool
        ) -> NSToolbarItem? {
            guard let tab = SettingsTab(itemIdentifier: identifier) else { return nil }
            let item = NSToolbarItem(itemIdentifier: identifier)
            item.label = tab.title
            item.paletteLabel = tab.title
            item.image = NSImage(
                systemSymbolName: tab.symbolName,
                accessibilityDescription: tab.title
            )
            item.target = self
            item.action = #selector(selectTab(_:))
            return item
        }

        @MainActor
        @objc private func selectTab(_ sender: NSToolbarItem) {
            guard let tab = SettingsTab(itemIdentifier: sender.itemIdentifier) else { return }
            controller?.select(tab)
        }

        func windowWillClose(_ notification: Notification) {
            controller?.windowDidClose()
        }
    }
}
