import CopyDraftCore
import SwiftUI

/// Onglet Popup (§7) : position d'ouverture, nombre d'éléments visibles, options d'affichage.
struct PopupSettingsView: View {
    @Bindable var preferences: Preferences

    /// Bornes du curseur, reprises du PRD (FR-20) : le contrôle ne redéfinit pas ses limites.
    static let rowsRange = Limits.visibleRows

    /// Les trois positions du §7, dans leur ordre.
    static let positionOptions: [SettingsOption<PopupPosition>] = [
        SettingsOption(value: .cursor, titleKey: "popup.position.cursor"),
        SettingsOption(value: .centered, titleKey: "popup.position.centered"),
        SettingsOption(value: .menuBar, titleKey: "popup.position.menuBar")
    ]

    /// Liaison du curseur : il travaille en `Double`, le réglage est un nombre d'éléments.
    /// L'arrondi se fait ici, le bornage reste l'affaire de `Preferences`.
    static func rowsBinding(_ preferences: Preferences) -> Binding<Double> {
        Binding(
            get: { Double(preferences.visibleRows) },
            set: { preferences.visibleRows = Int($0.rounded()) }
        )
    }

    var body: some View {
        SettingsPane {
            SettingsRow(titleKey: "popup.position.label") {
                SettingsRadioGroup(
                    options: Self.positionOptions,
                    selection: $preferences.popupPosition,
                    accessibilityKey: "popup.position.label"
                )
            }

            SettingsRow(titleKey: "popup.rows.label") {
                HStack(spacing: CD.Space.x3) {
                    SettingsSlider(
                        value: Self.rowsBinding(preferences),
                        range: Double(Self.rowsRange.lowerBound)...Double(Self.rowsRange.upperBound)
                    )

                    Text(preferences.visibleRows, format: .number)
                        .font(CD.Font.body.monospacedDigit())
                        .foregroundStyle(CD.Color.text1)
                }
                .accessibilityLabel(Text(L.t("popup.rows.label", table: .settings)))

                SettingsHelp(key: "popup.rows.help")
            }

            SettingsRow(titleKey: "popup.display.label") {
                SettingsCheckbox(
                    titleKey: "popup.translucent",
                    isOn: $preferences.translucentBackground
                )
                SettingsCheckbox(
                    titleKey: "popup.showSource",
                    isOn: $preferences.showSourceApp
                )
                SettingsCheckbox(
                    titleKey: "popup.closeAfterQuickPaste",
                    isOn: $preferences.closeAfterQuickPaste
                )
            }
        }
    }
}
