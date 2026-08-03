import Foundation

/// Position d'ouverture de la popup (§7 · onglet Popup).
public enum PopupPosition: String, CaseIterable, Sendable {
    /// Au curseur, coin supérieur gauche à +12 / +12 — comportement Windows.
    case cursor
    /// Centrée sur l'écran actif.
    case centered
    /// Sous l'icône de la barre de menus.
    case menuBar
}

/// Apparence de l'application (§7 · onglet Apparence).
public enum AppTheme: String, CaseIterable, Sendable {
    case system
    case light
    case dark
}

/// Langue de l'interface (§7 · onglet Général).
public enum AppLanguage: String, CaseIterable, Sendable {
    /// Suit les préférences de langue du système.
    case system
    case french = "fr"
    case english = "en"
}

/// Bornes et limites fixées par le PRD et le design system. Ce ne sont pas des réglages :
/// elles encadrent les réglages.
public enum Limits {
    /// Taille d'historique configurable (§7 : « de 10 à 500 »).
    public static let historySize = 10...500
    /// Éléments visibles avant défilement (§7 : « de 5 à 12 »).
    public static let visibleRows = 5...12
    /// Intervalle de sondage du presse-papiers, en secondes (NFR-4).
    public static let pollingInterval = 0.2...1.0
    /// Taille maximale d'un élément capturé — 4 Mo, aligné sur Windows (FR-7).
    public static let itemBytes = 4 * 1024 * 1024
    /// Nombre d'éléments repris dans le menu de la barre de menus (§6).
    public static let menuItems = 5
    /// Nombre d'indices ⌘n affichés dans la popup (§2.4).
    public static let quickPasteSlots = 10
}
