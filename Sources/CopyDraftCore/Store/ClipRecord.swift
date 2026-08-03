import Foundation
import GRDB

/// Ce qui est chiffré dans la colonne `payload` (ADR-2).
///
/// Tout ce qui est signifiant vit ici : contenu, projection de recherche, aperçu, nom de
/// l'application source. Les colonnes en clair de `ClipRecord` ne servent qu'à trier, purger
/// et dédoublonner sans avoir à déchiffrer la base entière.
struct ClipPayload: Codable, Sendable, Equatable {
    var text: String?
    var rtfData: Data?
    var htmlData: Data?
    var sourceBundleIdentifier: String?
    var sourceName: String
    var customName: String?
    var searchText: String
    var previewLines: [String]
    /// Nom du fichier image chiffré, sans le dossier.
    var imageFileName: String?
}

/// Ligne de la table `clip_item`.
///
/// Les dates sont stockées en secondes depuis 1970 : comparables en SQL sans conversion,
/// donc utilisables pour l'index de tri et la purge.
struct ClipRecord: Codable, Sendable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "clip_item"

    var id: String
    var kind: String
    var subtype: String
    var createdAt: Double
    var updatedAt: Double
    var pinned: Bool
    var pinOrder: Int?
    var byteCount: Int
    var pixelWidth: Int?
    var pixelHeight: Int?
    var charCount: Int?
    /// HMAC-SHA256 du contenu — déduplication sans divulgation (FR-6).
    var contentHmac: Data
    /// `ClipPayload` sérialisé puis scellé en AES-GCM.
    var payload: Data
    /// Nom du fichier image chiffré, en clair : nécessaire pour supprimer les fichiers
    /// orphelins même quand la clé de chiffrement a été perdue.
    var imageFile: String?

    enum Columns {
        static let id = Column("id")
        static let kind = Column("kind")
        static let subtype = Column("subtype")
        static let createdAt = Column("createdAt")
        static let updatedAt = Column("updatedAt")
        static let pinned = Column("pinned")
        static let pinOrder = Column("pinOrder")
        static let byteCount = Column("byteCount")
        static let contentHmac = Column("contentHmac")
        static let imageFile = Column("imageFile")
    }
}
