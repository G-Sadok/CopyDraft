import AppKit
import SwiftUI

// MARK: - Mouvement (§10)

extension CD {
    /// Durées et courbe du design system. Rien ne dure plus de 180 ms : une animation qui se
    /// remarque est une animation trop lente.
    ///
    /// Toutes les durées passent à 0 avec « Réduire les animations », sauf les fondus d'opacité
    /// ramenés à 80 ms — utiliser `CD.Motion.animation(_:)` plutôt que `withAnimation` direct.
    public enum Motion {
        public static let popupIn: TimeInterval = 0.140
        public static let popupOut: TimeInterval = 0.100
        public static let selection: TimeInterval = 0.080
        public static let hover: TimeInterval = 0.060
        public static let press: TimeInterval = 0.060
        public static let reorder: TimeInterval = 0.140
        public static let delete: TimeInterval = 0.120
        /// Le filtrage de recherche n'est jamais animé.
        public static let search: TimeInterval = 0
        public static let toastIn: TimeInterval = 0.180
        public static let toastOut: TimeInterval = 0.120
        /// La bascule de thème est gérée par le système.
        public static let theme: TimeInterval = 0

        /// Délai avant l'infobulle d'aperçu étendu.
        public static let tooltipDelay: TimeInterval = 0.800
        /// Durée d'affichage d'un toast, hors entrée et sortie.
        public static let toastDwell: TimeInterval = 1.400

        /// Courbe unique du design system : sortie rapide, arrivée douce.
        public static let curve = UnitCurve.bezier(
            startControlPoint: UnitPoint(x: 0.2, y: 0.8),
            endControlPoint: UnitPoint(x: 0.3, y: 1.0)
        )

        /// Durée des fondus quand les animations sont réduites.
        public static let reducedFade: TimeInterval = 0.080

        /// Vrai si l'utilisateur a activé « Réduire les animations ».
        public static var isReduced: Bool {
            NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        }

        /// Animation d'un déplacement, d'un changement d'échelle ou de couleur.
        /// Supprimée si les animations sont réduites.
        public static func animation(_ duration: TimeInterval) -> Animation? {
            guard duration > 0 else { return nil }
            guard !isReduced else { return nil }
            return .timingCurve(0.2, 0.8, 0.3, 1.0, duration: duration)
        }

        /// Animation d'un fondu d'opacité : conservée, raccourcie, quand les animations
        /// sont réduites.
        public static func fade(_ duration: TimeInterval) -> Animation? {
            guard duration > 0 else { return nil }
            let effective = isReduced ? reducedFade : duration
            return .timingCurve(0.2, 0.8, 0.3, 1.0, duration: effective)
        }
    }
}
