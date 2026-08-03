import CopyDraftCore
import SwiftUI

/// Pied de la popup (§3, §5) : décompte à gauche, actions à droite, hauteur 32.
///
/// Le décompte dit toujours la vérité du moment : « 25 éléments · 1 épinglé » au repos,
/// « 3 sur 25 éléments » pendant une recherche, « 2 éléments · en pause » quand la capture
/// est suspendue.
public struct FooterBar: View {
    private let itemCount: Int
    private let totalCount: Int
    private let pinnedCount: Int
    private let isSearching: Bool
    private let isPaused: Bool
    private let onTogglePause: () -> Void
    private let onOpenSettings: () -> Void
    private let onClearAll: () -> Void

    public init(
        itemCount: Int,
        totalCount: Int,
        pinnedCount: Int,
        isSearching: Bool,
        isPaused: Bool,
        onTogglePause: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onClearAll: @escaping () -> Void
    ) {
        self.itemCount = itemCount
        self.totalCount = totalCount
        self.pinnedCount = pinnedCount
        self.isSearching = isSearching
        self.isPaused = isPaused
        self.onTogglePause = onTogglePause
        self.onOpenSettings = onOpenSettings
        self.onClearAll = onClearAll
    }

    public var body: some View {
        HStack(spacing: CD.Space.x2) {
            Text(Self.summary(
                itemCount: itemCount, totalCount: totalCount, pinnedCount: pinnedCount,
                isSearching: isSearching, isPaused: isPaused
            ))
            .font(CD.Font.small)
            .foregroundStyle(CD.Color.text2)
            .lineLimit(1)

            Spacer(minLength: CD.Space.x2)

            iconButton(
                systemName: isPaused ? "play.fill" : "pause.fill",
                label: L.t(isPaused ? "menubar.resumeCapture" : "menubar.pauseCapture"),
                action: onTogglePause
            )
            iconButton(
                systemName: "trash",
                label: L.t("menubar.clearAll"),
                action: onClearAll,
                isEnabled: totalCount > 0
            )
            iconButton(
                systemName: "gearshape",
                label: L.t("menubar.settings"),
                action: onOpenSettings
            )
        }
        .padding(.horizontal, CD.Space.x2)
        .frame(height: CD.Metric.footerHeight)
    }

    /// Décompte affiché, en toutes lettres et accordé.
    static func summary(
        itemCount: Int, totalCount: Int, pinnedCount: Int, isSearching: Bool, isPaused: Bool
    ) -> String {
        if isSearching {
            return String(
                format: L.t("popup.footer.filtered %lld %lld"), itemCount, totalCount
            )
        }

        var parts = [String(format: L.t("popup.footer.items %lld"), totalCount)]
        if pinnedCount > 0 {
            parts.append(String(format: L.t("popup.footer.pinned %lld"), pinnedCount))
        }
        if isPaused {
            parts.append(L.t("popup.footer.paused"))
        }
        return parts.joined(separator: " · ")
    }

    /// Bouton d'icône : glyphe de 15 pt dans une zone cliquable de 22 pt (§10 accessibilité).
    private func iconButton(
        systemName: String, label: String, action: @escaping () -> Void, isEnabled: Bool = true
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(isEnabled ? CD.Color.text2 : CD.Color.textDisabled)
                .frame(width: CD.Metric.hitTargetMin, height: CD.Metric.hitTargetMin)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .help(label)
        .accessibilityLabel(label)
    }
}
