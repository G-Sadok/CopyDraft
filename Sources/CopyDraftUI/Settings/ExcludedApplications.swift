import AppKit
import CopyDraftCore
import UniformTypeIdentifiers

/// Une application exclue, telle qu'elle s'affiche : icône et nom, jamais l'identifiant de
/// bundle brut (§7).
struct ExcludedApplication: Identifiable {
    /// Identifiant de bundle — c'est lui qui est persisté et comparé (FR-11).
    let id: String
    let name: String
    let icon: NSImage?
}

/// Traduit un identifiant de bundle en nom et en icône.
///
/// Abstrait pour que la logique d'ajout et de retrait se teste sans dépendre des
/// applications installées sur la machine.
@MainActor
protocol ApplicationResolving {
    func url(forBundleIdentifier identifier: String) -> URL?
}

/// Résolution par le Finder.
@MainActor
struct WorkspaceApplicationResolver: ApplicationResolving {
    func url(forBundleIdentifier identifier: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier)
    }
}

/// Liste des applications exclues (§7 · onglet Confidentialité, FR-11).
///
/// Le modèle ne conserve aucun état : `Preferences.excludedBundleIdentifiers` est la seule
/// source de vérité, et c'est elle qui dédoublonne et normalise. Le modèle ne fait que la
/// présenter et la modifier.
@MainActor
final class ExcludedApplicationsModel {
    private let preferences: Preferences
    private let resolver: ApplicationResolving

    init(preferences: Preferences, resolver: ApplicationResolving = WorkspaceApplicationResolver()) {
        self.preferences = preferences
        self.resolver = resolver
    }

    var applications: [ExcludedApplication] {
        preferences.excludedBundleIdentifiers.map(application(for:))
    }

    var isEmpty: Bool { preferences.excludedBundleIdentifiers.isEmpty }

    func application(for identifier: String) -> ExcludedApplication {
        guard let url = resolver.url(forBundleIdentifier: identifier) else {
            return ExcludedApplication(id: identifier, name: Self.fallbackName(for: identifier), icon: nil)
        }
        return ExcludedApplication(
            id: identifier,
            name: FileManager.default.displayName(atPath: url.path),
            icon: NSWorkspace.shared.icon(forFile: url.path)
        )
    }

    /// Nom de repli quand l'application n'est plus installée : le dernier segment de
    /// l'identifiant reste lisible, « com.apple.Terminal » → « Terminal » (§7).
    static func fallbackName(for identifier: String) -> String {
        let segment = identifier.split(separator: ".").last.map(String.init) ?? identifier
        return segment.isEmpty ? identifier : segment
    }

    @discardableResult
    func add(bundleIdentifier: String) -> Bool {
        let trimmed = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !preferences.excludedBundleIdentifiers.contains(trimmed) else {
            return false
        }
        preferences.excludedBundleIdentifiers.append(trimmed)
        return true
    }

    /// Ajoute l'application choisie dans le sélecteur. Un paquet sans identifiant de bundle
    /// est ignoré : il n'y aurait rien à comparer au moment de la capture.
    @discardableResult
    func add(applicationAt url: URL) -> Bool {
        guard let identifier = Bundle(url: url)?.bundleIdentifier else { return false }
        return add(bundleIdentifier: identifier)
    }

    func remove(bundleIdentifier: String) {
        preferences.excludedBundleIdentifiers.removeAll { $0 == bundleIdentifier }
    }

    /// Sélecteur d'application (FR-11), restreint aux applications et ouvert sur `/Applications`.
    func chooseApplications() -> [URL] {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.application]
        panel.directoryURL = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask).first
        panel.prompt = L.t("privacy.excluded.panel.prompt", table: .settings)
        panel.message = L.t("privacy.excluded.panel.message", table: .settings)
        return panel.runModal() == .OK ? panel.urls : []
    }
}
