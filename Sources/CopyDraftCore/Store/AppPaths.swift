import Foundation

/// Emplacements sur disque de CopyDraft.
///
/// Tout vit dans un dossier propre à l'application, en `0700` : lisible par le seul compte
/// utilisateur, comme l'exige NFR-6.
public struct AppPaths: Sendable {
    /// Dossier racine — `~/Library/Application Support/CopyDraft` en usage normal.
    public let root: URL

    public var databaseURL: URL { root.appendingPathComponent("history.sqlite") }
    public var imagesDirectory: URL { root.appendingPathComponent("Images") }
    public var thumbnailsDirectory: URL { root.appendingPathComponent("Thumbs") }

    /// Emplacement standard de l'application.
    public static func standard(fileManager: FileManager = .default) throws -> AppPaths {
        let support = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return AppPaths(root: support.appendingPathComponent(AppInfo.name, isDirectory: true))
    }

    public init(root: URL) {
        self.root = root
    }

    /// Crée les dossiers manquants et impose `0700` à chacun.
    @discardableResult
    public func createDirectories(fileManager: FileManager = .default) throws -> AppPaths {
        for directory in [root, imagesDirectory, thumbnailsDirectory] {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            // Un dossier préexistant conserve ses permissions : on les corrige.
            try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        }
        return self
    }

    /// Fichier d'image chiffrée d'un élément.
    public func imageFile(for identifier: UUID) -> URL {
        imagesDirectory.appendingPathComponent("\(identifier.uuidString).enc")
    }

    /// Fichier de vignette chiffrée d'un élément.
    public func thumbnailFile(for identifier: UUID) -> URL {
        thumbnailsDirectory.appendingPathComponent("\(identifier.uuidString).enc")
    }
}
