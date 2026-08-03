import SwiftUI

// MARK: - Indice de raccourci (§2.4)

/// Indice ⌘n posé à droite d'une cellule : min 24 × 16, r 4, chiffres tabulaires (§2.4).
///
/// Deux apparences seulement : sur matériau et sur sélection. Sur sélection le fond n'est pas
/// une autre couleur mais un voile translucide clair posé sur l'accent — c'est ce qui garde le
/// badge lisible quel que soit l'accent choisi par l'utilisateur.
///
/// Les indices ne s'affichent que sur les dix premières cellules non filtrées : c'est à la
/// liste, pas au badge, de décider de leur présence.
public struct CDShortcutBadge: View {
    private let index: Int
    private let isSelected: Bool

    /// - Parameter index: rang de la cellule, 1 à 10. Le dixième porte ⌘0.
    public init(index: Int, isSelected: Bool) {
        self.index = index
        self.isSelected = isSelected
    }

    /// Libellé d'un rang : ⌘1 à ⌘9 puis ⌘0 pour le dixième (§2.4).
    static func label(for index: Int) -> String {
        "⌘\(index % 10)"
    }

    public var body: some View {
        Text(Self.label(for: index))
            .font(CD.Font.shortcut)
            .foregroundStyle(isSelected ? CD.Color.textOnAccent : CD.Color.text2)
            .padding(.horizontal, CD.Space.x1)
            .frame(
                minWidth: CD.Metric.cellShortcutBadgeWidth,
                minHeight: CD.Metric.cellShortcutBadgeHeight
            )
            .background(
                isSelected
                    ? CD.Color.textOnAccent.opacity(CDBadgeMetrics.onSelectionFill)
                    : CD.Color.fillHover,
                in: RoundedRectangle(cornerRadius: CD.Radius.badge)
            )
            .accessibilityLabel(Text(L.t("popup.shortcut.accessibilityLabel \(index % 10)")))
    }
}

// MARK: - Badge d'information (§2.4)

/// Poids d'un badge d'information.
///
/// `warning` est réservé aux états qui suspendent une fonction — « EN PAUSE ». `onSelection`
/// est la variante à poser sur une cellule sélectionnée, où le fond est déjà l'accent.
public enum CDBadgeEmphasis: Sendable {
    case neutral
    case warning
    case onSelection
}

/// Badge d'information du §2.4 : « IMAGE », « 1,2 Mo », « EN PAUSE »… h 16, r 4.
///
/// Le badge ne porte jamais d'action : c'est une étiquette. Son texte arrive déjà localisé ou
/// déjà formaté (un volume, une taille), d'où le `String` plutôt qu'une clé.
public struct CDBadge: View {
    private let text: String
    private let emphasis: CDBadgeEmphasis

    public init(_ text: String, emphasis: CDBadgeEmphasis = .neutral) {
        self.text = text
        self.emphasis = emphasis
    }

    private var foreground: Color {
        switch emphasis {
        case .neutral: CD.Color.text2
        case .warning, .onSelection: CD.Color.textOnAccent
        }
    }

    private var background: Color {
        switch emphasis {
        case .neutral: CD.Color.fillHover
        case .warning: CD.Color.warning
        case .onSelection: CD.Color.textOnAccent.opacity(CDBadgeMetrics.onSelectionFill)
        }
    }

    public var body: some View {
        Text(text)
            .font(CD.Font.micro)
            .foregroundStyle(foreground)
            .padding(.horizontal, CD.Space.x1_5)
            .frame(minHeight: CD.Metric.cellShortcutBadgeHeight)
            .background(background, in: RoundedRectangle(cornerRadius: CD.Radius.badge))
            .accessibilityLabel(Text(text))
    }
}

/// Cotes du §2.4 absentes de `CD`.
enum CDBadgeMetrics {
    /// Voile clair du badge posé sur une sélection — « rgba(255,255,255,.22) » du §2.4.
    static let onSelectionFill: Double = 0.22
}
