import AppKit
import Foundation

/// Identifiants de types du presse-papiers utilisés à la capture (FR-2).
///
/// Rassemblés ici pour qu'aucune chaîne d'UTI ne soit écrite deux fois : le lecteur, le
/// filtre de confidentialité et les tests parlent du même vocabulaire.
public enum PasteboardUTI {
    public static let png = "public.png"
    public static let tiff = "public.tiff"
    public static let rtf = "public.rtf"
    public static let html = "public.html"
    public static let utf8PlainText = "public.utf8-plain-text"
}

/// Presse-papiers vu par la capture.
///
/// `NSPasteboard` est un singleton du système : sans cette abstraction, ni le lecteur ni le
/// moniteur ne seraient testables sans piétiner le presse-papiers réel de la machine.
public protocol PasteboardSource: Sendable {
    /// Compteur de modifications. Seule valeur lue au repos : le sondage doit coûter un
    /// entier comparé, rien de plus (FR-1, NFR-1).
    var changeCount: Int { get }
    /// Identifiants bruts des représentations disponibles.
    func availableTypes() -> [String]
    func data(forType type: String) -> Data?
    /// Projection texte telle que le presse-papiers la propose.
    func string() -> String?
}

/// Implémentation adossée au presse-papiers général du système.
///
/// Sans état propre : `NSPasteboard.general` est résolu à chaque accès, ce qui rend le type
/// trivialement `Sendable` et évite de conserver une référence à un objet qui ne l'est pas.
public struct SystemPasteboard: PasteboardSource {
    public init() {}

    private var pasteboard: NSPasteboard { .general }

    public var changeCount: Int {
        pasteboard.changeCount
    }

    public func availableTypes() -> [String] {
        (pasteboard.types ?? []).map(\.rawValue)
    }

    public func data(forType type: String) -> Data? {
        pasteboard.data(forType: NSPasteboard.PasteboardType(type))
    }

    public func string() -> String? {
        pasteboard.string(forType: .string)
    }
}

/// Presse-papiers pilotable, pour les tests.
///
/// Compte les accès au contenu : c'est la seule façon de vérifier que rien n'est lu tant que
/// `changeCount` n'a pas bougé (FR-1).
public final class FakePasteboard: PasteboardSource, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Data] = [:]
    private var count: Int
    private var accesses = 0

    public init(changeCount: Int = 0) {
        count = changeCount
    }

    public var changeCount: Int {
        lock.withLock { count }
    }

    /// Nombre d'accès au contenu — types, données ou texte — depuis la dernière remise à
    /// zéro.
    public var contentAccessCount: Int {
        lock.withLock { accesses }
    }

    public func availableTypes() -> [String] {
        lock.withLock {
            accesses += 1
            return Array(storage.keys)
        }
    }

    public func data(forType type: String) -> Data? {
        lock.withLock {
            accesses += 1
            return storage[type]
        }
    }

    public func string() -> String? {
        lock.withLock {
            accesses += 1
            guard let data = storage[PasteboardUTI.utf8PlainText] else { return nil }
            return String(data: data, encoding: .utf8)
        }
    }

    // MARK: Pilotage

    /// Remplace le contenu et incrémente `changeCount`, comme le ferait une copie réelle.
    public func write(_ representations: [String: Data]) {
        lock.withLock {
            storage = representations
            count += 1
        }
    }

    public func writeText(_ text: String) {
        write([PasteboardUTI.utf8PlainText: Data(text.utf8)])
    }

    public func writeRichText(rtf: Data? = nil, html: Data? = nil, text: String? = nil) {
        var representations: [String: Data] = [:]
        if let rtf { representations[PasteboardUTI.rtf] = rtf }
        if let html { representations[PasteboardUTI.html] = html }
        if let text { representations[PasteboardUTI.utf8PlainText] = Data(text.utf8) }
        write(representations)
    }

    public func writeImage(png: Data? = nil, tiff: Data? = nil, text: String? = nil) {
        var representations: [String: Data] = [:]
        if let png { representations[PasteboardUTI.png] = png }
        if let tiff { representations[PasteboardUTI.tiff] = tiff }
        if let text { representations[PasteboardUTI.utf8PlainText] = Data(text.utf8) }
        write(representations)
    }

    /// Copie sans représentation exploitable.
    public func clear() {
        write([:])
    }

    public func resetContentAccessCount() {
        lock.withLock { accesses = 0 }
    }
}
