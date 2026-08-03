import CoreGraphics
import Foundation
import Testing

@testable import CopyDraftCore

@Suite("Aperçus et projection de recherche")
struct PreviewBuilderTests {
    private let builder = PreviewBuilder()

    private func content(_ value: String, kind: ClipKind = .text) -> CapturedContent {
        CapturedContent(kind: kind, text: value, byteCount: value.utf8.count)
    }

    private func image() -> CapturedContent {
        CapturedContent(
            kind: .image,
            imageData: Data([0x89, 0x50, 0x4E, 0x47]),
            pixelSize: CGSize(width: 1512, height: 982),
            byteCount: 4
        )
    }

    // MARK: Projection de recherche

    @Test("La projection de recherche ramène tout blanc à une espace simple")
    func searchTextNormalizesWhitespace() {
        let text = "  Sprint 24\n\n\tRevue   de   design\n jeudi 14 h  "
        #expect(builder.searchText(for: content(text)) == "Sprint 24 Revue de design jeudi 14 h")
    }

    @Test("Les fins de ligne Windows sont normalisées comme les autres")
    func searchTextNormalizesWindowsNewlines() {
        #expect(builder.searchText(for: content("Première\r\nSeconde\rTroisième")) == "Première Seconde Troisième")
    }

    @Test("La projection de recherche est plafonnée à 2 048 caractères")
    func searchTextIsCapped() {
        let long = String(repeating: "a", count: 10_000)
        let result = builder.searchText(for: content(long))
        #expect(result.count == ClipItem.searchTextLimit)
        #expect(result.count == 2_048)
    }

    @Test("Le plafond tient compte des blancs supprimés, pas du texte brut")
    func searchTextCapsAfterFlattening() {
        // Un contenu qui s'ouvre sur un mur de lignes vides doit tout de même remplir la
        // projection : la normalisation passe avant le plafonnement.
        let text = String(repeating: "\n", count: 5_000) + String(repeating: "b", count: 5_000)
        #expect(builder.searchText(for: content(text)).count == ClipItem.searchTextLimit)
    }

    @Test("Le plafond compte des caractères, pas des octets : les émojis restent entiers")
    func searchTextCountsCharacters() {
        let text = String(repeating: "🎉", count: 3_000)
        let result = builder.searchText(for: content(text))
        #expect(result.count == ClipItem.searchTextLimit)
        #expect(result.allSatisfy { $0 == "🎉" })

        let family = String(repeating: "👨‍👩‍👧‍👦", count: 10)
        #expect(builder.searchText(for: content(family)) == family)
    }

    @Test("Une image ne produit pas de texte de recherche")
    func searchTextForImageIsEmpty() {
        #expect(builder.searchText(for: image()).isEmpty)
    }

    @Test("Un contenu entièrement blanc donne une projection vide")
    func searchTextForBlankIsEmpty() {
        #expect(builder.searchText(for: content("  \n\t \r\n ")).isEmpty)
    }

    @Test("Une projection de recherche passe le constructeur de ClipItem sans être rognée")
    func searchTextFitsClipItem() {
        let long = String(repeating: "mot ", count: 5_000)
        let projection = builder.searchText(for: content(long))
        let item = ClipItem(
            kind: .text,
            subtype: .plain,
            createdAt: Date(),
            source: SourceApp(bundleIdentifier: "fr.exemple.app", name: "Exemple"),
            byteCount: long.utf8.count,
            searchText: projection,
            previewLines: builder.previewLines(for: content(long), subtype: .plain)
        )
        #expect(item.searchText == projection)
    }

    // MARK: Aperçu — image

    @Test("Une image ne produit aucune ligne d'aperçu")
    func previewForImageIsEmpty() {
        #expect(builder.previewLines(for: image(), subtype: .image).isEmpty)
        #expect(builder.previewLines(for: content("texte"), subtype: .image).isEmpty)
    }

    // MARK: Aperçu — code

    @Test("Le code garde ses deux premières lignes non vides, telles quelles")
    func codeKeepsFirstTwoLines() {
        let snippet = """
            func startMonitoring() {
                timer = Timer.scheduledTimer(
                    withTimeInterval: 0.4, repeats: true
                )
            }
            """
        #expect(
            builder.previewLines(for: content(snippet), subtype: .code) == [
                "func startMonitoring() {",
                "    timer = Timer.scheduledTimer(",
            ]
        )
    }

    @Test("L'indentation commune est retirée, l'indentation relative conservée")
    func codeIsDedented() {
        let snippet = """
                    timer = Timer.scheduledTimer(
                        withTimeInterval: 0.4
                    )
            """
        #expect(
            builder.previewLines(for: content(snippet), subtype: .code) == [
                "timer = Timer.scheduledTimer(",
                "    withTimeInterval: 0.4",
            ]
        )
    }

    @Test("Les lignes vides en tête et entre deux lignes de code sont ignorées")
    func codeSkipsBlankLines() {
        let snippet = "\n   \nimport Foundation\n\n\nstruct Cipher {}\n\n"
        #expect(
            builder.previewLines(for: content(snippet), subtype: .code) == [
                "import Foundation",
                "struct Cipher {}",
            ]
        )
    }

    @Test("Les fins de ligne Windows découpent le code comme les fins Unix")
    func codeHandlesWindowsNewlines() {
        let snippet = "SELECT id\r\nFROM clip_item\r\nWHERE pinned = 1"
        #expect(
            builder.previewLines(for: content(snippet), subtype: .code) == [
                "SELECT id", "FROM clip_item",
            ]
        )
    }

    @Test("Les blancs de fin de ligne du code sont retirés")
    func codeTrimsTrailingWhitespace() {
        #expect(builder.previewLines(for: content("let x = 1   \t"), subtype: .code) == ["let x = 1"])
    }

    @Test("Un code d'une seule ligne ne produit qu'une ligne")
    func singleLineCode() {
        let sql = "SELECT id, created_at FROM clip_item WHERE pinned = 1"
        #expect(builder.previewLines(for: content(sql), subtype: .code) == [sql])
    }

    // MARK: Aperçu — chemin

    @Test("Un chemin d'une seule ligne est rendu tel quel")
    func singleLinePath() {
        let path = "~/Developer/copydraft/Sources/CopyDraftCore/Clipboard/ClipboardMonitor.swift"
        #expect(builder.previewLines(for: content(path), subtype: .path) == [path])
    }

    @Test("Un chemin multiligne garde ses deux premières lignes")
    func multilinePath() {
        let paths = "/Users/sadok/Documents/a.txt\n/Users/sadok/Documents/b.txt\n/Users/sadok/c.txt"
        #expect(
            builder.previewLines(for: content(paths), subtype: .path) == [
                "/Users/sadok/Documents/a.txt",
                "/Users/sadok/Documents/b.txt",
            ]
        )
    }

    // MARK: Aperçu — tout le reste

    @Test(
        "Le contenu multiligne non-code est aplati en une seule chaîne",
        arguments: [ClipSubtype.plain, .rich, .link, .color]
    )
    func flattensMultiline(_ subtype: ClipSubtype) {
        let text = "Sprint 24 — revue de design\n\njeudi 14 h"
        #expect(
            builder.previewLines(for: content(text), subtype: subtype)
                == ["Sprint 24 — revue de design jeudi 14 h"]
        )
    }

    @Test("Un texte d'une seule ligne est rendu débarrassé de ses blancs d'extrémité")
    func singleLinePlain() {
        let text = "   Merci pour votre message, je regarde ça dès que possible.  "
        #expect(
            builder.previewLines(for: content(text), subtype: .plain)
                == ["Merci pour votre message, je regarde ça dès que possible."]
        )
    }

    @Test("Un contenu blanc ne produit aucune ligne d'aperçu")
    func blankProducesNoLine() {
        #expect(builder.previewLines(for: content("  \n\t\r\n "), subtype: .plain).isEmpty)
        #expect(builder.previewLines(for: content("  \n\t\r\n "), subtype: .code).isEmpty)
        #expect(builder.previewLines(for: content(""), subtype: .plain).isEmpty)
    }

    @Test("Aucune ligne vide ne se glisse jamais dans le résultat")
    func neverReturnsBlankLines() {
        let samples = ["\n\n\n", "  \n texte \n  ", "a\n\n\nb", "\t\n\t\n"]
        for sample in samples {
            for subtype in ClipSubtype.allCases {
                let lines = builder.previewLines(for: content(sample), subtype: subtype)
                #expect(lines.allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
            }
        }
    }

    // MARK: Bornes

    @Test("L'aperçu ne dépasse jamais deux lignes")
    func neverMoreThanTwoLines() {
        let manyLines = (1...50).map { "ligne \($0) {" }.joined(separator: "\n")
        for subtype in ClipSubtype.allCases {
            let lines = builder.previewLines(for: content(manyLines), subtype: subtype)
            #expect(lines.count <= ClipItem.previewLineLimit)
        }
    }

    @Test("Une ligne d'aperçu est bornée à 512 caractères, sans ellipsis")
    func lineIsBounded() {
        let long = String(repeating: "x", count: 4_000)
        let flat = builder.previewLines(for: content(long), subtype: .plain)
        #expect(flat == [String(repeating: "x", count: PreviewBuilder.lineCharacterLimit)])

        let code = builder.previewLines(for: content("\(long)\n\(long)"), subtype: .code)
        #expect(code.count == 2)
        #expect(code.allSatisfy { $0.count == PreviewBuilder.lineCharacterLimit })
        // Pas d'ellipsis : la troncature visible relève de la vue (§1.2).
        #expect(!flat[0].contains("…"))
    }

    @Test("Un contenu de 10 000 caractères produit un aperçu borné")
    func veryLongContent() {
        let long = String(repeating: "Une phrase française tout à fait ordinaire. ", count: 250)
        #expect(long.count >= 10_000)
        let lines = builder.previewLines(for: content(long), subtype: .plain)
        #expect(lines.count == 1)
        #expect(lines[0].count == PreviewBuilder.lineCharacterLimit)
    }

    // MARK: Accord avec le classifieur

    @Test("Classifieur et fabricant d'aperçu s'accordent sur les exemples du design system")
    func matchesDesignSystemSamples() {
        let classifier = ContentClassifier()
        let snippet = "func startMonitoring() {\n    timer = Timer.scheduledTimer("
        let captured = content(snippet)
        let subtype = classifier.classify(captured)

        #expect(subtype == .code)
        #expect(builder.previewLines(for: captured, subtype: subtype).count == 2)
        #expect(
            builder.searchText(for: captured)
                == "func startMonitoring() { timer = Timer.scheduledTimer("
        )
    }
}
