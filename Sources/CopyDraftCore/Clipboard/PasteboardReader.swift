import AppKit
import CoreGraphics
import Foundation

/// Lecture typée du presse-papiers (FR-2, FR-3, FR-7).
///
/// Ordre de préférence : image, texte enrichi, texte brut. L'ordre décide seul du type de
/// l'élément ; il n'y a pas de repli d'une famille sur l'autre, sans quoi une image de 5 Mo
/// accompagnée de son texte alternatif serait enregistrée comme du texte.
public struct PasteboardReader: Sendable {
    public init() {}

    /// Renvoie le contenu à enregistrer, ou `nil` si rien n'est exploitable ou si la limite
    /// de 4 Mo est dépassée — dans les deux cas l'élément est ignoré silencieusement (FR-7).
    public func read(from source: PasteboardSource) -> CapturedContent? {
        let types = Set(source.availableTypes())
        let content = image(from: source, types: types)
            ?? richText(from: source, types: types)
            ?? plainText(from: source)

        guard let content, !content.isEmpty, !content.exceedsSizeLimit else { return nil }
        return content
    }

    // MARK: Image

    private func image(from source: PasteboardSource, types: Set<String>) -> CapturedContent? {
        let candidates = [PasteboardUTI.png, PasteboardUTI.tiff]
        guard
            let data = candidates
                .filter({ types.contains($0) })
                .compactMap({ source.data(forType: $0) })
                .first(where: { !$0.isEmpty })
        else { return nil }

        return CapturedContent(
            kind: .image,
            imageData: data,
            pixelSize: Self.pixelSize(of: data),
            byteCount: data.count
        )
    }

    /// Dimensions réelles en pixels — pas la taille en points, qui vaudrait la moitié sur un
    /// écran Retina et fausserait la métadonnée affichée (FR-3).
    private static func pixelSize(of data: Data) -> CGSize? {
        guard let representation = NSBitmapImageRep(data: data) else { return nil }
        return CGSize(width: representation.pixelsWide, height: representation.pixelsHigh)
    }

    // MARK: Texte enrichi

    private func richText(from source: PasteboardSource, types: Set<String>) -> CapturedContent? {
        let rtf = types.contains(PasteboardUTI.rtf)
            ? source.data(forType: PasteboardUTI.rtf).nonEmpty
            : nil
        let html = types.contains(PasteboardUTI.html)
            ? source.data(forType: PasteboardUTI.html).nonEmpty
            : nil
        guard rtf != nil || html != nil else { return nil }

        // La projection texte sert à la recherche et à la déduplication : elle doit exister
        // même quand l'application source n'a déposé aucun texte brut.
        let text = source.string().nonEmpty
            ?? rtf.flatMap(Self.text(fromRTF:))
            ?? html.flatMap(Self.text(fromHTML:))
            ?? ""

        return CapturedContent(
            kind: .rich,
            text: text,
            rtfData: rtf,
            htmlData: html,
            byteCount: max(rtf?.count ?? 0, html?.count ?? 0, text.utf8.count)
        )
    }

    private static func text(fromRTF data: Data) -> String? {
        let attributed = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        )
        return attributed?.string
    }

    /// Aplatissement HTML fait à la main : l'import `NSAttributedString` en HTML passe par
    /// WebKit, qui exige le fil principal et une boucle d'exécution active — trop lourd et
    /// trop fragile pour une opération déclenchée à chaque copie.
    private static func text(fromHTML data: Data) -> String? {
        guard let markup = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .utf16)
            ?? String(data: data, encoding: .isoLatin1)
        else { return nil }
        return HTMLFlattener.plainText(from: markup)
    }

    // MARK: Texte brut

    private func plainText(from source: PasteboardSource) -> CapturedContent? {
        guard let text = source.string() else { return nil }
        return CapturedContent(kind: .text, text: text, byteCount: text.utf8.count)
    }
}

// MARK: - Aplatissement HTML

/// Réduit un fragment HTML à sa lecture texte : balises retirées, entités décodées,
/// structure de blocs rendue par des retours à la ligne.
private enum HTMLFlattener {
    /// Balises dont l'ouverture ou la fermeture marque une rupture de ligne.
    private static let blockTags: Set<String> = [
        "br", "p", "div", "li", "tr", "ul", "ol", "table", "blockquote", "pre", "hr",
        "h1", "h2", "h3", "h4", "h5", "h6"
    ]
    /// Balises dont le contenu n'est pas du texte lisible.
    private static let opaqueTags: Set<String> = ["script", "style", "head"]

    private static let namedEntities: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": "\u{00A0}"
    ]

    static func plainText(from markup: String) -> String {
        var output = ""
        var scanner = Substring(markup)
        var opaque: String?

        while let start = scanner.firstIndex(of: "<") {
            let before = scanner[scanner.startIndex..<start]
            if opaque == nil { output += decodeEntities(String(before)) }

            guard let end = scanner[start...].firstIndex(of: ">") else {
                // Balise jamais refermée : le reste du fragment n'est pas du texte lisible.
                scanner = scanner[scanner.endIndex...]
                break
            }
            let tag = scanner[scanner.index(after: start)..<end]
            let (name, isClosing) = parse(tag: tag)

            if let open = opaque {
                if isClosing && name == open { opaque = nil }
            } else if opaqueTags.contains(name) && !isClosing {
                opaque = name
            } else if blockTags.contains(name) {
                output += "\n"
            }

            scanner = scanner[scanner.index(after: end)...]
        }
        if opaque == nil { output += decodeEntities(String(scanner)) }

        return normalize(output)
    }

    private static func parse(tag: Substring) -> (name: String, isClosing: Bool) {
        var body = tag
        let isClosing = body.first == "/"
        if isClosing { body = body.dropFirst() }
        let name = body.prefix { !$0.isWhitespace && $0 != "/" && $0 != ">" }
        return (name.lowercased(), isClosing)
    }

    private static func decodeEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }

        var output = ""
        var rest = Substring(text)
        while let start = rest.firstIndex(of: "&") {
            output += rest[rest.startIndex..<start]
            let body = rest[rest.index(after: start)...]
            guard
                let end = body.firstIndex(of: ";"),
                body.distance(from: body.startIndex, to: end) <= 8,
                let decoded = decode(entity: body[body.startIndex..<end])
            else {
                output.append("&")
                rest = body
                continue
            }
            output += decoded
            rest = body[body.index(after: end)...]
        }
        return output + rest
    }

    private static func decode(entity: Substring) -> String? {
        if let named = namedEntities[entity.lowercased()] { return named }
        guard entity.first == "#" else { return nil }

        let digits = entity.dropFirst()
        let scalar: UInt32? = if digits.first == "x" || digits.first == "X" {
            UInt32(digits.dropFirst(), radix: 16)
        } else {
            UInt32(digits, radix: 10)
        }
        return scalar.flatMap(Unicode.Scalar.init).map(String.init)
    }

    /// Espaces répétés ramenés à un seul, lignes vides limitées à une : le HTML du
    /// presse-papiers est presque toujours indenté, la projection ne doit pas l'être.
    private static func normalize(_ text: String) -> String {
        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in
                line
                    .split(whereSeparator: { $0.isWhitespace })
                    .joined(separator: " ")
            }

        var compacted: [String] = []
        for line in lines where !(line.isEmpty && compacted.last?.isEmpty != false) {
            compacted.append(line)
        }
        return compacted.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: -

extension Optional where Wrapped == Data {
    /// Une représentation présente mais vide n'en est pas une.
    fileprivate var nonEmpty: Data? {
        guard let data = self, !data.isEmpty else { return nil }
        return data
    }
}

extension Optional where Wrapped == String {
    /// Un texte présent mais vide ne fait pas une projection de recherche.
    fileprivate var nonEmpty: String? {
        guard let text = self, !text.isEmpty else { return nil }
        return text
    }
}
