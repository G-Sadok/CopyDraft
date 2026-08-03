import Foundation

/// Espace de noms des tokens du design system CopyDraft.
///
/// Transcription littérale de `design-system/tokens.json`, lui-même extrait de
/// « CopyDraft Design System » v1.0. **Aucune valeur littérale ne doit apparaître dans une
/// vue** : tout passe par `CD`. `DesignTokensTests` vérifie que le Swift et le JSON ne
/// divergent pas.
public enum CD {}

// MARK: - Rayons (§1.4)

extension CD {
    public enum Radius {
        public static let popover: CGFloat = 12
        public static let window: CGFloat = 10
        public static let menu: CGFloat = 6
        public static let cell: CGFloat = 6
        public static let field: CGFloat = 6
        public static let button: CGFloat = 6
        public static let badge: CGFloat = 4
        public static let thumbnail: CGFloat = 4
    }
}

// MARK: - Espacements, base 4 pt (§1.3)

extension CD {
    public enum Space {
        /// 2 pt — écart titre ↔ aperçu dans une cellule.
        public static let x0_5: CGFloat = 2
        /// 4 pt — icône ↔ libellé de menu.
        public static let x1: CGFloat = 4
        /// 6 pt — marge intérieure de la popup, écart entre cellules.
        public static let x1_5: CGFloat = 6
        /// 8 pt — padding horizontal de cellule, gouttière d'icônes.
        public static let x2: CGFloat = 8
        /// 10 pt — vignette ↔ texte, padding du champ de recherche.
        public static let x2_5: CGFloat = 10
        /// 12 pt — écart entre groupes dans un onglet de Préférences.
        public static let x3: CGFloat = 12
        /// 16 pt — gouttière libellé ↔ contrôle.
        public static let x4: CGFloat = 16
        /// 20 pt — marge intérieure d'un panneau de Préférences.
        public static let x5: CGFloat = 20
        /// 24 pt — marges d'un état vide.
        public static let x6: CGFloat = 24
        /// 32 pt — marges de l'écran d'onboarding.
        public static let x8: CGFloat = 32
    }
}

// MARK: - Cotes des surfaces (§2, §3, §6, §7, §8, §9)

extension CD {
    public enum Metric {
        // Popup (§3)
        public static let popupWidth: CGFloat = 360
        public static let popupHeightMin: CGFloat = 148
        public static let popupHeightMax: CGFloat = 564
        /// Plafond de hauteur exprimé en fraction de l'écran actif.
        public static let popupHeightScreenFraction: CGFloat = 0.6
        /// Décalage du coin supérieur gauche par rapport au curseur (+12 / +12).
        public static let popupCursorOffset: CGFloat = 12
        /// Marge minimale avec les bords de l'écran visible.
        public static let popupScreenMargin: CGFloat = 8
        public static let popupInnerPadding: CGFloat = 6
        public static let popupCellGap: CGFloat = 2
        public static let popupSectionHeader: CGFloat = 20

        // Cellule (§2.5)
        public static let cellWidth: CGFloat = 348
        public static let cellHeightMin: CGFloat = 44
        public static let cellHeightMax: CGFloat = 60
        public static let cellThumbnail: CGFloat = 28
        public static let cellThumbnailGap: CGFloat = 10
        public static let cellPadding: CGFloat = 8
        public static let cellPin: CGFloat = 14
        public static let cellShortcutBadgeWidth: CGFloat = 24
        public static let cellShortcutBadgeHeight: CGFloat = 16

        // Champ de recherche et pied (§2.3, §3)
        public static let searchHeight: CGFloat = 28
        public static let footerHeight: CGFloat = 32
        public static let rowsVisible = 8
        public static let rowsVisibleMin = 5
        public static let rowsVisibleMax = 12

        // Contrôles (§1.5, §2.1)
        public static let iconBox: CGFloat = 16
        public static let hitTargetMin: CGFloat = 22
        /// Épaisseur de l'anneau de focus, tracé **hors** du contrôle (§2.1).
        public static let focusRingWidth: CGFloat = 3
        /// Hauteur des contrôles discrets et des contrôles « small » d'AppKit (§2.2).
        public static let controlHeightSmall: CGFloat = 24
        /// Glyphe d'un état vide (§5).
        public static let emptyStateGlyph: CGFloat = 36
        public static let buttonHeight: CGFloat = 28
        public static let buttonPaddingHorizontal: CGFloat = 14

        // Barre de menus (§6)
        public static let menuWidth: CGFloat = 252
        public static let menuItemHeight: CGFloat = 22
        public static let statusIconTemplate: CGFloat = 18
        public static let statusIconBox: CGFloat = 22

        // Réglages (§7)
        public static let settingsWidth: CGFloat = 480
        public static let settingsLabelColumn: CGFloat = 150
        public static let settingsGutter: CGFloat = 24

        // Onboarding (§8) et toast (§9)
        public static let onboardingWidth: CGFloat = 560
        public static let onboardingHeight: CGFloat = 420
        public static let toastBottomInset: CGFloat = 24
    }
}

// MARK: - Opacités nommées (§2.1, §2.4, §5, §6)

extension CD {
    /// Voiles et opacités qui reviennent d'une surface à l'autre. Nommés ici pour qu'aucun
    /// composant n'ait à choisir sa propre valeur.
    public enum Opacity {
        /// Anneau de focus : plus marqué en sombre, où le fond absorbe davantage.
        public static let focusRingLight: Double = 0.35
        public static let focusRingDark: Double = 0.45
        /// Badge d'indice posé sur une cellule sélectionnée.
        public static let badgeOnSelection: Double = 0.22
        /// Teinte ambre du bandeau de pause.
        public static let pauseBannerTint: Double = 0.14
        /// Champ de recherche inactif, historique vide.
        public static let fieldDisabled: Double = 0.55
        /// Icône de barre de menus en pause (§6).
        public static let statusIconPaused: Double = 0.40
    }
}
