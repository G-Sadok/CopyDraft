import CoreGraphics
import CopyDraftCore
import Foundation

/// Calcule où poser la popup (FR-21, FR-22).
///
/// Géométrie pure, sans AppKit : elle prend des rectangles et rend un rectangle, ce qui la
/// rend testable sur des écrans qui n'existent pas — bords, Dock, deux écrans d'échelles
/// différentes.
///
/// Repère AppKit : origine en bas à gauche, `y` croissant vers le haut.
public struct PopupPositioner: Sendable {
    /// Décalage du coin supérieur gauche par rapport au curseur (+12 / +12 vers le bas-droite).
    public static let cursorOffset = CD.Metric.popupCursorOffset
    /// Marge minimale avec les bords de la zone visible.
    public static let screenMargin = CD.Metric.popupScreenMargin

    public init() {}

    /// Cadre de la popup pour une position donnée.
    ///
    /// - Parameters:
    ///   - size: taille souhaitée de la popup.
    ///   - position: réglage choisi par l'utilisateur.
    ///   - cursor: position du curseur, en coordonnées écran.
    ///   - visibleFrame: zone utile de l'écran du curseur, barre de menus et Dock exclus.
    ///   - statusItemFrame: cadre de l'icône de barre de menus, pour la position « sous l'icône ».
    public func frame(
        size: CGSize,
        position: PopupPosition,
        cursor: CGPoint,
        visibleFrame: CGRect,
        statusItemFrame: CGRect? = nil
    ) -> CGRect {
        // Une popup plus grande que l'écran est d'abord ramenée à la taille utile.
        let size = CGSize(
            width: min(size.width, visibleFrame.width - 2 * Self.screenMargin),
            height: min(size.height, visibleFrame.height - 2 * Self.screenMargin)
        )

        let origin =
            switch position {
            case .cursor:
                originAtCursor(size: size, cursor: cursor, visibleFrame: visibleFrame)
            case .centered:
                CGPoint(
                    x: visibleFrame.midX - size.width / 2,
                    y: visibleFrame.midY - size.height / 2
                )
            case .menuBar:
                originUnderStatusItem(
                    size: size, statusItemFrame: statusItemFrame, visibleFrame: visibleFrame
                )
            }

        return clamp(CGRect(origin: origin, size: size), in: visibleFrame)
    }

    // MARK: Positions

    /// Ouverture vers le bas-droite du curseur, avec **retournement** — et non simple
    /// décalage — sur l'axe qui déborde : le curseur reste visible et la liste ne recouvre
    /// pas ce qu'on vient de désigner.
    private func originAtCursor(
        size: CGSize, cursor: CGPoint, visibleFrame: CGRect
    ) -> CGPoint {
        var x = cursor.x + Self.cursorOffset
        var y = cursor.y - Self.cursorOffset - size.height

        if x + size.width > visibleFrame.maxX - Self.screenMargin {
            x = cursor.x - Self.cursorOffset - size.width
        }
        if y < visibleFrame.minY + Self.screenMargin {
            y = cursor.y + Self.cursorOffset
        }

        return CGPoint(x: x, y: y)
    }

    /// Sous l'icône de barre de menus, alignée sur son bord droit — comme un menu système.
    private func originUnderStatusItem(
        size: CGSize, statusItemFrame: CGRect?, visibleFrame: CGRect
    ) -> CGPoint {
        guard let statusItemFrame else {
            // Icône introuvable : on retombe sur le coin supérieur droit de l'écran.
            return CGPoint(
                x: visibleFrame.maxX - Self.screenMargin - size.width,
                y: visibleFrame.maxY - Self.screenMargin - size.height
            )
        }

        return CGPoint(
            x: statusItemFrame.maxX - size.width,
            y: statusItemFrame.minY - Self.screenMargin - size.height
        )
    }

    // MARK: Bornage

    /// Ramène le cadre dans la zone visible, marge comprise. Après retournement, il peut
    /// rester un débordement d'un côté : c'est ici qu'il est absorbé.
    private func clamp(_ rect: CGRect, in visibleFrame: CGRect) -> CGRect {
        var rect = rect
        rect.origin.x = min(
            max(rect.minX, visibleFrame.minX + Self.screenMargin),
            visibleFrame.maxX - Self.screenMargin - rect.width
        )
        rect.origin.y = min(
            max(rect.minY, visibleFrame.minY + Self.screenMargin),
            visibleFrame.maxY - Self.screenMargin - rect.height
        )
        return rect
    }

    // MARK: Hauteur

    /// Hauteur de la popup pour un nombre d'éléments donné (FR-20).
    ///
    /// Bornée par les valeurs du design system **et** par 60 % de l'écran : la popup reste
    /// une palette, jamais une fenêtre.
    public func height(
        itemCount: Int,
        visibleRows: Int,
        twoLineCount: Int = 0,
        visibleFrame: CGRect
    ) -> CGFloat {
        let rows = min(itemCount, visibleRows)
        let twoLine = min(twoLineCount, rows)
        let content =
            CGFloat(rows - twoLine) * CD.Metric.cellHeightMin
            + CGFloat(twoLine) * CD.Metric.cellHeightMax
            + CGFloat(max(0, rows - 1)) * CD.Metric.popupCellGap

        let chrome =
            CD.Metric.searchHeight + CD.Metric.footerHeight + 2 * CD.Metric.popupInnerPadding
            + CD.Metric.popupSectionHeader

        let ceiling = min(
            CD.Metric.popupHeightMax, visibleFrame.height * CD.Metric.popupHeightScreenFraction
        )
        return min(max(content + chrome, CD.Metric.popupHeightMin), ceiling)
    }

    /// Écran qui contient le curseur : la popup ne doit jamais être à cheval sur deux écrans.
    public func screen(containing cursor: CGPoint, among frames: [CGRect]) -> CGRect? {
        frames.first { $0.contains(cursor) } ?? frames.first
    }
}
