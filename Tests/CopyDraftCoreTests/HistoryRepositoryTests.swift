import CoreGraphics
import CryptoKit
import Foundation
import GRDB
import Testing

@testable import CopyDraftCore

@Suite("Persistance de l'historique")
struct HistoryRepositoryTests {
    // MARK: Fabriques

    private func makeCipher() -> Cipher {
        Cipher(key: SymmetricKey(size: .bits256))
    }

    private func makeRepository(cipher: Cipher? = nil) throws -> (HistoryRepository, Cipher) {
        let cipher = cipher ?? makeCipher()
        return (HistoryRepository(queue: try HistoryDatabase.openInMemory(), cipher: cipher), cipher)
    }

    private func makeItem(
        id: UUID = UUID(),
        text: String = "let items = try store.fetch()",
        kind: ClipKind = .text,
        subtype: ClipSubtype = .code,
        createdAt: Date = Date(timeIntervalSince1970: 1_000),
        pinned: Bool = false,
        appName: String = "Xcode",
        bundleIdentifier: String? = "com.apple.dt.Xcode"
    ) -> ClipItem {
        ClipItem(
            id: id,
            kind: kind,
            subtype: subtype,
            createdAt: createdAt,
            pinned: pinned,
            source: SourceApp(bundleIdentifier: bundleIdentifier, name: appName),
            byteCount: text.utf8.count,
            characterCount: text.count,
            searchText: text,
            previewLines: [text]
        )
    }

    // MARK: Base et migrations

    @Test("La base est créée à froid avec sa table et ses index")
    func coldStart() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("copydraft-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }

        let queue = try HistoryDatabase.open(at: url)
        try queue.read { db in
            #expect(try db.tableExists("clip_item"))
            let indexes = try db.indexes(on: "clip_item").map(\.name)
            #expect(indexes.contains("idx_clip_item_order"))
            #expect(indexes.contains("idx_clip_item_hmac"))
        }
    }

    @Test("Le fichier de base n'est lisible que par son propriétaire")
    func databaseFileIsPrivate() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("copydraft-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }

        _ = try HistoryDatabase.open(at: url)
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        #expect((attributes[.posixPermissions] as? NSNumber)?.int16Value == 0o600)
    }

    @Test("Rouvrir la base conserve les données et rejoue les migrations sans effet")
    func reopenIsIdempotent() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("copydraft-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }

        let cipher = makeCipher()
        let item = makeItem()

        let first = HistoryRepository(queue: try HistoryDatabase.open(at: url), cipher: cipher)
        try await first.insert(item, content: StoredContent(text: "contenu"), contentHash: Data([1]))

        let second = HistoryRepository(queue: try HistoryDatabase.open(at: url), cipher: cipher)
        let items = try await second.allItems()
        #expect(items.count == 1)
        #expect(items.first?.id == item.id)
    }

    // MARK: Écriture et lecture

    @Test("Un élément inséré se relit à l'identique")
    func insertRoundTrip() async throws {
        let (repository, _) = try makeRepository()
        let item = makeItem(
            kind: .image,
            subtype: .image,
            createdAt: Date(timeIntervalSince1970: 2_000)
        )

        try await repository.insert(
            item, content: StoredContent(imageFileName: "\(item.id.uuidString).enc"),
            contentHash: Data([0xAB])
        )

        let restored = try #require(try await repository.allItems().first)
        #expect(restored.id == item.id)
        #expect(restored.kind == .image)
        #expect(restored.subtype == .image)
        #expect(restored.createdAt == item.createdAt)
        #expect(restored.source.name == "Xcode")
        #expect(restored.source.bundleIdentifier == "com.apple.dt.Xcode")
        #expect(restored.searchText == item.searchText)
        #expect(restored.previewLines == item.previewLines)
        #expect(restored.byteCount == item.byteCount)
    }

    @Test("Les dimensions d'une image survivent à l'aller-retour")
    func pixelSizeRoundTrip() async throws {
        let (repository, _) = try makeRepository()
        let item = ClipItem(
            kind: .image,
            subtype: .image,
            createdAt: Date(timeIntervalSince1970: 10),
            source: SourceApp(bundleIdentifier: "com.apple.Preview", name: "Aperçu"),
            byteCount: 1_200_000,
            pixelSize: CGSize(width: 1_512, height: 982),
            searchText: "",
            previewLines: []
        )

        try await repository.insert(item, content: StoredContent(), contentHash: Data([2]))
        let restored = try #require(try await repository.allItems().first)
        #expect(restored.pixelSize == CGSize(width: 1_512, height: 982))
    }

    @Test("Le contenu complet est relu à la demande, jamais avec la liste")
    func contentIsLoadedOnDemand() async throws {
        let (repository, _) = try makeRepository()
        let item = makeItem()
        let content = StoredContent(
            text: "contenu intégral",
            rtfData: Data([0x7B, 0x5C]),
            htmlData: Data("<b>x</b>".utf8)
        )

        try await repository.insert(item, content: content, contentHash: Data([3]))

        #expect(try await repository.content(for: item.id) == content)
        #expect(try await repository.content(for: UUID()) == nil)
    }

    @Test("Les épinglés viennent en tête, puis du plus récent au plus ancien")
    func ordering() async throws {
        let (repository, _) = try makeRepository()
        let ancien = makeItem(text: "ancien", createdAt: Date(timeIntervalSince1970: 100))
        let recent = makeItem(text: "récent", createdAt: Date(timeIntervalSince1970: 300))
        let epingle = makeItem(
            text: "épinglé", createdAt: Date(timeIntervalSince1970: 200), pinned: true
        )

        for (index, item) in [ancien, recent, epingle].enumerated() {
            try await repository.insert(
                item, content: StoredContent(text: item.searchText),
                contentHash: Data([UInt8(index)])
            )
        }

        let items = try await repository.allItems()
        #expect(items.map(\.searchText) == ["épinglé", "récent", "ancien"])
    }

    @Test("Un contenu chiffré n'apparaît pas en clair dans le fichier de base")
    func payloadIsEncryptedOnDisk() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("copydraft-\(UUID().uuidString).sqlite")
        defer {
            for suffix in ["", "-wal", "-shm"] {
                try? FileManager.default.removeItem(atPath: url.path + suffix)
            }
        }

        let repository = HistoryRepository(
            queue: try HistoryDatabase.open(at: url), cipher: makeCipher()
        )
        let secret = "mot-de-passe-tres-reconnaissable-42"
        try await repository.insert(
            makeItem(text: secret), content: StoredContent(text: secret),
            contentHash: Data([9])
        )

        var raw = Data()
        for suffix in ["", "-wal"] {
            raw.append((try? Data(contentsOf: URL(fileURLWithPath: url.path + suffix))) ?? Data())
        }
        #expect(!raw.isEmpty)
        #expect(raw.range(of: Data(secret.utf8)) == nil, "le contenu se lit en clair sur disque")
    }

    // MARK: Modifications

    @Test("Remonter un élément met à jour sa date sans le dupliquer")
    func touch() async throws {
        let (repository, _) = try makeRepository()
        let item = makeItem(createdAt: Date(timeIntervalSince1970: 100))
        try await repository.insert(item, content: StoredContent(), contentHash: Data([1]))

        try await repository.touch(id: item.id, at: Date(timeIntervalSince1970: 500))

        let items = try await repository.allItems()
        #expect(items.count == 1)
        #expect(items.first?.createdAt == Date(timeIntervalSince1970: 500))
    }

    @Test("L'épinglage est persisté")
    func pinning() async throws {
        let (repository, _) = try makeRepository()
        let item = makeItem()
        try await repository.insert(item, content: StoredContent(), contentHash: Data([1]))

        try await repository.setPinned(true, id: item.id, at: Date(timeIntervalSince1970: 200))
        #expect(try await repository.allItems().first?.pinned == true)

        try await repository.setPinned(false, id: item.id, at: Date(timeIntervalSince1970: 300))
        #expect(try await repository.allItems().first?.pinned == false)
    }

    @Test("Renommer conserve l'horodatage d'origine")
    func rename() async throws {
        let (repository, _) = try makeRepository()
        let item = makeItem(createdAt: Date(timeIntervalSince1970: 100))
        try await repository.insert(item, content: StoredContent(), contentHash: Data([1]))

        try await repository.rename(
            id: item.id, to: "Requête épinglée", at: Date(timeIntervalSince1970: 900)
        )

        let restored = try #require(try await repository.allItems().first)
        #expect(restored.customName == "Requête épinglée")
        #expect(restored.createdAt == Date(timeIntervalSince1970: 100))
    }

    // MARK: Suppression et purge

    @Test("La suppression rend les fichiers image à effacer")
    func deleteReturnsImageFiles() async throws {
        let (repository, _) = try makeRepository()
        let item = makeItem(kind: .image, subtype: .image)
        try await repository.insert(
            item, content: StoredContent(imageFileName: "image.enc"), contentHash: Data([1])
        )

        let files = try await repository.delete(ids: [item.id])
        #expect(files == ["image.enc"])
        #expect(try await repository.count() == 0)
    }

    @Test("« Tout effacer » respecte le choix de conserver les épinglés")
    func deleteAll() async throws {
        let (repository, _) = try makeRepository()
        let ordinaire = makeItem(text: "ordinaire")
        let epingle = makeItem(text: "épinglé", pinned: true)
        try await repository.insert(ordinaire, content: StoredContent(), contentHash: Data([1]))
        try await repository.insert(epingle, content: StoredContent(), contentHash: Data([2]))

        try await repository.deleteAll(keepingPinned: true)
        #expect(try await repository.allItems().map(\.searchText) == ["épinglé"])

        try await repository.deleteAll(keepingPinned: false)
        #expect(try await repository.count() == 0)
    }

    @Test("La purge supprime les plus anciens non épinglés, jamais les épinglés")
    func enforceLimit() async throws {
        let (repository, _) = try makeRepository()

        for index in 0..<5 {
            try await repository.insert(
                makeItem(
                    text: "élément \(index)",
                    createdAt: Date(timeIntervalSince1970: TimeInterval(index * 100)),
                    pinned: index == 0
                ),
                content: StoredContent(),
                contentHash: Data([UInt8(index)])
            )
        }

        try await repository.enforceLimit(2)

        let remaining = try await repository.allItems().map(\.searchText)
        // L'épinglé (le plus ancien) survit ; deux non épinglés les plus récents restent.
        #expect(remaining == ["élément 0", "élément 4", "élément 3"])
    }

    @Test("Sous la limite, la purge ne supprime rien")
    func enforceLimitBelowThreshold() async throws {
        let (repository, _) = try makeRepository()
        try await repository.insert(makeItem(), content: StoredContent(), contentHash: Data([1]))

        #expect(try await repository.enforceLimit(25).isEmpty)
        #expect(try await repository.count() == 1)
    }

    // MARK: Robustesse

    @Test("Une ligne illisible est ignorée plutôt que de bloquer le chargement")
    func unreadableRowIsSkipped() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("copydraft-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }

        let queue = try HistoryDatabase.open(at: url)
        let lisible = makeItem(text: "lisible")
        let perdu = makeItem(text: "perdu")

        let ancienne = makeCipher()
        try await HistoryRepository(queue: queue, cipher: ancienne)
            .insert(perdu, content: StoredContent(), contentHash: Data([1]))

        // Nouvelle clé : la ligne précédente devient indéchiffrable.
        let nouvelle = makeCipher()
        let repository = HistoryRepository(queue: queue, cipher: nouvelle)
        try await repository.insert(lisible, content: StoredContent(), contentHash: Data([2]))

        let items = try await repository.allItems()
        #expect(items.map(\.searchText) == ["lisible"])
        #expect(try await repository.count() == 2, "la ligne illisible reste en base")
    }

    @Test("Les empreintes sont rendues avec date et épinglage")
    func fingerprints() async throws {
        let (repository, _) = try makeRepository()
        let item = makeItem(createdAt: Date(timeIntervalSince1970: 700), pinned: true)
        try await repository.insert(
            item, content: StoredContent(), contentHash: Data([0xAA, 0xBB])
        )

        let fingerprints = try await repository.fingerprints()
        #expect(fingerprints.count == 1)
        #expect(fingerprints.first?.id == item.id)
        #expect(fingerprints.first?.contentHash == Data([0xAA, 0xBB]))
        #expect(fingerprints.first?.createdAt == Date(timeIntervalSince1970: 700))
        #expect(fingerprints.first?.pinned == true)
    }

    @Test("Les fichiers image référencés sont listables pour traquer les orphelins")
    func referencedImageFiles() async throws {
        let (repository, _) = try makeRepository()
        try await repository.insert(
            makeItem(kind: .image, subtype: .image),
            content: StoredContent(imageFileName: "a.enc"), contentHash: Data([1])
        )
        try await repository.insert(
            makeItem(text: "texte"), content: StoredContent(text: "texte"),
            contentHash: Data([2])
        )

        #expect(try await repository.referencedImageFiles() == ["a.enc"])
    }
}
