import CoreGraphics
import Foundation
import GRDB

/// Contenu complet d'un élément, tel qu'il est nécessaire pour coller ou éditer.
///
/// Ne vit jamais en mémoire avec la liste : il est relu à la demande (ADR-4).
public struct StoredContent: Sendable, Equatable {
    public var text: String?
    public var rtfData: Data?
    public var htmlData: Data?
    /// Nom du fichier image chiffré, images uniquement.
    public var imageFileName: String?

    public init(
        text: String? = nil,
        rtfData: Data? = nil,
        htmlData: Data? = nil,
        imageFileName: String? = nil
    ) {
        self.text = text
        self.rtfData = rtfData
        self.htmlData = htmlData
        self.imageFileName = imageFileName
    }
}

/// Empreinte d'un élément déjà stocké, telle que la déduplication en a besoin (FR-6).
public struct ClipFingerprint: Sendable, Equatable {
    public let id: UUID
    public let contentHash: Data
    public let createdAt: Date
    public let pinned: Bool
}

/// Erreurs de persistance.
public enum HistoryRepositoryError: Error, Equatable {
    /// Ligne présente mais illisible : clé de chiffrement changée ou payload corrompu.
    case unreadableItem(UUID)
}

/// Accès à la base d'historique : lectures, écritures, purge.
///
/// `actor` : toutes les écritures sont sérialisées et transactionnelles. Une interruption
/// — arrêt brutal, coupure — laisse la base dans son état d'avant la transaction, jamais une
/// ligne à moitié écrite (FR-18, NFR-14).
public actor HistoryRepository {
    private let queue: DatabaseQueue
    private let cipher: Cipher

    public init(queue: DatabaseQueue, cipher: Cipher) {
        self.queue = queue
        self.cipher = cipher
    }

    /// Resserre les permissions des fichiers annexes créés depuis l'ouverture (`-wal`, `-shm`).
    public func restrictFilePermissions(at url: URL) {
        HistoryDatabase.restrictPermissions(at: url)
    }

    // MARK: Écritures

    /// Insère un élément et son contenu, en une transaction.
    public func insert(_ item: ClipItem, content: StoredContent, contentHash: Data) throws {
        let record = try makeRecord(item: item, content: content, contentHash: contentHash)
        try queue.write { db in
            try record.insert(db)
        }
    }

    /// Remonte un élément existant en tête sans dupliquer son contenu (FR-6).
    public func touch(id: UUID, at date: Date) throws {
        try queue.write { db in
            try db.execute(
                sql: """
                    UPDATE \(ClipRecord.databaseTableName)
                    SET createdAt = ?, updatedAt = ?
                    WHERE id = ?
                    """,
                arguments: [date.timeIntervalSince1970, date.timeIntervalSince1970, id.uuidString]
            )
        }
    }

    /// Épingle ou désépingle.
    public func setPinned(_ pinned: Bool, id: UUID, at date: Date) throws {
        try queue.write { db in
            try db.execute(
                sql: """
                    UPDATE \(ClipRecord.databaseTableName)
                    SET pinned = ?, updatedAt = ?
                    WHERE id = ?
                    """,
                arguments: [pinned, date.timeIntervalSince1970, id.uuidString]
            )
        }
    }

    /// Renomme un élément (FR-52).
    public func rename(id: UUID, to name: String?, at date: Date) throws {
        try queue.write { db in
            guard var record = try ClipRecord.fetchOne(db, key: id.uuidString) else { return }
            var payload = try self.decodePayload(record)
            payload.customName = name
            record.payload = try self.encodePayload(payload)
            record.updatedAt = date.timeIntervalSince1970
            try record.update(db)
        }
    }

    /// Supprime des éléments et renvoie les fichiers image à effacer.
    ///
    /// La liste est rendue à l'appelant plutôt que supprimée ici : les fichiers ne doivent
    /// disparaître qu'une fois la transaction validée, jamais avant (S-2.2).
    @discardableResult
    public func delete(ids: [UUID]) throws -> [String] {
        guard !ids.isEmpty else { return [] }
        return try queue.write { db in
            let keys = ids.map(\.uuidString)
            let files =
                try ClipRecord
                .filter(keys.contains(ClipRecord.Columns.id))
                .fetchAll(db)
                .compactMap(\.imageFile)
            _ = try ClipRecord.filter(keys.contains(ClipRecord.Columns.id)).deleteAll(db)
            return files
        }
    }

    /// Vide l'historique, en conservant ou non les éléments épinglés (FR-12).
    @discardableResult
    public func deleteAll(keepingPinned: Bool) throws -> [String] {
        try queue.write { db in
            let request =
                keepingPinned
                ? ClipRecord.filter(ClipRecord.Columns.pinned == false)
                : ClipRecord.all()
            let files = try request.fetchAll(db).compactMap(\.imageFile)
            _ = try request.deleteAll(db)
            return files
        }
    }

    /// Supprime les éléments non épinglés les plus anciens au-delà de la limite (FR-14).
    @discardableResult
    public func enforceLimit(_ limit: Int) throws -> [String] {
        try queue.write { db in
            let unpinned =
                try ClipRecord
                .filter(ClipRecord.Columns.pinned == false)
                .order(ClipRecord.Columns.createdAt.desc)
                .fetchAll(db)

            guard unpinned.count > limit else { return [] }
            let excess = unpinned.suffix(from: limit)
            let keys = excess.map(\.id)
            let files = excess.compactMap(\.imageFile)
            _ = try ClipRecord.filter(keys.contains(ClipRecord.Columns.id)).deleteAll(db)
            return files
        }
    }

    // MARK: Lectures

    /// Tous les éléments, épinglés d'abord puis du plus récent au plus ancien (FR-17).
    ///
    /// Une ligne illisible — clé perdue — est ignorée plutôt que de faire échouer le
    /// chargement complet : mieux vaut un historique partiel qu'une application bloquée.
    public func allItems() throws -> [ClipItem] {
        try queue.read { db in
            try ClipRecord
                .order(ClipRecord.Columns.pinned.desc, ClipRecord.Columns.createdAt.desc)
                .fetchAll(db)
                .compactMap { try? self.makeItem($0) }
        }
    }

    /// Contenu complet d'un élément, déchiffré à la demande.
    public func content(for id: UUID) throws -> StoredContent? {
        try queue.read { db in
            guard let record = try ClipRecord.fetchOne(db, key: id.uuidString) else { return nil }
            let payload = try self.decodePayload(record)
            return StoredContent(
                text: payload.text,
                rtfData: payload.rtfData,
                htmlData: payload.htmlData,
                imageFileName: payload.imageFileName
            )
        }
    }

    /// Empreintes des éléments, pour la déduplication.
    public func fingerprints() throws -> [ClipFingerprint] {
        try queue.read { db in
            try ClipRecord.fetchAll(db).map {
                ClipFingerprint(
                    id: UUID(uuidString: $0.id) ?? UUID(),
                    contentHash: $0.contentHmac,
                    createdAt: Date(timeIntervalSince1970: $0.createdAt),
                    pinned: $0.pinned
                )
            }
        }
    }

    public func count() throws -> Int {
        try queue.read { db in try ClipRecord.fetchCount(db) }
    }

    /// Noms de fichiers image encore référencés — sert à débusquer les orphelins (S-2.2).
    public func referencedImageFiles() throws -> Set<String> {
        try queue.read { db in
            Set(try ClipRecord.fetchAll(db).compactMap(\.imageFile))
        }
    }

    // MARK: Conversions

    private func makeRecord(
        item: ClipItem, content: StoredContent, contentHash: Data
    ) throws -> ClipRecord {
        let payload = ClipPayload(
            text: content.text,
            rtfData: content.rtfData,
            htmlData: content.htmlData,
            sourceBundleIdentifier: item.source.bundleIdentifier,
            sourceName: item.source.name,
            customName: item.customName,
            searchText: item.searchText,
            previewLines: item.previewLines,
            imageFileName: content.imageFileName
        )

        return ClipRecord(
            id: item.id.uuidString,
            kind: item.kind.rawValue,
            subtype: item.subtype.rawValue,
            createdAt: item.createdAt.timeIntervalSince1970,
            updatedAt: item.updatedAt.timeIntervalSince1970,
            pinned: item.pinned,
            pinOrder: nil,
            byteCount: item.byteCount,
            pixelWidth: item.pixelSize.map { Int($0.width) },
            pixelHeight: item.pixelSize.map { Int($0.height) },
            charCount: item.characterCount,
            contentHmac: contentHash,
            payload: try encodePayload(payload),
            imageFile: content.imageFileName
        )
    }

    private nonisolated func makeItem(_ record: ClipRecord) throws -> ClipItem {
        guard let id = UUID(uuidString: record.id),
            let kind = ClipKind(rawValue: record.kind),
            let subtype = ClipSubtype(rawValue: record.subtype)
        else {
            throw HistoryRepositoryError.unreadableItem(
                UUID(uuidString: record.id) ?? UUID()
            )
        }

        let payload = try decodePayload(record)
        let pixelSize: CGSize? =
            if let width = record.pixelWidth, let height = record.pixelHeight {
                CGSize(width: width, height: height)
            } else {
                nil
            }

        return ClipItem(
            id: id,
            kind: kind,
            subtype: subtype,
            createdAt: Date(timeIntervalSince1970: record.createdAt),
            updatedAt: Date(timeIntervalSince1970: record.updatedAt),
            pinned: record.pinned,
            customName: payload.customName,
            source: SourceApp(
                bundleIdentifier: payload.sourceBundleIdentifier, name: payload.sourceName
            ),
            byteCount: record.byteCount,
            pixelSize: pixelSize,
            characterCount: record.charCount,
            searchText: payload.searchText,
            previewLines: payload.previewLines
        )
    }

    private nonisolated func encodePayload(_ payload: ClipPayload) throws -> Data {
        try cipher.seal(JSONEncoder().encode(payload))
    }

    private nonisolated func decodePayload(_ record: ClipRecord) throws -> ClipPayload {
        do {
            return try JSONDecoder().decode(ClipPayload.self, from: cipher.open(record.payload))
        } catch {
            throw HistoryRepositoryError.unreadableItem(UUID(uuidString: record.id) ?? UUID())
        }
    }
}
