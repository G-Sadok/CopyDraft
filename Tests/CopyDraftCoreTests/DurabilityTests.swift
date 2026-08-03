import CryptoKit
import Foundation
import Testing

@testable import CopyDraftCore

/// Ce que l'on promet en cas d'arrêt brutal (NFR-14, FR-18) : les éléments déjà confirmés
/// survivent, les épinglés en particulier, et jamais de ligne à moitié écrite.
@Suite("Durabilité de l'historique")
struct DurabilityTests {
    private func makeItem(_ text: String, pinned: Bool = false) -> ClipItem {
        ClipItem(
            kind: .text,
            subtype: .plain,
            createdAt: Date(timeIntervalSince1970: 1_000),
            pinned: pinned,
            source: SourceApp(bundleIdentifier: "com.test", name: "Test"),
            byteCount: text.utf8.count,
            characterCount: text.count,
            searchText: text,
            previewLines: [text]
        )
    }

    private func temporaryDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("copydraft-durability-\(UUID().uuidString).sqlite")
    }

    private func removeDatabase(at url: URL) {
        for suffix in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(atPath: url.path + suffix)
        }
    }

    /// Une connexion abandonnée sans fermeture propre — l'équivalent d'un `kill -9` : la
    /// base rouverte doit contenir tout ce qui avait été confirmé.
    @Test("Un arrêt sans fermeture propre ne perd aucun élément confirmé")
    func abandonedConnectionLosesNothing() async throws {
        let url = temporaryDatabaseURL()
        defer { removeDatabase(at: url) }
        let cipher = Cipher(key: SymmetricKey(size: .bits256))

        do {
            let repository = HistoryRepository(
                queue: try HistoryDatabase.open(at: url), cipher: cipher
            )
            try await repository.insert(
                makeItem("épinglé", pinned: true), content: StoredContent(text: "épinglé"),
                contentHash: Data([1])
            )
            try await repository.insert(
                makeItem("ordinaire"), content: StoredContent(text: "ordinaire"),
                contentHash: Data([2])
            )
            // Ni fermeture, ni vidage explicite : la connexion est simplement abandonnée.
        }

        let reopened = HistoryRepository(
            queue: try HistoryDatabase.open(at: url), cipher: cipher
        )
        let items = try await reopened.allItems()

        #expect(items.count == 2)
        #expect(items.first?.pinned == true)
        #expect(items.contains { $0.searchText == "épinglé" })
    }

    /// Une insertion qui échoue ne doit rien laisser derrière elle.
    @Test("Une insertion en échec ne laisse aucune ligne partielle")
    func failedInsertLeavesNothing() async throws {
        let url = temporaryDatabaseURL()
        defer { removeDatabase(at: url) }
        let cipher = Cipher(key: SymmetricKey(size: .bits256))
        let repository = HistoryRepository(
            queue: try HistoryDatabase.open(at: url), cipher: cipher
        )

        let item = makeItem("unique")
        try await repository.insert(item, content: StoredContent(), contentHash: Data([1]))

        // Même identifiant : la contrainte de clé primaire rejette l'insertion.
        await #expect(throws: (any Error).self) {
            try await repository.insert(item, content: StoredContent(), contentHash: Data([2]))
        }

        #expect(try await repository.count() == 1)
        #expect(try await repository.allItems().first?.searchText == "unique")
    }

    /// Les épinglés survivent à un vidage de l'historique au redémarrage.
    @Test("Un vidage au redémarrage épargne les épinglés")
    func restartPurgeKeepsPinned() async throws {
        let url = temporaryDatabaseURL()
        defer { removeDatabase(at: url) }
        let cipher = Cipher(key: SymmetricKey(size: .bits256))

        let repository = HistoryRepository(
            queue: try HistoryDatabase.open(at: url), cipher: cipher
        )
        try await repository.insert(
            makeItem("gardé", pinned: true), content: StoredContent(), contentHash: Data([1])
        )
        try await repository.insert(
            makeItem("jeté"), content: StoredContent(), contentHash: Data([2])
        )

        try await repository.deleteAll(keepingPinned: true)

        let reopened = HistoryRepository(
            queue: try HistoryDatabase.open(at: url), cipher: cipher
        )
        #expect(try await reopened.allItems().map(\.searchText) == ["gardé"])
    }

    /// Cinquante écritures d'affilée, puis réouverture : rien ne manque, rien n'est corrompu.
    @Test("Une rafale d'écritures est intégralement relue après réouverture")
    func burstOfWritesSurvives() async throws {
        let url = temporaryDatabaseURL()
        defer { removeDatabase(at: url) }
        let cipher = Cipher(key: SymmetricKey(size: .bits256))

        do {
            let repository = HistoryRepository(
                queue: try HistoryDatabase.open(at: url), cipher: cipher
            )
            for index in 0..<50 {
                try await repository.insert(
                    makeItem("élément \(index)"),
                    content: StoredContent(text: "élément \(index)"),
                    contentHash: Data([UInt8(index)])
                )
            }
        }

        let reopened = HistoryRepository(
            queue: try HistoryDatabase.open(at: url), cipher: cipher
        )
        let items = try await reopened.allItems()
        #expect(items.count == 50)
        #expect(Set(items.map(\.searchText)).count == 50, "aucun contenu corrompu ni dupliqué")
    }
}
