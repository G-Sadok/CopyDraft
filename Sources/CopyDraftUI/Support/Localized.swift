import Foundation

/// Point d'accès unique aux chaînes localisées de l'interface.
///
/// Aucune chaîne visible par l'utilisateur ne doit être écrite en dur dans une vue :
/// elle passe toujours par `L.t(_:)`, qui résout la clé dans le catalogue de `CopyDraftUI`.
public enum L {
    public static func t(_ key: String.LocalizationValue) -> String {
        String(localized: key, bundle: .module)
    }
}
