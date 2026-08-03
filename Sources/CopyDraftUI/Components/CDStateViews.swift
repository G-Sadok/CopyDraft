import SwiftUI

// MARK: - État vide (§5)

/// État vide de la popup : glyphe 36 pt en `text3`, titre 13 pt semibold, phrase courte en
/// `text2`, action facultative (§5).
///
/// Règle du design system : « un état vide n'est jamais une page blanche ; il dit ce qui va s'y
/// passer, et rien de plus ». Pas d'illustration, pas de ton badin, pas de deuxième paragraphe.
public struct CDEmptyState: View {
    private let symbolName: String
    private let titleKey: String.LocalizationValue
    private let messageKey: String.LocalizationValue
    private let actionTitleKey: String.LocalizationValue?
    private let action: (() -> Void)?

    public init(
        symbolName: String,
        titleKey: String.LocalizationValue,
        messageKey: String.LocalizationValue,
        actionTitleKey: String.LocalizationValue? = nil,
        action: (() -> Void)? = nil
    ) {
        self.symbolName = symbolName
        self.titleKey = titleKey
        self.messageKey = messageKey
        self.actionTitleKey = actionTitleKey
        self.action = action
    }

    public var body: some View {
        VStack(spacing: CD.Space.x2_5) {
            Image(systemName: symbolName)
                .font(.system(size: CDStateMetrics.emptyGlyph))
                .foregroundStyle(CD.Color.text3)
                .accessibilityHidden(true)

            Text(L.t(titleKey))
                .font(CD.Font.emphasis)
                .foregroundStyle(CD.Color.text1)

            Text(L.t(messageKey))
                .font(CD.Font.small)
                .foregroundStyle(CD.Color.text2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let actionTitleKey, let action {
                CDButton(L.t(actionTitleKey), style: .secondary, action: action)
                    .padding(.top, CD.Space.x1)
            }
        }
        .padding(.horizontal, CD.Space.x8)
        .padding(.vertical, CD.Space.x8)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Bandeau de capture suspendue (§5)

/// Bandeau ambre « Capture suspendue — rien n'est enregistré. » avec son action « Reprendre »
/// (§5).
///
/// Il se glisse entre la recherche et la liste : l'historique existant reste consultable, et
/// c'est justement ce que le bandeau doit rendre évident — la pause n'a rien effacé.
public struct CDPauseBanner: View {
    private let onResume: () -> Void

    public init(onResume: @escaping () -> Void) {
        self.onResume = onResume
    }

    public var body: some View {
        HStack(spacing: CD.Space.x2) {
            Image(systemName: "pause.fill")
                .imageScale(.small)
                .font(CD.Font.small)
                .foregroundStyle(CD.Color.warning)
                .accessibilityHidden(true)

            Text(L.t("popup.pause.banner"))
                .font(CD.Font.small)
                .foregroundStyle(CD.Color.text1)
                .frame(maxWidth: .infinity, alignment: .leading)

            CDButton(L.t("popup.pause.resume"), style: .quiet, action: onResume)
        }
        .padding(.horizontal, CD.Space.x2_5)
        .padding(.vertical, CD.Space.x1_5)
        .background(CD.Color.warning.opacity(CDStateMetrics.pauseTint))
        .overlay(alignment: .top) { hairline }
        .overlay(alignment: .bottom) { hairline }
        .accessibilityElement(children: .contain)
    }

    /// Filets haut et bas : le bandeau doit se lire comme une bande insérée, pas comme un fond.
    private var hairline: some View {
        Rectangle()
            .fill(CD.Color.separator)
            .frame(height: CDStateMetrics.hairline)
    }
}

/// Cotes du §5 absentes de `CD`.
enum CDStateMetrics {
    /// Glyphe d'un état vide : 34–36 pt (§5).
    static let emptyGlyph: CGFloat = 36
    /// Teinte du bandeau de pause — « rgba(255,149,0,.14) » du §5.
    static let pauseTint: Double = 0.14
    /// Épaisseur d'un filet.
    static let hairline: CGFloat = 1
}
