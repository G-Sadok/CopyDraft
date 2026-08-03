import CopyDraftCore
import SwiftUI

/// Onglet Apparence (§7) : thème, couleur d'accent, respect de « Réduire les animations ».
struct AppearanceSettingsView: View {
    @Bindable var preferences: Preferences
    /// Renvoi vers Réglages système → Accessibilité → Affichage.
    let onOpenAccessibilitySettings: () -> Void

    /// Pastilles d'accent du §7. Décoratives et estompées : CopyDraft suit la couleur d'accent
    /// du système et n'en stocke aucune — la ligne existe pour dire ce qui est suivi.
    private static let swatches: [Color] = [
        Color(nsColor: .systemBlue),
        Color(nsColor: .systemPurple),
        Color(nsColor: .systemGreen),
        Color(nsColor: .systemOrange),
        Color(nsColor: .systemGray)
    ]

    /// Liaison du thème : le réglage est écrit **et** appliqué dans la foulée (FR-46).
    static func themeBinding(
        _ preferences: Preferences,
        apply: @escaping (AppTheme) -> Void = { AppearanceApplier.apply($0) }
    ) -> Binding<AppTheme> {
        Binding(
            get: { preferences.theme },
            set: { theme in
                preferences.theme = theme
                apply(theme)
            }
        )
    }

    /// Ordre du §7 : Clair, Sombre, Système.
    static let themeOptions: [SettingsOption<AppTheme>] = [
        SettingsOption(value: .light, titleKey: "appearance.theme.light"),
        SettingsOption(value: .dark, titleKey: "appearance.theme.dark"),
        SettingsOption(value: .system, titleKey: "appearance.theme.system")
    ]

    /// « Suivre le système » ou « Personnalisée » — deux états d'un même réglage booléen.
    static let accentOptions: [SettingsOption<Bool>] = [
        SettingsOption(value: true, titleKey: "appearance.accent.system"),
        SettingsOption(value: false, titleKey: "appearance.accent.custom")
    ]

    var body: some View {
        SettingsPane {
            SettingsRow(titleKey: "appearance.theme.label") {
                SettingsSegmented(
                    options: Self.themeOptions,
                    selection: Self.themeBinding(preferences),
                    accessibilityKey: "appearance.theme.label"
                )

                SettingsHelp(key: "appearance.theme.help")
            }

            SettingsRow(titleKey: "appearance.accent.label") {
                SettingsRadioGroup(
                    options: Self.accentOptions,
                    selection: $preferences.accentFollowsSystem,
                    accessibilityKey: "appearance.accent.label"
                )

                HStack(spacing: CD.Space.x1_5) {
                    ForEach(Array(Self.swatches.enumerated()), id: \.offset) { _, color in
                        Circle()
                            .fill(color)
                            .frame(width: SettingsMetrics.swatch, height: SettingsMetrics.swatch)
                    }
                }
                .opacity(SettingsMetrics.swatchOpacity)
                .accessibilityHidden(true)
            }

            SettingsRow(titleKey: "appearance.motion.label") {
                // Le respect de « Réduire les animations » n'est pas négociable (§10) : la
                // case dit ce que fait CopyDraft, elle ne se décoche pas.
                SettingsCheckbox(
                    titleKey: "appearance.motion",
                    isOn: .constant(Self.respectsReducedMotion),
                    isEnabled: false
                )

                // Le chemin des Réglages système est cliquable : le lire sans pouvoir s'y
                // rendre serait une invitation à chercher.
                CDButton(
                    L.t("appearance.motion.help", table: .settings),
                    style: .quiet,
                    action: onOpenAccessibilitySettings
                )
                // Le bouton discret porte sa propre marge (§2.1) ; on la reprend pour que le
                // texte reste aligné sur la case au-dessus de lui.
                .padding(.leading, -CD.Space.x2)
            }
        }
    }

    /// CopyDraft respecte toujours le réglage système (§10) : aucune préférence ne le
    /// contredit.
    static let respectsReducedMotion = true
}
