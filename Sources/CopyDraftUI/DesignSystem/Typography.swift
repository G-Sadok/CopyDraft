import SwiftUI

// MARK: - Typographie (§1.2)

extension CD {
    /// Rôles typographiques. SF Pro Text sous 20 pt, SF Pro Display au-delà : la bascule est
    /// faite par `Font.system`. SF Mono pour le code et les chemins.
    ///
    /// Trois niveaux de hiérarchie au maximum par surface ; aucun texte sous 10 pt.
    public enum Font {
        /// 26/32 semibold — titre d'onboarding.
        public static let titleLarge = SwiftUI.Font.system(size: 26, weight: .semibold)
        /// 22/26 semibold.
        public static let title1 = SwiftUI.Font.system(size: 22, weight: .semibold)
        /// 17/22 semibold — titre de section de réglages.
        public static let title2 = SwiftUI.Font.system(size: 17, weight: .semibold)
        /// 15/20 semibold — libellé de réglage.
        public static let title3 = SwiftUI.Font.system(size: 15, weight: .semibold)
        /// 13/17 semibold — titre de cellule.
        public static let emphasis = SwiftUI.Font.system(size: 13, weight: .semibold)
        /// 13/17 regular — corps de référence, taille de contrôle macOS.
        public static let body = SwiftUI.Font.system(size: 13)
        /// 11,5/16 mono — aperçus de code et de chemins.
        public static let code = SwiftUI.Font.system(size: 11.5, design: .monospaced)
        /// 12/16 regular — métadonnées de cellule.
        public static let caption = SwiftUI.Font.system(size: 12)
        /// 11,5/16 regular — phrase d'un état vide, bandeau de pause.
        public static let detail = SwiftUI.Font.system(size: 11.5)
        /// 11/14 regular — pied de popup.
        public static let small = SwiftUI.Font.system(size: 11)
        /// 11/11 medium, chiffres tabulaires — indices ⌘n.
        public static let shortcut = SwiftUI.Font.system(size: 11, weight: .medium)
            .monospacedDigit()
        /// 10/13 semibold — en-têtes de section « Épinglés » / « Récents ».
        public static let micro = SwiftUI.Font.system(size: 10, weight: .semibold)
    }

    /// Interlignes du §1.2, à appliquer via `lineSpacing` (SwiftUI ajoute l'écart *entre*
    /// lignes : `lineSpacing = interligne − taille`).
    public enum LineHeight {
        public static let titleLarge: CGFloat = 32
        public static let title1: CGFloat = 26
        public static let title2: CGFloat = 22
        public static let title3: CGFloat = 20
        public static let emphasis: CGFloat = 17
        public static let body: CGFloat = 17
        public static let code: CGFloat = 16
        public static let caption: CGFloat = 16
        public static let detail: CGFloat = 16
        public static let small: CGFloat = 14
        public static let shortcut: CGFloat = 11
        public static let micro: CGFloat = 13
    }
}

extension View {
    /// Applique un rôle typographique et son interligne d'un seul geste.
    public func cdFont(_ font: SwiftUI.Font, lineHeight: CGFloat, size: CGFloat) -> some View {
        self.font(font).lineSpacing(max(0, lineHeight - size))
    }
}
