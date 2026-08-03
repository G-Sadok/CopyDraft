import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

@testable import CopyDraftCore

@Suite("Stockage des images")
struct ImageStoreTests {
    // MARK: Fabriques

    private func makeStore() -> (ImageStore, AppPaths) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("copydraft-images-\(UUID().uuidString)", isDirectory: true)
        let paths = AppPaths(root: root)
        return (ImageStore(paths: paths, cipher: Cipher(key: SymmetricKey(size: .bits256))), paths)
    }

    /// PNG uni, généré sans AppKit pour rester utilisable partout.
    private func makePNG(width: Int, height: Int) throws -> Data {
        let context = try #require(
            CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        )
        context.setFillColor(CGColor(red: 0.04, green: 0.52, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        let image = try #require(context.makeImage())
        let output = NSMutableData()
        let destination = try #require(
            CGImageDestinationCreateWithData(
                output as CFMutableData, UTType.png.identifier as CFString, 1, nil
            )
        )
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return output as Data
    }

    // MARK: Cycle complet

    @Test("Une image stockée se relit à l'identique")
    func storeAndRead() async throws {
        let (store, paths) = makeStore()
        defer { try? FileManager.default.removeItem(at: paths.root) }

        let identifier = UUID()
        let png = try makePNG(width: 120, height: 80)

        let stored = try await store.store(png, for: identifier)
        #expect(stored.fileName == "\(identifier.uuidString).enc")
        #expect(stored.pixelSize == CGSize(width: 120, height: 80))
        #expect(stored.byteCount == png.count)

        #expect(try await store.image(for: identifier) == png)
    }

    @Test("Une vignette est produite et reste sous 112 px")
    func thumbnailIsGenerated() async throws {
        let (store, paths) = makeStore()
        defer { try? FileManager.default.removeItem(at: paths.root) }

        let identifier = UUID()
        _ = try await store.store(try makePNG(width: 1_512, height: 982), for: identifier)

        let thumbnail = try #require(try await store.thumbnail(for: identifier))
        let source = try #require(CGImageSourceCreateWithData(thumbnail as CFData, nil))
        let properties = try #require(
            CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        )
        let width = try #require(properties[kCGImagePropertyPixelWidth] as? Int)
        let height = try #require(properties[kCGImagePropertyPixelHeight] as? Int)

        #expect(max(width, height) <= Int(ImageStore.thumbnailPixelSize))
        #expect(width > height, "le rapport d'aspect est conservé")
    }

    @Test("Les fichiers sont chiffrés sur le disque")
    func filesAreEncrypted() async throws {
        let (store, paths) = makeStore()
        defer { try? FileManager.default.removeItem(at: paths.root) }

        let identifier = UUID()
        let png = try makePNG(width: 40, height: 40)
        _ = try await store.store(png, for: identifier)

        let raw = try Data(contentsOf: paths.imageFile(for: identifier))
        #expect(raw != png)
        // Un PNG commence par cette signature : elle ne doit pas se retrouver sur le disque.
        #expect(raw.prefix(8) != Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]))
    }

    @Test("Les fichiers ne sont lisibles que par leur propriétaire")
    func filePermissions() async throws {
        let (store, paths) = makeStore()
        defer { try? FileManager.default.removeItem(at: paths.root) }

        let identifier = UUID()
        _ = try await store.store(try makePNG(width: 20, height: 20), for: identifier)

        let attributes = try FileManager.default.attributesOfItem(
            atPath: paths.imageFile(for: identifier).path
        )
        #expect((attributes[.posixPermissions] as? NSNumber)?.int16Value == 0o600)
    }

    @Test("Des données qui ne sont pas une image sont refusées")
    func rejectsNonImage() async throws {
        let (store, paths) = makeStore()
        defer { try? FileManager.default.removeItem(at: paths.root) }

        await #expect(throws: ImageStoreError.unreadableImage) {
            _ = try await store.store(Data("pas une image".utf8), for: UUID())
        }
    }

    @Test("Lire un élément absent ne lève pas d'erreur")
    func missingFileIsNotAnError() async throws {
        let (store, paths) = makeStore()
        defer { try? FileManager.default.removeItem(at: paths.root) }

        #expect(try await store.image(for: UUID()) == nil)
        #expect(try await store.thumbnail(for: UUID()) == nil)
    }

    // MARK: Suppression

    @Test("Supprimer un élément efface son image et sa vignette")
    func removeDeletesBothFiles() async throws {
        let (store, paths) = makeStore()
        defer { try? FileManager.default.removeItem(at: paths.root) }

        let identifier = UUID()
        _ = try await store.store(try makePNG(width: 60, height: 60), for: identifier)

        try await store.remove(for: identifier)

        #expect(!FileManager.default.fileExists(atPath: paths.imageFile(for: identifier).path))
        #expect(!FileManager.default.fileExists(atPath: paths.thumbnailFile(for: identifier).path))
    }

    @Test("Les noms de fichiers rendus par la base sont effaçables tels quels")
    func removeByFileName() async throws {
        let (store, paths) = makeStore()
        defer { try? FileManager.default.removeItem(at: paths.root) }

        let identifier = UUID()
        let stored = try await store.store(try makePNG(width: 30, height: 30), for: identifier)

        try await store.remove(fileNames: [stored.fileName, "nom-invalide.enc"])
        #expect(try await store.image(for: identifier) == nil)
    }

    @Test("Les images orphelines sont traquées et supprimées")
    func orphansAreRemoved() async throws {
        let (store, paths) = makeStore()
        defer { try? FileManager.default.removeItem(at: paths.root) }

        let garde = UUID()
        let orphelin = UUID()
        let conserve = try await store.store(try makePNG(width: 24, height: 24), for: garde)
        _ = try await store.store(try makePNG(width: 24, height: 24), for: orphelin)

        let removed = try await store.removeOrphans(referenced: [conserve.fileName])

        // Image et vignette de l'orphelin.
        #expect(removed == 2)
        #expect(try await store.image(for: garde) != nil)
        #expect(try await store.image(for: orphelin) == nil)
    }

    @Test("Sans orphelin, rien n'est supprimé")
    func noOrphansNoDeletion() async throws {
        let (store, paths) = makeStore()
        defer { try? FileManager.default.removeItem(at: paths.root) }

        let identifier = UUID()
        let stored = try await store.store(try makePNG(width: 24, height: 24), for: identifier)

        #expect(try await store.removeOrphans(referenced: [stored.fileName]) == 0)
        #expect(try await store.image(for: identifier) != nil)
    }
}
