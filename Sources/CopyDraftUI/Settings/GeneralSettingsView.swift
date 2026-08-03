import CopyDraftCore
import SwiftUI

/// Onglet Général (§7) : démarrage, taille de l'historique, conservation au redémarrage,
/// langue, et le pied qui rappelle la version et le traitement local.
struct GeneralSettingsView: View {
    @Bindable var preferences: Preferences
    let launchAtLogin: LaunchAtLoginController
    /// Version affichée au pied. Injectée pour que l'instantané ne dépende pas du bundle.
    var version: String = AppInfo.shortVersion
    /// Cible du réglage de langue. Injectée pour qu'un test n'écrive pas dans les
    /// préférences système de l'utilisateur.
    var languageDefaults: UserDefaults = .standard

    /// Bornes du pas-à-pas, reprises telles quelles du PRD (FR-13) : le contrôle ne redéfinit
    /// jamais ses propres limites.
    static let historyRange = Limits.historySize
    /// Pas du pas-à-pas — régler 10 à 500 un élément à la fois n'aurait pas de sens.
    static let historyStep = 5

    /// Ordre du §7 : Français, English, puis « Système ».
    static let languageOptions: [SettingsOption<AppLanguage>] = [
        SettingsOption(value: .french, titleKey: "general.language.french"),
        SettingsOption(value: .english, titleKey: "general.language.english"),
        SettingsOption(value: .system, titleKey: "general.language.system")
    ]

    /// Liaison de la bascule d'ouverture à la connexion : l'écriture passe par le contrôleur,
    /// qui n'enregistre le réglage qu'en cas de succès.
    static func launchAtLoginBinding(
        _ preferences: Preferences,
        controller: LaunchAtLoginController
    ) -> Binding<Bool> {
        Binding(
            get: { preferences.launchAtLogin },
            set: { controller.setEnabled($0, in: preferences) }
        )
    }

    /// Liaison de la langue : le réglage est écrit **et** appliqué dans la foulée (FR-46).
    static func languageBinding(
        _ preferences: Preferences,
        defaults: UserDefaults
    ) -> Binding<AppLanguage> {
        Binding(
            get: { preferences.language },
            set: { language in
                preferences.language = language
                LanguageApplier.apply(language, to: defaults)
            }
        )
    }

    var body: some View {
        SettingsPane {
            SettingsRow(titleKey: "general.startup.label") {
                SettingsSwitch(
                    titleKey: "general.launchAtLogin",
                    isOn: Self.launchAtLoginBinding(preferences, controller: launchAtLogin)
                )

                if let failure = launchAtLogin.failureMessage {
                    Text(failure)
                        .font(CD.Font.small)
                        .foregroundStyle(CD.Color.danger)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            SettingsRow(titleKey: "general.historySize.label") {
                HStack(spacing: CD.Space.x2) {
                    SettingsValueField(value: preferences.historySize)
                    SettingsStepper(
                        value: $preferences.historySize,
                        range: Self.historyRange,
                        step: Self.historyStep
                    )
                    Text(L.t("general.historySize.unit", table: .settings))
                        .font(CD.Font.body)
                        .foregroundStyle(CD.Color.text1)
                }
                .accessibilityLabel(Text(L.t("general.historySize.label", table: .settings)))

                SettingsHelp(key: "general.historySize.help")
            }

            SettingsRow(titleKey: "general.restart.label") {
                SettingsCheckbox(
                    titleKey: "general.keepHistory",
                    isOn: $preferences.keepHistoryOnRestart
                )

                SettingsHelp(key: "general.keepHistory.help")
            }

            SettingsRow(titleKey: "general.language.label") {
                SettingsMenuPicker(
                    options: Self.languageOptions,
                    selection: Self.languageBinding(preferences, defaults: languageDefaults),
                    accessibilityKey: "general.language.label"
                )
            }

            SettingsSeparator()

            Text(L.t("general.footer \(version)", table: .settings))
                .font(CD.Font.small)
                .foregroundStyle(CD.Color.text2)
        }
    }
}
