import AppKit

/// Les cinq onglets de la fenêtre de réglages (§7).
///
/// L'ordre de déclaration est celui de la barre d'outils : il n'est pas décoratif, c'est
/// celui du design system et celui que reprend la barre d'onglets.
public enum SettingsTab: String, CaseIterable, Sendable {
    case general
    case shortcut
    case popup
    case privacy
    case appearance

    /// Clé du libellé d'onglet, qui sert aussi de titre de fenêtre — comme les Réglages
    /// système, le titre suit l'onglet actif (§7).
    var titleKey: String.LocalizationValue {
        switch self {
        case .general: "tab.general"
        case .shortcut: "tab.shortcut"
        case .popup: "tab.popup"
        case .privacy: "tab.privacy"
        case .appearance: "tab.appearance"
        }
    }

    var title: String { L.t(titleKey, table: .settings) }

    /// Symbole SF le plus proche du glyphe dessiné au §7 : roue dentée, clavier, fenêtre,
    /// bouclier, cercle mi-rempli.
    var symbolName: String {
        switch self {
        case .general: "gearshape"
        case .shortcut: "keyboard"
        case .popup: "macwindow"
        case .privacy: "shield"
        case .appearance: "circle.lefthalf.filled"
        }
    }

    /// Identifiant de l'item de barre d'outils correspondant.
    var itemIdentifier: NSToolbarItem.Identifier {
        NSToolbarItem.Identifier("settings.\(rawValue)")
    }

    init?(itemIdentifier: NSToolbarItem.Identifier) {
        guard let match = Self.allCases.first(where: { $0.itemIdentifier == itemIdentifier }) else {
            return nil
        }
        self = match
    }
}
