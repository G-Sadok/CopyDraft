import AppKit
import CopyDraftCore
import Foundation
import SwiftUI
import Testing

@testable import CopyDraftUI

/// Élément d'ouverture inerte : un instantané ne touche pas au `launchd` de la session.
@MainActor
private final class InertLoginItem: LoginItemRegistering {
    var isRegistered = false
    func setRegistered(_ registered: Bool) throws { isRegistered = registered }
}

/// Rend chaque onglet de la fenêtre de réglages en PNG, en clair et en sombre.
///
/// Seul contrôle visuel possible sans capture d'écran. Désactivé par défaut :
/// `CD_SNAPSHOTS=1 swift test` écrit les images dans `dist/snapshots/`.
///
/// `ImageRenderer` ne dessine ni `ScrollView`, ni `TextField`, ni vue AppKit hébergée : les
/// onglets n'en contiennent aucun, et l'enregistreur de raccourci est remplacé ici par sa
/// transcription SwiftUI, `ShortcutRecorderChip`.
@Suite("Instantanés de la fenêtre de réglages")
struct SettingsSnapshotTests {
    static let isEnabled = ProcessInfo.processInfo.environment["CD_SNAPSHOTS"] == "1"

    struct Case: Sendable, CustomStringConvertible {
        let tab: SettingsTab
        let appearance: NSAppearance.Name

        var description: String {
            "\(tab.rawValue)-\(appearance == .darkAqua ? "dark" : "light")"
        }
    }

    static let cases: [Case] = SettingsTab.allCases.flatMap { tab in
        [NSAppearance.Name.aqua, .darkAqua].map { Case(tab: tab, appearance: $0) }
    }

    /// Jeu de réglages figé, dans un domaine jetable : l'instantané doit être reproductible.
    @MainActor
    private static func makePreferences() -> Preferences {
        let suite = "com.copydraft.tests.snapshots.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let preferences = Preferences(defaults: defaults)
        preferences.excludedBundleIdentifiers = [
            "com.agilebits.onepassword7", "com.apple.keychainaccess", "com.apple.Terminal"
        ]
        return preferences
    }

    @MainActor
    @ViewBuilder
    private static func content(for tab: SettingsTab, preferences: Preferences) -> some View {
        switch tab {
        case .general:
            GeneralSettingsView(
                preferences: preferences,
                launchAtLogin: LaunchAtLoginController(item: InertLoginItem()),
                version: "1.0.4",
                languageDefaults: UserDefaults(suiteName: "com.copydraft.tests.snapshots.lang")!
            )
        case .shortcut:
            ShortcutSettingsView(
                preferences: preferences,
                isAccessibilityGranted: false,
                hasOpenPopupShortcut: true,
                onOpenAccessibilitySettings: {}
            ) { name in
                ShortcutRecorderChip(
                    state: .defined(name == .openPopup ? "⇧⌘V" : "⌥⇧⌘V")
                )
            }
        case .popup:
            PopupSettingsView(preferences: preferences)
        case .privacy:
            PrivacySettingsView(
                preferences: preferences,
                excluded: ExcludedApplicationsModel(preferences: preferences),
                canClearHistory: true,
                onClearAll: {}
            )
        case .appearance:
            AppearanceSettingsView(preferences: preferences, onOpenAccessibilitySettings: {})
        }
    }

    @MainActor
    @Test(
        "Rendu clair et sombre",
        .enabled(if: SettingsSnapshotTests.isEnabled),
        arguments: SettingsSnapshotTests.cases
    )
    func renderTab(_ testCase: Case) throws {
        let appearance = try #require(NSAppearance(named: testCase.appearance))
        let outputDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("dist/snapshots")
        try FileManager.default.createDirectory(
            at: outputDirectory, withIntermediateDirectories: true
        )

        let preferences = Self.makePreferences()
        var data: Data?
        appearance.performAsCurrentDrawingAppearance {
            let renderer = ImageRenderer(
                content: Self.content(for: testCase.tab, preferences: preferences)
                    .settingsDrawnControls()
                    .environment(\.colorScheme, testCase.appearance == .darkAqua ? .dark : .light)
            )
            renderer.scale = 2
            guard let image = renderer.nsImage,
                let tiff = image.tiffRepresentation,
                let bitmap = NSBitmapImageRep(data: tiff)
            else { return }
            data = bitmap.representation(using: .png, properties: [:])
        }

        let png = try #require(data, "rendu impossible")
        let file = outputDirectory.appendingPathComponent("settings-\(testCase).png")
        try png.write(to: file)
        #expect(png.count > 5_000, "image suspecte : \(png.count) octets")
    }
}
