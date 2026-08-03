import SwiftUI

// MARK: - Boutons (§2.1)

/// Les cinq variantes de bouton du §2.1.
///
/// `primary` est l'action par défaut d'une surface : **une seule par surface**, jamais deux.
/// `quiet` et `destructiveQuiet` sont les boutons « discrets » du design system — pas de fond
/// au repos, un libellé teinté, réservés aux actions secondaires posées dans un bandeau ou un
/// état vide.
public enum CDButtonStyle: Sendable {
    case primary
    case secondary
    case quiet
    case destructive
    case destructiveQuiet
}

/// Bouton du design system : h 28, r 6, padding horizontal 14, 13 pt (§2.1).
///
/// Les cinq états du §2.1 sont dessinés — repos, survol, pressé, focus, désactivé — parce que
/// l'application se pilote quasi entièrement au clavier : un état de focus invisible rendrait
/// la navigation impossible à suivre. Le focus est un anneau *hors du tracé*, jamais un simple
/// changement de couleur.
public struct CDButton: View {
    private let title: String
    private let style: CDButtonStyle
    private let isEnabled: Bool
    private let action: () -> Void

    @State private var isHovering = false
    @FocusState private var isFocused: Bool

    public init(
        _ title: String,
        style: CDButtonStyle = .secondary,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.isEnabled = isEnabled
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
        }
        .buttonStyle(
            CDButtonRenderer(style: style, isEnabled: isEnabled, isHovering: isHovering, isFocused: isFocused)
        )
        .disabled(!isEnabled)
        .focusable(isEnabled)
        .focused($isFocused)
        .onHover { hovering in
            // 60 ms (§10) : l'entrée de survol se remarque sans se regarder.
            withAnimation(CD.Motion.animation(CD.Motion.hover)) {
                isHovering = hovering && isEnabled
            }
        }
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Rendu

/// Traduit l'état d'interaction d'un `Button` en surface dessinée.
///
/// Le style est séparé de `CDButton` pour que les instantanés de contrôle puissent forcer
/// chacun des cinq états : ni le survol ni la pression ne sont scriptables autrement.
struct CDButtonRenderer: ButtonStyle {
    let style: CDButtonStyle
    let isEnabled: Bool
    let isHovering: Bool
    let isFocused: Bool

    func makeBody(configuration: Configuration) -> some View {
        CDButtonSurface(
            style: style,
            isEnabled: isEnabled,
            isHovering: isHovering,
            isPressed: configuration.isPressed,
            isFocused: isFocused
        ) {
            configuration.label
        }
        .animation(CD.Motion.animation(CD.Motion.press), value: configuration.isPressed)
    }
}

/// Surface dessinée d'un bouton, tous ses états passés explicitement.
struct CDButtonSurface<Label: View>: View {
    let style: CDButtonStyle
    let isEnabled: Bool
    let isHovering: Bool
    let isPressed: Bool
    let isFocused: Bool
    @ViewBuilder let label: Label

    var body: some View {
        let appearance = CDButtonAppearance(
            style: style, isEnabled: isEnabled, isHovering: isHovering, isPressed: isPressed,
            isFocused: isFocused
        )

        label
            .font(appearance.font)
            .fontWeight(appearance.weight)
            .foregroundStyle(appearance.foreground)
            // Un bouton de 28 pt ne se replie jamais sur deux lignes : il s'élargit.
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, appearance.horizontalPadding)
            .frame(minWidth: appearance.height, minHeight: appearance.height)
            .background(appearance.background, in: RoundedRectangle(cornerRadius: CD.Radius.button))
            .brightness(appearance.brightness)
            .overlay {
                RoundedRectangle(cornerRadius: CD.Radius.button)
                    .strokeBorder(appearance.border, lineWidth: CDFocusRing.borderWidth)
            }
            .contentShape(RoundedRectangle(cornerRadius: CD.Radius.button))
            .cdFocusRing(isFocused && isEnabled, cornerRadius: CD.Radius.button)
    }
}

// MARK: - Résolution des états

/// Table d'états du §2.1, résolue en tokens `CD`.
private struct CDButtonAppearance {
    let background: Color
    let foreground: Color
    let border: Color
    let brightness: Double
    let height: CGFloat
    let horizontalPadding: CGFloat
    let font: Font
    let weight: Font.Weight

    init(style: CDButtonStyle, isEnabled: Bool, isHovering: Bool, isPressed: Bool, isFocused: Bool) {
        let isQuiet = style == .quiet || style == .destructiveQuiet
        // Les boutons discrets sont plus compacts (§2.1). À défaut d'un token de 24 pt, on
        // s'arrête à la cible cliquable minimale, qui reste conforme au §2.2.
        height = isQuiet ? CD.Metric.hitTargetMin : CD.Metric.buttonHeight
        horizontalPadding = isQuiet ? CD.Space.x2 : CD.Metric.buttonPaddingHorizontal
        font = isQuiet ? CD.Font.caption : CD.Font.body

        switch style {
        case .primary, .destructive:
            // Fond plein : le survol éclaircit, la pression assombrit (« accent-pressed »).
            weight = .medium
            border = .clear
            if isEnabled {
                background = style == .primary ? CD.Color.accent : CD.Color.danger
                foreground = CD.Color.textOnAccent
                brightness = isPressed ? CDFilledTint.pressed : (isHovering ? CDFilledTint.hover : 0)
            } else {
                background = CD.Color.fillHover
                foreground = CD.Color.textDisabled
                brightness = 0
            }

        case .secondary:
            weight = .regular
            brightness = 0
            foreground = isEnabled ? CD.Color.text1 : CD.Color.textDisabled
            // Le focus reprend le tracé en accent, en plus de l'anneau (§2.1).
            border = isFocused && isEnabled ? CD.Color.accent : CD.Color.separator
            guard isEnabled else {
                background = CD.Color.fill1
                break
            }
            if isPressed {
                background = CD.Color.fill3
            } else if isHovering {
                background = CD.Color.fillHover
            } else {
                background = CD.Color.fill1
            }

        case .quiet, .destructiveQuiet:
            weight = .regular
            brightness = 0
            border = .clear
            let tint = style == .quiet ? CD.Color.accent : CD.Color.danger
            foreground = isEnabled ? tint : CD.Color.textDisabled
            guard isEnabled else {
                background = .clear
                break
            }
            if isPressed {
                background = CD.Color.fill3
            } else if isHovering {
                background = CD.Color.fill1
            } else {
                background = .clear
            }
        }
    }
}

// MARK: - Anneau de focus

/// Cotes de l'anneau de focus du §2.1 — 3 pt d'accent à 35 %, posés **hors** du tracé.
///
/// Aucune de ces valeurs n'existe dans `CD` : elles sont regroupées ici en attendant des
/// tokens `CD.Metric.focusRing*`.
enum CDFocusRing {
    /// Épaisseur de l'anneau, en points.
    static let width: CGFloat = 3
    /// Opacité de l'accent dans l'anneau — plus soutenue en sombre, où l'accent se détache moins.
    static func opacity(_ scheme: ColorScheme) -> Double { scheme == .dark ? 0.45 : 0.35 }
    /// Épaisseur d'un tracé de contrôle (« border-control », un demi-point).
    static let borderWidth: CGFloat = 0.5
}

/// Écarts de luminosité du survol et de la pression sur un fond plein (§2.1).
///
/// Le design system nomme une couleur « accent pressé » que `CD.Color` n'expose pas encore ;
/// on l'approche par un écart de luminosité, qui suit l'accent choisi par l'utilisateur.
enum CDFilledTint {
    static let hover: Double = 0.06
    static let pressed: Double = -0.06
}

/// Anneau de focus posé **hors** du tracé, pour qu'il ne rogne jamais le contenu du contrôle.
private struct CDFocusRingModifier: ViewModifier {
    let isVisible: Bool
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius + CDFocusRing.width)
                    .strokeBorder(
                        CD.Color.accent
                            .opacity(isVisible ? CDFocusRing.opacity(colorScheme) : 0),
                        lineWidth: CDFocusRing.width
                    )
                    .padding(-CDFocusRing.width)
            }
            .animation(CD.Motion.fade(CD.Motion.selection), value: isVisible)
    }
}

extension View {
    /// Pose l'anneau de focus du §2.1 : 3 pt d'accent à 35 % (45 % en sombre), à l'extérieur
    /// du tracé.
    func cdFocusRing(_ isVisible: Bool, cornerRadius: CGFloat) -> some View {
        modifier(CDFocusRingModifier(isVisible: isVisible, cornerRadius: cornerRadius))
    }
}
