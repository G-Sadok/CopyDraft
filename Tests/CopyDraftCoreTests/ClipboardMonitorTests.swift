import AppKit
import Foundation
import Testing

@testable import CopyDraftCore

@MainActor
@Suite("Moniteur de presse-papiers")
struct ClipboardMonitorTests {
    /// Application frontale factice : `NSWorkspace` ne se pilote pas depuis un test.
    private final class StubFrontmostApp: FrontmostAppProviding {
        var app: SourceApp

        init(_ app: SourceApp) {
            self.app = app
        }

        func currentApp() -> SourceApp { app }
    }

    /// Contexte d'un cas : presse-papiers, réglages et notifications sont tous privés, rien
    /// n'atteint la machine réelle.
    private struct Context {
        let pasteboard = FakePasteboard()
        let center = NotificationCenter()
        let frontmostApp: StubFrontmostApp
        let preferences: Preferences
        let monitor: ClipboardMonitor
        let captures: Captures

        @MainActor
        init() {
            let suite = "com.copydraft.tests.\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suite)!
            defaults.removePersistentDomain(forName: suite)
            preferences = Preferences(defaults: defaults)
            frontmostApp = StubFrontmostApp(
                SourceApp(bundleIdentifier: "com.apple.dt.Xcode", name: "Xcode")
            )

            let captures = Captures()
            self.captures = captures
            monitor = ClipboardMonitor(
                pasteboard: pasteboard,
                preferences: preferences,
                frontmostApp: frontmostApp,
                notificationCenter: center
            )
            monitor.onCapture = { content, source in
                captures.append(content, from: source)
            }
        }

        func post(_ name: Notification.Name) {
            center.post(name: name, object: nil)
        }
    }

    @MainActor
    private final class Captures {
        private(set) var items: [(content: CapturedContent, source: SourceApp)] = []

        var count: Int { items.count }
        var last: (content: CapturedContent, source: SourceApp)? { items.last }

        func append(_ content: CapturedContent, from source: SourceApp) {
            items.append((content, source))
        }
    }

    // MARK: Sondage

    @Test("Aucun accès au contenu tant que changeCount ne bouge pas")
    func idlePollingDoesNotTouchContent() {
        let context = Context()
        context.pasteboard.writeText("déjà là")
        context.monitor.poll()
        context.pasteboard.resetContentAccessCount()

        context.monitor.poll()
        context.monitor.poll()
        context.monitor.poll()

        #expect(context.pasteboard.contentAccessCount == 0)
    }

    @Test("Un changement de changeCount déclenche une capture")
    func changeTriggersCapture() {
        let context = Context()
        context.pasteboard.writeText("Bonjour")

        context.monitor.poll()

        #expect(context.captures.count == 1)
        #expect(context.captures.last?.content.text == "Bonjour")
        #expect(context.captures.last?.content.kind == .text)
    }

    @Test("Une copie n'est capturée qu'une fois")
    func sameChangeCountIsCapturedOnce() {
        let context = Context()
        context.pasteboard.writeText("Bonjour")

        context.monitor.poll()
        context.monitor.poll()

        #expect(context.captures.count == 1)
    }

    @Test("Les copies successives sont toutes capturées")
    func successiveChangesAreAllCaptured() {
        let context = Context()

        for text in ["un", "deux", "trois"] {
            context.pasteboard.writeText(text)
            context.monitor.poll()
        }

        #expect(context.captures.count == 3)
        #expect(context.captures.items.map(\.content.text) == ["un", "deux", "trois"])
    }

    @Test("Le contenu au moment du démarrage n'est pas capturé")
    func preexistingContentIsNotCaptured() {
        let pasteboard = FakePasteboard()
        pasteboard.writeText("copié avant le lancement")

        let suite = "com.copydraft.tests.\(UUID().uuidString)"
        let captures = Captures()
        let monitor = ClipboardMonitor(
            pasteboard: pasteboard,
            preferences: Preferences(defaults: UserDefaults(suiteName: suite)!),
            notificationCenter: NotificationCenter()
        ) { content, source in captures.append(content, from: source) }

        monitor.poll()

        #expect(captures.count == 0)
    }

    // MARK: Application source

    @Test("L'application frontale est rattachée à la capture")
    func sourceApplicationIsAttached() {
        let context = Context()
        context.pasteboard.writeText("extrait de code")

        context.monitor.poll()

        #expect(context.captures.last?.source.bundleIdentifier == "com.apple.dt.Xcode")
        #expect(context.captures.last?.source.name == "Xcode")
    }

    @Test("Chaque capture porte l'application active à ce moment-là")
    func sourceApplicationFollowsFrontmostApp() {
        let context = Context()
        context.pasteboard.writeText("premier")
        context.monitor.poll()

        context.frontmostApp.app = SourceApp(bundleIdentifier: "com.apple.Safari", name: "Safari")
        context.pasteboard.writeText("second")
        context.monitor.poll()

        #expect(context.captures.items.map(\.source.name) == ["Xcode", "Safari"])
    }

    // MARK: Contenus ignorés

    @Test("Un contenu vide ne produit aucune capture")
    func emptyContentIsIgnored() {
        let context = Context()
        context.pasteboard.clear()

        context.monitor.poll()

        #expect(context.captures.count == 0)
    }

    @Test("Un contenu de plus de 4 Mo ne produit aucune capture")
    func oversizedContentIsIgnored() {
        let context = Context()
        context.pasteboard.writeText(String(repeating: "a", count: Limits.itemBytes + 1))

        context.monitor.poll()

        #expect(context.captures.count == 0)
    }

    /// Un contenu ignoré ne doit pas être réexaminé à chaque tick : son `changeCount` est
    /// mémorisé comme celui d'une capture réussie.
    @Test("Un contenu ignoré n'est pas relu au tick suivant")
    func ignoredContentIsNotReread() {
        let context = Context()
        context.pasteboard.clear()
        context.monitor.poll()
        context.pasteboard.resetContentAccessCount()

        context.monitor.poll()

        #expect(context.pasteboard.contentAccessCount == 0)
    }

    // MARK: Veille, verrouillage et session

    @Test(
        "La suspension arrête la capture",
        arguments: [
            NSWorkspace.willSleepNotification,
            NSWorkspace.screensDidSleepNotification,
            NSWorkspace.sessionDidResignActiveNotification
        ]
    )
    func suspensionStopsCapture(notification: Notification.Name) {
        let context = Context()
        context.monitor.start()

        context.post(notification)
        context.pasteboard.writeText("copié pendant la suspension")
        context.monitor.poll()

        #expect(context.monitor.isSuspended)
        #expect(context.monitor.isPolling == false)
        #expect(context.captures.count == 0)

        context.monitor.stop()
    }

    @Test(
        "La reprise ne capture pas rétroactivement mais reprend les copies suivantes",
        arguments: [
            (NSWorkspace.willSleepNotification, NSWorkspace.didWakeNotification),
            (NSWorkspace.screensDidSleepNotification, NSWorkspace.screensDidWakeNotification),
            (
                NSWorkspace.sessionDidResignActiveNotification,
                NSWorkspace.sessionDidBecomeActiveNotification
            )
        ]
    )
    func resumptionSkipsWhatHappenedMeanwhile(
        suspend: Notification.Name, resume: Notification.Name
    ) {
        let context = Context()
        context.monitor.start()

        context.post(suspend)
        context.pasteboard.writeText("copié pendant la suspension")
        context.post(resume)
        context.monitor.poll()

        #expect(context.monitor.isSuspended == false)
        #expect(context.captures.count == 0)

        context.pasteboard.writeText("copié après la reprise")
        context.monitor.poll()

        #expect(context.captures.count == 1)
        #expect(context.captures.last?.content.text == "copié après la reprise")

        context.monitor.stop()
    }

    /// L'écran s'endort avant le système : le réveil du système seul ne doit pas relancer la
    /// capture tant que l'autre cause tient.
    @Test("Les causes de suspension se cumulent")
    func suspensionCausesAccumulate() {
        let context = Context()
        context.monitor.start()

        context.post(NSWorkspace.screensDidSleepNotification)
        context.post(NSWorkspace.willSleepNotification)
        context.post(NSWorkspace.didWakeNotification)

        #expect(context.monitor.isSuspended)
        #expect(context.monitor.isPolling == false)

        context.post(NSWorkspace.screensDidWakeNotification)

        #expect(context.monitor.isSuspended == false)
        #expect(context.monitor.isPolling)

        context.monitor.stop()
    }

    @Test("Une reprise sans démarrage ne relance pas le timer")
    func resumptionWhileStoppedDoesNotSchedule() {
        let context = Context()

        context.post(NSWorkspace.willSleepNotification)
        context.post(NSWorkspace.didWakeNotification)

        #expect(context.monitor.isPolling == false)
    }

    // MARK: Timer

    @Test("Le démarrage arme un timer à l'intervalle des réglages")
    func startSchedulesTimer() {
        let context = Context()

        #expect(context.monitor.isPolling == false)
        context.monitor.start()
        #expect(context.monitor.currentPollingInterval == 0.4)

        context.monitor.stop()
        #expect(context.monitor.isPolling == false)
    }

    @Test("Le timer se reprogramme quand l'intervalle change")
    func timerReschedulesOnIntervalChange() async {
        let context = Context()
        context.monitor.start()
        #expect(context.monitor.currentPollingInterval == 0.4)

        context.preferences.pollingInterval = 0.9
        await Task.yield()
        await Task.yield()

        #expect(context.monitor.currentPollingInterval == 0.9)

        context.monitor.stop()
    }
}
