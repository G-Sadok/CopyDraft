import CopyDraftCore
import Foundation

/// Point d'accès unique aux chaînes localisées de l'interface.
///
/// Aucune chaîne visible par l'utilisateur ne doit être écrite en dur dans une vue : elle
/// passe toujours par `L.t(_:)`, qui résout la clé dans les catalogues de `CopyDraftUI`.
///
/// Les surfaces volumineuses ont leur propre table (`Settings`, `Onboarding`, `Feedback`,
/// `MenuBar`) : les catalogues restent lisibles et deux surfaces ne se disputent jamais le
/// même fichier.
///
/// **Une seule langue à l'écran.** Le réglage « Langue » (FR-44) fixe ici le catalogue *et*
/// le `Locale` des formateurs de dates, de nombres et de tailles : sans ce point commun, une
/// interface anglaise afficherait « il y a 4 min » sous ses cellules.
public enum L {
    /// Langue choisie par l'utilisateur, `nil` pour suivre le système.
    nonisolated(unsafe) private static var override: (bundle: Bundle, locale: Locale)?

    /// Applique le réglage de langue. À appeler au démarrage et à chaque changement.
    public static func setLanguage(_ language: AppLanguage) {
        guard language != .system,
            let path = Bundle.module.path(forResource: language.rawValue, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else {
            override = nil
            return
        }
        override = (bundle, Locale(identifier: language.rawValue))
    }

    /// Bundle dans lequel les chaînes sont résolues.
    public static var bundle: Bundle {
        override?.bundle ?? .module
    }

    /// Locale des formateurs. Suit le réglage de langue, sinon le système.
    public static var locale: Locale {
        override?.locale ?? .current
    }

    public static func t(_ key: String.LocalizationValue) -> String {
        String(localized: key, bundle: bundle, locale: locale)
    }

    /// Chaîne d'une table dédiée, par exemple `L.t("general.launch", table: .settings)`.
    public static func t(_ key: String.LocalizationValue, table: Table) -> String {
        String(localized: key, table: table.rawValue, bundle: bundle, locale: locale)
    }

    /// Tables de chaînes disponibles.
    public enum Table: String, Sendable {
        /// Table par défaut : popup et composants partagés.
        case main = "Localizable"
        case settings = "Settings"
        case onboarding = "Onboarding"
        case feedback = "Feedback"
        case menuBar = "MenuBar"
    }
}
