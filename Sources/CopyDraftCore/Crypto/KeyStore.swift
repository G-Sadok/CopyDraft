import CryptoKit
import Foundation

/// Clé de chiffrement de l'historique : créée au premier lancement, conservée dans le
/// Trousseau, jamais écrite sur disque.
///
/// Perdre la clé rend l'historique illisible. Ce cas — Trousseau réinitialisé, restauration
/// partielle — est traité comme une réinitialisation propre, jamais comme une erreur fatale :
/// `loadOrCreate()` reforge une clé et l'appelant repart d'un historique vide.
public struct KeyStore: Sendable {
    /// Compte sous lequel la clé est rangée dans le Trousseau.
    public static let account = "history-encryption-key"
    /// 256 bits.
    public static let keyByteCount = 32

    private let store: SecretStore

    public init(store: SecretStore = KeychainSecretStore()) {
        self.store = store
    }

    /// Clé existante, ou clé fraîche créée et rangée à la volée.
    ///
    /// Une clé présente mais illisible — signature de l'application changée, Trousseau
    /// verrouillé autrement — est remplacée plutôt que de bloquer le démarrage : l'historique
    /// qu'elle protégeait est de toute façon indéchiffrable.
    public func loadOrCreate() throws -> SymmetricKey {
        do {
            if let existing = try store.data(for: Self.account),
                existing.count == Self.keyByteCount
            {
                return SymmetricKey(data: existing)
            }
        } catch SecretStoreError.inaccessible {
            try? store.remove(Self.account)
        }

        let key = SymmetricKey(size: .bits256)
        let material = key.withUnsafeBytes { Data($0) }
        try store.set(material, for: Self.account)
        return key
    }

    /// Vrai si une clé exploitable est déjà en place.
    public func hasKey() throws -> Bool {
        do {
            return try store.data(for: Self.account)?.count == Self.keyByteCount
        } catch SecretStoreError.inaccessible {
            return false
        }
    }

    /// Supprime la clé. L'historique déjà chiffré devient définitivement illisible :
    /// réservé à la réinitialisation complète.
    public func destroy() throws {
        try store.remove(Self.account)
    }
}
