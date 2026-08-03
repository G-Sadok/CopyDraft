import Foundation
import Observation

/// Historique tel que l'interface le voit.
///
/// Source de vérité unique du rendu : liste ordonnée — épinglés d'abord, puis du plus récent
/// au plus ancien (FR-17) — où chaque élément ne porte qu'une projection de recherche et une
/// ou deux lignes d'aperçu. Le contenu complet reste en base et n'est relu qu'au moment de
/// coller (ADR-4).
@MainActor
@Observable
public final class HistoryStore {
    /// Éléments affichés, déjà ordonnés.
    public private(set) var items: [ClipItem] = []
    /// Vrai pendant la restauration initiale — pilote l'écran « Restauration de l'historique… ».
    public private(set) var isRestoring = false

    @ObservationIgnored private let repository: HistoryRepository
    @ObservationIgnored private let imageStore: ImageStore
    @ObservationIgnored private let preferences: Preferences
    @ObservationIgnored private let deduplication = DeduplicationPolicy()
    @ObservationIgnored private let now: @Sendable () -> Date

    public init(
        repository: HistoryRepository,
        imageStore: ImageStore,
        preferences: Preferences,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.repository = repository
        self.imageStore = imageStore
        self.preferences = preferences
        self.now = now
    }

    // MARK: Chargement

    /// Restaure l'historique au lancement, en appliquant le réglage de persistance (FR-16).
    ///
    /// Les épinglés survivent dans tous les cas (FR-15) : seul le reste est vidé quand
    /// l'utilisateur a décoché « Conserver l'historique ».
    public func restore() async {
        isRestoring = true
        defer { isRestoring = false }

        if !preferences.keepHistoryOnRestart {
            let files = (try? await repository.deleteAll(keepingPinned: true)) ?? []
            try? await imageStore.remove(fileNames: files)
        }

        items = (try? await repository.allItems()) ?? []
        await removeOrphanImages()
    }

    // MARK: Capture

    /// Enregistre une capture, doublons et limite d'historique traités.
    ///
    /// `imageData` n'est fourni que pour un élément image : il est écrit chiffré hors base et
    /// l'élément ne conserve que le nom du fichier.
    @discardableResult
    public func ingest(
        item: ClipItem,
        content: StoredContent,
        contentHash: Data,
        imageData: Data? = nil
    ) async -> ClipItem? {
        let candidates = ((try? await repository.fingerprints()) ?? []).map {
            DeduplicationCandidate(
                id: $0.id, contentHash: $0.contentHash, createdAt: $0.createdAt,
                pinned: $0.pinned
            )
        }

        switch deduplication.evaluate(contentHash: contentHash, against: candidates) {
        case .promote(let existing):
            try? await repository.touch(id: existing, at: now())
            await reload()
            return items.first { $0.id == existing }

        case .insert(let obsolete):
            var content = content

            if let imageData {
                guard let stored = try? await imageStore.store(imageData, for: item.id) else {
                    return nil
                }
                content.imageFileName = stored.fileName
            }

            do {
                try await repository.insert(item, content: content, contentHash: contentHash)
            } catch {
                // L'insertion a échoué : ne pas laisser derrière l'image déjà écrite.
                try? await imageStore.remove(for: item.id)
                return nil
            }

            if let obsolete {
                let files = (try? await repository.delete(ids: [obsolete])) ?? []
                try? await imageStore.remove(fileNames: files)
            }
            await enforceLimit()
            await reload()
            return items.first { $0.id == item.id }
        }
    }

    // MARK: Actions de l'utilisateur

    /// Épingle ou désépingle (FR-23).
    public func togglePin(_ id: UUID) async {
        guard let item = items.first(where: { $0.id == id }) else { return }
        try? await repository.setPinned(!item.pinned, id: id, at: now())
        await reload()
    }

    /// Supprime un élément et ses fichiers (FR-32).
    public func delete(_ id: UUID) async {
        let files = (try? await repository.delete(ids: [id])) ?? []
        try? await imageStore.remove(fileNames: files)
        await reload()
    }

    /// Renomme un élément, horodatage d'origine conservé (FR-52).
    public func rename(_ id: UUID, to name: String?) async {
        try? await repository.rename(id: id, to: name, at: now())
        await reload()
    }

    /// Vide l'historique (FR-12).
    public func clearAll(keepingPinned: Bool) async {
        let files = (try? await repository.deleteAll(keepingPinned: keepingPinned)) ?? []
        try? await imageStore.remove(fileNames: files)
        await reload()
    }

    /// Contenu complet d'un élément, relu à la demande pour le collage.
    public func content(for id: UUID) async -> StoredContent? {
        (try? await repository.content(for: id)) ?? nil
    }

    /// Image d'origine d'un élément, déchiffrée à la demande.
    public func imageData(for id: UUID) async -> Data? {
        (try? await imageStore.image(for: id)) ?? nil
    }

    /// Vignette d'un élément, déchiffrée à la demande.
    public func thumbnail(for id: UUID) async -> Data? {
        (try? await imageStore.thumbnail(for: id)) ?? nil
    }

    // MARK: Recherche

    /// Filtre l'historique sur le contenu **et** le nom de l'application source (FR-36).
    ///
    /// Comparaison insensible à la casse et aux diacritiques : « resume » trouve « résumé ».
    public func filtered(by query: String) -> [ClipItem] {
        Self.filter(items, query: query)
    }

    /// Filtrage pur, exposé pour être testé sans magasin.
    public static func filter(_ items: [ClipItem], query: String) -> [ClipItem] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return items }

        return items.filter { item in
            item.searchText.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive])
                != nil
                || item.source.name.range(
                    of: needle, options: [.caseInsensitive, .diacriticInsensitive]
                ) != nil
                || (item.customName?.range(
                    of: needle, options: [.caseInsensitive, .diacriticInsensitive]
                ) != nil)
        }
    }

    // MARK: Interne

    /// Applique la limite configurée : les plus anciens non épinglés partent d'abord (FR-14).
    private func enforceLimit() async {
        let files = (try? await repository.enforceLimit(preferences.historySize)) ?? []
        try? await imageStore.remove(fileNames: files)
    }

    private func reload() async {
        items = (try? await repository.allItems()) ?? []
    }

    /// Nettoie les fichiers image que plus aucune ligne ne référence.
    private func removeOrphanImages() async {
        guard let referenced = try? await repository.referencedImageFiles() else { return }
        _ = try? await imageStore.removeOrphans(referenced: referenced)
    }
}
