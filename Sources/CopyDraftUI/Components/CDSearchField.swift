import SwiftUI

// MARK: - Champ de recherche (§2.3)

/// Champ de recherche de la popup : h 28, r 6, loupe à gauche, bouton d'effacement dès le
/// premier caractère (§2.3).
///
/// Le champ prend le focus à l'ouverture de la popup ; l'anneau de focus est donc visible la
/// plupart du temps et fait partie du dessin normal, pas d'un cas limite. Quand l'historique
/// est vide, le champ passe inactif plutôt que de disparaître : la surface garde sa hauteur et
/// la popup ne saute pas.
public struct CDSearchField: View {
    @Binding private var text: String
    private let isEnabled: Bool
    private let placeholderKey: String.LocalizationValue

    @FocusState private var isFocused: Bool

    public init(text: Binding<String>, isEnabled: Bool = true, placeholderKey: String.LocalizationValue) {
        self._text = text
        self.isEnabled = isEnabled
        self.placeholderKey = placeholderKey
    }

    public var body: some View {
        CDSearchFieldBody(
            isEnabled: isEnabled,
            isFocused: isFocused,
            hasText: !text.isEmpty,
            onClear: { text = "" }
        ) {
            TextField(text: $text) {
                Text(L.t(placeholderKey)).foregroundStyle(CD.Color.text3)
            }
            .textFieldStyle(.plain)
            .font(CD.Font.body)
            .foregroundStyle(isEnabled ? CD.Color.text1 : CD.Color.textDisabled)
            .focused($isFocused)
            .disabled(!isEnabled)
            .accessibilityLabel(Text(L.t(placeholderKey)))
        }
    }
}

// MARK: - Habillage

/// Habillage du champ : fond, loupe, bouton d'effacement, anneau de focus.
///
/// Le champ de saisie lui-même est injecté pour que les instantanés de contrôle puissent lui
/// substituer un simple `Text` — `ImageRenderer` ne dessine pas un `TextField`, adossé à AppKit.
struct CDSearchFieldBody<Field: View>: View {
    let isEnabled: Bool
    let isFocused: Bool
    let hasText: Bool
    let onClear: () -> Void
    @ViewBuilder let field: Field

    private var showsClearButton: Bool { hasText && isEnabled }

    private var glyphColor: Color {
        guard isEnabled else { return CD.Color.textDisabled }
        return isFocused ? CD.Color.text2 : CD.Color.text3
    }

    var body: some View {
        HStack(spacing: CD.Space.x2) {
            Image(systemName: "magnifyingglass")
                .imageScale(.small)
                .font(CD.Font.body)
                .foregroundStyle(glyphColor)
                .accessibilityHidden(true)

            field

            if showsClearButton {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .imageScale(.small)
                        .font(CD.Font.body)
                        .foregroundStyle(CD.Color.text3)
                        // La cible reste à 22 pt même si le glyphe en fait 15 (§2.2).
                        .frame(width: CD.Metric.hitTargetMin, height: CD.Metric.hitTargetMin)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(L.t("search.clear")))
                .accessibilityAddTraits(.isButton)
                .transition(.opacity)
            }
        }
        .padding(.leading, CD.Space.x2_5)
        // Le bouton d'effacement porte déjà sa propre marge : sans cela la loupe et la croix
        // ne seraient pas à la même distance des bords.
        .padding(.trailing, showsClearButton ? CD.Space.x1 : CD.Space.x2_5)
        .frame(height: CD.Metric.searchHeight)
        .background(CD.Color.bgField, in: RoundedRectangle(cornerRadius: CD.Radius.field))
        .opacity(isEnabled ? 1 : CDSearchFieldMetrics.disabledOpacity)
        .cdFocusRing(isFocused && isEnabled, cornerRadius: CD.Radius.field)
        .animation(CD.Motion.fade(CD.Motion.hover), value: showsClearButton)
    }
}

/// Cotes du §2.3 absentes de `CD`.
enum CDSearchFieldMetrics {
    /// Opacité du champ inactif — historique vide (§2.3).
    static let disabledOpacity: Double = 0.55
}
