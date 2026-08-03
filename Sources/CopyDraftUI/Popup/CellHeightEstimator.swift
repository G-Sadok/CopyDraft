import AppKit
import CopyDraftCore
import CoreGraphics

/// Hauteur qu'occupera une cellule, mesurée avant l'affichage.
///
/// La popup doit connaître sa hauteur **avant** de s'ouvrir : elle se positionne d'un coup,
/// sans repositionnement visible. `ClipItem.previewLines` ne suffit pas — un paragraphe
/// aplati tient sur une seule entrée mais s'affichera sur deux lignes. On mesure donc le
/// texte avec la police réelle, ce qui évite la dernière ligne coupée en deux.
public enum CellHeightEstimator {
    /// Largeur utile de l'aperçu : cellule moins vignette, écart, marges et indice `⌘n`.
    static var previewWidth: CGFloat {
        CD.Metric.cellWidth
            - 2 * CD.Metric.cellPadding
            - CD.Metric.cellThumbnail
            - CD.Metric.cellThumbnailGap
            - CD.Metric.cellShortcutBadgeWidth
            - CD.Space.x2
    }

    /// Hauteur d'une cellule : 44 pt pour un aperçu d'une ligne, 60 pt pour deux (§2.5).
    public static func height(for item: ClipItem) -> CGFloat {
        lineCount(for: item) > 1 ? CD.Metric.cellHeightMax : CD.Metric.cellHeightMin
    }

    /// Nombre de lignes qu'occupera l'aperçu, plafonné à deux.
    public static func lineCount(for item: ClipItem) -> Int {
        if item.previewLines.count > 1 { return 2 }
        guard let text = item.customName ?? item.previewLines.first, !text.isEmpty else {
            return 1
        }

        let font =
            item.subtype.usesMonospacedPreview
            ? NSFont.monospacedSystemFont(ofSize: 11.5, weight: .regular)
            : NSFont.systemFont(ofSize: 13)

        let width = (text as NSString).size(withAttributes: [.font: font]).width
        return width > previewWidth ? 2 : 1
    }

    /// Hauteur totale de la popup pour une liste donnée (FR-20).
    ///
    /// Seules les `visibleRows` premières cellules comptent : au-delà, la liste défile —
    /// et aucune cellule ne doit se retrouver coupée en son milieu.
    public static func popupHeight(
        for items: [ClipItem],
        pinnedCount: Int,
        visibleRows: Int,
        visibleFrame: CGRect,
        showsPauseBanner: Bool = false
    ) -> CGFloat {
        let rows = Array(items.prefix(visibleRows))
        let content =
            rows.reduce(0) { $0 + height(for: $1) }
            + CGFloat(max(0, rows.count - 1)) * CD.Metric.popupCellGap

        // En-têtes de section : « Épinglés » n'apparaît qu'avec des épinglés, et « Récents »
        // seulement quand les deux sections coexistent.
        let headers: CGFloat = pinnedCount > 0 ? 2 * CD.Metric.popupSectionHeader : 0

        let chrome =
            CD.Metric.searchHeight + CD.Metric.footerHeight
            + 2 * CD.Space.x1_5  // marge intérieure
            + 2 * CD.Space.x1_5  // écarts entre recherche, liste et pied
            + (showsPauseBanner ? CD.Metric.searchHeight + CD.Space.x1_5 : 0)

        let ceiling = min(
            CD.Metric.popupHeightMax,
            visibleFrame.height * CD.Metric.popupHeightScreenFraction
        )
        return min(max(content + headers + chrome, CD.Metric.popupHeightMin), ceiling)
    }
}
