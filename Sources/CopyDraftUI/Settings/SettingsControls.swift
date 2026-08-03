import SwiftUI

// MARK: - Contrôles de la fenêtre de réglages (§7)

/// Un choix d'une liste de réglage : sa valeur et le libellé qui la nomme.
struct SettingsOption<Value: Hashable>: Identifiable {
    let value: Value
    let titleKey: String.LocalizationValue

    var id: Value { value }
    var title: String { L.t(titleKey, table: .settings) }
}

/// Vrai quand les contrôles doivent être **dessinés** plutôt que délégués à AppKit.
///
/// La fenêtre de réglages utilise les contrôles `small` d'AppKit (§7) : ce sont eux qui
/// apportent le comportement clavier, le focus et VoiceOver. Mais `ImageRenderer` ne dessine
/// pas une vue AppKit hébergée — il pose un cartouche jaune à la place. Les instantanés de
/// contrôle basculent donc sur une transcription SwiftUI fidèle aux cotes du §7, exactement
/// comme `CDSearchFieldBody` reçoit un `Text` à la place de son `TextField`.
private struct SettingsDrawnControlsKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var settingsDrawsControls: Bool {
        get { self[SettingsDrawnControlsKey.self] }
        set { self[SettingsDrawnControlsKey.self] = newValue }
    }
}

extension View {
    /// Bascule les contrôles de réglages en rendu dessiné — réservé aux instantanés.
    func settingsDrawnControls(_ drawn: Bool = true) -> some View {
        environment(\.settingsDrawsControls, drawn)
    }
}

// MARK: Interrupteur

/// Bascule à interrupteur — « Démarrage », « Capture » (§7).
struct SettingsSwitch: View {
    let titleKey: String.LocalizationValue
    @Binding var isOn: Bool

    @Environment(\.settingsDrawsControls) private var drawn

    var body: some View {
        if drawn {
            HStack(spacing: CD.Space.x2) {
                Capsule()
                    .fill(isOn ? CD.Color.accent : CD.Color.fill3)
                    .frame(width: SettingsMetrics.switchWidth, height: SettingsMetrics.switchHeight)
                    .overlay(alignment: isOn ? .trailing : .leading) {
                        Circle()
                            .fill(.white)
                            .frame(height: SettingsMetrics.switchKnob)
                            .padding(SettingsMetrics.switchPadding)
                    }
                label
            }
        } else {
            Toggle(L.t(titleKey, table: .settings), isOn: $isOn)
                .toggleStyle(.switch)
                .font(CD.Font.body)
        }
    }

    private var label: some View {
        Text(L.t(titleKey, table: .settings))
            .font(CD.Font.body)
            .foregroundStyle(CD.Color.text1)
    }
}

// MARK: Case à cocher

/// Case à cocher de réglage (§7). Désactivée, elle reste lisible : c'est le cas de
/// « Ignorer les contenus confidentiels », toujours actif (FR-9).
struct SettingsCheckbox: View {
    let titleKey: String.LocalizationValue
    @Binding var isOn: Bool
    var isEnabled = true

    @Environment(\.settingsDrawsControls) private var drawn

    var body: some View {
        if drawn {
            HStack(spacing: SettingsMetrics.markGap) {
                box
                Text(L.t(titleKey, table: .settings))
                    .font(CD.Font.body)
                    .foregroundStyle(isEnabled ? CD.Color.text1 : CD.Color.text2)
            }
        } else {
            Toggle(L.t(titleKey, table: .settings), isOn: $isOn)
                .font(CD.Font.body)
                .disabled(!isEnabled)
        }
    }

    private var box: some View {
        RoundedRectangle(cornerRadius: SettingsMetrics.markRadius)
            .fill(fill)
            .frame(width: SettingsMetrics.markSize, height: SettingsMetrics.markSize)
            .overlay {
                if !isOn {
                    RoundedRectangle(cornerRadius: SettingsMetrics.markRadius)
                        .strokeBorder(CD.Color.borderControl, lineWidth: SettingsMetrics.borderWidth)
                }
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: SettingsMetrics.markGlyph, weight: .bold))
                        .foregroundStyle(isEnabled ? CD.Color.textOnAccent : CD.Color.text2)
                }
            }
    }

    private var fill: Color {
        guard isOn else { return CD.Color.bgControl }
        return isEnabled ? CD.Color.accent : CD.Color.fill3
    }
}

// MARK: Boutons radio

/// Groupe de boutons radio — « Position », « Couleur d'accent » (§7).
struct SettingsRadioGroup<Value: Hashable>: View {
    let options: [SettingsOption<Value>]
    @Binding var selection: Value
    let accessibilityKey: String.LocalizationValue

    @Environment(\.settingsDrawsControls) private var drawn

    var body: some View {
        if drawn {
            VStack(alignment: .leading, spacing: SettingsMetrics.markGap) {
                ForEach(options) { option in
                    HStack(spacing: SettingsMetrics.markGap) {
                        dot(isSelected: option.value == selection)
                        Text(option.title)
                            .font(CD.Font.body)
                            .foregroundStyle(CD.Color.text1)
                    }
                }
            }
        } else {
            Picker("", selection: $selection) {
                ForEach(options) { option in
                    Text(option.title).tag(option.value)
                }
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
            .accessibilityLabel(Text(L.t(accessibilityKey, table: .settings)))
        }
    }

    private func dot(isSelected: Bool) -> some View {
        Circle()
            .fill(isSelected ? CD.Color.accent : CD.Color.bgControl)
            .frame(width: SettingsMetrics.markSize, height: SettingsMetrics.markSize)
            .overlay {
                if isSelected {
                    Circle()
                        .fill(CD.Color.textOnAccent)
                        .frame(width: SettingsMetrics.radioDot, height: SettingsMetrics.radioDot)
                } else {
                    Circle().strokeBorder(
                        CD.Color.borderControl, lineWidth: SettingsMetrics.borderWidth
                    )
                }
            }
    }
}

// MARK: Contrôle segmenté

/// Contrôle segmenté — « Thème » (§7).
struct SettingsSegmented<Value: Hashable>: View {
    let options: [SettingsOption<Value>]
    @Binding var selection: Value
    let accessibilityKey: String.LocalizationValue

    @Environment(\.settingsDrawsControls) private var drawn

    var body: some View {
        if drawn {
            HStack(spacing: CD.Space.x0_5) {
                ForEach(options) { option in
                    let isSelected = option.value == selection
                    Text(option.title)
                        .font(isSelected ? CD.Font.caption.weight(.medium) : CD.Font.caption)
                        .foregroundStyle(isSelected ? CD.Color.text1 : CD.Color.text2)
                        .padding(.vertical, CD.Space.x1)
                        .padding(.horizontal, CD.Metric.buttonPaddingHorizontal)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: CD.Radius.badge + CD.Space.x0_5 / 2)
                                    .fill(CD.Color.bgControl)
                            }
                        }
                }
            }
            .padding(SettingsMetrics.segmentedPadding)
            .background(
                CD.Color.fill1,
                in: RoundedRectangle(cornerRadius: SettingsMetrics.segmentedRadius)
            )
        } else {
            Picker("", selection: $selection) {
                ForEach(options) { option in
                    Text(option.title).tag(option.value)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .accessibilityLabel(Text(L.t(accessibilityKey, table: .settings)))
        }
    }
}

// MARK: Liste déroulante

/// Liste déroulante — « Langue » (§7).
struct SettingsMenuPicker<Value: Hashable>: View {
    let options: [SettingsOption<Value>]
    @Binding var selection: Value
    let accessibilityKey: String.LocalizationValue

    @Environment(\.settingsDrawsControls) private var drawn

    var body: some View {
        if drawn {
            HStack(spacing: CD.Space.x2) {
                Text(options.first { $0.value == selection }?.title ?? "")
                    .font(CD.Font.body)
                    .foregroundStyle(CD.Color.text1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: SettingsMetrics.markGlyph, weight: .semibold))
                    .foregroundStyle(CD.Color.textOnAccent)
                    .frame(width: SettingsMetrics.markSize, height: SettingsMetrics.markSize)
                    .background(
                        CD.Color.accent,
                        in: RoundedRectangle(cornerRadius: CD.Radius.thumbnail)
                    )
            }
            .padding(.leading, SettingsMetrics.menuLeading)
            .padding(.trailing, CD.Space.x1_5)
            .frame(height: SettingsMetrics.compactControlHeight)
            .background(CD.Color.bgControl, in: RoundedRectangle(cornerRadius: CD.Radius.field))
            .overlay {
                RoundedRectangle(cornerRadius: CD.Radius.field)
                    .strokeBorder(CD.Color.borderControl, lineWidth: SettingsMetrics.borderWidth)
            }
        } else {
            Picker("", selection: $selection) {
                ForEach(options) { option in
                    Text(option.title).tag(option.value)
                }
            }
            .labelsHidden()
            .fixedSize()
            .accessibilityLabel(Text(L.t(accessibilityKey, table: .settings)))
        }
    }
}

// MARK: Pas-à-pas

/// Pas-à-pas — « Taille de l'historique » (§7).
struct SettingsStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int

    @Environment(\.settingsDrawsControls) private var drawn

    var body: some View {
        if drawn {
            VStack(spacing: 0) {
                chevron("chevron.up")
                Rectangle()
                    .fill(CD.Color.borderControl)
                    .frame(height: SettingsMetrics.borderWidth)
                chevron("chevron.down")
            }
            .frame(width: SettingsMetrics.stepperWidth, height: SettingsMetrics.compactControlHeight)
            .background(CD.Color.bgControl, in: RoundedRectangle(cornerRadius: CD.Radius.field))
            .overlay {
                RoundedRectangle(cornerRadius: CD.Radius.field)
                    .strokeBorder(CD.Color.borderControl, lineWidth: SettingsMetrics.borderWidth)
            }
        } else {
            Stepper("", value: $value, in: range, step: step)
                .labelsHidden()
        }
    }

    private func chevron(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: SettingsMetrics.stepperGlyph, weight: .bold))
            .foregroundStyle(CD.Color.text2)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: Curseur

/// Curseur — « Éléments visibles » (§7).
struct SettingsSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>

    @Environment(\.settingsDrawsControls) private var drawn

    var body: some View {
        if drawn {
            let fraction = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
            Capsule()
                .fill(CD.Color.fill3)
                .frame(width: SettingsMetrics.sliderWidth, height: SettingsMetrics.sliderRail)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(CD.Color.accent)
                        .frame(width: SettingsMetrics.sliderWidth * fraction)
                }
                .overlay(alignment: .leading) {
                    Circle()
                        .fill(.white)
                        // Un liseré, sinon la pastille disparaît sur un fond clair (§7 lui
                        // donne une ombre portée, que `ImageRenderer` ne dessinerait pas).
                        .overlay {
                            Circle().strokeBorder(
                                CD.Color.borderControl, lineWidth: SettingsMetrics.borderWidth
                            )
                        }
                        .frame(
                            width: SettingsMetrics.sliderKnob, height: SettingsMetrics.sliderKnob
                        )
                        .offset(
                            x: (SettingsMetrics.sliderWidth - SettingsMetrics.sliderKnob) * fraction
                        )
                }
        } else {
            Slider(value: $value, in: range, step: 1)
                .frame(width: SettingsMetrics.sliderWidth)
        }
    }
}
