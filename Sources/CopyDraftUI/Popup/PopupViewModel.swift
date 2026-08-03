import CopyDraftCore
import Foundation
import Observation

/// État et comportement de la popup : recherche, sélection, exécution des commandes clavier.
///
/// Toute la logique de la liste vit ici, séparée du rendu : c'est ce qui permet de vérifier
/// la table de raccourcis du §3 sans ouvrir une fenêtre.
@MainActor
@Observable
public final class PopupViewModel {
    /// Ce que le modèle demande à l'extérieur : coller, copier, fermer.
    public struct Actions {
        public var paste: (ClipItem, _ plainTextOnly: Bool) -> Void
        public var copy: (ClipItem) -> Void
        public var dismiss: () -> Void
        public var rename: (ClipItem) -> Void
        public var excludeApp: (SourceApp) -> Void

        public init(
            paste: @escaping (ClipItem, Bool) -> Void = { _, _ in },
            copy: @escaping (ClipItem) -> Void = { _ in },
            dismiss: @escaping () -> Void = {},
            rename: @escaping (ClipItem) -> Void = { _ in },
            excludeApp: @escaping (SourceApp) -> Void = { _ in }
        ) {
            self.paste = paste
            self.copy = copy
            self.dismiss = dismiss
            self.rename = rename
            self.excludeApp = excludeApp
        }
    }

    /// Texte de recherche saisi.
    public var query = "" {
        didSet { queryDidChange() }
    }
    /// Identifiant de l'élément sélectionné, `nil` si la liste est vide.
    public private(set) var selectedID: UUID?

    @ObservationIgnored private let store: HistoryStore
    @ObservationIgnored private let preferences: Preferences
    @ObservationIgnored public var actions: Actions

    public init(store: HistoryStore, preferences: Preferences, actions: Actions = Actions()) {
        self.store = store
        self.preferences = preferences
        self.actions = actions
    }

    // MARK: Liste affichée

    /// Éléments visibles, recherche appliquée.
    public var visibleItems: [ClipItem] {
        store.filtered(by: query)
    }

    /// Éléments épinglés, en tête (§3).
    public var pinnedItems: [ClipItem] {
        visibleItems.filter(\.pinned)
    }

    /// Éléments récents, sous les épinglés.
    public var recentItems: [ClipItem] {
        visibleItems.filter { !$0.pinned }
    }

    public var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    public var isEmpty: Bool {
        store.items.isEmpty
    }

    public var hasNoResults: Bool {
        !store.items.isEmpty && visibleItems.isEmpty
    }

    /// Indice `⌘n` d'un élément : rangs 1 à 9 puis 0 pour le dixième, **masqués dès qu'une
    /// recherche est active** — la numérotation ne suivrait plus (§2.4).
    public func shortcutIndex(for item: ClipItem) -> Int? {
        guard !isSearching, preferences.quickPasteEnabled,
            let position = visibleItems.firstIndex(where: { $0.id == item.id }),
            position < Limits.quickPasteSlots
        else { return nil }
        return position + 1
    }

    public var selectedItem: ClipItem? {
        guard let selectedID else { return nil }
        return visibleItems.first { $0.id == selectedID }
    }

    // MARK: Cycle de vie

    /// À appeler à chaque ouverture : la popup repart toujours d'une recherche vide et du
    /// premier élément.
    public func prepareForDisplay() {
        query = ""
        selectFirst()
    }

    public func select(_ id: UUID) {
        guard visibleItems.contains(where: { $0.id == id }) else { return }
        selectedID = id
    }

    // MARK: Commandes clavier (§3)

    /// Exécute une commande. Renvoie `true` si elle a été consommée.
    @discardableResult
    public func handle(_ command: PopupCommand) -> Bool {
        switch command {
        case .moveUp:
            move(by: -1)
        case .moveDown:
            move(by: 1)
        case .jumpToStart:
            selectedID = visibleItems.first?.id
        case .jumpToEnd:
            selectedID = visibleItems.last?.id
        case .paste:
            paste(plainTextOnly: false)
        case .pastePlainText:
            paste(plainTextOnly: true)
        case .quickPaste(let rank):
            quickPaste(rank: rank)
        case .togglePin:
            togglePin()
        case .copy:
            if let selectedItem { actions.copy(selectedItem) }
        case .deleteSelection:
            deleteSelection()
        case .deleteSearchCharacter:
            if !query.isEmpty { query.removeLast() }
        case .cycleFocus:
            // Le parcours du focus est piloté par la vue ; le modèle n'a rien à changer.
            return false
        case .dismiss:
            dismiss()
        case .appendToSearch(let characters):
            query.append(characters)
        }
        return true
    }

    // MARK: Détail des commandes

    /// Déplacement **sans rebouclage** : arrivé en bout de liste, on y reste (§3).
    private func move(by offset: Int) {
        let items = visibleItems
        guard !items.isEmpty else {
            selectedID = nil
            return
        }
        guard let current = items.firstIndex(where: { $0.id == selectedID }) else {
            selectedID = items.first?.id
            return
        }
        let target = min(max(current + offset, 0), items.count - 1)
        selectedID = items[target].id
    }

    private func paste(plainTextOnly: Bool) {
        guard let selectedItem else { return }
        actions.paste(selectedItem, plainTextOnly)
    }

    /// `⌘n` colle directement, sans passer par la sélection.
    private func quickPaste(rank: Int) {
        guard preferences.quickPasteEnabled, !isSearching else { return }
        let items = visibleItems
        guard rank >= 1, rank <= items.count, rank <= Limits.quickPasteSlots else { return }
        actions.paste(items[rank - 1], false)
    }

    private func togglePin() {
        guard let selectedItem else { return }
        Task { await store.togglePin(selectedItem.id) }
    }

    /// Supprime la sélection et laisse le curseur sur l'élément suivant, pour enchaîner.
    private func deleteSelection() {
        guard let selectedItem else { return }
        let items = visibleItems
        let index = items.firstIndex { $0.id == selectedItem.id }
        let successor = index.map { $0 + 1 < items.count ? items[$0 + 1] : items[max(0, $0 - 1)] }
        selectedID = successor?.id == selectedItem.id ? nil : successor?.id

        Task { await store.delete(selectedItem.id) }
    }

    /// `Échap` vide d'abord la recherche, puis ferme au second appui (§2.3, §3).
    private func dismiss() {
        if isSearching {
            query = ""
        } else {
            actions.dismiss()
        }
    }

    // MARK: Recherche

    /// La sélection retombe sur le premier résultat à chaque frappe (§2.3).
    private func queryDidChange() {
        selectFirst()
    }

    private func selectFirst() {
        selectedID = visibleItems.first?.id
    }
}
