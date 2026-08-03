import CopyDraftCore
import Foundation
import Testing

@testable import CopyDraftUI

/// Ligne de métadonnées d'une cellule (§2.5), en français et en anglais.
///
/// Aucune date n'est prise à l'horloge : `now` est construit une fois pour toutes à partir de
/// composantes explicites, dans le fuseau de la machine, et tous les éléments s'y rapportent.
/// Les tests restent donc justes quel que soit le moment et le lieu où ils tournent.
@Suite("Métadonnées de cellule")
struct ItemMetadataTests {

    // MARK: Fixtures

    static let french = Locale(identifier: "fr_FR")
    static let english = Locale(identifier: "en_US")

    /// Jeudi 12 mars 2026, 14 h 30, heure locale.
    static let now: Date = {
        Calendar.current.date(
            from: DateComponents(year: 2026, month: 3, day: 12, hour: 14, minute: 30)
        )!
    }()

    /// Mercredi 11 mars 2026, 18 h 42 — « hier » par rapport à ``now``.
    static let yesterday: Date = {
        Calendar.current.date(
            from: DateComponents(year: 2026, month: 3, day: 11, hour: 18, minute: 42)
        )!
    }()

    static func item(
        subtype: ClipSubtype,
        kind: ClipKind = .text,
        createdAt: Date = ItemMetadataTests.now.addingTimeInterval(-240),
        appName: String = "Xcode",
        byteCount: Int = 62,
        pixelSize: CGSize? = nil,
        characterCount: Int? = 62,
        previewLines: [String] = ["aperçu"]
    ) -> ClipItem {
        ClipItem(
            kind: kind,
            subtype: subtype,
            createdAt: createdAt,
            source: SourceApp(bundleIdentifier: "com.apple.dt.Xcode", name: appName),
            byteCount: byteCount,
            pixelSize: pixelSize,
            characterCount: characterCount,
            searchText: previewLines.joined(separator: " "),
            previewLines: previewLines
        )
    }

    /// Ramène espaces fines, insécables et étroites à une espace ordinaire.
    ///
    /// Le design system demande des espaces fines autour du « · » et les formateurs de
    /// Foundation en glissent d'autres dans « 1 512 » ou « 6:42 PM ». Les comparer telles
    /// quelles rendrait les tests illisibles et les casserait au premier changement d'ICU ;
    /// ce qui est vérifié ici, c'est le contenu de la ligne, pas la largeur de ses blancs.
    static func normalized(_ text: String) -> String {
        String(text.map { $0.isWhitespace ? " " : $0 })
    }

    static func line(
        _ item: ClipItem, showSourceApp: Bool = true, locale: Locale
    ) -> String {
        normalized(
            ItemMetadata.line(for: item, showSourceApp: showSourceApp, now: now, locale: locale)
        )
    }

    // MARK: Texte

    @Test("Texte — français")
    func plainFrench() {
        #expect(
            Self.line(Self.item(subtype: .plain), locale: Self.french)
                == "Xcode · il y a 4 min · 62 caractères"
        )
    }

    @Test("Texte — anglais")
    func plainEnglish() {
        #expect(
            Self.line(Self.item(subtype: .plain), locale: Self.english)
                == "Xcode · 4 min. ago · 62 characters"
        )
    }

    @Test("Un seul caractère — accord du singulier")
    func singleCharacter() {
        let item = Self.item(subtype: .plain, byteCount: 1, characterCount: 1)
        #expect(Self.line(item, locale: Self.french) == "Xcode · il y a 4 min · 1 caractère")
        #expect(Self.line(item, locale: Self.english) == "Xcode · 4 min. ago · 1 character")
    }

    @Test("Nombre de caractères groupé selon la langue")
    func groupedCharacterCount() {
        let item = Self.item(subtype: .plain, characterCount: 1_512)
        #expect(Self.line(item, locale: Self.french) == "Xcode · il y a 4 min · 1 512 caractères")
        #expect(Self.line(item, locale: Self.english) == "Xcode · 4 min. ago · 1,512 characters")
    }

    @Test("Texte sans compte de caractères — le segment disparaît")
    func missingCharacterCount() {
        let item = Self.item(subtype: .plain, characterCount: nil)
        #expect(Self.line(item, locale: Self.french) == "Xcode · il y a 4 min")
    }

    // MARK: Code

    @Test("Code — compté en caractères comme le texte")
    func code() {
        let item = Self.item(
            subtype: .code, appName: "Xcode", characterCount: 68,
            previewLines: ["timer = Timer.scheduledTimer(", "withTimeInterval: 0.4)"]
        )
        #expect(Self.line(item, locale: Self.french) == "Xcode · il y a 4 min · 68 caractères")
        #expect(Self.line(item, locale: Self.english) == "Xcode · 4 min. ago · 68 characters")
    }

    // MARK: Image

    @Test("Image — dimensions puis poids")
    func image() {
        let item = Self.item(
            subtype: .image,
            kind: .image,
            createdAt: Self.now.addingTimeInterval(-26 * 60),
            appName: "Aperçu",
            byteCount: 1_200_000,
            pixelSize: CGSize(width: 1_512, height: 982),
            characterCount: nil,
            previewLines: []
        )
        #expect(
            Self.line(item, locale: Self.french)
                == "Aperçu · il y a 26 min · 1 512 × 982 · 1,2 Mo"
        )
        #expect(
            Self.line(item, locale: Self.english)
                == "Aperçu · 26 min. ago · 1,512 × 982 · 1.2 MB"
        )
    }

    @Test("Image sans dimensions connues — seul le poids reste")
    func imageWithoutPixelSize() {
        let item = Self.item(
            subtype: .image, kind: .image, appName: "Aperçu",
            byteCount: 1_200_000, pixelSize: nil, characterCount: nil, previewLines: []
        )
        #expect(Self.line(item, locale: Self.french) == "Aperçu · il y a 4 min · 1,2 Mo")
    }

    @Test("Très gros volume — l'unité suit")
    func largeVolume() {
        let item = Self.item(
            subtype: .image, kind: .image, appName: "Aperçu",
            byteCount: 4_294_967_296,
            pixelSize: CGSize(width: 12_000, height: 8_000),
            characterCount: nil, previewLines: []
        )
        #expect(
            Self.line(item, locale: Self.french)
                == "Aperçu · il y a 4 min · 12 000 × 8 000 · 4,29 Go"
        )
        #expect(
            Self.line(item, locale: Self.english)
                == "Aperçu · 4 min. ago · 12,000 × 8,000 · 4.29 GB"
        )
    }

    // MARK: Chemin, lien, couleur, enrichi

    @Test("Chemin — « hier, 18:42 » puis la nature du contenu")
    func path() {
        let item = Self.item(
            subtype: .path, createdAt: Self.yesterday, appName: "Finder",
            previewLines: ["~/Developer/copydraft/Sources/ClipboardMonitor.swift"]
        )
        #expect(Self.line(item, locale: Self.french) == "Finder · hier, 18:42 · chemin")
        #expect(Self.line(item, locale: Self.english) == "Finder · yesterday, 6:42 PM · path")
    }

    @Test("Lien — l'adresse se suffit, pas de troisième segment")
    func link() {
        let item = Self.item(
            subtype: .link, createdAt: Self.now.addingTimeInterval(-18 * 60), appName: "Safari",
            previewLines: ["developer.apple.com/design/human-interface-guidelines/materials"]
        )
        #expect(Self.line(item, locale: Self.french) == "Safari · il y a 18 min")
        #expect(Self.line(item, locale: Self.english) == "Safari · 18 min. ago")
    }

    @Test("Couleur")
    func color() {
        let item = Self.item(
            subtype: .color, createdAt: Self.yesterday, appName: "Sketch",
            previewLines: ["#0A84FF"]
        )
        #expect(Self.line(item, locale: Self.french) == "Sketch · hier, 18:42 · couleur")
        #expect(Self.line(item, locale: Self.english) == "Sketch · yesterday, 6:42 PM · color")
    }

    @Test("Texte enrichi")
    func rich() {
        let item = Self.item(
            subtype: .rich, kind: .rich, createdAt: Self.yesterday, appName: "Notes",
            previewLines: ["Sprint 24 — revue de design jeudi 14 h"]
        )
        #expect(Self.line(item, locale: Self.french) == "Notes · hier, 18:42 · texte enrichi")
        #expect(Self.line(item, locale: Self.english) == "Notes · yesterday, 6:42 PM · rich text")
    }

    // MARK: Application source

    @Test("Application masquée — la ligne commence à l'horodatage")
    func hiddenSourceApp() {
        let item = Self.item(subtype: .plain)
        #expect(
            Self.line(item, showSourceApp: false, locale: Self.french)
                == "il y a 4 min · 62 caractères"
        )
        #expect(
            Self.line(item, showSourceApp: false, locale: Self.english)
                == "4 min. ago · 62 characters"
        )
    }

    @Test("Application inconnue — aucun segment vide")
    func unknownSourceApp() {
        let item = ClipItem(
            kind: .text,
            subtype: .plain,
            createdAt: Self.now.addingTimeInterval(-240),
            source: .unknown,
            byteCount: 62,
            characterCount: 62,
            searchText: "aperçu",
            previewLines: ["aperçu"]
        )
        #expect(Self.line(item, locale: Self.french) == "il y a 4 min · 62 caractères")
        #expect(Self.line(item, locale: Self.english) == "4 min. ago · 62 characters")
    }

    // MARK: Horodatage

    @Test("Copie à l'instant")
    func justNow() {
        let item = Self.item(subtype: .plain, createdAt: Self.now, characterCount: nil)
        #expect(Self.line(item, locale: Self.french) == "Xcode · maintenant")
        #expect(Self.line(item, locale: Self.english) == "Xcode · now")
    }

    @Test("Même journée — heures relatives, pas de date")
    func sameDay() {
        let item = Self.item(
            subtype: .plain, createdAt: Self.now.addingTimeInterval(-3 * 3_600),
            characterCount: nil
        )
        #expect(Self.line(item, locale: Self.french) == "Xcode · il y a 3 h")
    }

    @Test("Plus vieux qu'hier — date courte puis heure")
    func olderThanYesterday() {
        let older = Calendar.current.date(
            from: DateComponents(year: 2026, month: 1, day: 5, hour: 9, minute: 12)
        )!
        let item = Self.item(subtype: .plain, createdAt: older, characterCount: nil)
        #expect(Self.line(item, locale: Self.french) == "Xcode · 5 janv., 09:12")
        #expect(Self.line(item, locale: Self.english) == "Xcode · Jan 5, 9:12 AM")
    }

    @Test("Année différente — l'année apparaît")
    func previousYear() {
        let older = Calendar.current.date(
            from: DateComponents(year: 2025, month: 11, day: 2, hour: 9, minute: 12)
        )!
        let item = Self.item(subtype: .plain, createdAt: older, characterCount: nil)
        #expect(Self.line(item, locale: Self.french) == "Xcode · 2 nov. 2025, 09:12")
        #expect(Self.line(item, locale: Self.english) == "Xcode · Nov 2, 2025, 9:12 AM")
    }

    // MARK: Séparateur

    @Test("Le séparateur est un point médian encadré d'espaces fines (§2.5)")
    func separator() {
        #expect(ItemMetadata.separator == "\u{2009}·\u{2009}")
        let raw = ItemMetadata.line(
            for: Self.item(subtype: .plain), showSourceApp: true,
            now: Self.now, locale: Self.french
        )
        #expect(raw.contains("\u{2009}·\u{2009}"))
    }

    // MARK: Accessibilité (NFR-12)

    @Test("Libellé VoiceOver — type, aperçu, application, horodatage, épinglé")
    func accessibilityLabel() {
        var item = Self.item(subtype: .code, previewLines: ["let x = 1"])
        item.pinned = true
        let label = Self.normalized(
            ItemMetadata.accessibilityLabel(
                for: item, preview: "let x = 1", showSourceApp: true,
                now: Self.now, locale: Self.french
            )
        )
        #expect(label == "code, let x = 1, Xcode, il y a 4 min, épinglé")
    }

    @Test("Libellé VoiceOver — sans épingle ni application")
    func accessibilityLabelWithoutPin() {
        let item = Self.item(subtype: .link, previewLines: ["apple.com"])
        let label = Self.normalized(
            ItemMetadata.accessibilityLabel(
                for: item, preview: "apple.com", showSourceApp: false,
                now: Self.now, locale: Self.english
            )
        )
        #expect(label == "link, apple.com, 4 min. ago")
    }

    @Test("Rang annoncé après le libellé")
    func accessibilityRank() {
        #expect(
            Self.normalized(
                ItemMetadata.accessibilityRank(index: 3, total: 1_025, locale: Self.french)
            ) == "rang 3 sur 1 025"
        )
        #expect(
            Self.normalized(
                ItemMetadata.accessibilityRank(index: 3, total: 1_025, locale: Self.english)
            ) == "row 3 of 1,025"
        )
    }

    // MARK: Repli de langue

    @Test("Langue non couverte — l'anglais sert de repli")
    func unsupportedLanguageFallsBackToEnglish() {
        let japanese = Locale(identifier: "ja_JP")
        #expect(
            ItemMetadata.Vocabulary.subtypeName(.path, locale: japanese)
                == ItemMetadata.Vocabulary.subtypeName(.path, locale: Self.english)
        )
    }
}
