import Foundation

/// Résout une clé d'une table de chaînes, avec la possibilité de forcer une langue.
///
/// Les surfaces du §8 et du §9 assemblent leurs libellés : un décompte, un nom d'application,
/// un accord singulier/pluriel. Ces assemblages doivent pouvoir être relus **langue par
/// langue**, ce que `L.t` ne permet pas puisqu'il suit la langue de l'utilisateur. Sans
/// `language`, la résolution repasse exactement par `L.t` : le chemin d'exécution reste celui
/// du reste de l'interface, seule la relecture par les tests emprunte la variante explicite.
enum LocalizedTable {
    /// Chaîne brute d'une table.
    static func string(_ key: String, table: L.Table, language: String? = nil) -> String {
        guard let language, let catalog = catalog(for: language) else {
            return L.t(String.LocalizationValue(stringLiteral: key), table: table)
        }
        return catalog.localizedString(forKey: key, value: nil, table: table.rawValue)
    }

    /// Chaîne d'une table dont la valeur porte des marqueurs `printf` (`%@`, `%lld`).
    static func format(
        _ key: String,
        table: L.Table,
        language: String? = nil,
        _ arguments: CVarArg...
    ) -> String {
        String(format: string(key, table: table, language: language), arguments: arguments)
    }

    /// Langue effective de l'interface, telle que le catalogue la résoudra.
    static var interfaceLanguage: String {
        Bundle.module.preferredLocalizations.first ?? "fr"
    }

    /// Catégorie de pluriel utile ici, dans la version courte des règles CLDR : le français
    /// range **0 et 1** dans « one », l'anglais seulement 1.
    ///
    /// Deux clés explicites plutôt qu'un `.stringsdict` : le décompte du §9 n'a que deux
    /// formes, et un test peut alors vérifier la chaîne rendue au lieu du format.
    static func isSingular(_ count: Int, language: String? = nil) -> Bool {
        let code = language ?? interfaceLanguage
        return code.hasPrefix("fr") ? abs(count) < 2 : abs(count) == 1
    }

    /// Catalogue d'une langue précise. `nil` si la langue n'est pas embarquée.
    private static func catalog(for language: String) -> Bundle? {
        Bundle.module.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:))
    }
}
