import AppKit
import CopyDraftCore
import Foundation
import SwiftUI
import Testing

@testable import CopyDraftUI

// MARK: - Doublures

/// Élément d'ouverture simulé : ni `launchd`, ni bundle signé.
@MainActor
private final class FakeLoginItem: LoginItemRegistering {
    var isRegistered = false
    var failure: Error?

    struct Refused: Error {}

    func setRegistered(_ registered: Bool) throws {
        if let failure { throw failure }
        isRegistered = registered
    }
}

/// Résolution d'applications simulée : aucune dépendance aux apps installées.
@MainActor
private struct FakeResolver: ApplicationResolving {
    var known: [String: URL] = [:]

    func url(forBundleIdentifier identifier: String) -> URL? { known[identifier] }
}

@MainActor
@Suite("Réglages — fenêtre et onglets")
struct SettingsTests {
    /// Domaine de test isolé : jamais les réglages réels de l'utilisateur.
    private func makeDefaults() -> UserDefaults {
        let suite = "com.copydraft.tests.settings.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    private func makePreferences() -> Preferences {
        Preferences(defaults: makeDefaults())
    }

    // MARK: Onglets

    @Test("Les cinq onglets du design system sont couverts, dans l'ordre du §7")
    func tabsMatchDesignSystem() {
        #expect(
            SettingsTab.allCases == [.general, .shortcut, .popup, .privacy, .appearance]
        )
    }

    @Test("Chaque onglet a un libellé, un symbole et un identifiant d'item distincts")
    func tabsAreDistinct() {
        let identifiers = Set(SettingsTab.allCases.map(\.itemIdentifier))
        #expect(identifiers.count == SettingsTab.allCases.count)

        for tab in SettingsTab.allCases {
            #expect(!tab.title.isEmpty)
            #expect(NSImage(systemSymbolName: tab.symbolName, accessibilityDescription: nil) != nil)
            #expect(SettingsTab(itemIdentifier: tab.itemIdentifier) == tab)
        }
    }

    @Test("Un identifiant d'item inconnu ne désigne aucun onglet")
    func unknownIdentifier() {
        #expect(SettingsTab(itemIdentifier: NSToolbarItem.Identifier("settings.inconnu")) == nil)
    }

    // MARK: Général

    @Test("La liaison de la taille d'historique écrit dans les réglages, et l'inverse")
    func historySizeBinding() {
        let preferences = makePreferences()
        let binding = Bindable(preferences).historySize

        binding.wrappedValue = 120
        #expect(preferences.historySize == 120)

        preferences.historySize = 42
        #expect(binding.wrappedValue == 42)
    }

    @Test("Le pas-à-pas reprend les bornes du PRD sans les redéfinir")
    func historyStepperRange() {
        #expect(GeneralSettingsView.historyRange == Limits.historySize)
        #expect(GeneralSettingsView.historyRange == 10...500)
        #expect(GeneralSettingsView.historyStep > 0)
    }

    @Test("Une valeur hors bornes est ramenée dans l'intervalle", arguments: [(0, 10), (9_999, 500)])
    func historySizeIsClamped(input: Int, expected: Int) {
        let preferences = makePreferences()
        Bindable(preferences).historySize.wrappedValue = input
        #expect(preferences.historySize == expected)
    }

    @Test("« Conserver l'historique » bascule le réglage de redémarrage")
    func keepHistoryBinding() {
        let preferences = makePreferences()
        let binding = Bindable(preferences).keepHistoryOnRestart

        #expect(binding.wrappedValue)
        binding.wrappedValue = false
        #expect(preferences.keepHistoryOnRestart == false)
    }

    @Test("Le changement de langue écrit le réglage et l'applique")
    func languageBindingApplies() {
        let preferences = makePreferences()
        // Domaine nommé : « Système » retire la clé, et seule la lecture du domaine
        // persistant le prouve — `stringArray(forKey:)` retomberait sur la valeur globale.
        let suite = "com.copydraft.tests.language.\(UUID().uuidString)"
        let systemDefaults = UserDefaults(suiteName: suite)!
        systemDefaults.removePersistentDomain(forName: suite)
        let binding = GeneralSettingsView.languageBinding(preferences, defaults: systemDefaults)

        binding.wrappedValue = .english
        #expect(preferences.language == .english)
        #expect(systemDefaults.persistentDomain(forName: suite)?[LanguageApplier.key] as? [String] == ["en"])

        binding.wrappedValue = .french
        #expect(systemDefaults.persistentDomain(forName: suite)?[LanguageApplier.key] as? [String] == ["fr"])

        binding.wrappedValue = .system
        #expect(preferences.language == .system)
        #expect(systemDefaults.persistentDomain(forName: suite)?[LanguageApplier.key] == nil)
    }

    @Test("« Ouvrir à la connexion » n'est écrit qu'après un enregistrement réussi")
    func launchAtLoginSucceeds() {
        let preferences = makePreferences()
        let item = FakeLoginItem()
        let controller = LaunchAtLoginController(item: item)
        let binding = GeneralSettingsView.launchAtLoginBinding(preferences, controller: controller)

        binding.wrappedValue = true
        #expect(item.isRegistered)
        #expect(preferences.launchAtLogin)
        #expect(controller.failureMessage == nil)
    }

    @Test("Un enregistrement refusé laisse le réglage à sa place et explique pourquoi")
    func launchAtLoginFallsBack() {
        let preferences = makePreferences()
        let item = FakeLoginItem()
        item.failure = FakeLoginItem.Refused()
        let controller = LaunchAtLoginController(item: item)

        GeneralSettingsView.launchAtLoginBinding(preferences, controller: controller)
            .wrappedValue = true

        #expect(preferences.launchAtLogin == false)
        #expect(controller.failureMessage != nil)
    }

    @Test("L'ouverture de la fenêtre réaligne le réglage sur l'état réel du service")
    func launchAtLoginSynchronizes() {
        let preferences = makePreferences()
        let item = FakeLoginItem()
        item.isRegistered = true

        LaunchAtLoginController(item: item).synchronize(with: preferences)
        #expect(preferences.launchAtLogin)
    }

    // MARK: Popup

    @Test("Le curseur d'éléments visibles reprend les bornes du PRD")
    func rowsSliderRange() {
        #expect(PopupSettingsView.rowsRange == Limits.visibleRows)
        #expect(PopupSettingsView.rowsRange == 5...12)
    }

    @Test("Le curseur arrondit et reste borné", arguments: [(7.4, 7), (11.6, 12), (99.0, 12), (1.0, 5)])
    func rowsBindingRounds(input: Double, expected: Int) {
        let preferences = makePreferences()
        PopupSettingsView.rowsBinding(preferences).wrappedValue = input
        #expect(preferences.visibleRows == expected)
    }

    @Test("La position d'ouverture écrit dans les réglages")
    func positionBinding() {
        let preferences = makePreferences()
        Bindable(preferences).popupPosition.wrappedValue = .menuBar
        #expect(preferences.popupPosition == .menuBar)
    }

    // MARK: Confidentialité

    @Test("« Ignorer les contenus confidentiels » ne peut pas être décoché (FR-9)")
    func confidentialContentCannotBeTurnedOff() {
        #expect(PrivacySettingsView.ignoresConfidentialContent)

        let binding = PrivacySettingsView.confidentialContentBinding
        binding.wrappedValue = false
        #expect(binding.wrappedValue)
    }

    @Test("L'ajout d'une application exclue passe par les réglages")
    func addExcludedApplication() {
        let preferences = makePreferences()
        let model = ExcludedApplicationsModel(preferences: preferences, resolver: FakeResolver())

        #expect(model.add(bundleIdentifier: "com.agilebits.onepassword7"))
        #expect(preferences.excludedBundleIdentifiers == ["com.agilebits.onepassword7"])

        // Deux fois la même application n'en fait pas deux lignes.
        #expect(model.add(bundleIdentifier: "com.agilebits.onepassword7") == false)
        #expect(preferences.excludedBundleIdentifiers.count == 1)

        // Une entrée vide n'est pas une application.
        #expect(model.add(bundleIdentifier: "   ") == false)
        #expect(preferences.excludedBundleIdentifiers.count == 1)
    }

    @Test("La suppression retire l'identifiant des réglages")
    func removeExcludedApplication() {
        let preferences = makePreferences()
        preferences.excludedBundleIdentifiers = ["com.apple.Terminal", "com.apple.keychainaccess"]
        let model = ExcludedApplicationsModel(preferences: preferences, resolver: FakeResolver())

        model.remove(bundleIdentifier: "com.apple.Terminal")
        #expect(preferences.excludedBundleIdentifiers == ["com.apple.keychainaccess"])
        #expect(model.isEmpty == false)

        model.remove(bundleIdentifier: "com.apple.keychainaccess")
        #expect(model.isEmpty)
    }

    @Test("Une application absente s'affiche par son nom, jamais par son identifiant brut")
    func fallbackNameIsReadable() {
        let preferences = makePreferences()
        preferences.excludedBundleIdentifiers = ["com.apple.Terminal"]
        let model = ExcludedApplicationsModel(preferences: preferences, resolver: FakeResolver())

        #expect(model.applications.map(\.name) == ["Terminal"])
        #expect(ExcludedApplicationsModel.fallbackName(for: "sansPoint") == "sansPoint")
    }

    @Test("Un paquet sans identifiant de bundle n'est pas ajouté")
    func applicationWithoutBundleIdentifier() {
        let preferences = makePreferences()
        let model = ExcludedApplicationsModel(preferences: preferences, resolver: FakeResolver())

        #expect(model.add(applicationAt: URL(fileURLWithPath: "/tmp/absente.app")) == false)
        #expect(preferences.excludedBundleIdentifiers.isEmpty)
    }

    // MARK: Apparence

    @Test("Le thème est écrit et appliqué immédiatement (FR-46)")
    func themeBindingApplies() {
        let preferences = makePreferences()
        var applied: [AppTheme] = []
        let binding = AppearanceSettingsView.themeBinding(preferences) { applied.append($0) }

        binding.wrappedValue = .dark
        #expect(preferences.theme == .dark)
        #expect(applied == [.dark])
    }

    @Test(
        "Chaque thème désigne l'apparence attendue",
        arguments: [
            (AppTheme.system, NSAppearance.Name?.none),
            (.light, .aqua),
            (.dark, .darkAqua)
        ]
    )
    func themeMapsToAppearance(theme: AppTheme, expected: NSAppearance.Name?) {
        #expect(AppearanceApplier.appearanceName(for: theme) == expected)
    }

    @Test("« Respecter Réduire les animations » est une garantie, pas un réglage")
    func reducedMotionIsAlwaysRespected() {
        #expect(AppearanceSettingsView.respectsReducedMotion)
    }

    @Test("La couleur d'accent bascule entre système et personnalisée")
    func accentBinding() {
        let preferences = makePreferences()
        let binding = Bindable(preferences).accentFollowsSystem

        #expect(binding.wrappedValue)
        binding.wrappedValue = false
        #expect(preferences.accentFollowsSystem == false)
    }

    // MARK: Raccourci

    @Test("Le collage rapide bascule le réglage ⌘1–⌘9")
    func quickPasteBinding() {
        let preferences = makePreferences()
        Bindable(preferences).quickPasteEnabled.wrappedValue = false
        #expect(preferences.quickPasteEnabled == false)
    }

    @Test("Le composant d'enregistrement couvre les cinq états du §7")
    func recorderStates() {
        let states: [ShortcutRecorderState] = [
            .empty, .defined("⇧⌘V"), .listening, .conflict("⌘C"), .disabled("⇧⌘V")
        ]
        #expect(Set(states.map(String.init(describing:))).count == states.count)
    }
}

// MARK: - Localisation

@MainActor
@Suite("Réglages — localisation")
struct SettingsLocalizationTests {
    /// Toutes les clés de la table `Settings`, dans l'ordre des onglets du §7.
    static let keys = [
        "tab.general", "tab.shortcut", "tab.popup", "tab.privacy", "tab.appearance",
        "general.startup.label", "general.launchAtLogin", "general.launchAtLogin.error",
        "general.historySize.label", "general.historySize.unit", "general.historySize.help",
        "general.restart.label", "general.keepHistory", "general.keepHistory.help",
        "general.language.label", "general.language.french", "general.language.english",
        "general.language.system", "general.footer %@",
        "shortcut.openPopup.label", "shortcut.plainText.label", "shortcut.quickPaste.label",
        "shortcut.quickPaste", "shortcut.quickPaste.help", "shortcut.footer",
        "shortcut.missing", "shortcut.permission.missing", "shortcut.permission.open",
        "recorder.empty", "recorder.listening",
        "popup.position.label", "popup.position.cursor", "popup.position.centered",
        "popup.position.menuBar", "popup.rows.label", "popup.rows.help", "popup.display.label",
        "popup.translucent", "popup.showSource", "popup.closeAfterQuickPaste",
        "privacy.capture.label", "privacy.capture", "privacy.sensitive.label", "privacy.sensitive",
        "privacy.sensitive.help", "privacy.excluded.label", "privacy.excluded.help",
        "privacy.excluded.empty", "privacy.excluded.add", "privacy.excluded.remove",
        "privacy.excluded.panel.prompt", "privacy.excluded.panel.message",
        "privacy.history.label", "privacy.clearAll",
        "appearance.theme.label", "appearance.theme.light", "appearance.theme.dark",
        "appearance.theme.system", "appearance.theme.help", "appearance.accent.label",
        "appearance.accent.system", "appearance.accent.custom", "appearance.motion.label",
        "appearance.motion", "appearance.motion.help"
    ]

    private static let table = L.Table.settings.rawValue

    private func bundle(for language: String) throws -> Bundle {
        try #require(
            Bundle.module.path(forResource: language, ofType: "lproj").map(Bundle.init(path:)) ?? nil,
            "catalogue \(language).lproj introuvable"
        )
    }

    @Test("Chaque clé des réglages existe en français et en anglais", arguments: ["fr", "en"])
    func everySettingsKeyIsTranslated(language: String) throws {
        let bundle = try bundle(for: language)

        for key in Self.keys {
            let value = bundle.localizedString(forKey: key, value: nil, table: Self.table)
            #expect(value != key, "clé « \(key) » non traduite en \(language)")
            #expect(!value.isEmpty)
        }
    }

    @Test("Les deux catalogues portent exactement les mêmes clés")
    func catalogsHaveTheSameKeys() throws {
        func keys(of language: String) throws -> Set<String> {
            let url = try #require(
                bundle(for: language).url(forResource: Self.table, withExtension: "strings"),
                "table \(Self.table) absente de \(language).lproj"
            )
            let contents = try #require(NSDictionary(contentsOf: url) as? [String: String])
            return Set(contents.keys)
        }

        let french = try keys(of: "fr")
        let english = try keys(of: "en")

        #expect(french == english, "clés divergentes : \(french.symmetricDifference(english))")
        #expect(Set(Self.keys) == french, "la liste du test et le catalogue ont divergé")
    }

    @Test("Les textes du §7 sont repris mot pour mot")
    func frenchWordingMatchesDesignSystem() throws {
        let bundle = try bundle(for: "fr")
        func value(_ key: String) -> String {
            bundle.localizedString(forKey: key, value: nil, table: Self.table)
        }

        #expect(value("general.launchAtLogin") == "Ouvrir CopyDraft à la connexion")
        #expect(
            value("general.historySize.help")
                == "De 10 à 500. Les éléments non épinglés les plus anciens sont supprimés en premier."
        )
        #expect(
            value("general.keepHistory.help")
                == "Stocké en local et chiffré. Décoché, l'historique est vidé à chaque extinction."
        )
        #expect(value("popup.rows.help") == "De 5 à 12. Au-delà, la liste défile.")
        #expect(value("popup.closeAfterQuickPaste") == "Fermer après un collage rapide ⌘n")
        #expect(value("privacy.sensitive") == "Ignorer les contenus confidentiels")
        #expect(
            value("privacy.excluded.help") == "Rien de ce qui est copié depuis ces apps n'est enregistré."
        )
        #expect(value("privacy.clearAll") == "Tout effacer…")
        #expect(value("appearance.motion") == "Respecter « Réduire les animations »")
        #expect(value("appearance.motion.help") == "Réglages système → Accessibilité → Affichage.")
        #expect(value("shortcut.quickPaste") == "Activer ⌘1 à ⌘9 dans la popup")
    }

    /// Libellés de la colonne de gauche, dans l'ordre des onglets.
    static let columnLabels = [
        "general.startup.label", "general.historySize.label", "general.restart.label",
        "general.language.label",
        "shortcut.openPopup.label", "shortcut.plainText.label", "shortcut.quickPaste.label",
        "popup.position.label", "popup.rows.label", "popup.display.label",
        "privacy.capture.label", "privacy.sensitive.label", "privacy.excluded.label",
        "privacy.history.label",
        "appearance.theme.label", "appearance.accent.label", "appearance.motion.label"
    ]

    /// La colonne de 150 pt du §7 est un token, pas une suggestion : un libellé plus large
    /// se replie sur deux lignes, toujours aligné à droite. Un seul le fait aujourd'hui —
    /// « Coller sans mise en forme : », dont le §7 fixe le texte au mot près. Ce test cadre
    /// la situation : toute nouvelle formulation trop longue se signale ici.
    @Test("Un seul libellé déborde la colonne de 150 pt", arguments: ["fr", "en"])
    func labelsFitTheColumn(language: String) throws {
        let bundle = try bundle(for: language)
        let font = NSFont.systemFont(ofSize: 13)

        let overflowing = Self.columnLabels.filter { key in
            let label = bundle.localizedString(forKey: key, value: nil, table: Self.table)
            let width = (label as NSString).size(withAttributes: [.font: font]).width
            return width > CD.Metric.settingsLabelColumn
        }

        #expect(overflowing == ["shortcut.plainText.label"], "libellés trop larges : \(overflowing)")
    }

    @Test("Le pied de l'onglet Général interpole la version")
    func footerInterpolatesVersion() {
        let footer = L.t("general.footer \("1.0.4")", table: .settings)
        #expect(footer.contains("1.0.4"))
        // Le pour-cent doit survivre au formatage : « 100 % » et non « 100 ».
        #expect(footer.contains("100 %"))
    }
}
