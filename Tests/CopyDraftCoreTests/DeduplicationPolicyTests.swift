import Foundation
import Testing

@testable import CopyDraftCore

@Suite("Déduplication")
struct DeduplicationPolicyTests {
    private let policy = DeduplicationPolicy()
    /// Instant de référence : les dates sont exprimées en secondes relatives, plus lisibles.
    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    /// Empreinte factice de 32 octets, comme un HMAC-SHA256.
    private func hash(_ label: String) -> Data {
        var data = Data(label.utf8)
        data.append(Data(repeating: 0, count: max(0, 32 - data.count)))
        return data.prefix(32)
    }

    private func candidate(
        _ label: String,
        at seconds: TimeInterval,
        pinned: Bool = false,
        id: UUID = UUID()
    ) -> DeduplicationCandidate {
        DeduplicationCandidate(
            id: id,
            contentHash: hash(label),
            createdAt: epoch.addingTimeInterval(seconds),
            pinned: pinned
        )
    }

    // MARK: Cas de base

    @Test("Un historique vide accepte la capture sans rien supprimer")
    func emptyHistory() {
        #expect(policy.evaluate(contentHash: hash("A"), against: []) == .insert(removing: nil))
    }

    @Test("Aucune correspondance : simple insertion")
    func noMatch() {
        let history = [candidate("A", at: 10), candidate("B", at: 20)]
        #expect(policy.evaluate(contentHash: hash("C"), against: history) == .insert(removing: nil))
    }

    @Test("Un doublon du plus récent remonte l'existant")
    func duplicateOfNewest() {
        let newest = candidate("B", at: 20)
        let history = [candidate("A", at: 10), newest]

        #expect(policy.evaluate(contentHash: hash("B"), against: history) == .promote(newest.id))
    }

    @Test("Un doublon d'un élément plus ancien crée une entrée et supprime l'ancienne")
    func duplicateOfOlder() {
        let older = candidate("A", at: 10)
        let history = [older, candidate("B", at: 20)]

        #expect(
            policy.evaluate(contentHash: hash("A"), against: history) == .insert(removing: older.id)
        )
    }

    // MARK: Séquence des critères d'acceptation — A, A, B, A

    /// Le scénario exigé par S-1.5, joué pas à pas en appliquant chaque verdict à la main.
    @Test("La séquence A, A, B, A rend le bon verdict à chaque étape")
    func acceptanceSequence() {
        var history: [DeduplicationCandidate] = []

        // 1. Copie A sur historique vide : insertion sèche.
        #expect(policy.evaluate(contentHash: hash("A"), against: history) == .insert(removing: nil))
        let firstA = candidate("A", at: 10)
        history.append(firstA)

        // 2. Copie A à nouveau : A est le plus récent, on le remonte sans rien créer.
        #expect(policy.evaluate(contentHash: hash("A"), against: history) == .promote(firstA.id))
        history = [candidate("A", at: 20, id: firstA.id)]  // horodatage rafraîchi par l'appelant

        // 3. Copie B : rien d'identique, insertion en tête.
        #expect(policy.evaluate(contentHash: hash("B"), against: history) == .insert(removing: nil))
        let b = candidate("B", at: 30)
        history.append(b)

        // 4. Copie A : A existe mais n'est plus le plus récent — nouvelle entrée, ancienne retirée.
        #expect(
            policy.evaluate(contentHash: hash("A"), against: history) == .insert(removing: firstA.id)
        )
        history = [b, candidate("A", at: 40)]

        // L'historique final ne contient bien qu'une occurrence de A.
        #expect(history.filter { $0.contentHash == hash("A") }.count == 1)
    }

    // MARK: Épinglés

    @Test("Un épinglé identique et le plus récent est remonté")
    func pinnedNewestIsPromoted() {
        let pinned = candidate("A", at: 20, pinned: true)
        let history = [candidate("B", at: 10), pinned]

        #expect(policy.evaluate(contentHash: hash("A"), against: history) == .promote(pinned.id))
    }

    /// Le cas qui justifie l'exception : un épinglé plus ancien serait supprimé par la règle
    /// générale. On le remonte à la place — un épinglé perdu ne se récupère pas.
    @Test("Un épinglé identique mais plus ancien est remonté, jamais supprimé")
    func pinnedOlderIsPromotedNotRemoved() {
        let pinned = candidate("A", at: 10, pinned: true)
        let history = [pinned, candidate("B", at: 20)]

        let outcome = policy.evaluate(contentHash: hash("A"), against: history)
        #expect(outcome == .promote(pinned.id))
        #expect(outcome != .insert(removing: pinned.id))
    }

    @Test("Une correspondance non épinglée reste supprimable malgré un épinglé voisin")
    func pinnedNeighbourDoesNotProtectOthers() {
        let older = candidate("A", at: 10)
        let history = [older, candidate("C", at: 15, pinned: true), candidate("B", at: 20)]

        #expect(
            policy.evaluate(contentHash: hash("A"), against: history) == .insert(removing: older.id)
        )
    }

    // MARK: Robustesse de l'entrée

    @Test("L'ordre du tableau d'historique ne change pas le verdict")
    func orderDoesNotMatter() {
        let older = candidate("A", at: 10)
        let newest = candidate("B", at: 30)
        let middle = candidate("C", at: 20)

        for history in [
            [older, middle, newest],
            [newest, middle, older],
            [middle, newest, older],
            [newest, older, middle],
        ] {
            #expect(policy.evaluate(contentHash: hash("B"), against: history) == .promote(newest.id))
            #expect(
                policy.evaluate(contentHash: hash("A"), against: history)
                    == .insert(removing: older.id)
            )
        }
    }

    @Test("Des empreintes de longueurs différentes ne se confondent pas")
    func lengthMismatchIsNotAMatch() {
        let short = DeduplicationCandidate(
            id: UUID(), contentHash: Data([0x01, 0x02]), createdAt: epoch, pinned: false
        )
        let long = DeduplicationCandidate(
            id: UUID(), contentHash: Data([0x01, 0x02, 0x03]), createdAt: epoch, pinned: false
        )

        #expect(
            policy.evaluate(contentHash: Data([0x01, 0x02, 0x03]), against: [short])
                == .insert(removing: nil)
        )
        #expect(
            policy.evaluate(contentHash: Data([0x01, 0x02]), against: [long, short])
                == .promote(short.id)
        )
        #expect(policy.evaluate(contentHash: Data([0x01, 0x02]), against: [short]) == .promote(short.id))
    }

    @Test("Une empreinte vide ne correspond qu'à une empreinte vide")
    func emptyHash() {
        let empty = DeduplicationCandidate(
            id: UUID(), contentHash: Data(), createdAt: epoch, pinned: false
        )

        #expect(policy.evaluate(contentHash: Data(), against: [candidate("A", at: 10)]) == .insert(removing: nil))
        #expect(policy.evaluate(contentHash: Data(), against: [empty]) == .promote(empty.id))
        #expect(policy.evaluate(contentHash: hash("A"), against: [empty]) == .insert(removing: nil))
    }

    @Test("Deux éléments au même instant : le doublon remonte plutôt que d'écraser")
    func tiedTimestampsPromote() {
        let first = candidate("A", at: 10)
        let second = candidate("B", at: 10)

        #expect(policy.evaluate(contentHash: hash("A"), against: [first, second]) == .promote(first.id))
    }

    // MARK: Passage à l'échelle

    /// Limite haute de l'historique (FR-13) : le verdict doit rester exact, sans dégradation
    /// perceptible — le parcours est linéaire.
    @Test("Un historique de 500 éléments reste correctement arbitré")
    func largeHistory() {
        var history = (0..<500).map { candidate("item-\($0)", at: TimeInterval($0)) }
        let oldest = history[0]
        let newest = history[499]

        #expect(policy.evaluate(contentHash: hash("absent"), against: history) == .insert(removing: nil))
        #expect(policy.evaluate(contentHash: hash("item-499"), against: history) == .promote(newest.id))
        #expect(
            policy.evaluate(contentHash: hash("item-0"), against: history)
                == .insert(removing: oldest.id)
        )

        // Même verdict sur un historique mélangé.
        history.shuffle()
        #expect(policy.evaluate(contentHash: hash("item-499"), against: history) == .promote(newest.id))
        #expect(
            policy.evaluate(contentHash: hash("item-0"), against: history)
                == .insert(removing: oldest.id)
        )
    }

    // MARK: Passerelle avec le modèle

    @Test("Un candidat construit depuis un ClipItem retient sa date de remontée")
    func candidateFromClipItem() {
        let item = ClipItem(
            kind: .text,
            subtype: .plain,
            createdAt: epoch,
            updatedAt: epoch.addingTimeInterval(3_600),
            pinned: true,
            source: .unknown,
            byteCount: 12,
            characterCount: 12,
            searchText: "presse-papiers",
            previewLines: ["presse-papiers"]
        )
        let fingerprint = hash("A")

        let candidate = DeduplicationCandidate(item: item, contentHash: fingerprint)

        #expect(candidate.id == item.id)
        #expect(candidate.contentHash == fingerprint)
        #expect(candidate.createdAt == item.updatedAt)
        #expect(candidate.pinned)
    }
}
