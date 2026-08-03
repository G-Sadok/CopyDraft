import SwiftUI

// MARK: - Cotes de l'écran (§8)

/// Cotes du §8 absentes de `CD` : l'onboarding est la seule surface qui les emploie.
enum OnboardingMetrics {
    /// Hauteur réservée aux feux tricolores : la fenêtre est en `fullSizeContentView` pour que
    /// son cadre mesure exactement 560 × 420 (§8).
    static let titleBarInset: CGFloat = 30
    /// Marge horizontale du contenu.
    static let horizontalPadding: CGFloat = 44
    /// Côté de l'icône d'application.
    static let mark: CGFloat = 56
    /// Écart entre deux blocs de l'écran. Serré : les 420 pt du §8 doivent contenir l'état
    /// « non accordée », qui est le plus chargé des deux.
    static let blockGap: CGFloat = 10
    /// Pastille numérotée d'une étape.
    static let stepNumber: CGFloat = 20
    /// Capuchon de touche du rappel de raccourci.
    static let keycap: CGFloat = 34
    static let keycapRadius: CGFloat = 8
    /// Relief bas d'un capuchon.
    static let keycapRelief: CGFloat = 1.5
    /// Pastille d'état, entièrement arrondie.
    static let statusHeight: CGFloat = 22
    static let statusDot: CGFloat = 7
    /// Puce de confirmation de l'état accordé.
    static let checkGlyph: CGFloat = 13
    /// Largeur de lecture confortable des paragraphes.
    static let proseWidth: CGFloat = 400
}

// MARK: - Écran

/// Écran d'onboarding du §8 : 560 × 420, un seul état à la fois (FR-47).
///
/// Les deux états partagent la même charpente — icône, titre, paragraphe, liste, boutons — et
/// ne diffèrent que par leur contenu : c'est ce qui rend la bascule automatique du FR-48
/// visuellement calme, sans que la fenêtre semble se reconstruire.
struct OnboardingView: View {
    let content: OnboardingContent
    let onPrimary: () -> Void
    let onSecondary: () -> Void
    /// Faux quand le bouton secondaire n'est raccordé à rien — état accordé non câblé.
    var isSecondaryEnabled = true

    var body: some View {
        VStack(spacing: OnboardingMetrics.blockGap) {
            AppMark(size: OnboardingMetrics.mark, isConfirmed: content.isGranted)

            VStack(spacing: CD.Space.x2) {
                Text(content.title)
                    .cdFont(CD.Font.titleLarge, lineHeight: CD.LineHeight.titleLarge, size: 26)
                    .foregroundStyle(CD.Color.text1)

                Text(content.body)
                    .font(CD.Font.body)
                    .foregroundStyle(CD.Color.text2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: OnboardingMetrics.proseWidth)
            }

            if content.isGranted {
                ShortcutKeycaps(keys: content.shortcutKeys)
                ConfirmationList(points: content.items)
            } else {
                StepsCard(steps: content.items)
                if let statusLabel = content.statusLabel {
                    StatusPill(text: statusLabel)
                }
            }

            HStack(spacing: CD.Space.x2_5) {
                CDButton(content.primaryTitle, style: .primary, action: onPrimary)
                CDButton(
                    content.secondaryTitle,
                    style: .secondary,
                    isEnabled: isSecondaryEnabled,
                    action: onSecondary
                )
            }

            if let footnote = content.footnote {
                Text(footnote)
                    .font(CD.Font.small)
                    .foregroundStyle(CD.Color.text3)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: OnboardingMetrics.proseWidth)
            }
        }
        .padding(.horizontal, OnboardingMetrics.horizontalPadding)
        .padding(.top, OnboardingMetrics.titleBarInset)
        .padding(.bottom, CD.Space.x6)
        .frame(width: CD.Metric.onboardingWidth, height: CD.Metric.onboardingHeight)
        .background(CD.Color.bgWindow)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Étapes numérotées

/// Les trois étapes du §8, dans une carte à filets : une marche à suivre, pas une liste à puces.
private struct StepsCard: View {
    let steps: [String]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                if index > 0 {
                    Rectangle()
                        .fill(CD.Color.separator)
                        .frame(height: CDFocusRing.borderWidth)
                }
                row(number: index + 1, text: step)
            }
        }
        .background(CD.Color.bgContent, in: RoundedRectangle(cornerRadius: CD.Radius.field))
        .overlay {
            RoundedRectangle(cornerRadius: CD.Radius.field)
                .strokeBorder(CD.Color.separator, lineWidth: CDFocusRing.borderWidth)
        }
    }

    private func row(number: Int, text: String) -> some View {
        HStack(spacing: CD.Space.x2_5) {
            Text("\(number)")
                .font(CD.Font.shortcut)
                .foregroundStyle(CD.Color.textOnAccent)
                .frame(width: OnboardingMetrics.stepNumber, height: OnboardingMetrics.stepNumber)
                .background(CD.Color.accent, in: Circle())
                .accessibilityHidden(true)

            Text(text)
                .font(CD.Font.caption)
                .foregroundStyle(CD.Color.text1)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, CD.Space.x3)
        .padding(.vertical, CD.Space.x1_5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            Text(
                LocalizedTable.format("step.accessibilityLabel", table: .onboarding, number)
                    + " — " + text
            )
        )
    }
}

// MARK: - Indicateur d'état

/// Pastille « Permission non accordée » : ambre, point plein, sans bouton (§8).
private struct StatusPill: View {
    let text: String

    var body: some View {
        HStack(spacing: CD.Space.x1_5) {
            Circle()
                .fill(CD.Color.warning)
                .frame(width: OnboardingMetrics.statusDot, height: OnboardingMetrics.statusDot)
                .accessibilityHidden(true)

            Text(text)
                .font(CD.Font.detail)
                .foregroundStyle(CD.Color.text1)
        }
        .padding(.horizontal, CD.Space.x2_5)
        .frame(height: OnboardingMetrics.statusHeight)
        .background(
            CD.Color.warning.opacity(CD.Opacity.pauseBannerTint),
            in: Capsule()
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Rappel du raccourci

/// Le raccourci d'ouverture **dessiné en touches** (§8) : « ⇧ ⌘ V », jamais la chaîne de texte.
private struct ShortcutKeycaps: View {
    let keys: [String]

    var body: some View {
        HStack(spacing: CD.Space.x1) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                Text(key)
                    .font(CD.Font.title3)
                    .foregroundStyle(CD.Color.text1)
                    .frame(
                        minWidth: OnboardingMetrics.keycap, minHeight: OnboardingMetrics.keycap
                    )
                    .background(
                        CD.Color.bgControl,
                        in: RoundedRectangle(cornerRadius: OnboardingMetrics.keycapRadius)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: OnboardingMetrics.keycapRadius)
                            .strokeBorder(
                                CD.Color.borderControl, lineWidth: CDFocusRing.borderWidth
                            )
                    }
                    // Relief bas : c'est ce qui fait lire un capuchon plutôt qu'une étiquette.
                    .shadow(color: CD.Color.separator, radius: 0, y: OnboardingMetrics.keycapRelief)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            Text(
                LocalizedTable.format(
                    "shortcut.accessibilityLabel", table: .onboarding, keys.joined(separator: " ")
                )
            )
        )
    }
}

// MARK: - Points de confirmation

/// Les trois points de l'état accordé : ce que CopyDraft fait désormais tout seul (§8).
private struct ConfirmationList: View {
    let points: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: CD.Space.x1_5) {
            ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                HStack(spacing: CD.Space.x2_5) {
                    Image(systemName: "checkmark")
                        .font(.system(size: OnboardingMetrics.checkGlyph, weight: .semibold))
                        .foregroundStyle(CD.Color.success)
                        .accessibilityHidden(true)

                    Text(point)
                        .font(CD.Font.caption)
                        .foregroundStyle(CD.Color.text1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }
}
