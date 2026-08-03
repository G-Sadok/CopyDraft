import SwiftUI

// MARK: - Grammaire de mise en page des réglages (§7)

/// Corps d'un onglet de réglages : 480 pt de large, marges de la gouttière, contrôles à la
/// taille `small` d'AppKit (§7).
///
/// La hauteur n'est jamais fixée : c'est elle qui commande celle de la fenêtre, laquelle
/// s'ajuste à l'onglet affiché. Aucun défilement — un onglet qui aurait besoin de défiler
/// serait un onglet de trop.
struct SettingsPane<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: SettingsMetrics.rowSpacing) {
            content
        }
        .controlSize(.small)
        .padding(.horizontal, CD.Metric.settingsGutter)
        .padding(.top, CD.Space.x5)
        .padding(.bottom, CD.Space.x6)
        .frame(width: CD.Metric.settingsWidth, alignment: .leading)
        .background(CD.Color.bgWindow)
    }
}

/// Une ligne de réglage : libellé aligné à droite sur 150 pt, gouttière de 24 pt, contrôles
/// à gauche (§7) — la grammaire des Réglages système.
///
/// Les deux colonnes sont alignées sur la première ligne de base et non sur leur centre :
/// un contrôle qui porte un texte d'aide sous lui ne doit pas décaler son libellé.
struct SettingsRow<Control: View>: View {
    let titleKey: String.LocalizationValue
    @ViewBuilder let control: Control

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: CD.Metric.settingsGutter) {
            Text(L.t(titleKey, table: .settings))
                .font(CD.Font.body)
                .foregroundStyle(CD.Color.text1)
                .frame(width: CD.Metric.settingsLabelColumn, alignment: .trailing)

            VStack(alignment: .leading, spacing: SettingsMetrics.controlSpacing) {
                control
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Texte d'aide posé **sous** le contrôle qu'il explique (§7) : 11 pt, texte secondaire.
///
/// Le design system en fait une règle : l'explication ne s'écrit ni dans le libellé, ni dans
/// une infobulle, elle se lit sous le contrôle.
struct SettingsHelp: View {
    let key: String.LocalizationValue

    var body: some View {
        Text(L.t(key, table: .settings))
            .font(CD.Font.small)
            .foregroundStyle(CD.Color.text2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Filet de séparation avant le pied d'un onglet (§7).
struct SettingsSeparator: View {
    var body: some View {
        Rectangle()
            .fill(CD.Color.separator)
            .frame(height: SettingsMetrics.hairline)
    }
}

/// Champ de valeur en lecture seule d'un pas-à-pas (§7) : chiffres tabulaires alignés à
/// droite dans un cadre de contrôle.
///
/// La valeur ne se saisit pas au clavier : elle se règle au pas-à-pas. C'est ce que dit le
/// design system (« pas-à-pas 10 à 500 ») et cela évite une saisie hors bornes à corriger.
struct SettingsValueField: View {
    let value: Int

    var body: some View {
        Text(value, format: .number)
            .font(CD.Font.body.monospacedDigit())
            .foregroundStyle(CD.Color.text1)
            .frame(width: SettingsMetrics.valueFieldWidth, alignment: .trailing)
            .frame(height: SettingsMetrics.compactControlHeight)
            .padding(.horizontal, CD.Space.x2)
            .background(CD.Color.bgControl, in: RoundedRectangle(cornerRadius: CD.Radius.field))
            .overlay {
                RoundedRectangle(cornerRadius: CD.Radius.field)
                    .strokeBorder(CD.Color.borderControl, lineWidth: SettingsMetrics.borderWidth)
            }
    }
}

// MARK: - Cotes du §7 absentes de `CD`

/// Cotes propres à la fenêtre de réglages que `CD` ne nomme pas encore.
///
/// Même parti que `CDSearchFieldMetrics` : regroupées ici plutôt que dispersées en valeurs
/// littérales dans les vues, en attendant des tokens `CD.Metric.settings*`.
enum SettingsMetrics {
    /// Écart vertical entre deux lignes de réglage (§7 : `gap: 14px 24px`).
    static let rowSpacing: CGFloat = 14
    /// Écart entre un contrôle et son texte d'aide.
    static let controlSpacing: CGFloat = 5
    /// Hauteur des contrôles compacts du §7 (champ de valeur, bouton de pied).
    static let compactControlHeight: CGFloat = 22
    /// Largeur du champ de valeur d'un pas-à-pas.
    static let valueFieldWidth: CGFloat = 30
    /// Largeur du rail d'un curseur (§7 : `width: 148px`).
    static let sliderWidth: CGFloat = 148
    /// Épaisseur du rail et diamètre du curseur (§7).
    static let sliderRail: CGFloat = 4
    static let sliderKnob: CGFloat = 14
    /// Cote d'une case à cocher, d'un bouton radio et du badge d'une liste déroulante (§7).
    static let markSize: CGFloat = 14
    static let markRadius: CGFloat = 3.5
    static let markGlyph: CGFloat = 9
    /// Écart entre une marque et son libellé (§7 : `gap: 7px`).
    static let markGap: CGFloat = 7
    /// Point plein d'un bouton radio sélectionné.
    static let radioDot: CGFloat = 5
    /// Interrupteur (§7 : `26 × 15`, pastille de 12).
    static let switchWidth: CGFloat = 26
    static let switchHeight: CGFloat = 15
    static let switchKnob: CGFloat = 12
    static let switchPadding: CGFloat = 1.5
    /// Contrôle segmenté (§7 : `padding: 3`, `radius: 7`).
    static let segmentedPadding: CGFloat = 3
    static let segmentedRadius: CGFloat = 7
    /// Marge intérieure gauche d'une liste déroulante (§7 : `padding: 0 6 0 9`).
    static let menuLeading: CGFloat = 9
    /// Largeur des chevrons d'un pas-à-pas (§7 : `width: 15px`).
    static let stepperWidth: CGFloat = 15
    static let stepperGlyph: CGFloat = 7
    /// Épaisseur d'un tracé de contrôle — un demi-point.
    static let borderWidth: CGFloat = 0.5
    /// Épaisseur d'un filet.
    static let hairline: CGFloat = 1
    /// Hauteur d'une ligne de la liste d'applications exclues (§7 : `height: 26px`).
    static let listRowHeight: CGFloat = 26
    /// Hauteur du pied « + / − » de cette liste.
    static let listFooterHeight: CGFloat = 22
    /// Icône d'application dans la liste.
    static let listIcon: CGFloat = 16
    /// Hauteur du cadre de liste, quatre lignes visibles.
    static let listHeight: CGFloat = 26 * 3 + 22
    /// Pastille de couleur d'accent (§7).
    static let swatch: CGFloat = 15
    /// Opacité des pastilles d'accent, décoratives tant qu'aucune couleur n'est stockée (§7).
    static let swatchOpacity: Double = 0.5
    /// Cote minimale du composant d'enregistrement de raccourci (§7 : « min-w 96 × 24 »).
    static let recorderMinWidth: CGFloat = 96
}
