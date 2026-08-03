import Foundation
import Testing

@testable import CopyDraftCore

// MARK: - Doublures

private final class SpyPasteboardWriter: PasteboardWriting, @unchecked Sendable {
    private let lock = NSLock()
    private var _writes: [(content: StoredContent, plainTextOnly: Bool)] = []

    var writes: [(content: StoredContent, plainTextOnly: Bool)] {
        lock.withLock { _writes }
    }

    func write(_ content: StoredContent, plainTextOnly: Bool) {
        lock.withLock { _writes.append((content, plainTextOnly)) }
    }
}

private final class SpySynthesizer: KeystrokeSynthesizing, @unchecked Sendable {
    private let lock = NSLock()
    private var _targets: [pid_t] = []
    let succeeds: Bool

    init(succeeds: Bool = true) { self.succeeds = succeeds }

    var targets: [pid_t] { lock.withLock { _targets } }

    func sendCommandV(to processIdentifier: pid_t) -> Bool {
        lock.withLock { _targets.append(processIdentifier) }
        return succeeds
    }
}

private struct StubPermission: AccessibilityPermissionChecking {
    let granted: Bool
    func isGranted() -> Bool { granted }
}

// MARK: - Tests

@MainActor
@Suite("Service de collage")
struct PasteServiceTests {
    private let content = StoredContent(
        text: "let items = try store.fetch()",
        rtfData: Data([0x7B, 0x5C]),
        htmlData: Data("<b>x</b>".utf8)
    )
    private let target = PasteTarget(processIdentifier: 4_242, name: "Xcode")

    private func makeService(
        granted: Bool,
        synthesizer: SpySynthesizer = SpySynthesizer(),
        writer: SpyPasteboardWriter = SpyPasteboardWriter(),
        activated: @escaping @MainActor (pid_t) -> Bool = { _ in true }
    ) -> PasteService {
        PasteService(
            writer: writer,
            synthesizer: synthesizer,
            permission: StubPermission(granted: granted),
            activate: activated
        )
    }

    @Test("Avec l'autorisation, l'élément est collé dans l'application visée")
    func pastesIntoTarget() async {
        let writer = SpyPasteboardWriter()
        let synthesizer = SpySynthesizer()
        let service = makeService(granted: true, synthesizer: synthesizer, writer: writer)

        let outcome = await service.paste(content, into: target)

        #expect(outcome == .pasted(appName: "Xcode"))
        #expect(writer.writes.count == 1)
        #expect(writer.writes.first?.plainTextOnly == false)
        #expect(synthesizer.targets == [4_242])
    }

    @Test("L'application visée est réactivée avant la frappe")
    func reactivatesTargetFirst() async {
        var activated: [pid_t] = []
        let service = makeService(granted: true, activated: { pid in
            activated.append(pid)
            return true
        })

        _ = await service.paste(content, into: target)
        #expect(activated == [4_242])
    }

    @Test("⇧↩︎ ne colle que le texte brut")
    func plainTextOnly() async {
        let writer = SpyPasteboardWriter()
        let service = makeService(granted: true, writer: writer)

        let outcome = await service.paste(content, into: target, plainTextOnly: true)

        #expect(outcome == .pastedPlainText(appName: "Xcode"))
        #expect(writer.writes.first?.plainTextOnly == true)
    }

    /// Repli FR-34 : sans autorisation, on copie et on le dit, jamais d'erreur bloquante.
    @Test("Sans autorisation, l'élément est copié et l'utilisateur colle lui-même")
    func fallsBackWithoutPermission() async {
        let writer = SpyPasteboardWriter()
        let synthesizer = SpySynthesizer()
        let service = makeService(granted: false, synthesizer: synthesizer, writer: writer)

        let outcome = await service.paste(content, into: target)

        #expect(outcome == .copiedOnly)
        #expect(writer.writes.count == 1, "le contenu est bien dans le presse-papiers")
        #expect(synthesizer.targets.isEmpty, "aucune frappe n'est synthétisée")
    }

    @Test("Sans application mémorisée, on se replie aussi sur la copie")
    func fallsBackWithoutTarget() async {
        let synthesizer = SpySynthesizer()
        let service = makeService(granted: true, synthesizer: synthesizer)

        #expect(await service.paste(content, into: nil) == .copiedOnly)
        #expect(synthesizer.targets.isEmpty)
    }

    @Test("Une frappe qui échoue se solde par un repli, pas par une erreur")
    func synthesisFailureFallsBack() async {
        let service = makeService(granted: true, synthesizer: SpySynthesizer(succeeds: false))
        #expect(await service.paste(content, into: target) == .copiedOnly)
    }

    @Test("« Copier » écrit dans le presse-papiers sans rien coller")
    func copyOnly() {
        let writer = SpyPasteboardWriter()
        let synthesizer = SpySynthesizer()
        let service = makeService(granted: true, synthesizer: synthesizer, writer: writer)

        service.copy(content)

        #expect(writer.writes.count == 1)
        #expect(synthesizer.targets.isEmpty)
    }
}

@MainActor
@Suite("Suivi de l'application à coller")
struct FrontmostAppTrackerTests {
    @Test("Aucune cible tant que rien n'a été mémorisé")
    func startsEmpty() {
        #expect(FrontmostAppTracker().target == nil)
    }

    @Test("La cible s'oublie sur demande")
    func clears() {
        let tracker = FrontmostAppTracker()
        tracker.capture()
        tracker.clear()
        #expect(tracker.target == nil)
    }
}

@MainActor
@Suite("Autorisation d'accessibilité")
struct AccessibilityPermissionTests {
    private final class MutablePermission: AccessibilityPermissionChecking, @unchecked Sendable {
        private let lock = NSLock()
        private var _granted: Bool

        init(granted: Bool) { _granted = granted }

        var granted: Bool {
            get { lock.withLock { _granted } }
            set { lock.withLock { _granted = newValue } }
        }

        func isGranted() -> Bool { granted }
    }

    @Test("L'état initial reflète l'autorisation réelle")
    func initialState() {
        #expect(AccessibilityPermissionMonitor(checker: MutablePermission(granted: true)).isGranted)
        #expect(
            AccessibilityPermissionMonitor(checker: MutablePermission(granted: false)).isGranted
                == false
        )
    }

    @Test("Un octroi est détecté et signalé une seule fois")
    func detectsGrant() {
        let checker = MutablePermission(granted: false)
        let monitor = AccessibilityPermissionMonitor(checker: checker)
        var changes: [Bool] = []
        monitor.onChange = { changes.append($0) }

        monitor.refresh()
        #expect(changes.isEmpty, "rien n'a changé")

        checker.granted = true
        monitor.refresh()
        monitor.refresh()

        #expect(changes == [true], "un seul signalement pour un seul changement")
        #expect(monitor.isGranted)
    }

    /// La révocation doit ramener l'application en mode replié sans redémarrage (S-4.1).
    @Test("Une révocation est détectée")
    func detectsRevocation() {
        let checker = MutablePermission(granted: true)
        let monitor = AccessibilityPermissionMonitor(checker: checker)
        var changes: [Bool] = []
        monitor.onChange = { changes.append($0) }

        checker.granted = false
        monitor.refresh()

        #expect(changes == [false])
        #expect(monitor.isGranted == false)
    }
}
