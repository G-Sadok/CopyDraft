import CryptoKit
import Foundation
import Testing

@testable import CopyDraftCore

@Suite("Chiffrement de l'historique")
struct CryptoTests {
    private func makeCipher() -> Cipher {
        Cipher(key: SymmetricKey(size: .bits256))
    }

    @Test("Un contenu chiffré se relit à l'identique")
    func roundTrip() throws {
        let cipher = makeCipher()
        let clear = Data("SELECT id FROM clip_item WHERE pinned = 1".utf8)

        let sealed = try cipher.seal(clear)
        #expect(sealed != clear)
        #expect(try cipher.open(sealed) == clear)
    }

    @Test("Un contenu vide et un contenu volumineux passent aussi")
    func edgeSizes() throws {
        let cipher = makeCipher()

        #expect(try cipher.open(cipher.seal(Data())) == Data())

        let large = Data(repeating: 0xAB, count: Limits.itemBytes)
        #expect(try cipher.open(cipher.seal(large)) == large)
    }

    @Test("Deux chiffrements du même contenu diffèrent")
    func nonceIsRandom() throws {
        let cipher = makeCipher()
        let clear = Data("timer = Timer.scheduledTimer(".utf8)
        #expect(try cipher.seal(clear) != cipher.seal(clear))
    }

    @Test("Un contenu altéré est rejeté, jamais lu de travers")
    func tamperingIsDetected() throws {
        let cipher = makeCipher()
        var sealed = try cipher.seal(Data("historique".utf8))
        sealed[sealed.count - 1] ^= 0xFF

        #expect(throws: CipherError.undecipherable) { try cipher.open(sealed) }
    }

    @Test("Une autre clé ne déchiffre rien")
    func wrongKeyFails() throws {
        let sealed = try makeCipher().seal(Data("secret".utf8))
        #expect(throws: CipherError.undecipherable) { try makeCipher().open(sealed) }
    }

    @Test("Des données quelconques ne passent pas pour du chiffré")
    func garbageIsRejected() {
        #expect(throws: CipherError.undecipherable) {
            try makeCipher().open(Data(repeating: 0x42, count: 12))
        }
    }

    // MARK: Empreinte de déduplication

    @Test("L'empreinte est stable pour un contenu identique")
    func hashIsStable() {
        let cipher = makeCipher()
        let content = Data("developer.apple.com/design".utf8)
        #expect(cipher.contentHash(content) == cipher.contentHash(content))
    }

    @Test("Deux contenus différents ont deux empreintes différentes")
    func hashDiscriminates() {
        let cipher = makeCipher()
        #expect(cipher.contentHash(Data("a".utf8)) != cipher.contentHash(Data("b".utf8)))
    }

    @Test("L'empreinte ne révèle pas le contenu")
    func hashDoesNotLeak() {
        let cipher = makeCipher()
        let content = Data("mot de passe".utf8)
        let hash = cipher.contentHash(content)
        #expect(hash.count == 32)
        #expect(hash != content)
        #expect(!hash.contains(content))
    }
}

@Suite("Clé de chiffrement")
struct KeyStoreTests {
    @Test("La clé est créée au premier appel puis réutilisée")
    func createsThenReuses() throws {
        let store = InMemorySecretStore()
        let keyStore = KeyStore(store: store)

        #expect(try keyStore.hasKey() == false)
        let first = try keyStore.loadOrCreate()
        #expect(try keyStore.hasKey())

        let second = try keyStore.loadOrCreate()
        #expect(first == second)
        #expect(first.bitCount == 256)
    }

    /// Trousseau réinitialisé ou clé corrompue : on reforge sans planter.
    @Test("Une clé absente ou corrompue est reforgée proprement")
    func recoversFromMissingOrCorruptKey() throws {
        let store = InMemorySecretStore()
        let keyStore = KeyStore(store: store)

        let original = try keyStore.loadOrCreate()

        try store.set(Data([0x01, 0x02]), for: KeyStore.account)
        #expect(try keyStore.hasKey() == false)

        let reforged = try keyStore.loadOrCreate()
        #expect(reforged != original)
        #expect(try keyStore.hasKey())
    }

    @Test("La destruction retire la clé")
    func destroy() throws {
        let store = InMemorySecretStore()
        let keyStore = KeyStore(store: store)
        _ = try keyStore.loadOrCreate()

        try keyStore.destroy()
        #expect(try keyStore.hasKey() == false)
    }

    /// Après reforge, l'ancien contenu est illisible : c'est bien une réinitialisation.
    @Test("Un historique chiffré avec l'ancienne clé devient illisible")
    func oldContentIsUnreadableAfterReset() throws {
        let store = InMemorySecretStore()
        let keyStore = KeyStore(store: store)
        let sealed = try Cipher(key: keyStore.loadOrCreate()).seal(Data("historique".utf8))

        try keyStore.destroy()
        let newCipher = Cipher(key: try keyStore.loadOrCreate())

        #expect(throws: CipherError.undecipherable) { try newCipher.open(sealed) }
    }
}

@Suite("Emplacements sur disque")
struct AppPathsTests {
    private func makeTemporaryRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("copydraft-tests-\(UUID().uuidString)", isDirectory: true)
    }

    @Test("Les dossiers sont créés en 0700")
    func directoriesArePrivate() throws {
        let root = makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let paths = try AppPaths(root: root).createDirectories()

        for directory in [paths.root, paths.imagesDirectory, paths.thumbnailsDirectory] {
            var isDirectory: ObjCBool = false
            #expect(FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory))
            #expect(isDirectory.boolValue)

            let attributes = try FileManager.default.attributesOfItem(atPath: directory.path)
            let permissions = try #require(attributes[.posixPermissions] as? NSNumber)
            #expect(permissions.int16Value == 0o700, "permissions \(permissions) sur \(directory.lastPathComponent)")
        }
    }

    /// Un dossier créé avant, avec des permissions trop larges, doit être resserré.
    @Test("Un dossier préexistant trop ouvert est corrigé")
    func existingDirectoryIsTightened() throws {
        let root = makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(
            at: root, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o755]
        )

        let paths = try AppPaths(root: root).createDirectories()
        let attributes = try FileManager.default.attributesOfItem(atPath: paths.root.path)
        #expect((attributes[.posixPermissions] as? NSNumber)?.int16Value == 0o700)
    }

    @Test("Les fichiers d'un élément portent son identifiant")
    func fileNaming() {
        let paths = AppPaths(root: URL(fileURLWithPath: "/tmp/copydraft"))
        let identifier = UUID()

        #expect(paths.imageFile(for: identifier).lastPathComponent == "\(identifier.uuidString).enc")
        #expect(
            paths.imageFile(for: identifier).deletingLastPathComponent().path
                == paths.imagesDirectory.path
        )
        #expect(
            paths.thumbnailFile(for: identifier).deletingLastPathComponent().path
                == paths.thumbnailsDirectory.path
        )
    }

    @Test("L'emplacement standard vit sous Application Support")
    func standardLocation() throws {
        let paths = try AppPaths.standard()
        #expect(paths.root.lastPathComponent == AppInfo.name)
        #expect(paths.root.path.contains("Application Support"))
        #expect(paths.databaseURL.lastPathComponent == "history.sqlite")
    }
}

/// Le démarrage ne doit jamais se bloquer ni s'arrêter sur un secret devenu illisible
/// (signature de l'application changée, Trousseau verrouillé autrement).
@Suite("Clé illisible au démarrage")
struct InaccessibleKeyTests {
    /// Coffre qui simule un secret présent mais refusé sans intervention de l'utilisateur.
    private final class LockedSecretStore: SecretStore, @unchecked Sendable {
        private let lock = NSLock()
        private var stored: Data?
        private var refuses = true
        private(set) var removals = 0

        init(seeded: Data) { stored = seeded }

        func data(for account: String) throws -> Data? {
            if lock.withLock({ refuses }) { throw SecretStoreError.inaccessible }
            return lock.withLock { stored }
        }

        func set(_ data: Data, for account: String) throws {
            lock.withLock {
                stored = data
                refuses = false
            }
        }

        func remove(_ account: String) throws {
            lock.withLock {
                stored = nil
                removals += 1
            }
        }
    }

    @Test("Une clé illisible est remplacée au lieu de bloquer le démarrage")
    func inaccessibleKeyIsReplaced() throws {
        let store = LockedSecretStore(seeded: Data(repeating: 0xAB, count: KeyStore.keyByteCount))
        let keyStore = KeyStore(store: store)

        #expect(try keyStore.hasKey() == false, "un secret refusé compte comme absent")

        let key = try keyStore.loadOrCreate()
        #expect(key.bitCount == 256)
        #expect(store.removals == 1, "l'ancien secret inutilisable est retiré")
        #expect(try keyStore.hasKey(), "la nouvelle clé est lisible")
    }
}
