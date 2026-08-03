import CoreGraphics
import Foundation
import Testing

@testable import CopyDraftCore

@Suite("Classification du contenu")
struct ContentClassifierTests {
    private let classifier = ContentClassifier()

    private func classify(_ value: String, kind: ClipKind = .text) -> ClipSubtype {
        classifier.classify(
            CapturedContent(kind: kind, text: value, byteCount: value.utf8.count)
        )
    }

    // MARK: Image

    @Test("Une image est classée image sans que son contenu soit lu")
    func imageWins() {
        let content = CapturedContent(
            kind: .image,
            text: "SELECT id FROM clip_item WHERE pinned = 1",
            imageData: Data([0x89, 0x50, 0x4E, 0x47]),
            pixelSize: CGSize(width: 1512, height: 982),
            byteCount: 4
        )
        #expect(classifier.classify(content) == .image)
    }

    // MARK: Lien

    @Test(
        "Une ligne entièrement occupée par une URL est un lien",
        arguments: [
            "https://developer.apple.com/design/human-interface-guidelines/materials",
            "http://exemple.fr",
            "https://exemple.fr/chemin?q=copy%20draft&page=2#ancre",
            "ftp://ftp.gnu.org/pub/gnu/",
            "mailto:sadok@exemple.fr",
            "www.apple.com/fr/",
            "  https://exemple.fr  ",
        ]
    )
    func links(_ value: String) {
        #expect(classify(value) == .link)
    }

    @Test(
        "Une URL noyée dans une phrase n'est pas un lien",
        arguments: [
            "Va voir https://developer.apple.com pour les détails.",
            "https://exemple.fr est le nouveau site.",
            "Deux liens : https://a.fr https://b.fr",
        ]
    )
    func urlInsideSentence(_ value: String) {
        #expect(classify(value) == .plain)
    }

    @Test("Une URL suivie d'une seconde ligne n'est plus un lien")
    func multilineURL() {
        #expect(classify("https://exemple.fr\nà lire ce soir") == .plain)
    }

    @Test(
        "Une amorce de lien incomplète reste du texte",
        arguments: ["https://", "www.", "www.fr", "mailto:", "mailto:@exemple.fr"]
    )
    func incompleteLinks(_ value: String) {
        #expect(classify(value) == .plain)
    }

    // MARK: Chemin

    @Test(
        "Les chemins absolus, tilde et file:// sont des chemins",
        arguments: [
            "/Users/sadok/Developer/copydraft/Sources/CopyDraftCore/Model/ClipItem.swift",
            "/etc/hosts",
            "~/Developer/copydraft/README.md",
            "file:///Users/sadok/Documents/rapport.pdf",
            "/Users/sadok/Mes documents/note de frais.txt",
        ]
    )
    func paths(_ value: String) {
        #expect(classify(value) == .path)
    }

    @Test("Un chemin Windows n'est pas reconnu comme chemin")
    func windowsPath() {
        #expect(classify(#"C:\Users\Sadok\Documents\rapport.docx"#) == .plain)
    }

    @Test(
        "Une phrase qui commence par une barre oblique n'est pas un chemin",
        arguments: ["/ ou alors on annule tout", "/", "Sources/CopyDraftCore/Model"]
    )
    func notPaths(_ value: String) {
        #expect(classify(value) == .plain)
    }

    // MARK: Couleur

    @Test(
        "Les notations de couleur CSS sont reconnues",
        arguments: [
            "#fff",
            "#0A84FF",
            "#0A84FF80",
            "rgb(10, 132, 255)",
            "rgba(10,132,255,0.5)",
            "hsl(211, 100%, 50%)",
            "hsla(211, 100%, 50%, 0.5)",
            "rgb(10 132 255 / 0.5)",
            "hsl(211deg 100% 50%)",
            "   #0A84FF   ",
        ]
    )
    func colors(_ value: String) {
        #expect(classify(value) == .color)
    }

    @Test(
        "Un dièse qui n'est pas une couleur reste du texte",
        arguments: [
            "# Rapport hebdomadaire",
            "## Notes de version",
            "#0A84F",
            "#Sprint",
            "#copydraft",
            "rgb(255)",
            "rgb(dix, cent, deux-cents)",
        ]
    )
    func notColors(_ value: String) {
        #expect(classify(value) == .plain)
    }

    // MARK: Code

    @Test("Un extrait Swift est du code")
    func swiftSnippet() {
        let snippet = """
            func startMonitoring() {
                timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
                    self.poll()
                }
            }
            """
        #expect(classify(snippet) == .code)
    }

    @Test("Une requête SQL en majuscules est du code")
    func uppercaseSQL() {
        #expect(classify("SELECT id, created_at FROM clip_item WHERE pinned = 1") == .code)
    }

    @Test("La même requête en minuscules est du code aussi")
    func lowercaseSQL() {
        #expect(classify("select id, created_at from clip_item where pinned = 1") == .code)
    }

    @Test("Un objet JSON est du code")
    func json() {
        let payload = """
            {
              "id": "9F2A-4C1D",
              "pinned": true,
              "characterCount": 62
            }
            """
        #expect(classify(payload) == .code)
    }

    @Test("Un objet JSON tenant sur une ligne est du code")
    func inlineJSON() {
        #expect(classify(#"{"id": "9F2A", "pinned": true}"#) == .code)
    }

    @Test("Une directive du préprocesseur C est du code")
    func cSnippet() {
        let snippet = """
            #include <stdio.h>
            int main(void) {
                printf("bonjour");
                return 0;
            }
            """
        #expect(classify(snippet) == .code)
    }

    // MARK: Cas ambigus — le doute profite au texte

    @Test("Une phrase française contenant « return » reste du texte")
    func frenchSentenceWithReturn() {
        #expect(classify("Je vous return le dossier dès demain, merci de votre patience.") == .plain)
    }

    @Test("Deux mots-clés isolés dans une phrase ne suffisent pas")
    func frenchSentenceWithTwoKeywords() {
        #expect(classify("Il faut return ce colis et faire un import avant la fin du mois.") == .plain)
    }

    @Test("Les parenthèses d'accord du français ne font pas basculer une phrase en code")
    func frenchInclusiveParentheses() {
        let sentence = "Merci de return le(s) formulaire(s) au(x) service(s) concerné(s)."
        #expect(classify(sentence) == .plain)
    }

    @Test("Un paragraphe de prose multiligne reste du texte")
    func prose() {
        let text = """
            Bonjour Camille,

            Merci pour ton retour sur la maquette. Je reprends la cellule cette semaine et
            je te renvoie une version jeudi.
            """
        #expect(classify(text) == .plain)
    }

    // MARK: Texte enrichi

    @Test("Un texte enrichi sans autre indice est classé enrichi")
    func rich() {
        #expect(classify("Sprint 24 — revue de design\njeudi 14 h", kind: .rich) == .rich)
    }

    @Test("Un texte enrichi qui porte du code est classé code : le contenu prime sur le format")
    func richCodeTakesPriority() {
        #expect(classify("SELECT id FROM clip_item WHERE pinned = 1", kind: .rich) == .code)
    }

    @Test("Un contenu vide retombe sur son type de stockage")
    func emptyFallsBack() {
        #expect(classify("   \n  \n") == .plain)
        #expect(classify("   \n  \n", kind: .rich) == .rich)
        #expect(classifier.classify(CapturedContent(kind: .rich, byteCount: 0)) == .rich)
    }

    // MARK: Robustesse

    @Test("Un texte d'une seule ligne sans indice est du texte")
    func singleLinePlain() {
        #expect(classify("Merci pour votre message, je regarde ça dès que possible.") == .plain)
    }

    @Test("Les fins de ligne Windows donnent la même classification que les fins Unix")
    func windowsNewlines() {
        let unix = "func startMonitoring() {\n    timer = nil\n}"
        let windows = "func startMonitoring() {\r\n    timer = nil\r\n}"
        #expect(classify(unix) == .code)
        #expect(classify(windows) == .code)
        #expect(classify("Première ligne\r\nSeconde ligne") == .plain)
    }

    @Test("Un texte avec émojis ne perturbe pas la classification")
    func emoji() {
        #expect(classify("Bravo 🎉 pour la démo, c'était top 🚀") == .plain)
        #expect(classify("👨‍👩‍👧‍👦") == .plain)
        #expect(classify("https://exemple.fr/🎉") == .link)
    }

    @Test("Un texte de 10 000 caractères est classé sans déborder la fenêtre d'analyse")
    func veryLongText() {
        let long = String(repeating: "Une phrase française tout à fait ordinaire. ", count: 250)
        #expect(long.count >= 10_000)
        #expect(classify(long) == .plain)
    }

    @Test("Un contenu très long n'est jamais pris pour un lien, un chemin ou une couleur")
    func veryLongSingleLineIsNotShortForm() {
        let long = "https://exemple.fr/" + String(repeating: "a", count: 10_000)
        #expect(classify(long) == .plain)
    }
}
