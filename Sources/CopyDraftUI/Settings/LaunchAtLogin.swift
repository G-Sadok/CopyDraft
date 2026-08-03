import CopyDraftCore
import Observation
import ServiceManagement

/// Enregistrement de CopyDraft comme élément d'ouverture (FR-42).
///
/// Abstrait pour que la logique de repli se teste sans toucher au `launchd` de la session.
@MainActor
public protocol LoginItemRegistering: AnyObject {
    var isRegistered: Bool { get }
    func setRegistered(_ registered: Bool) throws
}

/// Implémentation système, adossée à `SMAppService.mainApp`.
///
/// L'enregistrement échoue tant que l'exécutable ne tourne pas dans un `CopyDraft.app`
/// signé — c'est le cas en développement, d'où le repli soigné côté contrôleur.
@MainActor
public final class SystemLoginItem: LoginItemRegistering {
    public init() {}

    public var isRegistered: Bool { SMAppService.mainApp.status == .enabled }

    public func setRegistered(_ registered: Bool) throws {
        if registered {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}

/// Pilote « Ouvrir CopyDraft à la connexion » (§7 · onglet Général).
///
/// Le réglage n'est écrit **qu'après** un enregistrement réussi : si `launchd` refuse, la
/// bascule revient d'elle-même à sa position et un message s'affiche sous elle. Un réglage
/// qui prétendrait être actif sans l'être serait pire que pas de réglage du tout.
@MainActor
@Observable
public final class LaunchAtLoginController {
    /// Message de repli, affiché sous la bascule quand l'enregistrement a échoué.
    public private(set) var failureMessage: String?

    @ObservationIgnored private let item: LoginItemRegistering

    public init(item: LoginItemRegistering = SystemLoginItem()) {
        self.item = item
    }

    /// Aligne le réglage sur l'état réel du service, à l'ouverture de la fenêtre.
    ///
    /// L'utilisateur peut retirer CopyDraft de ses éléments d'ouverture depuis les Réglages
    /// système : la bascule doit le refléter sans qu'on ait touché à l'application.
    public func synchronize(with preferences: Preferences) {
        let registered = item.isRegistered
        guard registered != preferences.launchAtLogin else { return }
        preferences.launchAtLogin = registered
    }

    public func setEnabled(_ enabled: Bool, in preferences: Preferences) {
        do {
            try item.setRegistered(enabled)
            failureMessage = nil
            preferences.launchAtLogin = enabled
        } catch {
            failureMessage = L.t("general.launchAtLogin.error", table: .settings)
        }
    }
}
