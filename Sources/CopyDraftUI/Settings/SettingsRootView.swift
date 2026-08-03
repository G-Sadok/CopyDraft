import CopyDraftCore
import KeyboardShortcuts
import SwiftUI

/// Contenu de la fenêtre de réglages : l'onglet actif, et rien d'autre.
///
/// La barre d'onglets appartient à la barre d'outils de la fenêtre (§7) : elle est dessinée
/// par AppKit, pas ici. Chaque onglet fixe sa propre hauteur, c'est elle qui commande celle
/// de la fenêtre.
struct SettingsRootView: View {
    let tab: SettingsTab
    let preferences: Preferences
    let store: HistoryStore
    let launchAtLogin: LaunchAtLoginController
    let excluded: ExcludedApplicationsModel
    let permission: AccessibilityPermissionMonitor
    let shortcuts: ShortcutService
    let onOpenAccessibilitySettings: () -> Void
    let onClearAll: () -> Void

    var body: some View {
        switch tab {
        case .general:
            GeneralSettingsView(preferences: preferences, launchAtLogin: launchAtLogin)
        case .shortcut:
            ShortcutSettingsView(
                preferences: preferences,
                isAccessibilityGranted: permission.isGranted,
                hasOpenPopupShortcut: shortcuts.hasOpenPopupShortcut,
                onOpenAccessibilitySettings: onOpenAccessibilitySettings
            ) { name in
                KeyboardShortcuts.Recorder(for: name)
            }
        case .popup:
            PopupSettingsView(preferences: preferences)
        case .privacy:
            PrivacySettingsView(
                preferences: preferences,
                excluded: excluded,
                canClearHistory: !store.items.isEmpty,
                onClearAll: onClearAll
            )
        case .appearance:
            AppearanceSettingsView(
                preferences: preferences,
                onOpenAccessibilitySettings: onOpenAccessibilitySettings
            )
        }
    }
}
