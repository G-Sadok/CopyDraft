import CopyDraftCore
import CoreGraphics
import Foundation
import Testing

@testable import CopyDraftUI

@Suite("Hauteur de la popup")
struct CellHeightEstimatorTests {
    private let screen = CGRect(x: 0, y: 0, width: 1_920, height: 1_080)

    private func makeItem(
        _ text: String, subtype: ClipSubtype = .plain, pinned: Bool = false,
        previewLines: [String]? = nil
    ) -> ClipItem {
        ClipItem(
            kind: .text,
            subtype: subtype,
            createdAt: Date(timeIntervalSince1970: 0),
            pinned: pinned,
            source: SourceApp(bundleIdentifier: "com.test", name: "Test"),
            byteCount: text.utf8.count,
            characterCount: text.count,
            searchText: text,
            previewLines: previewLines ?? [text]
        )
    }

    // MARK: Lignes

    @Test("Un aperçu court tient sur une ligne")
    func shortPreviewIsOneLine() {
        #expect(CellHeightEstimator.lineCount(for: makeItem("#0A84FF")) == 1)
        #expect(CellHeightEstimator.height(for: makeItem("#0A84FF")) == CD.Metric.cellHeightMin)
    }

    /// Le cas qui coupait la dernière cellule en deux : un paragraphe aplati tient sur une
    /// seule entrée de `previewLines` mais s'affiche sur deux lignes.
    @Test("Un paragraphe aplati compte pour deux lignes")
    func flattenedParagraphIsTwoLines() {
        let item = makeItem(
            "Merci pour votre message, je regarde ça dès que possible et je reviens vers vous."
        )
        #expect(item.previewLines.count == 1, "le modèle n'en voit qu'une")
        #expect(CellHeightEstimator.lineCount(for: item) == 2, "l'affichage en occupe deux")
        #expect(CellHeightEstimator.height(for: item) == CD.Metric.cellHeightMax)
    }

    @Test("Un aperçu déjà sur deux lignes compte pour deux")
    func twoPreviewLines() {
        let item = makeItem(
            "func f() {", subtype: .code, previewLines: ["func f() {", "  return 1"]
        )
        #expect(CellHeightEstimator.lineCount(for: item) == 2)
    }

    @Test("Un nom personnalisé remplace l'aperçu dans la mesure")
    func customNameIsMeasured() {
        var item = makeItem("court")
        item.customName = String(repeating: "nom très long ", count: 6)
        #expect(CellHeightEstimator.lineCount(for: item) == 2)
    }

    @Test("Un aperçu vide reste sur une ligne")
    func emptyPreview() {
        let item = makeItem("", previewLines: [])
        #expect(CellHeightEstimator.lineCount(for: item) == 1)
    }

    // MARK: Hauteur de la popup

    @Test("Une liste vide reste à la hauteur minimale")
    func emptyList() {
        let height = CellHeightEstimator.popupHeight(
            for: [], pinnedCount: 0, visibleRows: 8, visibleFrame: screen
        )
        #expect(height == CD.Metric.popupHeightMin)
    }

    @Test("La hauteur grandit avec le nombre d'éléments, puis s'arrête")
    func heightGrowsThenStops() {
        let items = (0..<20).map { makeItem("élément \($0)") }

        let three = CellHeightEstimator.popupHeight(
            for: Array(items.prefix(3)), pinnedCount: 0, visibleRows: 8, visibleFrame: screen
        )
        let eight = CellHeightEstimator.popupHeight(
            for: Array(items.prefix(8)), pinnedCount: 0, visibleRows: 8, visibleFrame: screen
        )
        let twenty = CellHeightEstimator.popupHeight(
            for: items, pinnedCount: 0, visibleRows: 8, visibleFrame: screen
        )

        #expect(three < eight)
        #expect(eight == twenty, "au-delà des lignes visibles, la liste défile")
    }

    /// Le défaut constaté en usage réel : la hauteur doit contenir des cellules entières.
    @Test("La hauteur contient toujours un nombre entier de cellules")
    func heightHoldsWholeCells() {
        let items = [
            makeItem("court"),
            makeItem(String(repeating: "un texte assez long pour se replier ", count: 2)),
            makeItem("encore court"),
            makeItem(String(repeating: "et un autre paragraphe qui déborde largement ", count: 2))
        ]

        let height = CellHeightEstimator.popupHeight(
            for: items, pinnedCount: 0, visibleRows: 8, visibleFrame: screen
        )
        let content = items.reduce(0) { $0 + CellHeightEstimator.height(for: $1) }
            + CGFloat(items.count - 1) * CD.Metric.popupCellGap
        let chrome = height - content

        #expect(chrome > 0, "la hauteur couvre les cellules entières plus l'habillage")
        #expect(height <= CD.Metric.popupHeightMax)
    }

    @Test("Les en-têtes de section comptent quand il y a des épinglés")
    func sectionHeadersAreCounted() {
        let items = [makeItem("épinglé", pinned: true), makeItem("récent")]

        let withPinned = CellHeightEstimator.popupHeight(
            for: items, pinnedCount: 1, visibleRows: 8, visibleFrame: screen
        )
        let withoutPinned = CellHeightEstimator.popupHeight(
            for: items, pinnedCount: 0, visibleRows: 8, visibleFrame: screen
        )

        #expect(withPinned - withoutPinned == 2 * CD.Metric.popupSectionHeader)
    }

    @Test("Le bandeau de pause ajoute sa hauteur")
    func pauseBannerIsCounted() {
        let items = (0..<4).map { makeItem("élément \($0)") }

        let paused = CellHeightEstimator.popupHeight(
            for: items, pinnedCount: 0, visibleRows: 8, visibleFrame: screen,
            showsPauseBanner: true
        )
        let normal = CellHeightEstimator.popupHeight(
            for: items, pinnedCount: 0, visibleRows: 8, visibleFrame: screen
        )

        #expect(paused > normal)
    }

    @Test("La hauteur reste plafonnée à 60 % d'un petit écran")
    func cappedOnSmallScreen() {
        let items = (0..<12).map { _ in
            makeItem(String(repeating: "contenu long qui se replie sur deux lignes ", count: 2))
        }
        let small = CGRect(x: 0, y: 0, width: 1_280, height: 700)

        let height = CellHeightEstimator.popupHeight(
            for: items, pinnedCount: 0, visibleRows: 12, visibleFrame: small
        )
        #expect(height <= small.height * CD.Metric.popupHeightScreenFraction + 0.001)
    }
}
