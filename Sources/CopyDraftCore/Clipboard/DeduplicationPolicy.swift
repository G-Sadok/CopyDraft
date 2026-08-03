import Foundation

/// Une entrée d'historique, réduite à ce dont la déduplication a besoin.
///
/// Volontairement pauvre : la politique n'a pas à connaître le contenu, le type ni la source
/// d'un élément. Elle raisonne sur une empreinte, une date et un état d'épinglage — de quoi
/// rester testable sans base ni presse-papiers.
public struct DeduplicationCandidate: Sendable, Equatable {
    public let id: UUID
    /// Empreinte HMAC-SHA256 du contenu (`Cipher.contentHash`).
    public let contentHash: Data
    /// Date qui situe l'élément dans l'historique. Un élément remonté par `.promote` porte une
    /// date rafraîchie : c'est bien cette date-là qui dit qui est « le plus récent ».
    public let createdAt: Date
    public let pinned: Bool

    public init(id: UUID, contentHash: Data, createdAt: Date, pinned: Bool) {
        self.id = id
        self.contentHash = contentHash
        self.createdAt = createdAt
        self.pinned = pinned
    }
}

/// Verdict rendu sur une capture, à appliquer par le magasin d'historique (E2).
public enum DeduplicationOutcome: Sendable, Equatable {
    /// Rien d'identique en tête : insérer une nouvelle entrée. `removing` porte l'ancienne
    /// occurrence du même contenu, à supprimer dans la même opération, pour ne jamais laisser
    /// deux fois le même contenu dans la liste.
    case insert(removing: UUID?)
    /// Identique à l'élément le plus récent : ne rien créer, remonter l'existant et rafraîchir
    /// son horodatage.
    case promote(UUID)
}

/// Décide du sort d'une capture face à l'historique existant (FR-6).
///
/// Composant **pur** : il ne touche ni à la base, ni au disque, ni au presse-papiers. Il rend
/// un verdict que le magasin appliquera. Sans état et `Sendable`, il s'utilise depuis
/// n'importe quel acteur sans précaution.
public struct DeduplicationPolicy: Sendable {
    public init() {}

    /// Rend le verdict pour une capture d'empreinte `contentHash`.
    ///
    /// Aucune hypothèse n'est faite sur le tri de `history` : « le plus récent » se lit sur
    /// `createdAt`, jamais sur la position dans le tableau. Le coût est linéaire en nombre
    /// d'éléments, ce qui reste négligeable devant la limite d'historique (500).
    ///
    /// Règles :
    /// - historique vide ou aucune correspondance → `.insert(removing: nil)` ;
    /// - correspondance avec le plus récent → `.promote` : une recopie immédiate ne doit pas
    ///   empiler des doublons ;
    /// - correspondance avec un élément plus ancien → `.insert(removing:)` : l'entrée revient
    ///   en tête et l'ancienne occurrence disparaît ;
    /// - correspondance avec un élément **épinglé** → toujours `.promote`, voir plus bas.
    public func evaluate(
        contentHash: Data,
        against history: [DeduplicationCandidate]
    ) -> DeduplicationOutcome {
        let matches = history.filter { Self.hashesMatch($0.contentHash, contentHash) }

        // Rien d'identique : simple insertion en tête.
        guard let newestMatch = matches.max(by: { $0.createdAt < $1.createdAt }) else {
            return .insert(removing: nil)
        }

        // Une recopie de ce qui est déjà en tête : on remonte l'existant, l'appelant rafraîchira
        // son horodatage. L'égalité de dates suffit : deux éléments au même instant sont tous
        // deux « les plus récents », et promouvoir reste le geste le plus conservateur.
        let newestDate = history.lazy.map(\.createdAt).max()
        if newestMatch.createdAt == newestDate {
            return .promote(newestMatch.id)
        }

        // Un épinglé identique n'est jamais supprimé, même s'il est plus ancien : on le remonte
        // au lieu de le remplacer. Perdre un élément que l'utilisateur a explicitement conservé
        // serait une régression bien plus grave que de laisser un doublon apparent — d'autant
        // que l'épinglé et sa copie portent le même contenu, donc rien n'est perdu à l'écran.
        if let newestPinnedMatch = matches.filter(\.pinned).max(by: { $0.createdAt < $1.createdAt }) {
            return .promote(newestPinnedMatch.id)
        }

        // Correspondance plus ancienne et non épinglée : nouvelle entrée en tête, ancienne
        // occurrence supprimée.
        return .insert(removing: newestMatch.id)
    }

    /// Comparaison d'empreintes en temps constant.
    ///
    /// L'empreinte est un HMAC calculé avec la clé de l'application : la comparer octet par
    /// octet avec sortie anticipée révélerait, par le temps de réponse, sur combien d'octets
    /// deux empreintes coïncident. Le surcoût est nul à cette échelle, autant le faire.
    /// La longueur, elle, n'est pas secrète — un HMAC-SHA256 en fait toujours 32.
    private static func hashesMatch(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var difference: UInt8 = 0
        for (left, right) in zip(lhs, rhs) {
            difference |= left ^ right
        }
        return difference == 0
    }
}

extension DeduplicationCandidate {
    /// Construit un candidat à partir d'un élément d'historique et de son empreinte.
    ///
    /// L'empreinte n'est pas portée par `ClipItem` (elle vit en base, à côté du contenu
    /// chiffré) : le magasin la fournit. On retient `updatedAt` et non `createdAt`, car c'est
    /// la date de dernière remontée qui place un élément en tête de liste (FR-6, FR-17) — un
    /// élément promu hier mais créé il y a un mois est bien le plus récent.
    public init(item: ClipItem, contentHash: Data) {
        self.init(
            id: item.id,
            contentHash: contentHash,
            createdAt: item.updatedAt,
            pinned: item.pinned
        )
    }
}
