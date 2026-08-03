import Foundation
import GRDB

/// Ouverture et migration de la base d'historique.
///
/// Une seule connexion sérialisée (`DatabaseQueue`) : CopyDraft écrit peu, lit peu, et une
/// file unique supprime toute question de concurrence d'écriture. Les migrations sont
/// nommées et jamais réécrites — c'est ce qui permet d'ouvrir une base ancienne sans la
/// perdre.
public enum HistoryDatabase {
    /// Migrations, dans l'ordre. **Ne jamais modifier une migration déjà livrée** : en
    /// ajouter une nouvelle.
    static func migrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_clip_item") { db in
            try db.create(table: ClipRecord.databaseTableName) { table in
                table.primaryKey("id", .text).notNull()
                table.column("kind", .text).notNull()
                table.column("subtype", .text).notNull()
                table.column("createdAt", .double).notNull()
                table.column("updatedAt", .double).notNull()
                table.column("pinned", .boolean).notNull().defaults(to: false)
                table.column("pinOrder", .integer)
                table.column("byteCount", .integer).notNull()
                table.column("pixelWidth", .integer)
                table.column("pixelHeight", .integer)
                table.column("charCount", .integer)
                table.column("contentHmac", .blob).notNull()
                table.column("payload", .blob).notNull()
                table.column("imageFile", .text)
            }

            // Ordre d'affichage : épinglés d'abord, puis du plus récent au plus ancien (FR-17).
            try db.create(
                index: "idx_clip_item_order",
                on: ClipRecord.databaseTableName,
                columns: ["pinned", "createdAt"]
            )
            // Recherche d'un doublon par empreinte (FR-6).
            try db.create(
                index: "idx_clip_item_hmac",
                on: ClipRecord.databaseTableName,
                columns: ["contentHmac"]
            )
        }

        return migrator
    }

    /// Ouvre — et crée au besoin — la base à l'emplacement donné, migrations appliquées.
    public static func open(at url: URL) throws -> DatabaseQueue {
        var configuration = Configuration()
        // Le fichier ne doit jamais être lisible par un autre compte (NFR-6).
        configuration.prepareDatabase { db in
            try db.execute(sql: "PRAGMA journal_mode = WAL")
        }

        let queue = try DatabaseQueue(path: url.path, configuration: configuration)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600], ofItemAtPath: url.path
        )
        try migrator().migrate(queue)
        return queue
    }

    /// Base en mémoire, pour les tests.
    public static func openInMemory() throws -> DatabaseQueue {
        let queue = try DatabaseQueue()
        try migrator().migrate(queue)
        return queue
    }
}
