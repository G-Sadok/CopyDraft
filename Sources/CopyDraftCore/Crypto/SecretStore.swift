import Foundation
import Security

/// Coffre de secrets. Abstrait le stockage pour que la logique de clé soit testable sans
/// toucher au Trousseau réel de l'utilisateur.
public protocol SecretStore: Sendable {
    func data(for account: String) throws -> Data?
    func set(_ data: Data, for account: String) throws
    func remove(_ account: String) throws
}

/// Erreurs du coffre.
public enum SecretStoreError: Error, Equatable {
    /// Erreur brute renvoyée par le Trousseau.
    case keychain(OSStatus)
    /// Le secret n'est pas accessible sans intervention de l'utilisateur, ou le Trousseau
    /// n'est pas utilisable par cette application.
    ///
    /// Pour un agent lancé à l'ouverture de session, un dialogue système au démarrage est
    /// inacceptable : l'appelant se rabat sur le coffre de secours.
    case inaccessible
    /// Écriture impossible sur le disque.
    case file(String)
}

/// Trousseau moderne, dit *data protection keychain*.
///
/// Choix délibéré du trousseau moderne plutôt que du trousseau historique : ce dernier
/// protège chaque secret par une liste d'applications autorisées et **redemande
/// l'autorisation par un dialogue modal dès que la signature de l'application change**.
/// Constaté en usage réel : le lancement restait bloqué derrière cette fenêtre, clé jamais
/// lue, base jamais ouverte. Le trousseau moderne n'a pas d'ACL par application : l'accès
/// découle de l'identité de signature, sans jamais interrompre l'utilisateur.
///
/// Accessibilité `AfterFirstUnlockThisDeviceOnly` : lisible dès le premier déverrouillage
/// après démarrage, jamais synchronisée, jamais hors de ce Mac (ENF-5, NFR-6).
public struct KeychainSecretStore: SecretStore {
    private let service: String

    public init(service: String = AppInfo.bundleIdentifier) {
        self.service = service
    }

    private func baseQuery(for account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: false,
            kSecUseDataProtectionKeychain as String: true
        ]
    }

    /// Statuts qui signifient « ce Trousseau n'est pas exploitable ici », par opposition à
    /// une vraie erreur : build sans identité de signature stable, session verrouillée,
    /// utilisateur qui refuse.
    private static let unusable: Set<OSStatus> = [
        errSecInteractionNotAllowed, errSecAuthFailed, errSecUserCanceled,
        errSecMissingEntitlement, errSecNotAvailable
    ]

    public func data(for account: String) throws -> Data? {
        var query = baseQuery(for: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        // Aucune invite : le démarrage ne doit pas pouvoir se bloquer sur une fenêtre système.
        query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUISkip

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        case let status where Self.unusable.contains(status):
            throw SecretStoreError.inaccessible
        default:
            throw SecretStoreError.keychain(status)
        }
    }

    public func set(_ data: Data, for account: String) throws {
        let query = baseQuery(for: account)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        switch status {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var insert = query
            insert.merge(attributes) { current, _ in current }
            let addStatus = SecItemAdd(insert as CFDictionary, nil)
            switch addStatus {
            case errSecSuccess: return
            case let status where Self.unusable.contains(status):
                throw SecretStoreError.inaccessible
            default: throw SecretStoreError.keychain(addStatus)
            }
        case let status where Self.unusable.contains(status):
            throw SecretStoreError.inaccessible
        default:
            throw SecretStoreError.keychain(status)
        }
    }

    public func remove(_ account: String) throws {
        let status = SecItemDelete(baseQuery(for: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecretStoreError.keychain(status)
        }
    }
}

/// Coffre de secours : un fichier `0600` dans le dossier de données, lui-même en `0700`.
///
/// Sert quand le Trousseau moderne n'est pas exploitable — build ad hoc sans identité de
/// signature stable, typiquement pendant le développement. La protection est alors celle du
/// compte utilisateur et non celle du Trousseau : repli assumé, jamais le chemin nominal.
public struct FileSecretStore: SecretStore {
    private let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    private func url(for account: String) -> URL {
        directory.appendingPathComponent("\(account).key")
    }

    public func data(for account: String) throws -> Data? {
        try? Data(contentsOf: url(for: account))
    }

    public func set(_ data: Data, for account: String) throws {
        let url = url(for: account)
        do {
            try data.write(to: url, options: [.atomic])
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600], ofItemAtPath: url.path
            )
        } catch {
            throw SecretStoreError.file(String(describing: error))
        }
    }

    public func remove(_ account: String) throws {
        try? FileManager.default.removeItem(at: url(for: account))
    }
}

/// Trousseau d'abord, fichier en secours.
///
/// L'ordre compte : une installation signée range sa clé dans le Trousseau, une copie de
/// développement se rabat sur le fichier, et aucune des deux ne montre jamais de fenêtre.
public struct FallbackSecretStore: SecretStore {
    private let primary: any SecretStore
    private let fallback: any SecretStore

    public init(primary: any SecretStore, fallback: any SecretStore) {
        self.primary = primary
        self.fallback = fallback
    }

    public func data(for account: String) throws -> Data? {
        do {
            if let data = try primary.data(for: account) { return data }
        } catch SecretStoreError.inaccessible {
            return try fallback.data(for: account)
        }
        // Absent du Trousseau : la clé vient peut-être d'une session où il n'était pas
        // exploitable.
        return try fallback.data(for: account)
    }

    public func set(_ data: Data, for account: String) throws {
        do {
            try primary.set(data, for: account)
        } catch SecretStoreError.inaccessible {
            try fallback.set(data, for: account)
        }
    }

    public func remove(_ account: String) throws {
        try? primary.remove(account)
        try fallback.remove(account)
    }
}

/// Coffre en mémoire, pour les tests. Ne persiste rien.
public final class InMemorySecretStore: SecretStore, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Data] = [:]

    public init() {}

    public func data(for account: String) throws -> Data? {
        lock.withLock { storage[account] }
    }

    public func set(_ data: Data, for account: String) throws {
        lock.withLock { storage[account] = data }
    }

    public func remove(_ account: String) throws {
        _ = lock.withLock { storage.removeValue(forKey: account) }
    }
}
