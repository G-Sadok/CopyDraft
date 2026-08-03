import AppKit

// MARK: - Glyphe de la barre de menus (§6)

/// Icône de CopyDraft dans la barre de menus, tracée en code.
///
/// Aucun asset : le glyphe du §6 tient en deux tracés — la feuille au premier plan et
/// l'ancienne qui dépasse derrière, « l'histoire du presse-papiers en un glyphe » (§9). Le
/// dessiner permet de le rendre à n'importe quelle résolution sans jeu d'images à maintenir,
/// et de dériver l'état de pause du même tracé plutôt que d'un second fichier.
///
/// Rendue en *template image* : macOS applique lui-même le noir ou le blanc selon le thème,
/// et l'inversion quand le menu est ouvert (FR-40). Le code ne choisit donc aucune couleur.
public enum StatusItemIcon {
    /// Image template 18 × 18, optiquement centrée par AppKit dans la boîte de 22 × 22 du
    /// `NSStatusItem` (§6).
    public static func image(paused: Bool) -> NSImage {
        image(paused: paused, side: CD.Metric.statusIconTemplate)
    }

    /// Même glyphe à une taille arbitraire. Réservé aux instantanés de contrôle : la barre de
    /// menus n'utilise que le gabarit de 18 pt.
    static func image(paused: Bool, side: CGFloat) -> NSImage {
        let image = NSImage(
            size: NSSize(width: side, height: side),
            flipped: true  // le tracé du §6 est exprimé en coordonnées SVG, axe Y vers le bas
        ) { rect in
            draw(paused: paused, in: rect)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = L.t(
            paused ? "menubar.accessibility.paused" : "statusItem.accessibilityLabel"
        )
        return image
    }

    // MARK: Tracé

    /// Dessine le glyphe dans `rect`, en contexte retourné.
    ///
    /// Les coordonnées sont celles du §6 (boîte de 16, axe Y vers le bas) ; l'épaisseur de
    /// trait, elle, est ramenée au gabarit de 18 pt pour rester à 1,35 pt quelle que soit la
    /// taille demandée.
    static func draw(paused: Bool, in rect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        context.saveGState()
        defer { context.restoreGState() }

        context.translateBy(x: rect.minX, y: rect.minY)
        let scale = rect.width / Design.unit
        context.scaleBy(x: scale, y: scale)

        context.setStrokeColor(NSColor.black.cgColor)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        // Opacité appliquée au groupe entier : sans calque de transparence, les tracés qui se
        // recouvrent (les barres de pause sur la feuille) s'assombriraient à leur croisement.
        context.setAlpha(paused ? Design.pausedOpacity : 1)
        context.beginTransparencyLayer(auxiliaryInfo: nil)

        context.setLineWidth(Design.strokeWidth * Design.unit / CD.Metric.statusIconTemplate)
        context.addPath(sheets())
        context.strokePath()

        if paused {
            context.setLineWidth(Design.pauseBarWidth * Design.unit / CD.Metric.statusIconTemplate)
            context.addPath(pauseBars())
            context.strokePath()
        }

        context.endTransparencyLayer()
    }

    /// Les deux feuilles : celle du dessus, fermée, et l'ancienne réduite à son contour visible.
    private static func sheets() -> CGPath {
        let path = CGMutablePath()

        path.addRoundedRect(
            in: CGRect(x: 2.6, y: 4.4, width: 8, height: 9.2),
            cornerWidth: 1.7,
            cornerHeight: 1.7
        )

        path.move(to: CGPoint(x: 5.6, y: 4.4))
        path.addArc(
            tangent1End: CGPoint(x: 5.6, y: 1.6),
            tangent2End: CGPoint(x: 13.4, y: 1.6),
            radius: 1.6
        )
        path.addArc(
            tangent1End: CGPoint(x: 13.4, y: 1.6),
            tangent2End: CGPoint(x: 13.4, y: 10.2),
            radius: 1.6
        )
        path.addLine(to: CGPoint(x: 13.4, y: 10.2))

        return path
    }

    /// Les deux barres de pause, dans la feuille du dessus. Jamais de pastille rouge : trop
    /// bruyant pour une barre de menus (§6).
    private static func pauseBars() -> CGPath {
        let path = CGMutablePath()
        for x in [5.2, 8.0] as [CGFloat] {
            path.move(to: CGPoint(x: x, y: 7.2))
            path.addLine(to: CGPoint(x: x, y: 10.8))
        }
        return path
    }

    /// Constantes de tracé du §6. Ce ne sont pas des tokens : elles décrivent une forme, pas
    /// une cote réutilisable ailleurs dans l'interface.
    private enum Design {
        /// Côté de la boîte de coordonnées du dessin, telle qu'elle figure au §6.
        static let unit: CGFloat = 16
        /// « tracé 1,35 », exprimé dans le gabarit de 18 pt.
        static let strokeWidth: CGFloat = 1.35
        /// Les barres de pause sont un rien plus épaisses que le contour.
        static let pauseBarWidth: CGFloat = 1.5
        /// « Pause = même glyphe à 40 % d'opacité » (FR-40).
        static let pausedOpacity: CGFloat = 0.40
    }
}
