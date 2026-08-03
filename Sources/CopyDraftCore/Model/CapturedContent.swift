import CoreGraphics
import Foundation

/// Contenu brut lu dans le presse-papiers, avant classification et stockage (FR-2, FR-3).
///
/// Toutes les représentations utiles à un collage fidèle sont conservées ; `text` en est la
/// projection lisible, utilisée pour l'aperçu, la recherche et la déduplication.
public struct CapturedContent: Sendable, Equatable {
    public let kind: ClipKind
    /// Projection texte du contenu. Toujours renseignée pour `.text` et `.rich`, absente
    /// pour une image.
    public let text: String?
    /// Représentation RTF d'origine, si le presse-papiers en proposait une.
    public let rtfData: Data?
    /// Représentation HTML d'origine, si le presse-papiers en proposait une.
    public let htmlData: Data?
    /// Données image d'origine (PNG ou TIFF).
    public let imageData: Data?
    /// Dimensions de l'image en pixels.
    public let pixelSize: CGSize?
    /// Taille de la représentation la plus lourde, en octets — arbitre la limite de 4 Mo (FR-7).
    public let byteCount: Int

    public init(
        kind: ClipKind,
        text: String? = nil,
        rtfData: Data? = nil,
        htmlData: Data? = nil,
        imageData: Data? = nil,
        pixelSize: CGSize? = nil,
        byteCount: Int
    ) {
        self.kind = kind
        self.text = text
        self.rtfData = rtfData
        self.htmlData = htmlData
        self.imageData = imageData
        self.pixelSize = pixelSize
        self.byteCount = byteCount
    }

    /// Nombre de caractères de la projection texte.
    public var characterCount: Int? {
        text?.count
    }

    /// Données servant à l'empreinte de déduplication : le texte quand il existe, sinon
    /// l'image (FR-6).
    public var fingerprintData: Data {
        if let text { return Data(text.utf8) }
        return imageData ?? Data()
    }

    /// Vrai si le contenu ne porte rien d'exploitable : à ignorer sans créer d'entrée.
    public var isEmpty: Bool {
        switch kind {
        case .text, .rich:
            (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && rtfData == nil && htmlData == nil
        case .image:
            (imageData?.isEmpty ?? true)
        }
    }

    /// Vrai si le contenu dépasse la limite par élément (FR-7).
    public var exceedsSizeLimit: Bool {
        byteCount > Limits.itemBytes
    }
}
