import AppKit
import SwiftUI

// MARK: - Couleurs sémantiques (§1.1)

extension CD {
    /// Rôles de couleur en `NSColor`.
    ///
    /// Chaque rôle est adossé à une couleur système lorsqu'un équivalent existe : le thème
    /// clair/sombre, l'accent choisi par l'utilisateur et « Augmenter le contraste » suivent
    /// alors automatiquement. Les rôles sans équivalent système sont des couleurs dynamiques
    /// dont les deux valeurs viennent du §1.1.
    public enum Palette {
        // Fonds
        public static let bgWindow: NSColor = .windowBackgroundColor
        public static let bgContent: NSColor = .textBackgroundColor
        /// Repli opaque du matériau de la popup (« Réduire la transparence »).
        public static let bgPopoverSolid = NSColor.dynamic(light: 0xF6_F6_F6, dark: 0x2C_2C_2E)
        public static let bgField = NSColor.dynamic(
            light: (0x00_00_00, 0.05), dark: (0xFF_FF_FF, 0.07)
        )

        // Remplissages
        public static let fill1: NSColor = .quinarySystemFill
        /// Remplissage de survol d'une cellule.
        public static let fillHover: NSColor = .quaternarySystemFill
        public static let fill3: NSColor = .tertiarySystemFill

        // Textes
        public static let text1: NSColor = .labelColor
        public static let text2: NSColor = .secondaryLabelColor
        /// Texte tertiaire et placeholder.
        public static let text3: NSColor = .tertiaryLabelColor
        public static let textDisabled: NSColor = .quaternaryLabelColor
        public static let textOnAccent: NSColor = .white

        // Traits
        public static let separator: NSColor = .separatorColor
        public static let hairline = NSColor.dynamic(
            light: (0x00_00_00, 0.14), dark: (0xFF_FF_FF, 0.10)
        )

        // Accent et sélection
        public static let accent: NSColor = .controlAccentColor
        public static let selection: NSColor = .selectedContentBackgroundColor
        /// Sélection non emphatique : survol souris et listes inactives.
        public static let selectionUnemphasized: NSColor = .unemphasizedSelectedContentBackgroundColor

        // Sémantique d'état
        public static let success: NSColor = .systemGreen
        public static let warning: NSColor = .systemOrange
        public static let danger: NSColor = .systemRed
    }

    /// Mêmes rôles, exposés à SwiftUI.
    public enum Color {
        public static let bgWindow = SwiftUI.Color(nsColor: Palette.bgWindow)
        public static let bgContent = SwiftUI.Color(nsColor: Palette.bgContent)
        public static let bgPopoverSolid = SwiftUI.Color(nsColor: Palette.bgPopoverSolid)
        public static let bgField = SwiftUI.Color(nsColor: Palette.bgField)

        public static let fill1 = SwiftUI.Color(nsColor: Palette.fill1)
        public static let fillHover = SwiftUI.Color(nsColor: Palette.fillHover)
        public static let fill3 = SwiftUI.Color(nsColor: Palette.fill3)

        public static let text1 = SwiftUI.Color(nsColor: Palette.text1)
        public static let text2 = SwiftUI.Color(nsColor: Palette.text2)
        public static let text3 = SwiftUI.Color(nsColor: Palette.text3)
        public static let textDisabled = SwiftUI.Color(nsColor: Palette.textDisabled)
        public static let textOnAccent = SwiftUI.Color(nsColor: Palette.textOnAccent)

        public static let separator = SwiftUI.Color(nsColor: Palette.separator)
        public static let hairline = SwiftUI.Color(nsColor: Palette.hairline)

        public static let accent = SwiftUI.Color(nsColor: Palette.accent)
        public static let selection = SwiftUI.Color(nsColor: Palette.selection)
        public static let selectionUnemphasized = SwiftUI.Color(
            nsColor: Palette.selectionUnemphasized
        )

        public static let success = SwiftUI.Color(nsColor: Palette.success)
        public static let warning = SwiftUI.Color(nsColor: Palette.warning)
        public static let danger = SwiftUI.Color(nsColor: Palette.danger)
    }
}

// MARK: - Fabrique de couleurs dynamiques

extension NSColor {
    /// Couleur qui bascule avec l'apparence, à partir de deux valeurs sRGB opaques.
    static func dynamic(light: Int, dark: Int) -> NSColor {
        dynamic(light: (light, 1), dark: (dark, 1))
    }

    /// Couleur qui bascule avec l'apparence, à partir de deux couples (sRGB, alpha).
    static func dynamic(light: (rgb: Int, alpha: Double), dark: (rgb: Int, alpha: Double)) -> NSColor {
        let lightColor = NSColor(srgb: light.rgb, alpha: light.alpha)
        let darkColor = NSColor(srgb: dark.rgb, alpha: dark.alpha)
        return NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? darkColor : lightColor
        }
    }

    /// Couleur sRGB à partir d'un entier `0xRRGGBB`.
    convenience init(srgb value: Int, alpha: Double = 1) {
        self.init(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: CGFloat(alpha)
        )
    }
}
