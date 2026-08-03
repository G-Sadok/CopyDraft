import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Ce que le stockage d'une image laisse derrière lui.
public struct StoredImage: Sendable, Equatable {
    /// Nom du fichier chiffré, tel qu'il est référencé en base.
    public let fileName: String
    public let pixelSize: CGSize
    public let byteCount: Int
}

public enum ImageStoreError: Error, Equatable {
    /// Données qui ne sont pas une image exploitable.
    case unreadableImage
}

/// Stockage des images de l'historique : fichiers chiffrés hors de la base.
///
/// Les images ne vivent pas dans SQLite — une base de plusieurs centaines de mégaoctets
/// serait lente à ouvrir et à sauvegarder. Chaque élément image écrit deux fichiers : la
/// donnée d'origine et une vignette, tous deux chiffrés en AES-GCM comme le reste (NFR-6).
public actor ImageStore {
    /// Côté de la vignette affichée (28 pt) rendue en @2× (§2.5).
    public static let thumbnailPixelSize: CGFloat = 56 * 2

    private let paths: AppPaths
    private let cipher: Cipher
    private let fileManager: FileManager

    public init(paths: AppPaths, cipher: Cipher, fileManager: FileManager = .default) {
        self.paths = paths
        self.cipher = cipher
        self.fileManager = fileManager
    }

    // MARK: Écriture

    /// Chiffre et écrit l'image et sa vignette. Renvoie de quoi renseigner la base.
    public func store(_ imageData: Data, for identifier: UUID) throws -> StoredImage {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
            CGImageSourceGetCount(source) > 0,
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Int,
            let height = properties[kCGImagePropertyPixelHeight] as? Int
        else {
            throw ImageStoreError.unreadableImage
        }

        try paths.createDirectories(fileManager: fileManager)

        let imageURL = paths.imageFile(for: identifier)
        try write(imageData, to: imageURL)

        // Une vignette illisible ne doit pas empêcher de conserver l'élément : la cellule
        // retombera sur le glyphe de type.
        if let thumbnail = Self.makeThumbnail(from: source) {
            try? write(thumbnail, to: paths.thumbnailFile(for: identifier))
        }

        return StoredImage(
            fileName: imageURL.lastPathComponent,
            pixelSize: CGSize(width: width, height: height),
            byteCount: imageData.count
        )
    }

    // MARK: Lecture

    /// Image d'origine, déchiffrée.
    public func image(for identifier: UUID) throws -> Data? {
        try read(paths.imageFile(for: identifier))
    }

    /// Vignette, déchiffrée.
    public func thumbnail(for identifier: UUID) throws -> Data? {
        try read(paths.thumbnailFile(for: identifier))
    }

    // MARK: Suppression

    /// Supprime image et vignette d'un élément.
    public func remove(for identifier: UUID) throws {
        for url in [paths.imageFile(for: identifier), paths.thumbnailFile(for: identifier)] {
            try? fileManager.removeItem(at: url)
        }
    }

    /// Supprime les fichiers dont la base a rendu les noms au moment d'une suppression.
    public func remove(fileNames: [String]) throws {
        for name in fileNames {
            guard let identifier = Self.identifier(fromFileName: name) else { continue }
            try remove(for: identifier)
        }
    }

    /// Supprime les fichiers qui ne sont plus référencés par aucune ligne.
    ///
    /// Filet de sécurité : une suppression interrompue entre la transaction et l'effacement
    /// des fichiers laisserait sinon des images orphelines chiffrées sur le disque.
    @discardableResult
    public func removeOrphans(referenced: Set<String>) throws -> Int {
        var removed = 0
        let identifiers = Set(referenced.compactMap(Self.identifier(fromFileName:)))

        for directory in [paths.imagesDirectory, paths.thumbnailsDirectory] {
            let files =
                (try? fileManager.contentsOfDirectory(
                    at: directory, includingPropertiesForKeys: nil
                )) ?? []

            for file in files where file.pathExtension == "enc" {
                guard let identifier = Self.identifier(fromFileName: file.lastPathComponent),
                    !identifiers.contains(identifier)
                else { continue }
                try? fileManager.removeItem(at: file)
                removed += 1
            }
        }
        return removed
    }

    // MARK: Chiffrement des fichiers

    private func write(_ data: Data, to url: URL) throws {
        try cipher.seal(data).write(to: url, options: [.atomic])
        try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private func read(_ url: URL) throws -> Data? {
        guard let sealed = try? Data(contentsOf: url) else { return nil }
        return try cipher.open(sealed)
    }

    // MARK: Vignettes

    /// Vignette PNG bornée à `thumbnailPixelSize`, générée sans passer par AppKit.
    private static func makeThumbnail(from source: CGImageSource) -> Data? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: thumbnailPixelSize
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { return nil }

        let output = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(
                output as CFMutableData, UTType.png.identifier as CFString, 1, nil
            )
        else { return nil }

        CGImageDestinationAddImage(destination, thumbnail, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    /// `<uuid>.enc` → identifiant.
    private static func identifier(fromFileName name: String) -> UUID? {
        UUID(uuidString: (name as NSString).deletingPathExtension)
    }
}
