import AppKit
import SwiftUI

// MARK: - Matériaux et élévation (§1.4)

extension CD {
    /// Matériau translucide de la popup.
    ///
    /// Règle du design system : une surface = un matériau. Popover translucide **ou** fenêtre
    /// opaque, jamais empilés.
    public enum Material {
        /// `.hudWindow` — plus dense que `.popover`, garde le texte lisible sur un fond chargé.
        public static let popup: NSVisualEffectView.Material = .hudWindow
        /// Floute ce qu'il y a derrière la fenêtre, pas dedans.
        public static let blending: NSVisualEffectView.BlendingMode = .behindWindow

        /// Vrai si l'utilisateur a activé « Réduire la transparence » : le matériau doit alors
        /// céder la place au fond opaque `bgPopoverSolid`, ombre inchangée.
        public static var isReduced: Bool {
            NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        }
    }

    /// Trois niveaux d'élévation seulement. Seule la fenêtre flottante a droit à une ombre
    /// portée large : c'est ce qui la détache du contenu de l'application active.
    public enum Elevation {
        public struct Shadow: Sendable {
            public let radius: CGFloat
            public let y: CGFloat
            public let opacity: Double
        }

        /// Popup flottante — `0 10 34 rgba(0,0,0,.20)`.
        public static let popover = Shadow(radius: 34, y: 10, opacity: 0.20)
        /// Fenêtre (réglages, onboarding) — `0 22 60 rgba(0,0,0,.26)`.
        public static let window = Shadow(radius: 60, y: 22, opacity: 0.26)
        /// Menu de barre de menus — `0 6 20 rgba(0,0,0,.18)`.
        public static let menu = Shadow(radius: 20, y: 6, opacity: 0.18)

        /// Liseré d'un demi-point qui porte la séparation, plus marqué en sombre.
        public static let hairlineOpacity: Double = 0.10
    }
}

/// Fond translucide de la popup, avec repli opaque automatique.
public struct PopupBackground: NSViewRepresentable {
    public init() {}

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = CD.Material.popup
        view.blendingMode = CD.Material.blending
        view.state = .active
        return view
    }

    public func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = CD.Material.popup
        view.blendingMode = CD.Material.blending
    }
}
