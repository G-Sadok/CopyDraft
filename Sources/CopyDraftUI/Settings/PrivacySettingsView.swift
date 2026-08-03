import CopyDraftCore
import SwiftUI

/// Onglet Confidentialité (§7) : capture, contenus confidentiels, applications exclues,
/// effacement de l'historique.
struct PrivacySettingsView: View {
    @Bindable var preferences: Preferences
    let excluded: ExcludedApplicationsModel
    /// Faux quand l'historique est déjà vide : « Tout effacer… » n'aurait rien à effacer.
    let canClearHistory: Bool
    let onClearAll: () -> Void

    @State private var selection: String?

    /// « Ignorer les contenus confidentiels » est toujours actif (FR-9). Ce n'est pas un
    /// réglage : c'est une garantie, affichée cochée et désactivée pour qu'elle se voie.
    static let ignoresConfidentialContent = true

    /// Liaison en lecture seule du même : toute écriture est ignorée.
    static var confidentialContentBinding: Binding<Bool> {
        Binding(get: { ignoresConfidentialContent }, set: { _ in })
    }

    var body: some View {
        SettingsPane {
            SettingsRow(titleKey: "privacy.capture.label") {
                SettingsSwitch(titleKey: "privacy.capture", isOn: $preferences.captureEnabled)
            }

            SettingsRow(titleKey: "privacy.sensitive.label") {
                SettingsCheckbox(
                    titleKey: "privacy.sensitive",
                    isOn: Self.confidentialContentBinding,
                    isEnabled: false
                )

                SettingsHelp(key: "privacy.sensitive.help")
            }

            SettingsRow(titleKey: "privacy.excluded.label") {
                excludedList
                SettingsHelp(key: "privacy.excluded.help")
            }

            SettingsRow(titleKey: "privacy.history.label") {
                CDButton(
                    L.t("privacy.clearAll", table: .settings),
                    style: .destructiveQuiet,
                    isEnabled: canClearHistory,
                    action: onClearAll
                )
            }
        }
    }

    // MARK: Liste des applications exclues

    /// Cadre de liste avec son pied « + / − » (§7).
    ///
    /// Une liste dessinée plutôt qu'un `List` : trois ou quatre lignes ne justifient pas un
    /// défilement, et la fenêtre de réglages ne défile jamais.
    private var excludedList: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(excluded.applications) { application in
                    row(for: application)
                }
                if excluded.isEmpty {
                    Text(L.t("privacy.excluded.empty", table: .settings))
                        .font(CD.Font.caption)
                        .foregroundStyle(CD.Color.text3)
                        .padding(.horizontal, CD.Space.x2)
                        .frame(height: SettingsMetrics.listRowHeight)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            listFooter
        }
        .frame(height: SettingsMetrics.listHeight)
        .background(CD.Color.bgContent, in: RoundedRectangle(cornerRadius: CD.Radius.field))
        .overlay {
            RoundedRectangle(cornerRadius: CD.Radius.field)
                .strokeBorder(CD.Color.borderControl, lineWidth: SettingsMetrics.borderWidth)
        }
        .clipShape(RoundedRectangle(cornerRadius: CD.Radius.field))
        .accessibilityElement(children: .contain)
    }

    private func row(for application: ExcludedApplication) -> some View {
        HStack(spacing: CD.Space.x2) {
            icon(for: application)
            Text(application.name)
                .font(CD.Font.caption)
                .foregroundStyle(CD.Color.text1)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, CD.Space.x2)
        .frame(height: SettingsMetrics.listRowHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selection == application.id ? CD.Color.selectionUnemphasized : .clear)
        .contentShape(Rectangle())
        .onTapGesture { selection = application.id }
        .accessibilityLabel(Text(application.name))
    }

    @ViewBuilder
    private func icon(for application: ExcludedApplication) -> some View {
        if let icon = application.icon {
            Image(nsImage: icon)
                .resizable()
                .frame(width: SettingsMetrics.listIcon, height: SettingsMetrics.listIcon)
                .accessibilityHidden(true)
        } else {
            // L'application n'est plus installée : un gabarit neutre, jamais l'identifiant brut.
            RoundedRectangle(cornerRadius: CD.Radius.thumbnail)
                .fill(CD.Color.fill3)
                .frame(width: SettingsMetrics.listIcon, height: SettingsMetrics.listIcon)
                .accessibilityHidden(true)
        }
    }

    private var listFooter: some View {
        HStack(spacing: 0) {
            footerButton(symbol: "plus", labelKey: "privacy.excluded.add", isEnabled: true) {
                for url in excluded.chooseApplications() {
                    excluded.add(applicationAt: url)
                }
            }
            footerButton(
                symbol: "minus",
                labelKey: "privacy.excluded.remove",
                isEnabled: selection != nil
            ) {
                guard let selection else { return }
                excluded.remove(bundleIdentifier: selection)
                self.selection = nil
            }
            Spacer(minLength: 0)
        }
        .frame(height: SettingsMetrics.listFooterHeight)
        .background(CD.Color.bgWindow)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(CD.Color.separator)
                .frame(height: SettingsMetrics.borderWidth)
        }
    }

    private func footerButton(
        symbol: String,
        labelKey: String.LocalizationValue,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .imageScale(.small)
                .foregroundStyle(isEnabled ? CD.Color.text2 : CD.Color.textDisabled)
                // La cible reste à 22 pt même si le glyphe en fait moins (§2.2).
                .frame(width: CD.Metric.hitTargetMin, height: SettingsMetrics.listFooterHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(Text(L.t(labelKey, table: .settings)))
    }
}
