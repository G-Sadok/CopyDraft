import AppKit
import OSLog

/// Achemine les frappes vers la popup **sans que celle-ci prenne le focus** (ADR-6).
///
/// Le design system exige un panneau non activant qui reçoit pourtant les touches. Un
/// panneau non clé ne reçoit rien : le seul moyen est un tap d'événements, qui suppose
/// l'autorisation d'accessibilité — la même que le collage.
///
/// Garde-fou de confiance : **le tap n'existe que pendant l'ouverture de la popup**. Il est
/// installé à l'affichage et retiré à la fermeture ; CopyDraft n'écoute jamais le clavier en
/// dehors de ces quelques secondes, et jamais en arrière-plan.
@MainActor
public final class KeyEventRouter {
    /// Mode d'acheminement effectivement utilisé.
    public enum Mode: Sendable, Equatable {
        /// Tap d'événements : le panneau reste non activant, l'application active garde son focus.
        case eventTap
        /// Repli sans autorisation : la popup devient fenêtre clé et reçoit les touches par
        /// la chaîne de responsabilité d'AppKit.
        case keyWindow
    }

    /// Appelé pour chaque commande reconnue. Renvoyer `true` consomme l'événement, qui
    /// n'atteint donc pas l'application active.
    public var onCommand: ((PopupCommand) -> Bool)?

    public private(set) var isActive = false
    public private(set) var mode: Mode = .keyWindow

    /// Journal réduit au mode d'acheminement obtenu : de quoi comprendre un « le clavier ne
    /// répond pas » en assistance, sans jamais consigner ce qui est tapé.
    private static let log = Logger(subsystem: AppInfo.bundleIdentifier, category: "clavier")

    private let mapper = KeyCommandMapper()
    private let permission: AccessibilityPermissionChecking
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var localMonitor: Any?

    /// Contexte de décision fourni par la popup à chaque frappe.
    public var isSearchEmpty: () -> Bool = { true }
    public var quickPasteEnabled: () -> Bool = { true }

    public init(permission: AccessibilityPermissionChecking = SystemAccessibilityPermission()) {
        self.permission = permission
    }

    /// Installe le tap si l'autorisation le permet ; sinon signale le mode replié.
    @discardableResult
    public func start() -> Mode {
        guard !isActive else { return mode }

        let granted = permission.isGranted()
        let tap = granted ? makeTap() : nil
        Self.log.notice(
            "démarrage du clavier — autorisé \(granted, privacy: .public), tap \(tap != nil, privacy: .public)"
        )
        guard let tap else {
            // Repli : l'application est active et la popup est fenêtre clé, mais rien dans
            // SwiftUI ne connaît la table du §3. Un moniteur local d'événements rejoue le
            // même acheminement que le tap, en consommant ce qu'il traite.
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
                [weak self] event in
                guard let self else { return event }
                let characters = event.charactersIgnoringModifiers ?? event.characters ?? ""
                let consumed = self.handle(
                    keyCode: event.keyCode,
                    characters: characters,
                    modifiers: KeyModifiers(appKitFlags: event.modifierFlags)
                )
                return consumed ? nil : event
            }
            mode = .keyWindow
            isActive = true
            return mode
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.tap = tap
        self.runLoopSource = source
        mode = .eventTap
        isActive = true
        return mode
    }

    /// Retire le tap. Appelé à chaque fermeture de la popup, sans exception.
    public func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            }
            CFMachPortInvalidate(tap)
        }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        localMonitor = nil
        tap = nil
        runLoopSource = nil
        isActive = false
    }

    // Pas de nettoyage dans `deinit` : un `deinit` non isolé ne peut pas toucher l'état
    // d'une classe `@MainActor`. Le contrat est donc explicite — la popup appelle `stop()`
    // à chaque fermeture, et c'est ce qui garantit qu'aucun tap ne survit à l'affichage.

    /// Traduit et distribue un événement clavier. Exposé pour les tests.
    func handle(keyCode: UInt16, characters: String, modifiers: KeyModifiers) -> Bool {
        // Aucune journalisation de frappe ici, jamais : tracer les touches d'un utilisateur
        // pendant qu'il cherche dans son historique irait contre tout ce que promet
        // l'application.
        guard
            let command = mapper.command(
                keyCode: keyCode,
                characters: characters,
                modifiers: modifiers,
                isSearchEmpty: isSearchEmpty(),
                quickPasteEnabled: quickPasteEnabled()
            )
        else { return false }

        return onCommand?(command) ?? false
    }

    // MARK: Tap

    private func makeTap() -> CFMachPort? {
        let mask = (1 << CGEventType.keyDown.rawValue)

        return CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let router = Unmanaged<KeyEventRouter>.fromOpaque(refcon).takeUnretainedValue()

                // Le système désactive le tap s'il juge le traitement trop lent : on le réarme.
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    MainActor.assumeIsolated { router.reenableTap() }
                    return Unmanaged.passUnretained(event)
                }
                guard type == .keyDown else { return Unmanaged.passUnretained(event) }

                // Les valeurs sont extraites ici : `CGEvent` n'est pas `Sendable` et ne doit
                // pas franchir la frontière d'isolation.
                let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
                let modifiers = KeyModifiers(cgFlags: event.flags)
                let characters = KeyEventRouter.characters(from: event)

                let consumed = MainActor.assumeIsolated {
                    router.handle(keyCode: keyCode, characters: characters, modifiers: modifiers)
                }
                // Consommé : l'événement n'atteint pas l'application active, qui garde son
                // focus mais ne reçoit pas la frappe destinée à la popup.
                return consumed ? nil : Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
    }

    /// Réarme le tap après une désactivation par le système.
    private func reenableTap() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    }

    private static func characters(from event: CGEvent) -> String {
        var length = 0
        var buffer = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: &buffer)
        guard length > 0 else { return "" }
        return String(utf16CodeUnits: buffer, count: length)
    }
}

extension KeyModifiers {
    /// Traduit les drapeaux AppKit en modificateurs de la popup.
    init(appKitFlags: NSEvent.ModifierFlags) {
        var modifiers: KeyModifiers = []
        if appKitFlags.contains(.command) { modifiers.insert(.command) }
        if appKitFlags.contains(.shift) { modifiers.insert(.shift) }
        if appKitFlags.contains(.option) { modifiers.insert(.option) }
        if appKitFlags.contains(.control) { modifiers.insert(.control) }
        self = modifiers
    }

    /// Traduit les drapeaux CoreGraphics en modificateurs de la popup.
    init(cgFlags: CGEventFlags) {
        var modifiers: KeyModifiers = []
        if cgFlags.contains(.maskCommand) { modifiers.insert(.command) }
        if cgFlags.contains(.maskShift) { modifiers.insert(.shift) }
        if cgFlags.contains(.maskAlternate) { modifiers.insert(.option) }
        if cgFlags.contains(.maskControl) { modifiers.insert(.control) }
        self = modifiers
    }
}
