import CryptoKit
import Foundation
import Testing

@testable import CopyDraftCore

/// Garde-fous de performance (NFR-1 à NFR-3, FR-36).
///
/// Ces tests ne remplacent pas les mesures de `docs/perf-report.md` — ils empêchent une
/// régression franche de passer inaperçue.
///
/// **Les assertions de durée ne s'exécutent pas en intégration continue.** Un runner partagé
/// est lent et irrégulier : un build a déjà échoué sur du code strictement identique à celui
/// qui passait juste avant. Une CI qui échoue au hasard est une CI qu'on cesse de croire, et
/// qui finit par bloquer des publications sans raison. Les assertions de *comportement*, elles,
/// tournent partout.
@Suite("Performance")
struct PerformanceTests {
    /// Vrai sur un runner d'intégration continue (`CI` est posée par GitHub Actions).
    static var isContinuousIntegration: Bool {
        ProcessInfo.processInfo.environment["CI"] != nil
    }

    private func makeItems(_ count: Int) -> [ClipItem] {
        (0..<count).map { index in
            let text =
                "élément \(index) — contenu de test avec assez de matière pour ressembler "
                + "à ce qu'on copie vraiment, y compris des mots comme swift, safari ou git"
            return ClipItem(
                kind: .text,
                subtype: .plain,
                createdAt: Date(timeIntervalSince1970: TimeInterval(index)),
                source: SourceApp(
                    bundleIdentifier: "com.test.app\(index % 7)", name: "App\(index % 7)"
                ),
                byteCount: text.utf8.count,
                characterCount: text.count,
                searchText: text,
                previewLines: [text]
            )
        }
    }

    /// « Filtrage à chaque frappe, sans debounce perceptible (< 16 ms sur 500 éléments) »,
    /// design system §2.3.
    @Test(
        "Le filtrage de 500 éléments tient sous une image d'écran",
        .enabled(if: !PerformanceTests.isContinuousIntegration)
    )
    @MainActor
    func filteringIsInstant() {
        let items = makeItems(500)
        let requests = ["s", "sw", "swi", "swift", "introuvable"]

        let clock = ContinuousClock()
        let elapsed = clock.measure {
            for request in requests {
                _ = HistoryStore.filter(items, query: request)
            }
        }

        let perRequest = elapsed / requests.count
        // Seuil large : la cible est 16 ms, on échoue à 50 ms pour ne pas rendre la suite
        // dépendante de la charge de la machine.
        #expect(
            perRequest < .milliseconds(50),
            "filtrage à \(perRequest) par requête, cible 16 ms"
        )
    }

    @Test(
        "La déduplication reste rapide sur un historique plein",
        .enabled(if: !PerformanceTests.isContinuousIntegration)
    )
    func deduplicationScales() {
        let policy = DeduplicationPolicy()
        var history: [DeduplicationCandidate] = []
        for index in 0..<500 {
            let hash: Data = Data([UInt8(index % 256)]) + Data(repeating: 0, count: 31)
            let date = Date(timeIntervalSince1970: TimeInterval(index))
            history.append(
                DeduplicationCandidate(
                    id: UUID(), contentHash: hash, createdAt: date, pinned: index % 50 == 0
                )
            )
        }

        let clock = ContinuousClock()
        let elapsed = clock.measure {
            for index in 0..<100 {
                let probe: Data = Data([UInt8(index)]) + Data(repeating: 0, count: 31)
                _ = policy.evaluate(contentHash: probe, against: history)
            }
        }

        // 100 évaluations contre 500 candidats, soit 50 000 comparaisons en temps constant :
        // quelques centaines de millisecondes en debug, largement sous le seuil perceptible
        // à l'échelle d'une capture (une toutes les 0,4 s au plus).
        #expect(elapsed < .milliseconds(600), "déduplication à \(elapsed) pour 100 évaluations")
    }

    /// Le chiffrement est sur le chemin de chaque capture : il ne doit pas se voir.
    @Test(
        "Chiffrer un contenu de taille courante coûte moins d'une milliseconde",
        .enabled(if: !PerformanceTests.isContinuousIntegration)
    )
    func encryptionIsCheap() throws {
        let cipher = Cipher(key: SymmetricKey(size: .bits256))
        let payload = Data(String(repeating: "contenu copié ", count: 200).utf8)

        let clock = ContinuousClock()
        let elapsed = try clock.measure {
            for _ in 0..<100 {
                _ = try cipher.open(cipher.seal(payload))
            }
        }

        #expect(elapsed < .milliseconds(500), "100 aller-retours en \(elapsed)")
    }

    /// Un tick de sondage sans changement doit être quasi gratuit : c'est lui qui tourne
    /// deux fois et demie par seconde toute la journée (NFR-1).
    @Test("Un tick sans changement ne coûte rien")
    @MainActor
    func idlePollIsFree() {
        let pasteboard = FakePasteboard()
        let suite = "com.copydraft.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let monitor = ClipboardMonitor(
            pasteboard: pasteboard, preferences: Preferences(defaults: defaults)
        )
        pasteboard.writeText("état stable")
        monitor.poll()
        pasteboard.resetContentAccessCount()

        let clock = ContinuousClock()
        let elapsed = clock.measure {
            for _ in 0..<10_000 { monitor.poll() }
        }

        // Le comportement se vérifie partout : c'est lui qui porte NFR-1.
        #expect(pasteboard.contentAccessCount == 0, "aucune lecture de contenu à l'état stable")
        if !Self.isContinuousIntegration {
            #expect(elapsed < .milliseconds(200), "10 000 ticks en \(elapsed)")
        }
    }
}
