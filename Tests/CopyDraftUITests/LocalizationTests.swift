import Foundation
import Testing

@testable import CopyDraftUI

@Suite("Localisation")
struct LocalizationTests {
    /// Clés utilisées par l'interface au stade S-0.1. La liste grandit avec les surfaces :
    /// toute clé ajoutée ici doit exister dans les deux catalogues (NFR-13).
    static let keys = ["menu.quit", "statusItem.accessibilityLabel"]

    @Test("Chaque clé est traduite en français et en anglais", arguments: ["fr", "en"])
    func everyKeyIsTranslated(language: String) throws {
        let bundle = try #require(
            Bundle.module.path(forResource: language, ofType: "lproj").map(Bundle.init(path:)) ?? nil,
            "catalogue \(language).lproj introuvable"
        )

        for key in Self.keys {
            let value = bundle.localizedString(forKey: key, value: nil, table: nil)
            #expect(value != key, "clé « \(key) » non traduite en \(language)")
            #expect(!value.isEmpty)
        }
    }

    @Test("La résolution passe par le catalogue de CopyDraftUI")
    func resolverUsesModuleBundle() {
        #expect(L.t("menu.quit") != "menu.quit")
    }
}
