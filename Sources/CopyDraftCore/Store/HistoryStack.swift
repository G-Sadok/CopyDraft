import Foundation
import GRDB

/// Montage complet de la couche de persistance : dossiers, clé, base, images, magasin.
///
/// Existe pour que l'application n'ait à connaître ni GRDB ni CryptoKit : elle demande une
/// pile prête à l'emploi, et reçoit une erreur explicite si quoi que ce soit manque.
@MainActor
public struct HistoryStack {
    public let paths: AppPaths
    public let cipher: Cipher
    public let repository: HistoryRepository
    public let imageStore: ImageStore
    public let store: HistoryStore

    /// Ce qui peut manquer au démarrage. Chaque cas se lit tel quel dans la Console.
    public enum Failure: Error, CustomStringConvertible {
        case directories(any Error)
        case encryptionKey(any Error)
        case database(any Error)

        public var description: String {
            switch self {
            case .directories(let error):
                "dossier de données inaccessible : \(error)"
            case .encryptionKey(let error):
                "clé de chiffrement indisponible (Trousseau) : \(error)"
            case .database(let error):
                "base d'historique illisible : \(error)"
            }
        }
    }

    public static func make(preferences: Preferences) throws -> HistoryStack {
        let paths: AppPaths
        do {
            paths = try AppPaths.standard().createDirectories()
        } catch {
            throw Failure.directories(error)
        }

        let cipher: Cipher
        do {
            // Trousseau moderne d'abord, fichier 0600 dans le dossier 0700 en secours :
            // aucun des deux chemins ne peut ouvrir de fenêtre au démarrage (ADR-11).
            let secrets = FallbackSecretStore(
                primary: KeychainSecretStore(),
                fallback: FileSecretStore(directory: paths.root)
            )
            cipher = Cipher(key: try KeyStore(store: secrets).loadOrCreate())
        } catch {
            throw Failure.encryptionKey(error)
        }

        let queue: DatabaseQueue
        do {
            queue = try HistoryDatabase.open(at: paths.databaseURL)
        } catch {
            throw Failure.database(error)
        }

        let repository = HistoryRepository(queue: queue, cipher: cipher)
        let imageStore = ImageStore(paths: paths, cipher: cipher)

        return HistoryStack(
            paths: paths,
            cipher: cipher,
            repository: repository,
            imageStore: imageStore,
            store: HistoryStore(
                repository: repository, imageStore: imageStore, preferences: preferences
            )
        )
    }
}
