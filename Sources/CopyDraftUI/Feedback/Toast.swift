import AppKit
import CopyDraftCore
import SwiftUI

// MARK: - Contenu d'un toast (§9)

/// Les quatre retours du §9. Le quatrième est le repli sans permission Accessibilité (FR-34).
///
/// Le type est distinct de `PasteOutcome` parce qu'un toast couvre aussi l'épinglage, qui n'est
/// pas un collage : la surface de retour a son propre vocabulaire.
public enum ToastKind: Sendable, Equatable {
    case pasted(appName: String)
    case pastedPlainText
    case pinned
    case copiedOnly

    /// Traduit le résultat d'un collage (FR-35).
    ///
    /// « Collé en texte brut » ne nomme pas l'application : le §9 met en avant la
    /// transformation, pas la destination.
    public init(_ outcome: PasteOutcome) {
        switch outcome {
        case .pasted(let appName): self = .pasted(appName: appName)
        case .pastedPlainText: self = .pastedPlainText
        case .copiedOnly: self = .copiedOnly
        }
    }

    /// Libellé exact du §9.
    public func message(language: String? = nil) -> String {
        switch self {
        case .pasted(let appName):
            LocalizedTable.format("toast.pasted", table: .feedback, language: language, appName)
        case .pastedPlainText:
            LocalizedTable.string("toast.pastedPlainText", table: .feedback, language: language)
        case .pinned:
            LocalizedTable.string("toast.pinned", table: .feedback, language: language)
        case .copiedOnly:
            LocalizedTable.string("toast.copiedOnly", table: .feedback, language: language)
        }
    }

    /// Glyphe de gauche. Le repli sans permission est le seul à porter un signe d'alerte :
    /// c'est le cas où l'utilisateur a encore quelque chose à faire.
    var symbolName: String {
        switch self {
        case .pasted: "checkmark"
        case .pastedPlainText: "textformat"
        case .pinned: "pin.fill"
        case .copiedOnly: "exclamationmark.circle"
        }
    }

    var tint: Color {
        switch self {
        case .pasted: CD.Color.success
        case .pastedPlainText: CD.Color.text2
        case .pinned: CD.Color.accent
        case .copiedOnly: CD.Color.warning
        }
    }
}

// MARK: - Cotes du toast (§9)

/// Cotes du §9 absentes de `CD` : la pastille du toast n'a ni hauteur ni rayon tokenisés.
enum ToastMetrics {
    /// Hauteur de la pastille.
    static let height: CGFloat = 30
    /// Pastille entièrement arrondie.
    static var cornerRadius: CGFloat { height / 2 }
    /// Marge intérieure côté glyphe, plus serrée que côté texte.
    static let leadingPadding: CGFloat = 11
    /// Marge intérieure côté texte.
    static let trailingPadding: CGFloat = 14
    /// Glyphe de 15 pt, comme les puces du §8.
    static let glyph: CGFloat = 15
    /// Course verticale de l'entrée et de la sortie — « y 8 → 0 » du §10.
    static let travel: CGFloat = 8
    /// Un flou CSS vaut environ deux fois le rayon d'ombre de SwiftUI.
    static let shadowBlurRatio: CGFloat = 2
}

// MARK: - Pastille

/// Pastille du §9 : glyphe, libellé, matériau du popover, ombre.
///
/// `usesMaterial` retombe sur le fond opaque quand « Réduire la transparence » est actif — et
/// dans les instantanés, où `ImageRenderer` ne rend pas les vues AppKit hébergées.
struct ToastBody: View {
    let kind: ToastKind
    let message: String
    var usesMaterial: Bool = !CD.Material.isReduced

    var body: some View {
        HStack(spacing: CD.Space.x2) {
            Image(systemName: kind.symbolName)
                .font(.system(size: ToastMetrics.glyph, weight: .medium))
                .foregroundStyle(kind.tint)
                .accessibilityHidden(true)

            Text(message)
                .font(CD.Font.caption)
                .foregroundStyle(CD.Color.text1)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.leading, ToastMetrics.leadingPadding)
        .padding(.trailing, ToastMetrics.trailingPadding)
        .frame(height: ToastMetrics.height)
        .background {
            if usesMaterial {
                PopupBackground()
            } else {
                CD.Color.bgPopoverSolid
            }
        }
        .clipShape(pill)
        .overlay { pill.strokeBorder(CD.Color.hairline, lineWidth: CDFocusRing.borderWidth) }
        // Le §9 donne « 0 8 24 rgba(0,0,0,.18) » : de tous les niveaux d'élévation de `CD`,
        // celui du menu est le seul de cet ordre de grandeur.
        .shadow(
            color: .black.opacity(CD.Elevation.menu.opacity),
            radius: CD.Elevation.menu.radius / ToastMetrics.shadowBlurRatio,
            y: CD.Elevation.menu.y
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(message))
    }

    private var pill: RoundedRectangle {
        RoundedRectangle(cornerRadius: ToastMetrics.cornerRadius, style: .continuous)
    }
}

// MARK: - Position

/// Où poser le toast : centré, 24 pt au-dessus du bas de l'écran actif (§9).
///
/// Géométrie pure, comme `PopupPositioner` : elle prend des rectangles et rend un rectangle.
/// Repère AppKit — origine en bas à gauche, `y` croissant vers le haut.
public struct ToastPositioner: Sendable {
    public init() {}

    public func frame(size: CGSize, in visibleFrame: CGRect) -> CGRect {
        CGRect(
            x: visibleFrame.midX - size.width / 2,
            y: visibleFrame.minY + CD.Metric.toastBottomInset,
            width: size.width,
            height: size.height
        )
    }
}

// MARK: - État observé

/// État affiché par la fenêtre de toast. Isolé pour que le remplacement d'un toast par le
/// suivant soit un simple changement de valeur, sans nouvelle fenêtre ni nouvelle vue.
@MainActor
@Observable
final class ToastModel {
    var kind: ToastKind = .pinned
    var message: String = ""
    /// Faux avant l'entrée et pendant la sortie.
    var isPresented = false
}

/// Vue hébergée par la fenêtre : la pastille, son fondu et sa course verticale (§10).
struct ToastHost: View {
    let model: ToastModel

    private var duration: TimeInterval {
        model.isPresented ? CD.Motion.toastIn : CD.Motion.toastOut
    }

    var body: some View {
        ToastBody(kind: model.kind, message: model.message)
            .offset(y: model.isPresented ? 0 : ToastMetrics.travel)
            .animation(CD.Motion.animation(duration), value: model.isPresented)
            .opacity(model.isPresented ? 1 : 0)
            .animation(CD.Motion.fade(duration), value: model.isPresented)
            // La course de 8 pt ne doit jamais rogner la pastille ni son ombre.
            .padding(ToastMetrics.travel)
    }
}

// MARK: - Fenêtre

/// Fenêtre du toast : flottante, sans focus, **non cliquable** (§9).
///
/// `ignoresMouseEvents` est le point central : un toast qui intercepterait un clic volerait
/// l'interaction juste après un collage, au pire moment.
final class ToastPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(origin: .zero, size: contentView.fittingSize),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        // Au-dessus de la popup, qui est elle-même « floating » : le retour doit rester visible.
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        hidesOnDeactivate = false
        animationBehavior = .none
        isReleasedWhenClosed = false
        isExcludedFromWindowsMenu = true
        ignoresMouseEvents = true

        self.contentView = contentView
    }
}

// MARK: - Présentateur

/// Affiche les toasts du §9 (FR-35).
///
/// Une seule fenêtre pour toute la session : deux collages rapprochés ne superposent donc
/// jamais deux pastilles, le second libellé remplace simplement le premier et relance le
/// compte à rebours.
@MainActor
public final class ToastPresenter {
    private let model = ToastModel()
    private let positioner = ToastPositioner()
    /// Fenêtre unique de la session : c'est elle qui garantit qu'aucun toast ne se superpose.
    private(set) var panel: ToastPanel?
    private var hostingView: NSHostingView<ToastHost>?
    private var lifecycle: Task<Void, Never>?

    public init() {}

    /// Libellé actuellement affiché, `nil` quand aucun toast n'est visible.
    public private(set) var message: String?

    public var isVisible: Bool { message != nil }

    /// Affiche un libellé déjà composé, sous l'apparence de confirmation du §9 — coche verte.
    public func show(_ message: String) {
        present(kind: .pasted(appName: ""), message: message)
    }

    /// Traduit les quatre cas du §9 (FR-34, FR-35).
    public func show(_ outcome: PasteOutcome) {
        show(ToastKind(outcome))
    }

    public func show(_ kind: ToastKind) {
        present(kind: kind, message: kind.message())
    }

    /// « Élément épinglé » (§9).
    public func showPinned() {
        show(.pinned)
    }

    /// Retire le toast immédiatement, sans animation de sortie.
    public func dismiss() {
        lifecycle?.cancel()
        lifecycle = nil
        model.isPresented = false
        message = nil
        panel?.orderOut(nil)
    }

    // MARK: Présentation

    private func present(kind: ToastKind, message: String) {
        // Le toast en cours cède la place plutôt que de s'empiler.
        lifecycle?.cancel()

        let panel = panel ?? makePanel()
        // Une pastille déjà à l'écran ne repart pas de zéro : seul son libellé change, sinon
        // deux collages rapprochés produiraient un clignotement (§9).
        let isReplacing = panel.isVisible && model.isPresented

        model.kind = kind
        model.message = message
        if !isReplacing { model.isPresented = false }
        self.message = message

        layout(panel)
        panel.orderFrontRegardless()

        lifecycle = Task { [weak self] in
            guard let self else { return }
            if !isReplacing {
                // Un tour de boucle avant de lever le drapeau : sans lui, SwiftUI applique
                // l'état final dès la première passe de rendu et l'entrée ne s'anime pas.
                await Task.yield()
                guard !Task.isCancelled else { return }
                model.isPresented = true
            }

            try? await Task.sleep(for: .seconds(CD.Motion.toastIn + CD.Motion.toastDwell))
            guard !Task.isCancelled else { return }
            model.isPresented = false

            try? await Task.sleep(for: .seconds(CD.Motion.toastOut))
            guard !Task.isCancelled else { return }
            self.message = nil
            panel.orderOut(nil)
        }
    }

    private func makePanel() -> ToastPanel {
        let hostingView = NSHostingView(rootView: ToastHost(model: model))
        let panel = ToastPanel(contentView: hostingView)
        self.hostingView = hostingView
        self.panel = panel
        return panel
    }

    /// Recalcule la taille utile puis pose la fenêtre au bas de l'écran actif.
    private func layout(_ panel: ToastPanel) {
        hostingView?.layoutSubtreeIfNeeded()
        let size = hostingView?.fittingSize ?? panel.frame.size
        let visibleFrame = Self.activeScreen?.visibleFrame ?? .zero
        let frame = positioner.frame(size: size, in: visibleFrame)
        // La course de 8 pt fait partie de la fenêtre : on la retranche pour que ce soit la
        // pastille, et non son cadre, qui se trouve à 24 pt du bas (§9).
        panel.setFrame(frame.offsetBy(dx: 0, dy: -ToastMetrics.travel), display: false)
    }

    /// Écran actif : celui qui porte le curseur, comme pour la popup (§3).
    private static var activeScreen: NSScreen? {
        let location = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(location) } ?? NSScreen.main
    }
}
