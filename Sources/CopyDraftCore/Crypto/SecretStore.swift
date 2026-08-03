import Foundation
import Security

/// Coffre de secrets. Abstrait le Trousseau pour que la logique de clé soit testable sans
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
    /// Le secret existe mais n'est pas lisible sans intervention de l'utilisateur.
    ///
    /// Se produit quand la signature de l'application a changé depuis la création du secret :
    /// macOS demanderait alors l'autorisation par un dialogue modal. Pour un agent lancé à
    /// l'ouverture de session, ce dialogue est inacceptable — on préfère repartir d'une clé
    /// neuve, quitte à perdre un historique de toute façon illisible.
    case inaccessible
}

/// Implémentation adossée au Trousseau du système.
///
/// Accessibilité `AfterFirstUnlockThisDeviceOnly` : la clé est lisible dès le premier
/// déverrouillage après démarrage — CopyDraft étant un agent lancé à la connexion — mais ne
/// quitte jamais ce Mac et n'est jamais synchronisée sur iCloud (ENF-5, NFR-6).
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
            kSecAttrSynchronizable as String: false
        ]
    }

    public func data(for account: String) throws -> Data? {
        var query = baseQuery(for: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        // Jamais de dialogue : le démarrage ne doit pas pouvoir se bloquer sur une invite
        // système, fenêtre que l'utilisateur ne verrait même pas venir.
        query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUISkip

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        case errSecInteractionNotAllowed, errSecAuthFailed, errSecUserCanceled:
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
            guard addStatus == errSecSuccess else {
                throw SecretStoreError.keychain(addStatus)
            }
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
