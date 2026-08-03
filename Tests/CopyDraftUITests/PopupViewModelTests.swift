import CopyDraftCore
import CryptoKit
import Foundation
import Testing

@testable import CopyDraftUI

@MainActor
@Suite("Modèle de la popup")
struct PopupViewModelTests {
    // MARK: Montage

    private struct Harness {
        let model: PopupViewModel
        let store: HistoryStore
        let preferences: Preferences
        let root: URL
        let pasted: Box<[(ClipItem, Bool)]>
        let dismissed: Box<Int>
    }

    /// Petite boîte de référence : les closures capturent l'état à observer.
    private final class Box<T> {
        var value: T
        init(_ value: T) { self.value = value }
    }

    private func makeHarness(texts: [(String, Bool)] = []) async throws -> Harness {
        let cipher = Cipher(key: SymmetricKey(size: .bits256))
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("copydraft-popup-\(UUID().uuidString)", isDirectory: true)

        let suite = "com.copydraft.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let preferences = Preferences(defaults: defaults)

        let store = HistoryStore(
            repository: HistoryRepository(
                queue: try HistoryDatabase.openInMemory(), cipher: cipher
            ),
            imageStore: ImageStore(paths: AppPaths(root: root), cipher: cipher),
            preferences: preferences
        )

        for (index, entry) in texts.enumerated() {
            let (text, pinned) = entry
            await store.ingest(
                item: ClipItem(
                    kind: .text,
                    subtype: .plain,
                    createdAt: Date(timeIntervalSince1970: TimeInterval(100 * (index + 1))),
                    pinned: pinned,
                    source: SourceApp(bundleIdentifier: "com.test.app", name: "Xcode"),
                    byteCount: text.utf8.count,
                    characterCount: text.count,
                    searchText: text,
                    previewLines: [text]
                ),
                content: StoredContent(text: text),
                contentHash: Data(text.utf8).prefix(32)
                    + Data(repeating: 0, count: max(0, 32 - text.utf8.count))
            )
        }

        let pasted = Box<[(ClipItem, Bool)]>([])
        let dismissed = Box(0)
        let model = PopupViewModel(
            store: store,
            preferences: preferences,
            actions: PopupViewModel.Actions(
                paste: { item, plain in pasted.value.append((item, plain)) },
                dismiss: { dismissed.value += 1 }
            )
        )
        model.prepareForDisplay()

        return Harness(
            model: model, store: store, preferences: preferences, root: root,
            pasted: pasted, dismissed: dismissed
        )
    }

    private func cleanup(_ harness: Harness) {
        try? FileManager.default.removeItem(at: harness.root)
    }

    // MARK: Sélection

    @Test("À l'ouverture, le premier élément est sélectionné")
    func selectsFirstOnOpen() async throws {
        let harness = try await makeHarness(texts: [("A", false), ("B", false)])
        defer { cleanup(harness) }

        #expect(harness.model.selectedItem?.searchText == "B", "le plus récent est en tête")
    }

    @Test("Les flèches déplacent la sélection sans reboucler")
    func arrowsDoNotWrap() async throws {
        let harness = try await makeHarness(
            texts: [("A", false), ("B", false), ("C", false)]
        )
        defer { cleanup(harness) }
        let model = harness.model

        model.handle(.moveDown)
        #expect(model.selectedItem?.searchText == "B")

        model.handle(.moveDown)
        model.handle(.moveDown)
        #expect(model.selectedItem?.searchText == "A", "on reste en bout de liste")

        model.handle(.moveUp)
        model.handle(.moveUp)
        model.handle(.moveUp)
        #expect(model.selectedItem?.searchText == "C", "et en haut de liste")
    }

    @Test("⌥ + flèches saute aux extrémités")
    func jumps() async throws {
        let harness = try await makeHarness(
            texts: [("A", false), ("B", false), ("C", false)]
        )
        defer { cleanup(harness) }

        harness.model.handle(.jumpToEnd)
        #expect(harness.model.selectedItem?.searchText == "A")

        harness.model.handle(.jumpToStart)
        #expect(harness.model.selectedItem?.searchText == "C")
    }

    @Test("Les épinglés sont listés avant les récents")
    func pinnedFirst() async throws {
        let harness = try await makeHarness(
            texts: [("ancien épinglé", true), ("récent", false)]
        )
        defer { cleanup(harness) }

        #expect(harness.model.pinnedItems.map(\.searchText) == ["ancien épinglé"])
        #expect(harness.model.recentItems.map(\.searchText) == ["récent"])
        #expect(harness.model.visibleItems.first?.searchText == "ancien épinglé")
    }

    // MARK: Collage

    @Test("↩︎ colle la sélection, ⇧↩︎ la colle en texte brut")
    func pasteCommands() async throws {
        let harness = try await makeHarness(texts: [("A", false), ("B", false)])
        defer { cleanup(harness) }

        harness.model.handle(.paste)
        harness.model.handle(.pastePlainText)

        #expect(harness.pasted.value.count == 2)
        #expect(harness.pasted.value[0].0.searchText == "B")
        #expect(harness.pasted.value[0].1 == false)
        #expect(harness.pasted.value[1].1 == true)
    }

    @Test("⌘n colle directement le n-ième élément, sans passer par la sélection")
    func quickPaste() async throws {
        let harness = try await makeHarness(
            texts: [("A", false), ("B", false), ("C", false)]
        )
        defer { cleanup(harness) }

        harness.model.handle(.quickPaste(rank: 3))

        #expect(harness.pasted.value.map { $0.0.searchText } == ["A"])
        #expect(harness.model.selectedItem?.searchText == "C", "la sélection n'a pas bougé")
    }

    @Test("⌘n hors de la liste ne fait rien")
    func quickPasteOutOfRange() async throws {
        let harness = try await makeHarness(texts: [("A", false)])
        defer { cleanup(harness) }

        harness.model.handle(.quickPaste(rank: 7))
        #expect(harness.pasted.value.isEmpty)
    }

    @Test("Le collage rapide désactivé par réglage ne colle rien")
    func quickPasteDisabled() async throws {
        let harness = try await makeHarness(texts: [("A", false)])
        defer { cleanup(harness) }

        harness.preferences.quickPasteEnabled = false
        harness.model.handle(.quickPaste(rank: 1))

        #expect(harness.pasted.value.isEmpty)
    }

    // MARK: Indices ⌘n

    @Test("Les indices ⌘n numérotent les dix premiers éléments")
    func shortcutIndexes() async throws {
        let harness = try await makeHarness(
            texts: (0..<12).map { ("élément \($0)", false) }
        )
        defer { cleanup(harness) }
        let items = harness.model.visibleItems

        #expect(harness.model.shortcutIndex(for: items[0]) == 1)
        #expect(harness.model.shortcutIndex(for: items[9]) == 10)
        #expect(harness.model.shortcutIndex(for: items[10]) == nil)
    }

    /// §2.4 : « les indices ⌘n disparaissent dès qu'une recherche est active ».
    @Test("Les indices ⌘n disparaissent pendant une recherche")
    func shortcutIndexesHiddenWhileSearching() async throws {
        let harness = try await makeHarness(texts: [("swift", false), ("safari", false)])
        defer { cleanup(harness) }

        harness.model.query = "swi"
        let items = harness.model.visibleItems
        #expect(items.count == 1)
        #expect(harness.model.shortcutIndex(for: items[0]) == nil)
    }

    // MARK: Recherche

    @Test("La frappe alimente la recherche et la sélection retombe sur le premier résultat")
    func typingFiltersAndSelects() async throws {
        let harness = try await makeHarness(
            texts: [("swift", false), ("safari", false), ("git", false)]
        )
        defer { cleanup(harness) }

        harness.model.handle(.appendToSearch("s"))
        #expect(harness.model.visibleItems.count == 2)
        #expect(harness.model.selectedItem?.searchText == "safari")

        harness.model.handle(.appendToSearch("w"))
        #expect(harness.model.visibleItems.map(\.searchText) == ["swift"])
        #expect(harness.model.selectedItem?.searchText == "swift")
    }

    @Test("⌫ efface un caractère tant que la recherche n'est pas vide")
    func backspaceEditsSearch() async throws {
        let harness = try await makeHarness(texts: [("swift", false)])
        defer { cleanup(harness) }

        harness.model.query = "sw"
        harness.model.handle(.deleteSearchCharacter)
        #expect(harness.model.query == "s")
    }

    @Test("Sans résultat, l'état correspondant est signalé")
    func noResults() async throws {
        let harness = try await makeHarness(texts: [("swift", false)])
        defer { cleanup(harness) }

        harness.model.query = "introuvable"
        #expect(harness.model.hasNoResults)
        #expect(harness.model.isEmpty == false)
        #expect(harness.model.selectedItem == nil)
    }

    @Test("Un historique vide n'est pas confondu avec une recherche sans résultat")
    func emptyHistory() async throws {
        let harness = try await makeHarness()
        defer { cleanup(harness) }

        #expect(harness.model.isEmpty)
        #expect(harness.model.hasNoResults == false)
    }

    // MARK: Échap

    /// §3 : « Échap vide d'abord la recherche, puis ferme au second appui ».
    @Test("Échap vide la recherche, puis ferme")
    func escapeIsTwoStep() async throws {
        let harness = try await makeHarness(texts: [("swift", false)])
        defer { cleanup(harness) }

        harness.model.query = "swi"
        harness.model.handle(.dismiss)
        #expect(harness.model.query.isEmpty)
        #expect(harness.dismissed.value == 0)

        harness.model.handle(.dismiss)
        #expect(harness.dismissed.value == 1)
    }

    // MARK: Épinglage et suppression

    @Test("⌘P épingle la sélection et la fait remonter")
    func togglePin() async throws {
        let harness = try await makeHarness(texts: [("A", false), ("B", false)])
        defer { cleanup(harness) }

        harness.model.handle(.moveDown)
        let cible = try #require(harness.model.selectedItem)
        harness.model.handle(.togglePin)

        try await Task.sleep(for: .milliseconds(50))
        #expect(harness.store.items.first?.id == cible.id)
        #expect(harness.store.items.first?.pinned == true)
    }

    @Test("⌫ supprime la sélection quand la recherche est vide")
    func deleteSelection() async throws {
        let harness = try await makeHarness(texts: [("A", false), ("B", false)])
        defer { cleanup(harness) }

        harness.model.handle(.deleteSelection)
        try await Task.sleep(for: .milliseconds(50))

        #expect(harness.store.items.map(\.searchText) == ["A"])
    }

    @Test("Après suppression, la sélection passe à l'élément suivant")
    func selectionMovesAfterDelete() async throws {
        let harness = try await makeHarness(
            texts: [("A", false), ("B", false), ("C", false)]
        )
        defer { cleanup(harness) }

        harness.model.handle(.deleteSelection)
        try await Task.sleep(for: .milliseconds(50))

        #expect(harness.model.selectedItem?.searchText == "B")
    }

    // MARK: Focus

    @Test("⇥ n'est pas consommé par le modèle : c'est la vue qui déplace le focus")
    func tabIsNotHandled() async throws {
        let harness = try await makeHarness(texts: [("A", false)])
        defer { cleanup(harness) }

        #expect(harness.model.handle(.cycleFocus) == false)
    }
}
