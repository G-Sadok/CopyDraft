import Foundation
import Testing

@testable import CopyDraftCore

@MainActor
@Suite("Réglages")
struct PreferencesTests {
    /// Domaine de test isolé : jamais les réglages réels de l'utilisateur.
    private func makeDefaults() -> UserDefaults {
        let suite = "com.copydraft.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test("Les valeurs par défaut sont celles du PRD et du design system")
    func defaultValues() {
        let preferences = Preferences(defaults: makeDefaults())

        #expect(preferences.historySize == 25)
        #expect(preferences.visibleRows == 8)
        #expect(preferences.popupPosition == .cursor)
        #expect(preferences.theme == .system)
        #expect(preferences.language == .system)
        #expect(preferences.keepHistoryOnRestart)
        #expect(preferences.captureEnabled)
        #expect(preferences.quickPasteEnabled)
        #expect(preferences.closeAfterQuickPaste)
        #expect(preferences.translucentBackground)
        #expect(preferences.showSourceApp)
        #expect(preferences.clearAllKeepsPinned)
        #expect(preferences.accentFollowsSystem)
        #expect(preferences.launchAtLogin == false)
        #expect(preferences.hasCompletedOnboarding == false)
        #expect(preferences.excludedBundleIdentifiers.isEmpty)
        #expect(preferences.pollingInterval == 0.4)
    }

    @Test("Les réglages survivent à une nouvelle instance")
    func persistence() {
        let defaults = makeDefaults()

        let first = Preferences(defaults: defaults)
        first.historySize = 120
        first.visibleRows = 11
        first.popupPosition = .menuBar
        first.theme = .dark
        first.language = .english
        first.captureEnabled = false
        first.excludedBundleIdentifiers = ["com.agilebits.onepassword"]
        first.launchAtLogin = true

        let second = Preferences(defaults: defaults)
        #expect(second.historySize == 120)
        #expect(second.visibleRows == 11)
        #expect(second.popupPosition == .menuBar)
        #expect(second.theme == .dark)
        #expect(second.language == .english)
        #expect(second.captureEnabled == false)
        #expect(second.excludedBundleIdentifiers == ["com.agilebits.onepassword"])
        #expect(second.launchAtLogin)
    }

    @Test(
        "La taille d'historique reste dans 10…500",
        arguments: [(0, 10), (9, 10), (10, 10), (25, 25), (500, 500), (501, 500), (10_000, 500)]
    )
    func historySizeBounds(input: Int, expected: Int) {
        let preferences = Preferences(defaults: makeDefaults())
        preferences.historySize = input
        #expect(preferences.historySize == expected)
    }

    @Test(
        "Le nombre d'éléments visibles reste dans 5…12",
        arguments: [(1, 5), (4, 5), (5, 5), (8, 8), (12, 12), (13, 12), (99, 12)]
    )
    func visibleRowsBounds(input: Int, expected: Int) {
        let preferences = Preferences(defaults: makeDefaults())
        preferences.visibleRows = input
        #expect(preferences.visibleRows == expected)
    }

    @Test("L'intervalle de sondage reste dans 0,2…1 s")
    func pollingBounds() {
        let preferences = Preferences(defaults: makeDefaults())
        preferences.pollingInterval = 0.05
        #expect(preferences.pollingInterval == 0.2)
        preferences.pollingInterval = 5
        #expect(preferences.pollingInterval == 1.0)
    }

    /// Une valeur hors bornes forcée dans `UserDefaults` (ligne de commande, migration)
    /// ne doit pas contaminer l'application.
    @Test("Une valeur hors bornes déjà persistée est ramenée dans l'intervalle")
    func storedOutOfBoundsIsClamped() {
        let defaults = makeDefaults()
        defaults.set(9_999, forKey: Preferences.Key.historySize.rawValue)
        defaults.set(1, forKey: Preferences.Key.visibleRows.rawValue)

        let preferences = Preferences(defaults: defaults)
        #expect(preferences.historySize == 500)
        #expect(preferences.visibleRows == 5)
    }

    @Test("Une valeur d'énumération inconnue retombe sur le défaut")
    func unknownEnumFallsBack() {
        let defaults = makeDefaults()
        defaults.set("aléatoire", forKey: Preferences.Key.popupPosition.rawValue)
        defaults.set("néon", forKey: Preferences.Key.theme.rawValue)

        let preferences = Preferences(defaults: defaults)
        #expect(preferences.popupPosition == .cursor)
        #expect(preferences.theme == .system)
    }

    @Test("La liste d'exclusion est dédoublonnée et nettoyée")
    func excludedApplicationsAreNormalized() {
        let preferences = Preferences(defaults: makeDefaults())
        preferences.excludedBundleIdentifiers = [
            "com.apple.Terminal", " com.apple.Terminal ", "", "   ", "com.agilebits.onepassword"
        ]
        #expect(
            preferences.excludedBundleIdentifiers
                == ["com.apple.Terminal", "com.agilebits.onepassword"]
        )
    }

    @Test("La réinitialisation restaure toutes les valeurs par défaut")
    func reset() {
        let defaults = makeDefaults()
        let preferences = Preferences(defaults: defaults)
        preferences.historySize = 500
        preferences.theme = .light
        preferences.captureEnabled = false
        preferences.excludedBundleIdentifiers = ["com.apple.Terminal"]

        preferences.resetToDefaults()

        #expect(preferences.historySize == 25)
        #expect(preferences.theme == .system)
        #expect(preferences.captureEnabled)
        #expect(preferences.excludedBundleIdentifiers.isEmpty)
        #expect(Preferences(defaults: defaults).historySize == 25)
    }

    /// Les bornes du code et celles du design system ne doivent pas diverger.
    @Test("Les bornes correspondent au design system")
    func limitsMatchDesignSystem() {
        #expect(Limits.historySize == 10...500)
        #expect(Limits.visibleRows == 5...12)
        #expect(Limits.itemBytes == 4 * 1024 * 1024)
        #expect(Limits.menuItems == 5)
        #expect(Limits.quickPasteSlots == 10)
    }
}
