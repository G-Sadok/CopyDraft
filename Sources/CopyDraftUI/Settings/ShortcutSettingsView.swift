import CopyDraftCore
import KeyboardShortcuts
import SwiftUI

/// Onglet Raccourci (§7) : les deux raccourcis globaux, le collage rapide, et l'état de la
/// permission d'accessibilité quand elle manque (FR-31).
///
/// L'enregistreur est injecté : en production c'est `KeyboardShortcuts.Recorder`, qui refuse
/// déjà les combinaisons réservées par le système (FR-29) ; dans un instantané c'est
/// `ShortcutRecorderChip`, parce qu'`ImageRenderer` ne dessine pas une vue AppKit hébergée.
struct ShortcutSettingsView<Recorder: View>: View {
    @Bindable var preferences: Preferences
    /// Vrai quand CopyDraft a l'accès aux fonctions d'accessibilité : sans lui le raccourci
    /// ouvre bien la popup, mais le collage automatique se replie (FR-31, FR-34).
    let isAccessibilityGranted: Bool
    /// Faux quand aucun raccourci d'ouverture n'est défini : l'état doit se voir ici, et la
    /// popup reste joignable par ⌥-clic sur l'icône de la barre de menus (FR-31).
    var hasOpenPopupShortcut = true
    let onOpenAccessibilitySettings: () -> Void
    @ViewBuilder let recorder: (KeyboardShortcuts.Name) -> Recorder

    var body: some View {
        SettingsPane {
            SettingsRow(titleKey: "shortcut.openPopup.label") {
                recorder(.openPopup)
            }

            SettingsRow(titleKey: "shortcut.plainText.label") {
                recorder(.openPopupPlainText)
            }

            SettingsRow(titleKey: "shortcut.quickPaste.label") {
                SettingsCheckbox(
                    titleKey: "shortcut.quickPaste",
                    isOn: $preferences.quickPasteEnabled
                )

                SettingsHelp(key: "shortcut.quickPaste.help")
            }

            if !hasOpenPopupShortcut {
                notice(messageKey: "shortcut.missing", actionKey: nil)
            }

            if !isAccessibilityGranted {
                notice(
                    messageKey: "shortcut.permission.missing",
                    actionKey: "shortcut.permission.open"
                )
            }

            SettingsSeparator()

            Text(L.t("shortcut.footer", table: .settings))
                .font(CD.Font.small)
                .foregroundStyle(CD.Color.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Mention d'état posée sous les enregistreurs (FR-31).
    ///
    /// Elle ne bloque rien : elle dit ce qui se passera et, quand il y a quelque chose à
    /// faire, propose d'aller le faire — le même repli qu'au §8.
    private func notice(
        messageKey: String.LocalizationValue,
        actionKey: String.LocalizationValue?
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: CD.Space.x2) {
            Image(systemName: "exclamationmark.triangle")
                .imageScale(.small)
                .foregroundStyle(CD.Color.warning)
                .accessibilityHidden(true)

            Text(L.t(messageKey, table: .settings))
                .font(CD.Font.small)
                .foregroundStyle(CD.Color.text1)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let actionKey {
                CDButton(
                    L.t(actionKey, table: .settings),
                    style: .quiet,
                    action: onOpenAccessibilitySettings
                )
            }
        }
        .padding(.horizontal, CD.Space.x2_5)
        .padding(.vertical, CD.Space.x1_5)
        .background(
            CD.Color.warning.opacity(CD.Opacity.pauseBannerTint),
            in: RoundedRectangle(cornerRadius: CD.Radius.field)
        )
    }
}
