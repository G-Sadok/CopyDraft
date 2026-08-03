import Foundation

/// Élément d'historique tel que l'interface le manipule.
///
/// Le **contenu complet n'est jamais porté par ce type** (ADR-4) : seules une projection de
/// recherche bornée et une ou deux lignes d'aperçu le sont. Le contenu intégral est relu et
/// déchiffré à la demande, au moment du collage ou de l'édition.
public struct ClipItem: Sendable, Identifiable, Equatable {
    /// Longueur maximale de la projection de recherche (ADR-3).
    public static let searchTextLimit = 2_048
    /// Nombre maximal de lignes d'aperçu (§2.5 : 44 pt pour une ligne, 60 pt pour deux).
    public static let previewLineLimit = 2

    public let id: UUID
    public let kind: ClipKind
    public let subtype: ClipSubtype
    public let createdAt: Date
    public var updatedAt: Date
    public var pinned: Bool
    /// Nom donné par l'utilisateur (FR-52), sinon `nil`.
    public var customName: String?
    public let source: SourceApp
    public let byteCount: Int
    public let pixelSize: CGSize?
    public let characterCount: Int?
    /// Projection en clair, en mémoire, plafonnée à `searchTextLimit` caractères.
    public let searchText: String
    /// Lignes d'aperçu déjà aplaties, prêtes à l'affichage.
    public let previewLines: [String]

    public init(
        id: UUID = UUID(),
        kind: ClipKind,
        subtype: ClipSubtype,
        createdAt: Date,
        updatedAt: Date? = nil,
        pinned: Bool = false,
        customName: String? = nil,
        source: SourceApp,
        byteCount: Int,
        pixelSize: CGSize? = nil,
        characterCount: Int? = nil,
        searchText: String,
        previewLines: [String]
    ) {
        self.id = id
        self.kind = kind
        self.subtype = subtype
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.pinned = pinned
        self.customName = customName
        self.source = source
        self.byteCount = byteCount
        self.pixelSize = pixelSize
        self.characterCount = characterCount
        self.searchText = String(searchText.prefix(Self.searchTextLimit))
        self.previewLines = Array(previewLines.prefix(Self.previewLineLimit))
    }

    /// Hauteur de cellule correspondante, en points (§2.5).
    public var isTwoLine: Bool {
        previewLines.count > 1
    }
}
