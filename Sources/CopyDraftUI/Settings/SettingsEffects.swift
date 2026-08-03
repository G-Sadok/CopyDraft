import AppKit
import CopyDraftCore

/// Applique le thème choisi à l'application entière (FR-45, FR-46).
///
/// « Système » laisse `NSApp.appearance` à `nil` : c'est macOS qui décide, y compris le
/// passage automatique au coucher du soleil (§7). Forcer l'apparence claire ou sombre est
/// l'exception, pas la règle.
public enum AppearanceApplier {
    public static func appearanceName(for theme: AppTheme) -> NSAppearance.Name? {
        switch theme {
        case .system: nil
        case .light: .aqua
        case .dark: .darkAqua
        }
    }

    /// Applique immédiatement : aucun bouton « Appliquer », aucun redémarrage (FR-46).
    @MainActor
    public static func apply(_ theme: AppTheme, to application: NSApplication = .shared) {
        application.appearance = appearanceName(for: theme).flatMap(NSAppearance.init(named:))
    }
}

/// Applique la langue d'interface choisie (FR-44).
///
/// La liste `AppleLanguages` est le seul levier qui vaille : elle commande la résolution des
/// catalogues pour toute l'application. « Système » retire la clé et rend la main aux
/// préférences de langue du Mac.
public enum LanguageApplier {
    /// Clé de préférence système, hors de `Preferences.Key` : elle n'appartient pas à
    /// CopyDraft, c'est macOS qui la lit.
    static let key = "AppleLanguages"

    public static func languageCodes(for language: AppLanguage) -> [String]? {
        switch language {
        case .system: nil
        case .french: ["fr"]
        case .english: ["en"]
        }
    }

    public static func apply(_ language: AppLanguage, to defaults: UserDefaults = .standard) {
        if let codes = languageCodes(for: language) {
            defaults.set(codes, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
