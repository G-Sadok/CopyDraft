import SwiftUI

/// Les cinq états du composant d'enregistrement de raccourci (§7).
///
/// `KeyboardShortcuts.Recorder` dessine lui-même ces états dans l'application ; cette
/// transcription en SwiftUI pur sert de référence de contrôle et de doublure d'instantané —
/// `ImageRenderer` ne rend pas une vue AppKit hébergée.
enum ShortcutRecorderState: Equatable {
    /// Repos, vide. Placeholder en `text3`.
    case empty
    /// Défini. Symboles de modificateurs, jamais les mots.
    case defined(String)
    /// En écoute. `Échap` annule, `⌫` efface.
    case listening
    /// Conflit. Bordure danger, l'ancien raccourci est conservé.
    case conflict(String)
    /// Désactivé, quand la permission d'accessibilité manque.
    case disabled(String)
}

/// Champ d'enregistrement : min 96 × 24, r 6, 13 pt medium centré (§7).
struct ShortcutRecorderChip: View {
    let state: ShortcutRecorderState

    var body: some View {
        HStack(spacing: CD.Space.x1_5) {
            if state == .listening {
                Circle()
                    .fill(CD.Color.accent)
                    .frame(width: CD.Space.x1, height: CD.Space.x1)
                    .accessibilityHidden(true)
            }
            Text(label)
                .font(isPlaceholder ? CD.Font.body : CD.Font.body.weight(.medium))
                .foregroundStyle(foreground)
        }
        .frame(minWidth: SettingsMetrics.recorderMinWidth)
        .frame(height: CD.Metric.controlHeightSmall)
        .padding(.horizontal, CD.Space.x2_5)
        .background(CD.Color.bgControl, in: RoundedRectangle(cornerRadius: CD.Radius.field))
        .overlay {
            RoundedRectangle(cornerRadius: CD.Radius.field)
                .strokeBorder(border, lineWidth: SettingsMetrics.borderWidth)
        }
        .opacity(isDisabled ? CD.Opacity.fieldDisabled : 1)
        .fixedSize()
    }

    private var isPlaceholder: Bool { state == .empty || state == .listening }

    private var isDisabled: Bool {
        if case .disabled = state { return true }
        return false
    }

    private var label: String {
        switch state {
        case .empty: L.t("recorder.empty", table: .settings)
        case .listening: L.t("recorder.listening", table: .settings)
        case .defined(let keys), .conflict(let keys), .disabled(let keys): keys
        }
    }

    private var foreground: Color {
        switch state {
        case .empty: CD.Color.text3
        case .listening: CD.Color.accent
        case .conflict: CD.Color.danger
        case .disabled: CD.Color.textDisabled
        case .defined: CD.Color.text1
        }
    }

    private var border: Color {
        switch state {
        case .listening: CD.Color.accent
        case .conflict: CD.Color.danger
        case .disabled: CD.Color.separator
        case .empty, .defined: CD.Color.borderControl
        }
    }
}
