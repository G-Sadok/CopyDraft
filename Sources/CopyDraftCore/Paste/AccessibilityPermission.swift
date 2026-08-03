import AppKit
import ApplicationServices

/// État de l'autorisation d'accessibilité, seule permission demandée par CopyDraft.
///
/// Elle conditionne deux choses : la synthèse de `⌘V` pour coller dans l'application active
/// (FR-33) et le tap clavier qui permet à la popup de recevoir les frappes sans prendre le
/// focus (ADR-6). Sans elle, l'application reste utilisable en mode replié (FR-34).
public protocol AccessibilityPermissionChecking: Sendable {
    func isGranted() -> Bool
}

public struct SystemAccessibilityPermission: AccessibilityPermissionChecking {
    public init() {}

    public func isGranted() -> Bool {
        AXIsProcessTrusted()
    }
}

/// Surveille l'autorisation et prévient dès qu'elle change.
///
/// macOS ne notifie pas l'octroi ni la révocation : on interroge périodiquement. Le rythme
/// est lent (1 s) car cet état ne change qu'à la main, dans les Réglages système — c'est ce
/// qui permet à l'écran d'onboarding de basculer tout seul (FR-48).
@MainActor
@Observable
public final class AccessibilityPermissionMonitor {
    public private(set) var isGranted: Bool

    @ObservationIgnored private let checker: AccessibilityPermissionChecking
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private let interval: TimeInterval

    /// Appelé à chaque changement d'état, révocation comprise.
    public var onChange: ((Bool) -> Void)?

    public init(
        checker: AccessibilityPermissionChecking = SystemAccessibilityPermission(),
        interval: TimeInterval = 1.0
    ) {
        self.checker = checker
        self.interval = interval
        self.isGranted = checker.isGranted()
    }

    public func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Relit l'état immédiatement — utile au retour au premier plan.
    public func refresh() {
        let granted = checker.isGranted()
        guard granted != isGranted else { return }
        isGranted = granted
        onChange?(granted)
    }

    /// Ouvre le volet *Confidentialité et sécurité → Accessibilité* des Réglages système.
    public static func openSystemSettings() {
        guard
            let url = URL(
                string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            )
        else { return }
        NSWorkspace.shared.open(url)
    }

    /// Demande l'autorisation en affichant l'invite système, une seule fois par session.
    ///
    /// L'invite n'apparaît que si l'application n'est pas déjà autorisée ; elle ne bloque pas.
    @discardableResult
    public static func requestWithSystemPrompt() -> Bool {
        // `kAXTrustedCheckOptionPrompt` est une variable globale non isolée : on reconstruit
        // la clé littéralement plutôt que d'y toucher depuis un contexte concurrent.
        let options = ["AXTrustedCheckOptionPrompt": true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
}
