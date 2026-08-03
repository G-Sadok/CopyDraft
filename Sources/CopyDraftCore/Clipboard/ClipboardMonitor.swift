import AppKit
import Foundation
import Observation

/// Fournit l'application au premier plan au moment de la copie (FR-5).
///
/// Injectable : `NSWorkspace` ne peut pas être piloté depuis un test, et la valeur capturée
/// fait partie de ce que le moniteur doit garantir.
@MainActor
public protocol FrontmostAppProviding {
    func currentApp() -> SourceApp
}

/// Implémentation adossée à `NSWorkspace`.
public struct WorkspaceFrontmostApp: FrontmostAppProviding {
    public init() {}

    public func currentApp() -> SourceApp {
        guard let app = NSWorkspace.shared.frontmostApplication else { return .unknown }
        return SourceApp(bundleIdentifier: app.bundleIdentifier, name: app.localizedName ?? "")
    }
}

/// Moniteur de presse-papiers (FR-1, FR-5, FR-8, NFR-1, NFR-4).
///
/// Au repos, un tick ne fait que comparer deux entiers : le contenu n'est lu que lorsque
/// `changeCount` a bougé, condition pour tenir NFR-1. Le moniteur ne filtre rien — la
/// confidentialité (S-1.3) et la déduplication (S-1.5) travaillent en aval de `onCapture`.
@MainActor
public final class ClipboardMonitor {
    public typealias CaptureHandler = (CapturedContent, SourceApp) -> Void

    /// Causes de suspension. Elles se chevauchent — l'écran s'endort avant le système, une
    /// session peut se désactiver pendant la veille — donc un simple booléen laisserait le
    /// moniteur repris trop tôt ou suspendu pour toujours (FR-8).
    private enum SuspensionCause: Hashable {
        case systemSleep
        case screensSleep
        case sessionInactive
    }

    private let pasteboard: PasteboardSource
    private let reader: PasteboardReader
    private let preferences: Preferences
    private let frontmostApp: FrontmostAppProviding
    private let notificationCenter: NotificationCenter
    private let observers: NotificationObservers

    private var timer: Timer?
    private var lastChangeCount: Int
    private var suspensionCauses: Set<SuspensionCause> = []
    private var isStarted = false

    /// Appelée pour chaque contenu retenu, avec l'application d'où venait la copie.
    public var onCapture: CaptureHandler?

    public init(
        pasteboard: PasteboardSource = SystemPasteboard(),
        reader: PasteboardReader = PasteboardReader(),
        preferences: Preferences,
        frontmostApp: FrontmostAppProviding = WorkspaceFrontmostApp(),
        notificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
        onCapture: CaptureHandler? = nil
    ) {
        self.pasteboard = pasteboard
        self.reader = reader
        self.preferences = preferences
        self.frontmostApp = frontmostApp
        self.notificationCenter = notificationCenter
        self.onCapture = onCapture
        // Ce qui se trouvait déjà dans le presse-papiers au lancement a été copié avant
        // nous : l'historique restauré le contient déjà, le recapturer ferait un doublon.
        lastChangeCount = pasteboard.changeCount
        observers = NotificationObservers(center: notificationCenter)

        observeWorkspace()
        observePollingInterval()
    }

    // MARK: Marche et arrêt

    /// Vrai quand un timer est armé — faux à l'arrêt comme en suspension.
    public var isPolling: Bool { timer != nil }

    public var isSuspended: Bool { !suspensionCauses.isEmpty }

    public func start() {
        guard !isStarted else { return }
        isStarted = true
        scheduleTimer()
    }

    public func stop() {
        isStarted = false
        invalidateTimer()
    }

    // MARK: Sondage

    /// Un tick. Interne plutôt que privé : les tests l'appellent directement, sinon chaque
    /// cas devrait attendre un vrai intervalle de 0,4 s.
    func poll() {
        guard !isSuspended else { return }

        let currentChangeCount = pasteboard.changeCount
        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount

        // Relevée avant la lecture des représentations : c'est l'application qui a copié
        // qui nous intéresse, pas celle vers laquelle l'utilisateur bascule pendant ce temps.
        let source = frontmostApp.currentApp()
        guard let content = reader.read(from: pasteboard) else { return }
        onCapture?(content, source)
    }

    // MARK: Timer

    private func scheduleTimer() {
        invalidateTimer()
        let timer = Timer(
            timeInterval: preferences.pollingInterval, repeats: true
        ) { [weak self] _ in
            // Le timer est ordonnancé sur la boucle du fil principal : son bloc s'exécute
            // toujours là où le moniteur est isolé.
            MainActor.assumeIsolated { self?.poll() }
        }
        // `.common` : sinon le sondage s'arrête pendant qu'un menu est ouvert ou qu'une
        // fenêtre est redimensionnée, et les copies de cette période seraient perdues.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func invalidateTimer() {
        timer?.invalidate()
        timer = nil
    }

    /// Intervalle actuellement armé, pour les tests.
    var currentPollingInterval: TimeInterval? { timer?.timeInterval }

    /// L'intervalle est réglable à chaud (NFR-4) : le timer se reprogramme sans redémarrage.
    private func observePollingInterval() {
        withObservationTracking {
            _ = preferences.pollingInterval
        } onChange: { [weak self] in
            Task { @MainActor in self?.pollingIntervalDidChange() }
        }
    }

    private func pollingIntervalDidChange() {
        // `withObservationTracking` ne notifie qu'une fois : il faut se réabonner.
        observePollingInterval()
        guard isStarted, !isSuspended else { return }
        scheduleTimer()
    }

    // MARK: Veille, verrouillage et session

    private func observeWorkspace() {
        let suspensions: [(Notification.Name, SuspensionCause)] = [
            (NSWorkspace.willSleepNotification, .systemSleep),
            (NSWorkspace.screensDidSleepNotification, .screensSleep),
            (NSWorkspace.sessionDidResignActiveNotification, .sessionInactive)
        ]
        let resumptions: [(Notification.Name, SuspensionCause)] = [
            (NSWorkspace.didWakeNotification, .systemSleep),
            (NSWorkspace.screensDidWakeNotification, .screensSleep),
            (NSWorkspace.sessionDidBecomeActiveNotification, .sessionInactive)
        ]

        for (name, cause) in suspensions {
            observe(name) { $0.suspend(cause) }
        }
        for (name, cause) in resumptions {
            observe(name) { $0.resume(cause) }
        }
    }

    private func observe(
        _ name: Notification.Name,
        handler: @escaping @MainActor (ClipboardMonitor) -> Void
    ) {
        // File `nil` : les notifications de `NSWorkspace` sont émises sur le fil principal,
        // les traiter sur place évite un aller-retour et garde l'ordre des événements.
        let token = notificationCenter.addObserver(
            forName: name, object: nil, queue: nil
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                handler(self)
            }
        }
        observers.add(token)
    }

    private func suspend(_ cause: SuspensionCause) {
        suspensionCauses.insert(cause)
        invalidateTimer()
    }

    private func resume(_ cause: SuspensionCause) {
        suspensionCauses.remove(cause)
        guard !isSuspended else { return }

        // Resynchronisation sans lecture : ce qui a été copié pendant la suspension est
        // perdu volontairement, mais ne doit pas ressurgir d'un coup au réveil (FR-8).
        lastChangeCount = pasteboard.changeCount
        if isStarted { scheduleTimer() }
    }
}

/// Porte les jetons d'observation et les retire à la libération du moniteur.
///
/// Le `deinit` d'une classe isolée sur l'acteur principal ne peut pas toucher à son état
/// isolé : un porteur non isolé s'en charge.
private final class NotificationObservers {
    private let center: NotificationCenter
    private var tokens: [NSObjectProtocol] = []

    init(center: NotificationCenter) {
        self.center = center
    }

    func add(_ token: NSObjectProtocol) {
        tokens.append(token)
    }

    deinit {
        for token in tokens { center.removeObserver(token) }
    }
}
