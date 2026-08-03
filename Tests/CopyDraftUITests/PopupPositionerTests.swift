import CoreGraphics
import CopyDraftCore
import Foundation
import Testing

@testable import CopyDraftUI

@Suite("Positionnement de la popup")
struct PopupPositionerTests {
    private let positioner = PopupPositioner()
    private let size = CGSize(width: CD.Metric.popupWidth, height: 400)

    /// Écran 1 920 × 1 080 avec barre de menus (25 pt) et Dock (70 pt).
    private let screen = CGRect(x: 0, y: 70, width: 1_920, height: 985)

    // MARK: Position au curseur

    @Test("La popup s'ouvre à +12 / +12 du curseur, vers le bas-droite")
    func opensBelowRightOfCursor() {
        let cursor = CGPoint(x: 600, y: 800)
        let frame = positioner.frame(
            size: size, position: .cursor, cursor: cursor, visibleFrame: screen
        )

        #expect(frame.minX == cursor.x + 12)
        #expect(frame.maxY == cursor.y - 12, "le coin supérieur est 12 pt sous le curseur")
        #expect(frame.size == size)
    }

    @Test("Près du bord droit, la popup se retourne à gauche du curseur")
    func flipsHorizontally() {
        let cursor = CGPoint(x: 1_800, y: 800)
        let frame = positioner.frame(
            size: size, position: .cursor, cursor: cursor, visibleFrame: screen
        )

        #expect(frame.maxX <= cursor.x - 12 + 0.001, "elle passe à gauche du curseur")
        #expect(frame.minX >= screen.minX + 8)
    }

    @Test("Près du bord bas, la popup se retourne au-dessus du curseur")
    func flipsVertically() {
        let cursor = CGPoint(x: 600, y: 120)
        let frame = positioner.frame(
            size: size, position: .cursor, cursor: cursor, visibleFrame: screen
        )

        #expect(frame.minY >= cursor.y + 12 - 0.001, "elle passe au-dessus du curseur")
        #expect(frame.maxY <= screen.maxY - 8)
    }

    @Test(
        "Depuis n'importe quel coin, la popup reste entièrement visible",
        arguments: [
            CGPoint(x: 0, y: 70), CGPoint(x: 1_920, y: 70),
            CGPoint(x: 0, y: 1_055), CGPoint(x: 1_920, y: 1_055),
            CGPoint(x: 960, y: 560)
        ]
    )
    func staysOnScreen(cursor: CGPoint) {
        let frame = positioner.frame(
            size: size, position: .cursor, cursor: cursor, visibleFrame: screen
        )

        #expect(frame.minX >= screen.minX + 8 - 0.001)
        #expect(frame.maxX <= screen.maxX - 8 + 0.001)
        #expect(frame.minY >= screen.minY + 8 - 0.001)
        #expect(frame.maxY <= screen.maxY - 8 + 0.001)
    }

    @Test("La barre de menus et le Dock ne sont jamais recouverts")
    func respectsMenuBarAndDock() {
        let frame = positioner.frame(
            size: size, position: .cursor, cursor: CGPoint(x: 100, y: 100),
            visibleFrame: screen
        )

        #expect(frame.minY >= screen.minY, "le Dock reste libre")
        #expect(frame.maxY <= screen.maxY, "la barre de menus reste libre")
    }

    // MARK: Multi-écrans

    @Test("La popup s'ouvre sur l'écran du curseur")
    func picksCursorScreen() throws {
        let principal = CGRect(x: 0, y: 0, width: 1_920, height: 1_080)
        let secondaire = CGRect(x: 1_920, y: 0, width: 2_560, height: 1_440)

        let choisi = try #require(
            positioner.screen(
                containing: CGPoint(x: 3_000, y: 700), among: [principal, secondaire]
            )
        )
        #expect(choisi == secondaire)

        let frame = positioner.frame(
            size: size, position: .cursor, cursor: CGPoint(x: 3_000, y: 700),
            visibleFrame: secondaire
        )
        #expect(secondaire.contains(frame), "jamais à cheval sur deux écrans")
    }

    @Test("Un curseur hors de tout écran connu retombe sur le premier")
    func fallsBackToFirstScreen() throws {
        let principal = CGRect(x: 0, y: 0, width: 1_920, height: 1_080)
        let choisi = try #require(
            positioner.screen(containing: CGPoint(x: -500, y: -500), among: [principal])
        )
        #expect(choisi == principal)
    }

    // MARK: Autres positions

    @Test("La position centrée place la popup au milieu de l'écran actif")
    func centered() {
        let frame = positioner.frame(
            size: size, position: .centered, cursor: .zero, visibleFrame: screen
        )

        #expect(abs(frame.midX - screen.midX) < 0.001)
        #expect(abs(frame.midY - screen.midY) < 0.001)
    }

    @Test("La position « sous la barre de menus » s'aligne sur le bord droit de l'icône")
    func underStatusItem() {
        let statusItem = CGRect(x: 1_700, y: 1_055, width: 22, height: 22)
        let frame = positioner.frame(
            size: size, position: .menuBar, cursor: .zero, visibleFrame: screen,
            statusItemFrame: statusItem
        )

        #expect(abs(frame.maxX - statusItem.maxX) < 0.001)
        #expect(frame.maxY <= statusItem.minY)
        #expect(screen.insetBy(dx: 7, dy: 7).contains(frame))
    }

    @Test("Sans icône repérée, la popup se pose en haut à droite")
    func underStatusItemFallback() {
        let frame = positioner.frame(
            size: size, position: .menuBar, cursor: .zero, visibleFrame: screen
        )

        #expect(abs(frame.maxX - (screen.maxX - 8)) < 0.001)
        #expect(abs(frame.maxY - (screen.maxY - 8)) < 0.001)
    }

    // MARK: Écran exigu

    @Test("Sur un petit écran, la popup est réduite plutôt que débordante")
    func tinyScreen() {
        let petit = CGRect(x: 0, y: 0, width: 320, height: 300)
        let frame = positioner.frame(
            size: size, position: .cursor, cursor: CGPoint(x: 160, y: 150), visibleFrame: petit
        )

        #expect(frame.width <= petit.width - 16)
        #expect(frame.height <= petit.height - 16)
        #expect(petit.contains(frame))
    }

    // MARK: Hauteur adaptative

    @Test("La hauteur suit le nombre d'éléments, entre les bornes du design system")
    func heightGrowsWithItems() {
        let vide = positioner.height(itemCount: 0, visibleRows: 8, visibleFrame: screen)
        let deux = positioner.height(itemCount: 2, visibleRows: 8, visibleFrame: screen)
        let plein = positioner.height(itemCount: 8, visibleRows: 8, visibleFrame: screen)

        #expect(vide == CD.Metric.popupHeightMin)
        #expect(deux >= CD.Metric.popupHeightMin)
        #expect(plein > deux)
        #expect(plein <= CD.Metric.popupHeightMax)
    }

    @Test("Au-delà du nombre d'éléments visibles, la hauteur ne grandit plus")
    func heightStopsAtVisibleRows() {
        let huit = positioner.height(itemCount: 8, visibleRows: 8, visibleFrame: screen)
        let cinquante = positioner.height(itemCount: 50, visibleRows: 8, visibleFrame: screen)

        #expect(huit == cinquante, "au-delà, la liste défile")
    }

    @Test("La hauteur est plafonnée à 60 % de l'écran actif")
    func heightIsCappedByScreen() {
        let petit = CGRect(x: 0, y: 0, width: 1_280, height: 500)
        let hauteur = positioner.height(itemCount: 12, visibleRows: 12, visibleFrame: petit)

        #expect(hauteur <= petit.height * CD.Metric.popupHeightScreenFraction + 0.001)
    }

    @Test("Les cellules à deux lignes comptent pour 60 pt")
    func twoLineCellsAreTaller() {
        let uneLigne = positioner.height(itemCount: 6, visibleRows: 8, visibleFrame: screen)
        let deuxLignes = positioner.height(
            itemCount: 6, visibleRows: 8, twoLineCount: 6, visibleFrame: screen
        )

        #expect(deuxLignes - uneLigne == 6 * (CD.Metric.cellHeightMax - CD.Metric.cellHeightMin))
    }
}
