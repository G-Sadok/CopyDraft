import Foundation
import Observation

/// Réglages de CopyDraft, observables et persistés dans `UserDefaults`.
///
/// Toute écriture est immédiate : aucun bouton « Appliquer », aucun redémarrage (FR-46).
/// Les valeurs hors bornes sont ramenées dans `Limits` à l'écriture comme à la lecture, y
/// compris si elles ont été forcées en ligne de commande.
@MainActor
@Observable
public final class Preferences {
    /// Clés de persistance. Définies une seule fois : aucune chaîne de clé ailleurs.
    enum Key: String, CaseIterable {
        case launchAtLogin
        case historySize
        case keepHistoryOnRestart
        case language
        case quickPasteEnabled
        case closeAfterQuickPaste
        case popupPosition
        case visibleRows
        case translucentBackground
        case showSourceApp
        case captureEnabled
        case excludedBundleIdentifiers
        case clearAllKeepsPinned
        case theme
        case accentFollowsSystem
        case pollingInterval
        case hasCompletedOnboarding
        case accessibilityWasGranted
    }

    @ObservationIgnored private let defaults: UserDefaults

    // MARK: Général

    /// Ouvrir CopyDraft à la connexion (§7).
    public var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Key.launchAtLogin.rawValue) }
    }

    /// Nombre d'éléments conservés, 10 à 500, défaut 25 (FR-13).
    ///
    /// Accesseurs manuels : réassigner la propriété depuis son propre `didSet` réentre
    /// dans les accesseurs générés par `@Observable` et boucle.
    @ObservationIgnored private var storedHistorySize: Int
    public var historySize: Int {
        get {
            access(keyPath: \.historySize)
            return storedHistorySize
        }
        set {
            withMutation(keyPath: \.historySize) {
                storedHistorySize = newValue.clamped(to: Limits.historySize)
                defaults.set(storedHistorySize, forKey: Key.historySize.rawValue)
            }
        }
    }

    /// Conserver l'historique non épinglé au redémarrage (FR-16). Les épinglés survivent
    /// dans tous les cas.
    public var keepHistoryOnRestart: Bool {
        didSet { defaults.set(keepHistoryOnRestart, forKey: Key.keepHistoryOnRestart.rawValue) }
    }

    /// Langue de l'interface (FR-44).
    public var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: Key.language.rawValue) }
    }

    // MARK: Collage rapide

    /// Activer ⌘1 à ⌘9 dans la popup (FR-37).
    public var quickPasteEnabled: Bool {
        didSet { defaults.set(quickPasteEnabled, forKey: Key.quickPasteEnabled.rawValue) }
    }

    /// Fermer la popup après un collage rapide ⌘n (FR-37).
    public var closeAfterQuickPaste: Bool {
        didSet { defaults.set(closeAfterQuickPaste, forKey: Key.closeAfterQuickPaste.rawValue) }
    }

    // MARK: Popup

    /// Position d'ouverture, défaut « au curseur » (FR-21, FR-22).
    public var popupPosition: PopupPosition {
        didSet { defaults.set(popupPosition.rawValue, forKey: Key.popupPosition.rawValue) }
    }

    /// Éléments visibles avant défilement, 5 à 12, défaut 8 (FR-20).
    @ObservationIgnored private var storedVisibleRows: Int
    public var visibleRows: Int {
        get {
            access(keyPath: \.visibleRows)
            return storedVisibleRows
        }
        set {
            withMutation(keyPath: \.visibleRows) {
                storedVisibleRows = newValue.clamped(to: Limits.visibleRows)
                defaults.set(storedVisibleRows, forKey: Key.visibleRows.rawValue)
            }
        }
    }

    /// Fond translucide de la popup ; décoché, le matériau cède la place au fond opaque.
    public var translucentBackground: Bool {
        didSet { defaults.set(translucentBackground, forKey: Key.translucentBackground.rawValue) }
    }

    /// Afficher l'application source dans les métadonnées de cellule.
    public var showSourceApp: Bool {
        didSet { defaults.set(showSourceApp, forKey: Key.showSourceApp.rawValue) }
    }

    // MARK: Confidentialité

    /// Enregistrer l'historique. Faux = capture suspendue (FR-10).
    public var captureEnabled: Bool {
        didSet { defaults.set(captureEnabled, forKey: Key.captureEnabled.rawValue) }
    }

    /// Applications dont le contenu copié n'est jamais enregistré (FR-11).
    @ObservationIgnored private var storedExcludedBundleIdentifiers: [String]
    public var excludedBundleIdentifiers: [String] {
        get {
            access(keyPath: \.excludedBundleIdentifiers)
            return storedExcludedBundleIdentifiers
        }
        set {
            withMutation(keyPath: \.excludedBundleIdentifiers) {
                storedExcludedBundleIdentifiers = Self.normalize(newValue)
                defaults.set(
                    storedExcludedBundleIdentifiers,
                    forKey: Key.excludedBundleIdentifiers.rawValue
                )
            }
        }
    }

    /// « Tout effacer » conserve les éléments épinglés (FR-12).
    public var clearAllKeepsPinned: Bool {
        didSet { defaults.set(clearAllKeepsPinned, forKey: Key.clearAllKeepsPinned.rawValue) }
    }

    // MARK: Apparence

    public var theme: AppTheme {
        didSet { defaults.set(theme.rawValue, forKey: Key.theme.rawValue) }
    }

    /// Suivre la couleur d'accent du système (§7).
    public var accentFollowsSystem: Bool {
        didSet { defaults.set(accentFollowsSystem, forKey: Key.accentFollowsSystem.rawValue) }
    }

    // MARK: Interne

    /// Intervalle de sondage de `changeCount`, en secondes (NFR-4). Non exposé dans les
    /// réglages : réservé au diagnostic.
    @ObservationIgnored private var storedPollingInterval: TimeInterval
    public var pollingInterval: TimeInterval {
        get {
            access(keyPath: \.pollingInterval)
            return storedPollingInterval
        }
        set {
            withMutation(keyPath: \.pollingInterval) {
                storedPollingInterval = newValue.clamped(to: Limits.pollingInterval)
                defaults.set(storedPollingInterval, forKey: Key.pollingInterval.rawValue)
            }
        }
    }

    /// Dernier état connu de l'autorisation d'accessibilité.
    ///
    /// Sert à distinguer une **révocation** — l'autorisation était là, elle ne l'est plus, il
    /// faut le dire — d'une autorisation simplement jamais accordée, où l'utilisateur a déjà
    /// répondu « Plus tard » et n'a pas à revoir la même fenêtre à chaque lancement.
    public var accessibilityWasGranted: Bool {
        didSet {
            defaults.set(accessibilityWasGranted, forKey: Key.accessibilityWasGranted.rawValue)
        }
    }

    /// L'onboarding a déjà été mené à son terme (FR-47).
    public var hasCompletedOnboarding: Bool {
        didSet {
            defaults.set(hasCompletedOnboarding, forKey: Key.hasCompletedOnboarding.rawValue)
        }
    }

    // MARK: Initialisation

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        launchAtLogin = defaults.bool(forKey: Key.launchAtLogin.rawValue, default: false)
        storedHistorySize = defaults.integer(forKey: Key.historySize.rawValue, default: 25)
            .clamped(to: Limits.historySize)
        keepHistoryOnRestart = defaults.bool(
            forKey: Key.keepHistoryOnRestart.rawValue, default: true
        )
        language = defaults.decodable(forKey: Key.language.rawValue, default: AppLanguage.system)

        quickPasteEnabled = defaults.bool(forKey: Key.quickPasteEnabled.rawValue, default: true)
        closeAfterQuickPaste = defaults.bool(
            forKey: Key.closeAfterQuickPaste.rawValue, default: true
        )

        popupPosition = defaults.decodable(
            forKey: Key.popupPosition.rawValue, default: PopupPosition.cursor
        )
        storedVisibleRows = defaults.integer(forKey: Key.visibleRows.rawValue, default: 8)
            .clamped(to: Limits.visibleRows)
        translucentBackground = defaults.bool(
            forKey: Key.translucentBackground.rawValue, default: true
        )
        showSourceApp = defaults.bool(forKey: Key.showSourceApp.rawValue, default: true)

        captureEnabled = defaults.bool(forKey: Key.captureEnabled.rawValue, default: true)
        storedExcludedBundleIdentifiers = Self.normalize(
            defaults.stringArray(forKey: Key.excludedBundleIdentifiers.rawValue) ?? []
        )
        clearAllKeepsPinned = defaults.bool(
            forKey: Key.clearAllKeepsPinned.rawValue, default: true
        )

        theme = defaults.decodable(forKey: Key.theme.rawValue, default: AppTheme.system)
        accentFollowsSystem = defaults.bool(
            forKey: Key.accentFollowsSystem.rawValue, default: true
        )

        storedPollingInterval = defaults.double(forKey: Key.pollingInterval.rawValue, default: 0.4)
            .clamped(to: Limits.pollingInterval)
        hasCompletedOnboarding = defaults.bool(
            forKey: Key.hasCompletedOnboarding.rawValue, default: false
        )
        accessibilityWasGranted = defaults.bool(
            forKey: Key.accessibilityWasGranted.rawValue, default: false
        )
    }

    /// Remet tous les réglages à leurs valeurs par défaut.
    public func resetToDefaults() {
        for key in Key.allCases {
            defaults.removeObject(forKey: key.rawValue)
        }
        let fresh = Preferences(defaults: defaults)
        launchAtLogin = fresh.launchAtLogin
        historySize = fresh.historySize
        keepHistoryOnRestart = fresh.keepHistoryOnRestart
        language = fresh.language
        quickPasteEnabled = fresh.quickPasteEnabled
        closeAfterQuickPaste = fresh.closeAfterQuickPaste
        popupPosition = fresh.popupPosition
        visibleRows = fresh.visibleRows
        translucentBackground = fresh.translucentBackground
        showSourceApp = fresh.showSourceApp
        captureEnabled = fresh.captureEnabled
        excludedBundleIdentifiers = fresh.excludedBundleIdentifiers
        clearAllKeepsPinned = fresh.clearAllKeepsPinned
        theme = fresh.theme
        accentFollowsSystem = fresh.accentFollowsSystem
        pollingInterval = fresh.pollingInterval
        hasCompletedOnboarding = fresh.hasCompletedOnboarding
        accessibilityWasGranted = fresh.accessibilityWasGranted
    }

    /// Identifiants de bundle : sans doublon, sans vide, ordre stable.
    private static func normalize(_ identifiers: [String]) -> [String] {
        var seen = Set<String>()
        return identifiers
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}

// MARK: - Lecture de UserDefaults avec valeur par défaut explicite

extension UserDefaults {
    /// `bool(forKey:)` renvoie `false` pour une clé absente : ce cas doit rendre la valeur
    /// par défaut du réglage, pas `false`.
    fileprivate func bool(forKey key: String, default fallback: Bool) -> Bool {
        object(forKey: key) as? Bool ?? fallback
    }

    fileprivate func integer(forKey key: String, default fallback: Int) -> Int {
        object(forKey: key) as? Int ?? fallback
    }

    fileprivate func double(forKey key: String, default fallback: Double) -> Double {
        object(forKey: key) as? Double ?? fallback
    }

    /// Valeur d'énumération persistée sous sa forme brute, repli si la clé est absente ou
    /// si la valeur stockée n'est plus reconnue.
    fileprivate func decodable<T: RawRepresentable>(forKey key: String, default fallback: T) -> T
    where T.RawValue == String {
        guard let raw = string(forKey: key), let value = T(rawValue: raw) else { return fallback }
        return value
    }
}

// MARK: - Bornage

extension Comparable {
    /// Ramène la valeur dans l'intervalle.
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
