import AppKit
import SwiftUI

/// Panneau flottant de la popup (FR-19, design system §3).
///
/// `.nonactivatingPanel` : s'afficher ne rend pas CopyDraft actif, l'application de l'utilisateur
/// garde son focus et son apparence de fenêtre active. Sans bordure, sans titre, sans feux
/// tricolores, non redimensionnable, visible sur tous les Spaces.
///
/// `canBecomeKey` dépend du mode d'acheminement des frappes (ADR-6) : faux quand le tap
/// d'événements fonctionne — c'est le comportement décrit par le design system — vrai en mode
/// replié, faute d'autre moyen de recevoir les touches.
public final class PopupPanel: NSPanel {
    /// Vrai en mode replié : le panneau doit alors devenir fenêtre clé pour recevoir le clavier.
    ///
    /// Le style suit : `.nonactivatingPanel` interdit **par construction** à la fenêtre
    /// d'activer son application. Tant qu'il est posé, un panneau a beau devenir « clé », le
    /// système continue d'envoyer les frappes à l'application au premier plan. Sans
    /// autorisation d'accessibilité, il faut donc lever ce style — au prix du focus, ce qui
    /// est précisément le repli documenté par FR-34.
    public var acceptsKeyStatus = false {
        didSet {
            guard acceptsKeyStatus != oldValue else { return }
            if acceptsKeyStatus {
                styleMask.remove(.nonactivatingPanel)
            } else {
                styleMask.insert(.nonactivatingPanel)
            }
        }
    }

    public override var canBecomeKey: Bool { acceptsKeyStatus }
    public override var canBecomeMain: Bool { false }

    public init(contentView: NSView) {
        super.init(
            contentRect: NSRect(
                x: 0, y: 0, width: CD.Metric.popupWidth, height: CD.Metric.popupHeightMin
            ),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovable = false
        hidesOnDeactivate = false
        animationBehavior = .none
        isReleasedWhenClosed = false
        // Aucune trace dans la fenêtre de sélection d'app ni dans la restauration de session.
        isExcludedFromWindowsMenu = true

        self.contentView = contentView
    }
}
