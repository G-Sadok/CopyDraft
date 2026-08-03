import Foundation

/// Point d'accès unique aux chaînes localisées de l'interface.
///
/// Aucune chaîne visible par l'utilisateur ne doit être écrite en dur dans une vue : elle
/// passe toujours par `L.t(_:)`, qui résout la clé dans les catalogues de `CopyDraftUI`.
///
/// Les surfaces volumineuses ont leur propre table (`Settings`, `Onboarding`, `Feedback`,
/// `MenuBar`) : les catalogues restent lisibles et deux surfaces ne se disputent jamais le
/// même fichier.
public enum L {
    public static func t(_ key: String.LocalizationValue) -> String {
        String(localized: key, bundle: .module)
    }

    /// Chaîne d'une table dédiée, par exemple `L.t("general.launch", table: .settings)`.
    public static func t(_ key: String.LocalizationValue, table: Table) -> String {
        String(localized: key, table: table.rawValue, bundle: .module)
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
