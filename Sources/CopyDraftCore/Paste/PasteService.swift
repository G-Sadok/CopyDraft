import AppKit

/// Ce que le collage a réellement fait, pour choisir le bon toast (FR-35).
public enum PasteOutcome: Sendable, Equatable {
    /// Collé dans l'application nommée.
    case pasted(appName: String)
    /// Collé en texte brut dans l'application nommée.
    case pastedPlainText(appName: String)
    /// Repli sans autorisation : le contenu est dans le presse-papiers, à l'utilisateur de coller.
    case copiedOnly
}

/// Destination d'un collage : l'application qui était active avant l'ouverture de la popup.
public struct PasteTarget: Sendable, Equatable {
    public let processIdentifier: pid_t
    public let name: String

    public init(processIdentifier: pid_t, name: String) {
        self.processIdentifier = processIdentifier
        self.name = name
    }
}

/// Écriture dans le presse-papiers système, isolée pour les tests.
public protocol PasteboardWriting: Sendable {
    func write(_ content: StoredContent, plainTextOnly: Bool)
}

public struct SystemPasteboardWriter: PasteboardWriting {
    public init() {}

    public func write(_ content: StoredContent, plainTextOnly: Bool) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        if plainTextOnly {
            // « Coller sans mise en forme » : seul le texte part, jamais le RTF ni le HTML.
            if let text = content.text {
                pasteboard.setString(text, forType: .string)
            }
            return
        }

        if let rtf = content.rtfData { pasteboard.setData(rtf, forType: .rtf) }
        if let html = content.htmlData { pasteboard.setData(html, forType: .html) }
        if let text = content.text { pasteboard.setString(text, forType: .string) }
    }
}

/// Synthèse de frappes clavier, isolée pour les tests.
public protocol KeystrokeSynthesizing: Sendable {
    /// Envoie `⌘V` au processus visé. Renvoie faux si l'événement n'a pas pu être produit.
    func sendCommandV(to processIdentifier: pid_t) -> Bool
}

public struct CGEventKeystrokeSynthesizer: KeystrokeSynthesizing {
    /// Code de la touche V sur un clavier ANSI.
    private static let keyV: CGKeyCode = 9

    public init() {}

    public func sendCommandV(to processIdentifier: pid_t) -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState),
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: Self.keyV, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: Self.keyV, keyDown: false)
        else { return false }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        // Envoi ciblé sur le processus : plus sûr qu'un post global, qui suivrait le focus
        // s'il avait bougé entre-temps.
        keyDown.postToPid(processIdentifier)
        keyUp.postToPid(processIdentifier)
        return true
    }
}

/// Colle un élément dans l'application qui était active avant l'ouverture de la popup (FR-33).
///
/// Séquence : écrire dans le presse-papiers → rendre le focus à l'application visée →
/// synthétiser `⌘V`. Sans autorisation d'accessibilité, on s'arrête après l'écriture et le
/// toast invite à coller à la main (FR-34) : jamais d'erreur bloquante.
@MainActor
public final class PasteService {
    /// Délai laissé au système pour réactiver l'application avant la frappe.
    ///
    /// Sans cette respiration, `⌘V` peut partir alors que le focus n'est pas encore revenu et
    /// se perdre. 60 ms restent sous le seuil de perception.
    public static let focusRestoreDelay: Duration = .milliseconds(60)

    private let writer: PasteboardWriting
    private let synthesizer: KeystrokeSynthesizing
    private let permission: AccessibilityPermissionChecking
    private let activate: @MainActor (pid_t) -> Bool

    public init(
        writer: PasteboardWriting = SystemPasteboardWriter(),
        synthesizer: KeystrokeSynthesizing = CGEventKeystrokeSynthesizer(),
        permission: AccessibilityPermissionChecking = SystemAccessibilityPermission(),
        activate: @escaping @MainActor (pid_t) -> Bool = PasteService.activateApplication
    ) {
        self.writer = writer
        self.synthesizer = synthesizer
        self.permission = permission
        self.activate = activate
    }

    /// Colle `content` dans `target`. `plainTextOnly` correspond à `⇧↩︎` (FR-32).
    @discardableResult
    public func paste(
        _ content: StoredContent,
        into target: PasteTarget?,
        plainTextOnly: Bool = false
    ) async -> PasteOutcome {
        writer.write(content, plainTextOnly: plainTextOnly)

        guard permission.isGranted(), let target else { return .copiedOnly }

        _ = activate(target.processIdentifier)
        try? await Task.sleep(for: Self.focusRestoreDelay)

        guard synthesizer.sendCommandV(to: target.processIdentifier) else { return .copiedOnly }
        return plainTextOnly
            ? .pastedPlainText(appName: target.name) : .pasted(appName: target.name)
    }

    /// Copie seule, sans collage : action « Copier » du menu contextuel (§9).
    public func copy(_ content: StoredContent, plainTextOnly: Bool = false) {
        writer.write(content, plainTextOnly: plainTextOnly)
    }

    /// Réactivation par défaut : l'application visée redevient active avant la frappe.
    public static func activateApplication(_ pid: pid_t) -> Bool {
        NSRunningApplication(processIdentifier: pid)?.activate() ?? false
    }
}

/// Mémorise l'application active au moment où la popup s'ouvre : c'est elle qui recevra le
/// collage, même si le focus a bougé entre-temps.
@MainActor
public final class FrontmostAppTracker {
    private(set) public var target: PasteTarget?

    public init() {}

    /// À appeler juste avant d'afficher la popup.
    public func capture() {
        guard let app = NSWorkspace.shared.frontmostApplication,
            app.processIdentifier != ProcessInfo.processInfo.processIdentifier
        else { return }

        target = PasteTarget(
            processIdentifier: app.processIdentifier,
            name: app.localizedName ?? ""
        )
    }

    public func clear() {
        target = nil
    }
}
