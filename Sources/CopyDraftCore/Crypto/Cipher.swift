import CryptoKit
import Foundation

/// Erreurs de chiffrement.
public enum CipherError: Error, Equatable {
    /// Données illisibles : clé changée, fichier tronqué ou altéré.
    case undecipherable
}

/// Chiffrement des contenus de l'historique.
///
/// AES-GCM 256 bits : confidentialité **et** authentification — une base modifiée à la main
/// est rejetée plutôt que lue de travers. Chaque scellé porte son propre nonce aléatoire,
/// donc deux chiffrements du même contenu ne se ressemblent pas (ADR-2).
public struct Cipher: Sendable {
    private let key: SymmetricKey

    public init(key: SymmetricKey) {
        self.key = key
    }

    /// Chiffre et authentifie, nonce compris, en une seule représentation.
    public func seal(_ plaintext: Data) throws -> Data {
        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealed.combined else { throw CipherError.undecipherable }
        return combined
    }

    /// Déchiffre et vérifie l'authenticité.
    public func open(_ ciphertext: Data) throws -> Data {
        do {
            let box = try AES.GCM.SealedBox(combined: ciphertext)
            return try AES.GCM.open(box, using: key)
        } catch {
            throw CipherError.undecipherable
        }
    }

    /// Empreinte stable d'un contenu, utilisée pour la déduplication (FR-6).
    ///
    /// HMAC-SHA256 avec la clé de l'application : deux contenus identiques donnent la même
    /// empreinte, mais l'empreinte ne dit rien du contenu à qui ne détient pas la clé.
    public func contentHash(_ data: Data) -> Data {
        Data(HMAC<SHA256>.authenticationCode(for: data, using: key))
    }
}
