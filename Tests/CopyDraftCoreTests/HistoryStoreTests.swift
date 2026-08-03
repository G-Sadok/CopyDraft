import CoreGraphics
import CryptoKit
import Foundation
import Testing

@testable import CopyDraftCore

@MainActor
@Suite("Magasin d'historique")
struct HistoryStoreTests {
    // MARK: Fabriques

    private func makeStore(
        keepHistoryOnRestart: Bool = true,
        historySize: Int = 25,
        clock: @escaping @Sendable () -> Date = { Date(timeIntervalSince1970: 1_000) }
    ) throws -> (HistoryStore, HistoryRepository, AppPaths, Preferences) {
        let cipher = Cipher(key: SymmetricKey(size: .bits256))
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("copydraft-store-\(UUID().uuidString)", isDirectory: true)
        let paths = AppPaths(root: root)

        let suite = "com.copydraft.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let preferences = Preferences(defaults: defaults)
        preferences.keepHistoryOnRestart = keepHistoryOnRestart
        preferences.historySize = historySize

        let repository = HistoryRepository(
            queue: try HistoryDatabase.openInMemory(), cipher: cipher
        )
        let store = HistoryStore(
            repository: repository,
            imageStore: ImageStore(paths: paths, cipher: cipher),
            preferences: preferences,
            now: clock
        )
        return (store, repository, paths, preferences)
    }

    private func makeItem(
        _ text: String,
        createdAt: TimeInterval = 1_000,
        pinned: Bool = false,
        appName: String = "Xcode",
        kind: ClipKind = .text
    ) -> ClipItem {
        ClipItem(
            kind: kind,
            subtype: kind == .image ? .image : .plain,
            createdAt: Date(timeIntervalSince1970: createdAt),
            pinned: pinned,
            source: SourceApp(bundleIdentifier: "com.test.\(appName)", name: appName),
            byteCount: text.utf8.count,
            characterCount: text.count,
            searchText: text,
            previewLines: [text]
        )
    }

    private func hash(_ text: String) -> Data {
        Data(text.utf8).prefix(32) + Data(repeating: 0, count: max(0, 32 - text.utf8.count))
    }

    // MARK: Capture

    @Test("Une capture apparaît en tête de liste")
    func ingest() async throws {
        let (store, _, paths, _) = try makeStore()
        defer { try? FileManager.default.removeItem(at: paths.root) }

        await store.ingest(
            item: makeItem("premier"), content: StoredContent(text: "premier"),
            contentHash: hash("premier")
        )

        #expect(store.items.map(\.searchText) == ["premier"])
    }

    @Test("Une copie identique à la plus récente ne crée pas de doublon")
    func duplicateIsPromoted() async throws {
        let (store, _, paths, _) = try makeStore()
        defer { try? FileManager.default.removeItem(at: paths.root) }

        await store.ingest(
            item: makeItem("même"), content: StoredContent(text: "même"),
            contentHash: hash("même")
        )
        await store.ingest(
            item: makeItem("même"), content: StoredContent(text: "même"),
            contentHash: hash("même")
        )

        #expect(store.items.count == 1)
    }

    @Test("Une copie identique à un élément plus ancien remonte sans laisser de doublon")
    func olderDuplicateIsReplaced() async throws {
        let (store, _, paths, _) = try makeStore()
        defer { try? FileManager.default.removeItem(at: paths.root) }

        await store.ingest(
            item: makeItem("A", createdAt: 100), content: StoredContent(text: "A"),
            contentHash: hash("A")
        )
        await store.ingest(
            item: makeItem("B", createdAt: 200), content: StoredContent(text: "B"),
            contentHash: hash("B")
        )
        await store.ingest(
            item: makeItem("A", createdAt: 300), content: StoredContent(text: "A"),
            contentHash: hash("A")
        )

        #expect(store.items.count == 2)
        #expect(store.items.first?.searchText == "A")
        #expect(store.items.filter { $0.searchText == "A" }.count == 1)
    }

    @Test("Les épinglés restent en tête, les autres du plus récent au plus ancien")
    func ordering() async throws {
        let (store, _, paths, _) = try makeStore()
        defer { try? FileManager.default.removeItem(at: paths.root) }

        for (text, date, pinned) in [
            ("ancien", 100.0, false), ("récent", 300.0, false), ("épinglé", 200.0, true)
        ] {
            await store.ingest(
                item: makeItem(text, createdAt: date, pinned: pinned),
                content: StoredContent(text: text), contentHash: hash(text)
            )
        }

        #expect(store.items.map(\.searchText) == ["épinglé", "récent", "ancien"])
    }

    // MARK: Limite

    @Test("La limite supprime les plus anciens non épinglés")
    func limitIsEnforced() async throws {
        let (store, _, paths, _) = try makeStore(historySize: 10)
        defer { try? FileManager.default.removeItem(at: paths.root) }

        for index in 0..<12 {
            await store.ingest(
                item: makeItem("élément \(index)", createdAt: Double(index) * 10),
                content: StoredContent(text: "élément \(index)"),
                contentHash: hash("élément \(index)")
            )
        }

        #expect(store.items.count == 10)
        #expect(store.items.first?.searchText == "élément 11")
        #expect(!store.items.contains { $0.searchText == "élément 0" })
    }

    @Test("Un élément épinglé n'est jamais supprimé par la limite")
    func pinnedSurvivesLimit() async throws {
        let (store, _, paths, _) = try makeStore(historySize: 10)
        defer { try? FileManager.default.removeItem(at: paths.root) }

        await store.ingest(
            item: makeItem("gardé", createdAt: 0, pinned: true),
            content: StoredContent(text: "gardé"), contentHash: hash("gardé")
        )
        for index in 1..<15 {
            await store.ingest(
                item: makeItem("élément \(index)", createdAt: Double(index) * 10),
                content: StoredContent(text: "élément \(index)"),
                contentHash: hash("élément \(index)")
            )
        }

        #expect(store.items.contains { $0.searchText == "gardé" })
        #expect(store.items.count == 11, "10 non épinglés + l'épinglé")
    }

    // MARK: Actions

    @Test("Épingler remonte l'élément dans la section des épinglés")
    func togglePin() async throws {
        let (store, _, paths, _) = try makeStore()
        defer { try? FileManager.default.removeItem(at: paths.root) }

        await store.ingest(
            item: makeItem("A", createdAt: 100), content: StoredContent(text: "A"),
            contentHash: hash("A")
        )
        await store.ingest(
            item: makeItem("B", createdAt: 200), content: StoredContent(text: "B"),
            contentHash: hash("B")
        )
        let ancien = try #require(store.items.last)

        await store.togglePin(ancien.id)
        #expect(store.items.first?.searchText == "A")
        #expect(store.items.first?.pinned == true)

        await store.togglePin(ancien.id)
        #expect(store.items.first?.searchText == "B")
    }

    @Test("Supprimer retire l'élément de la liste")
    func delete() async throws {
        let (store, _, paths, _) = try makeStore()
        defer { try? FileManager.default.removeItem(at: paths.root) }

        await store.ingest(
            item: makeItem("à supprimer"), content: StoredContent(text: "à supprimer"),
            contentHash: hash("à supprimer")
        )
        let item = try #require(store.items.first)

        await store.delete(item.id)
        #expect(store.items.isEmpty)
    }

    @Test("« Tout effacer » respecte le choix de conserver les épinglés")
    func clearAll() async throws {
        let (store, _, paths, _) = try makeStore()
        defer { try? FileManager.default.removeItem(at: paths.root) }

        await store.ingest(
            item: makeItem("ordinaire", createdAt: 100),
            content: StoredContent(text: "ordinaire"), contentHash: hash("ordinaire")
        )
        await store.ingest(
            item: makeItem("épinglé", createdAt: 200, pinned: true),
            content: StoredContent(text: "épinglé"), contentHash: hash("épinglé")
        )

        await store.clearAll(keepingPinned: true)
        #expect(store.items.map(\.searchText) == ["épinglé"])

        await store.clearAll(keepingPinned: false)
        #expect(store.items.isEmpty)
    }

    @Test("Le contenu complet se relit à la demande")
    func contentOnDemand() async throws {
        let (store, _, paths, _) = try makeStore()
        defer { try? FileManager.default.removeItem(at: paths.root) }

        await store.ingest(
            item: makeItem("aperçu"),
            content: StoredContent(text: "contenu intégral bien plus long"),
            contentHash: hash("aperçu")
        )
        let item = try #require(store.items.first)

        #expect(await store.content(for: item.id)?.text == "contenu intégral bien plus long")
    }

    // MARK: Restauration

    @Test("Au redémarrage, l'historique est conservé quand le réglage le demande")
    func restoreKeepsHistory() async throws {
        let (store, _, paths, _) = try makeStore(keepHistoryOnRestart: true)
        defer { try? FileManager.default.removeItem(at: paths.root) }

        await store.ingest(
            item: makeItem("conservé"), content: StoredContent(text: "conservé"),
            contentHash: hash("conservé")
        )

        await store.restore()
        #expect(store.items.map(\.searchText) == ["conservé"])
        #expect(store.isRestoring == false)
    }

    @Test("Au redémarrage, seuls les épinglés survivent quand la persistance est décochée")
    func restoreDropsUnpinned() async throws {
        let (store, _, paths, preferences) = try makeStore(keepHistoryOnRestart: true)
        defer { try? FileManager.default.removeItem(at: paths.root) }

        await store.ingest(
            item: makeItem("volatile", createdAt: 100),
            content: StoredContent(text: "volatile"), contentHash: hash("volatile")
        )
        await store.ingest(
            item: makeItem("épinglé", createdAt: 200, pinned: true),
            content: StoredContent(text: "épinglé"), contentHash: hash("épinglé")
        )

        preferences.keepHistoryOnRestart = false
        await store.restore()

        #expect(store.items.map(\.searchText) == ["épinglé"])
    }

    // MARK: Recherche

    @Test("La recherche porte sur le contenu et sur l'application source")
    func search() async throws {
        let items = [
            makeItem("import AppKit", appName: "Xcode"),
            makeItem("developer.apple.com", appName: "Safari"),
            makeItem("Merci pour votre message", appName: "Mail")
        ]

        #expect(HistoryStore.filter(items, query: "apple").count == 1)
        #expect(HistoryStore.filter(items, query: "safari").count == 1)
        #expect(HistoryStore.filter(items, query: "").count == 3)
        #expect(HistoryStore.filter(items, query: "   ").count == 3)
        #expect(HistoryStore.filter(items, query: "introuvable").isEmpty)
    }

    @Test("La recherche ignore la casse et les accents")
    func searchIsLenient() {
        let items = [makeItem("Résumé de la réunion", appName: "Notes")]

        #expect(HistoryStore.filter(items, query: "resume").count == 1)
        #expect(HistoryStore.filter(items, query: "RÉSUMÉ").count == 1)
        #expect(HistoryStore.filter(items, query: "notes").count == 1)
    }
}
