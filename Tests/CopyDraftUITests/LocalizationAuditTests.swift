import Foundation
import Testing

@testable import CopyDraftUI

/// Audit transversal des catalogues (NFR-13).
///
/// Les tests de chaque surface vérifient leurs propres clés ; celui-ci vérifie qu'aucune
/// table ne dérive : même liste de clés en français et en anglais, aucune valeur vide,
/// aucune traduction laissée identique à la clé.
@Suite("Audit des traductions")
struct LocalizationAuditTests {
    private static let resourcesDirectory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // CopyDraftUITests
        .deletingLastPathComponent()  // Tests
        .deletingLastPathComponent()  // racine du dépôt
        .appendingPathComponent("Sources/CopyDraftUI/Resources")

    private static func tables() throws -> [String] {
        let french = Self.resourcesDirectory.appendingPathComponent("fr.lproj")
        let files = try FileManager.default.contentsOfDirectory(atPath: french.path)
        return files.filter { $0.hasSuffix(".strings") }.map {
            String($0.dropLast(".strings".count))
        }.sorted()
    }

    private static func keys(table: String, language: String) throws -> [String: String] {
        let url =
            resourcesDirectory
            .appendingPathComponent("\(language).lproj")
            .appendingPathComponent("\(table).strings")
        guard let data = try? Data(contentsOf: url) else { return [:] }
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return plist as? [String: String] ?? [:]
    }

    @Test("Chaque table existe dans les deux langues avec les mêmes clés")
    func tablesMatch() throws {
        for table in try Self.tables() {
            let french = try Self.keys(table: table, language: "fr")
            let english = try Self.keys(table: table, language: "en")

            #expect(!french.isEmpty, "table \(table) vide en français")
            #expect(
                Set(french.keys) == Set(english.keys),
                """
                table \(table) désynchronisée — \
                manquantes en anglais : \(Set(french.keys).subtracting(english.keys).sorted()), \
                manquantes en français : \(Set(english.keys).subtracting(french.keys).sorted())
                """
            )
        }
    }

    @Test("Aucune traduction n'est vide ni laissée à l'état de clé")
    func translationsAreReal() throws {
        for table in try Self.tables() {
            for language in ["fr", "en"] {
                for (key, value) in try Self.keys(table: table, language: language) {
                    #expect(!value.isEmpty, "\(table)/\(language) : « \(key) » est vide")
                    #expect(
                        value != key,
                        "\(table)/\(language) : « \(key) » n'est pas traduite"
                    )
                }
            }
        }
    }

    /// Les chaînes françaises portent des accents : une table entière sans caractère accentué
    /// trahit presque toujours un copier-coller de l'anglais.
    @Test("Les catalogues français ne sont pas de l'anglais recopié")
    func frenchLooksFrench() throws {
        for table in try Self.tables() {
            let french = try Self.keys(table: table, language: "fr")
            let english = try Self.keys(table: table, language: "en")

            let identiques = french.filter { key, value in
                english[key] == value && value.count > 12
            }
            #expect(
                identiques.count < max(2, french.count / 3),
                "table \(table) : trop de chaînes identiques en français et en anglais — \(identiques.keys.sorted())"
            )
        }
    }
}

/// Le réglage de langue doit gouverner **à la fois** les chaînes et les formateurs :
/// une interface anglaise ne doit pas afficher « il y a 4 min ».
@Suite("Réglage de langue")
struct LanguageSelectionTests {
    @Test("Choisir une langue change les chaînes et la locale ensemble")
    func languageDrivesBoth() {
        L.setLanguage(.french)
        #expect(L.locale.language.languageCode?.identifier == "fr")
        let french = L.t("popup.section.pinned")

        L.setLanguage(.english)
        #expect(L.locale.language.languageCode?.identifier == "en")
        let english = L.t("popup.section.pinned")

        #expect(french == "Épinglés")
        #expect(english == "Pinned")

        L.setLanguage(.system)
    }

    @Test("« Système » rend la main aux réglages du Mac")
    func systemFollowsMac() {
        L.setLanguage(.system)
        #expect(L.locale == .current)
        #expect(L.bundle == Bundle.module)
    }
}
