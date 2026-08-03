import AppKit
import Foundation
import Testing

@testable import CopyDraftCore

@Suite("Lecture du presse-papiers")
struct PasteboardReaderTests {
    private let reader = PasteboardReader()

    /// Image réelle, générée : les dimensions attendues ne dépendent d'aucun fichier annexe.
    private func makeImage(
        width: Int, height: Int, format: NSBitmapImageRep.FileType
    ) -> Data {
        let representation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        return representation.representation(using: format, properties: [:])!
    }

    private func makeRTF(_ text: String) -> Data {
        NSAttributedString(string: text).rtf(
            from: NSRange(location: 0, length: text.utf16.count), documentAttributes: [:]
        )!
    }

    // MARK: Texte brut

    @Test("Le texte brut est lu avec sa taille et son nombre de caractères")
    func plainText() {
        let pasteboard = FakePasteboard()
        pasteboard.writeText("Bonjour à tous")

        let content = reader.read(from: pasteboard)

        #expect(content?.kind == .text)
        #expect(content?.text == "Bonjour à tous")
        #expect(content?.characterCount == 14)
        #expect(content?.byteCount == Data("Bonjour à tous".utf8).count)
        #expect(content?.rtfData == nil)
        #expect(content?.imageData == nil)
    }

    // MARK: Texte enrichi

    @Test("Le texte enrichi conserve RTF, HTML et une projection texte")
    func richText() {
        let pasteboard = FakePasteboard()
        let rtf = makeRTF("Titre")
        let html = Data("<b>Titre</b>".utf8)
        pasteboard.writeRichText(rtf: rtf, html: html, text: "Titre")

        let content = reader.read(from: pasteboard)

        #expect(content?.kind == .rich)
        #expect(content?.text == "Titre")
        #expect(content?.rtfData == rtf)
        #expect(content?.htmlData == html)
        #expect(content?.byteCount == max(rtf.count, html.count, 5))
    }

    @Test("Sans texte brut, la projection texte est tirée du RTF")
    func richTextProjectionFromRTF() {
        let pasteboard = FakePasteboard()
        pasteboard.writeRichText(rtf: makeRTF("Contenu enrichi"))

        let content = reader.read(from: pasteboard)

        #expect(content?.kind == .rich)
        #expect(content?.text == "Contenu enrichi")
    }

    @Test("Sans texte brut ni RTF, la projection texte est tirée du HTML")
    func richTextProjectionFromHTML() {
        let pasteboard = FakePasteboard()
        let html = """
        <html><head><style>p { color: red }</style></head>
        <body><p>Premi&#232;re ligne</p><p>Seconde &amp; derni&#xE8;re</p></body></html>
        """
        pasteboard.writeRichText(html: Data(html.utf8))

        let content = reader.read(from: pasteboard)

        #expect(content?.kind == .rich)
        #expect(content?.text == "Première ligne\n\nSeconde & dernière")
        // La feuille de style n'est pas du texte lisible.
        #expect(content?.text?.contains("color") == false)
    }

    // MARK: Image

    @Test("L'image l'emporte sur le texte et porte ses dimensions en pixels")
    func imageWinsOverText() {
        let pasteboard = FakePasteboard()
        let png = makeImage(width: 24, height: 16, format: .png)
        pasteboard.writeImage(png: png, text: "capture d'écran")

        let content = reader.read(from: pasteboard)

        #expect(content?.kind == .image)
        #expect(content?.imageData == png)
        #expect(content?.pixelSize == CGSize(width: 24, height: 16))
        #expect(content?.text == nil)
        #expect(content?.byteCount == png.count)
    }

    @Test("Sans PNG, l'image est lue en TIFF")
    func imageFallsBackToTIFF() {
        let pasteboard = FakePasteboard()
        let tiff = makeImage(width: 8, height: 4, format: .tiff)
        pasteboard.writeImage(tiff: tiff)

        let content = reader.read(from: pasteboard)

        #expect(content?.kind == .image)
        #expect(content?.imageData == tiff)
        #expect(content?.pixelSize == CGSize(width: 8, height: 4))
    }

    // MARK: Rejets

    @Test("Un presse-papiers sans représentation exploitable ne donne rien")
    func unusableRepresentation() {
        let pasteboard = FakePasteboard()
        pasteboard.write(["com.exemple.format-proprietaire": Data([0x01, 0x02])])

        #expect(reader.read(from: pasteboard) == nil)
    }

    @Test("Un presse-papiers vide ne donne rien")
    func emptyPasteboard() {
        let pasteboard = FakePasteboard()
        pasteboard.clear()

        #expect(reader.read(from: pasteboard) == nil)
    }

    @Test("Un texte réduit à des espaces est ignoré", arguments: ["", "   ", "\n\t "])
    func blankTextIsIgnored(text: String) {
        let pasteboard = FakePasteboard()
        pasteboard.writeText(text)

        #expect(reader.read(from: pasteboard) == nil)
    }

    @Test("Une représentation présente mais vide est ignorée")
    func emptyRepresentationIsIgnored() {
        let pasteboard = FakePasteboard()
        pasteboard.writeImage(png: Data())

        #expect(reader.read(from: pasteboard) == nil)
    }

    @Test("Un texte de plus de 4 Mo est ignoré silencieusement")
    func oversizedTextIsIgnored() {
        let pasteboard = FakePasteboard()
        pasteboard.writeText(String(repeating: "a", count: Limits.itemBytes + 1))

        #expect(reader.read(from: pasteboard) == nil)
    }

    @Test("Une image de plus de 4 Mo est ignorée silencieusement")
    func oversizedImageIsIgnored() {
        let pasteboard = FakePasteboard()
        pasteboard.writeImage(png: Data(repeating: 0x2A, count: Limits.itemBytes + 1))

        #expect(reader.read(from: pasteboard) == nil)
    }

    /// La limite s'apprécie sur la représentation la plus lourde : un RTF surdimensionné ne
    /// doit pas se faire enregistrer sous couvert de sa projection texte, qui tient, elle.
    @Test("Un texte enrichi surdimensionné ne retombe pas sur le texte brut")
    func oversizedRichTextDoesNotFallBack() {
        let pasteboard = FakePasteboard()
        pasteboard.writeRichText(
            rtf: Data(repeating: 0x20, count: Limits.itemBytes + 1), text: "court"
        )

        #expect(reader.read(from: pasteboard) == nil)
    }

    @Test("Un contenu tout juste sous la limite est accepté")
    func contentAtLimitIsAccepted() {
        let pasteboard = FakePasteboard()
        pasteboard.writeText(String(repeating: "a", count: Limits.itemBytes))

        #expect(reader.read(from: pasteboard)?.byteCount == Limits.itemBytes)
    }
}
