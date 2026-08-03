import CryptoKit
import Foundation
import Testing

@testable import CopyDraftCore

@MainActor
@Suite("Chaîne de capture complète")
struct CaptureCoordinatorTests {
    private struct StubFrontmostApp: FrontmostAppProviding {
        let app: SourceApp
        func currentApp() -> SourceApp { app }
    }

    private struct Harness {
        let coordinator: CaptureCoordinator
        let monitor: ClipboardMonitor
        let pasteboard: FakePasteboard
        let store: HistoryStore
        let preferences: Preferences
        let root: URL
    }

    private func makeHarness(
        app: SourceApp = SourceApp(bundleIdentifier: "com.apple.dt.Xcode", name: "Xcode")
    ) throws -> Harness {
        let cipher = Cipher(key: SymmetricKey(size: .bits256))
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("copydraft-capture-\(UUID().uuidString)", isDirectory: true)

        let suite = "com.copydraft.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let preferences = Preferences(defaults: defaults)

        let store = HistoryStore(
            repository: HistoryRepository(
                queue: try HistoryDatabase.openInMemory(), cipher: cipher
            ),
            imageStore: ImageStore(paths: AppPaths(root: root), cipher: cipher),
            preferences: preferences
        )

        let pasteboard = FakePasteboard()
        let monitor = ClipboardMonitor(
            pasteboard: pasteboard,
            preferences: preferences,
            frontmostApp: StubFrontmostApp(app: app)
        )

        let coordinator = CaptureCoordinator(
            monitor: monitor,
            store: store,
            preferences: preferences,
            cipher: cipher,
            now: { Date(timeIntervalSince1970: 1_000) }
        )
        coordinator.start()

        return Harness(
            coordinator: coordinator, monitor: monitor, pasteboard: pasteboard,
            store: store, preferences: preferences, root: root
        )
    }

    /// Laisse la tâche d'enregistrement se terminer : `onCapture` délègue à un `Task`.
    private func settle() async {
        for _ in 0..<10 { await Task.yield() }
        try? await Task.sleep(for: .milliseconds(20))
    }

    // MARK: Cas nominal

    @Test("Un texte copié devient un élément d'historique complet")
    func capturesText() async throws {
        let harness = try makeHarness()
        defer { try? FileManager.default.removeItem(at: harness.root) }

        harness.pasteboard.writeText(
            """
            func startMonitoring() {
                timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true)
            }
            """
        )
        harness.monitor.poll()
        await settle()

        let item = try #require(harness.store.items.first)
        #expect(item.kind == .text)
        #expect(item.subtype == .code, "le classificateur a reconnu du code")
        #expect(item.source.name == "Xcode")
        #expect(item.searchText.contains("scheduledTimer"))
        #expect(item.createdAt == Date(timeIntervalSince1970: 1_000))
    }

    @Test("Deux copies identiques ne créent qu'un élément")
    func deduplicates() async throws {
        let harness = try makeHarness()
        defer { try? FileManager.default.removeItem(at: harness.root) }

        for _ in 0..<2 {
            harness.pasteboard.writeText("même contenu")
            harness.monitor.poll()
            await settle()
        }

        #expect(harness.store.items.count == 1)
    }

    // MARK: Confidentialité

    /// Non-régression FR-9 : rien de ce qui est marqué confidentiel ne doit être enregistré,
    /// **ni même lu**.
    @Test("Un contenu marqué confidentiel n'est ni lu ni enregistré")
    func concealedIsNeverCaptured() async throws {
        let harness = try makeHarness(
            app: SourceApp(bundleIdentifier: "com.agilebits.onepassword", name: "1Password")
        )
        defer { try? FileManager.default.removeItem(at: harness.root) }

        harness.pasteboard.write([
            "org.nspasteboard.ConcealedType": Data(),
            PasteboardUTI.utf8PlainText: Data("mot-de-passe-secret".utf8)
        ])
        harness.pasteboard.resetContentAccessCount()

        harness.monitor.poll()
        await settle()

        #expect(harness.store.items.isEmpty)
        // Un seul accès : la liste des types, que le filtre doit forcément consulter.
        // Aucune donnée n'a été lue derrière — c'est tout l'intérêt de filtrer en amont.
        #expect(harness.pasteboard.contentAccessCount == 1, "seul l'inventaire des types a été lu")
        #expect(harness.coordinator.lastRejection == .rejectedConcealed)
    }

    @Test("Une application exclue n'alimente jamais l'historique")
    func excludedAppIsIgnored() async throws {
        let harness = try makeHarness(
            app: SourceApp(bundleIdentifier: "com.apple.keychainaccess", name: "Trousseau")
        )
        defer { try? FileManager.default.removeItem(at: harness.root) }

        harness.preferences.excludedBundleIdentifiers = ["com.apple.keychainaccess"]
        harness.pasteboard.writeText("données bancaires")
        harness.monitor.poll()
        await settle()

        #expect(harness.store.items.isEmpty)
        #expect(harness.coordinator.lastRejection == .rejectedExcludedApp)
    }

    @Test("En pause, rien n'est enregistré mais l'historique reste consultable")
    func pauseStopsCapture() async throws {
        let harness = try makeHarness()
        defer { try? FileManager.default.removeItem(at: harness.root) }

        harness.pasteboard.writeText("avant la pause")
        harness.monitor.poll()
        await settle()

        harness.preferences.captureEnabled = false
        harness.pasteboard.writeText("pendant la pause")
        harness.monitor.poll()
        await settle()

        #expect(harness.store.items.map(\.searchText) == ["avant la pause"])
        #expect(harness.coordinator.lastRejection == .rejectedPaused)

        harness.preferences.captureEnabled = true
        harness.pasteboard.writeText("après la pause")
        harness.monitor.poll()
        await settle()

        #expect(harness.store.items.count == 2)
    }

    // MARK: Limites

    @Test("Un contenu au-delà de 4 Mo est ignoré silencieusement")
    func oversizedIsIgnored() async throws {
        let harness = try makeHarness()
        defer { try? FileManager.default.removeItem(at: harness.root) }

        harness.pasteboard.writeText(String(repeating: "a", count: Limits.itemBytes + 1))
        harness.monitor.poll()
        await settle()

        #expect(harness.store.items.isEmpty)
        #expect(harness.coordinator.lastRejection == nil, "ce n'est pas un refus de confidentialité")
    }

    @Test("La limite d'historique s'applique au fil des captures")
    func historyLimitApplies() async throws {
        let harness = try makeHarness()
        defer { try? FileManager.default.removeItem(at: harness.root) }

        harness.preferences.historySize = 10
        for index in 0..<13 {
            harness.pasteboard.writeText("élément \(index)")
            harness.monitor.poll()
            await settle()
        }

        #expect(harness.store.items.count == 10)
    }

    @Test("L'arrêt débranche le filtre et l'enregistrement")
    func stopUnhooks() async throws {
        let harness = try makeHarness()
        defer { try? FileManager.default.removeItem(at: harness.root) }

        harness.coordinator.stop()
        harness.pasteboard.writeText("après l'arrêt")
        harness.monitor.poll()
        await settle()

        #expect(harness.store.items.isEmpty)
    }
}
