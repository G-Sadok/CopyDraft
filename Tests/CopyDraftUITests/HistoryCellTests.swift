import AppKit
import CopyDraftCore
import SwiftUI
import Testing

@testable import CopyDraftUI

/// Cellule d'historique (§2.5) : cotes, contenu, et instantanés de contrôle.
///
/// Deux familles de vérifications. Les premières mesurent et lisent ce que la cellule produit —
/// hauteurs, lignes d'aperçu, indices, aperçu enrichi — et tournent toujours. Les secondes
/// rendent la cellule en PNG pour un contrôle à l'œil : elles ne s'exécutent que sous
/// `CD_SNAPSHOTS=1`, comme celles de la galerie de tokens.
@MainActor
@Suite("Cellule d'historique")
struct HistoryCellTests {

    // MARK: Fixtures

    static let now: Date = {
        Calendar.current.date(
            from: DateComponents(year: 2026, month: 3, day: 12, hour: 14, minute: 30)
        )!
    }()

    static let yesterday: Date = {
        Calendar.current.date(
            from: DateComponents(year: 2026, month: 3, day: 11, hour: 18, minute: 42)
        )!
    }()

    static func item(
        subtype: ClipSubtype,
        kind: ClipKind = .text,
        createdAt: Date = HistoryCellTests.now.addingTimeInterval(-240),
        pinned: Bool = false,
        customName: String? = nil,
        appName: String = "Xcode",
        byteCount: Int = 62,
        pixelSize: CGSize? = nil,
        characterCount: Int? = 62,
        previewLines: [String]
    ) -> ClipItem {
        ClipItem(
            kind: kind,
            subtype: subtype,
            createdAt: createdAt,
            pinned: pinned,
            customName: customName,
            source: SourceApp(bundleIdentifier: "com.example.\(appName)", name: appName),
            byteCount: byteCount,
            pixelSize: pixelSize,
            characterCount: characterCount,
            searchText: previewLines.joined(separator: " "),
            previewLines: previewLines
        )
    }

    static func cell(
        _ item: ClipItem,
        isSelected: Bool = false,
        shortcutIndex: Int? = 1,
        showSourceApp: Bool = true,
        thumbnail: Image? = nil
    ) -> HistoryCell {
        HistoryCell(
            item: item,
            isSelected: isSelected,
            shortcutIndex: shortcutIndex,
            showSourceApp: showSourceApp,
            thumbnail: thumbnail,
            appIcon: nil,
            richPreview: nil,
            onTogglePin: {}
        )
    }

    // MARK: Indice ⌘n (§2.4)

    @Test("Rangs 1 à 9 puis ⌘0, rien au-delà")
    func shortcutSymbols() {
        #expect(HistoryCell.shortcutSymbol(for: 1) == "⌘1")
        #expect(HistoryCell.shortcutSymbol(for: 9) == "⌘9")
        #expect(HistoryCell.shortcutSymbol(for: 10) == "⌘0")
        #expect(HistoryCell.shortcutSymbol(for: 11) == nil)
        #expect(HistoryCell.shortcutSymbol(for: 0) == nil)
    }

    // MARK: Lignes d'aperçu

    @Test("Un nom personnalisé remplace la première ligne, pas la seconde")
    func customNameReplacesFirstLine() {
        let cell = Self.cell(
            Self.item(
                subtype: .code, customName: "Timer de veille",
                previewLines: ["timer = Timer.scheduledTimer(", "withTimeInterval: 0.4)"]
            )
        )
        #expect(cell.previewLines == ["Timer de veille", "withTimeInterval: 0.4)"])
    }

    @Test("Une image sans nom montre au moins son type")
    func imageWithoutNameFallsBackToItsType() {
        let cell = Self.cell(
            Self.item(subtype: .image, kind: .image, characterCount: nil, previewLines: [])
        )
        #expect(cell.previewLines == ["Image"])
    }

    @Test("Une image nommée montre son nom")
    func namedImageShowsItsName() {
        let cell = Self.cell(
            Self.item(
                subtype: .image, kind: .image, customName: "Capture d'écran",
                characterCount: nil, previewLines: []
            )
        )
        #expect(cell.previewLines == ["Capture d'écran"])
    }

    // MARK: États (§2.5)

    @Test("La sélection l'emporte sur le survol, l'appui sur tout")
    func appearancePrecedence() {
        #expect(Self.cell(Self.item(subtype: .plain, previewLines: ["a"])).appearance == .rest)
        #expect(
            Self.cell(Self.item(subtype: .plain, previewLines: ["a"])).hovering(true).appearance
                == .hover
        )
        #expect(
            Self.cell(Self.item(subtype: .plain, previewLines: ["a"]), isSelected: true)
                .hovering(true).appearance == .selected
        )
    }

    // MARK: Aperçu du texte enrichi

    @Test("Le RTF ne garde que gras et italique")
    func richPreviewKeepsOnlyBoldAndItalic() throws {
        let source = NSMutableAttributedString()
        source.append(
            NSAttributedString(
                string: "Sprint 24 — ",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 24),
                    .foregroundColor: NSColor.systemPurple
                ]
            )
        )
        let italic = NSFontManager.shared.convert(
            NSFont.systemFont(ofSize: 24), toHaveTrait: .italicFontMask
        )
        source.append(
            NSAttributedString(string: "revue de design", attributes: [.font: italic])
        )
        source.append(
            NSAttributedString(
                string: "\n\n jeudi 14 h ", attributes: [.font: NSFont.boldSystemFont(ofSize: 24)]
            )
        )

        let rtf = try #require(
            source.rtf(from: NSRange(location: 0, length: source.length), documentAttributes: [:])
        )
        let preview = try #require(HistoryCell.richPreview(fromRTF: rtf))

        #expect(String(preview.characters) == "Sprint 24 — revue de design jeudi 14 h")

        let runs = preview.runs.map { (String(preview[$0.range].characters), $0.inlinePresentationIntent) }
        let italicRun = try #require(runs.first { $0.0.contains("revue de design") })
        #expect(italicRun.1 == .emphasized)
        let boldRun = try #require(runs.first { $0.0.contains("jeudi") })
        #expect(boldRun.1 == .stronglyEmphasized)
        // Ni couleur ni corps ne survivent : le seul attribut porté est l'intention.
        for run in preview.runs {
            var expected = AttributeContainer()
            if let intent = run.inlinePresentationIntent {
                expected.inlinePresentationIntent = intent
            }
            #expect(run.attributes == expected)
        }
    }

    @Test("Un RTF illisible ne fait rien planter")
    func richPreviewRejectsGarbage() {
        #expect(HistoryCell.richPreview(fromRTF: Data([0x00, 0x01, 0x02])) == nil)
        #expect(HistoryCell.richPreview(fromRTF: Data()) == nil)
    }

    @Test("Les blancs sont ramenés à une espace, les bords préservés")
    func whitespaceCollapsing() {
        #expect(HistoryCell.collapsedWhitespace("a\n\n  b\tc") == "a b c")
        #expect(HistoryCell.collapsedWhitespace("  bord ") == " bord ")
        #expect(HistoryCell.collapsedWhitespace("   ") == "")
    }

    // MARK: Cotes (§2.5)

    @Test("Une ligne d'aperçu tient dans 44 pt, deux dans 60 pt, jamais plus")
    @MainActor
    func cellHeights() throws {
        let single = Self.item(subtype: .plain, previewLines: ["Merci pour votre message."])
        #expect(Self.measuredHeight(Self.cell(single)) == CD.Metric.cellHeightMin)

        let two = Self.item(
            subtype: .code, characterCount: 68,
            previewLines: ["timer = Timer.scheduledTimer(", "withTimeInterval: 0.4, repeats: true)"]
        )
        let twoLineHeight = Self.measuredHeight(Self.cell(two))
        #expect(twoLineHeight > CD.Metric.cellHeightMin)
        #expect(twoLineHeight <= CD.Metric.cellHeightMax)

        // Un paragraphe aplati que la vue étale sur deux lignes n'a pas le droit d'aller plus loin.
        let wrapped = Self.item(
            subtype: .plain, characterCount: 240,
            previewLines: [String(repeating: "Un très long paragraphe de démonstration. ", count: 6)]
        )
        #expect(Self.measuredHeight(Self.cell(wrapped)) <= CD.Metric.cellHeightMax)
    }

    @MainActor
    static func measuredHeight(_ cell: HistoryCell) -> CGFloat {
        let renderer = ImageRenderer(
            content: cell
                .historyCellNow(now)
                .environment(\.locale, Locale(identifier: "fr_FR"))
                .frame(width: CD.Metric.cellWidth)
        )
        return renderer.nsImage?.size.height ?? 0
    }

    // MARK: Instantanés

    @MainActor
    @Test(
        "Instantanés — états et types de contenu",
        .enabled(if: ProcessInfo.processInfo.environment["CD_SNAPSHOTS"] == "1"),
        arguments: [NSAppearance.Name.aqua, NSAppearance.Name.darkAqua]
    )
    func renderStates(appearance name: NSAppearance.Name) throws {
        try Self.render(
            HistoryCellGallery(now: Self.now),
            appearance: name,
            named: "history-cell"
        )
    }

    @MainActor
    @Test(
        "Instantanés — liste de la popup",
        .enabled(if: ProcessInfo.processInfo.environment["CD_SNAPSHOTS"] == "1"),
        arguments: [NSAppearance.Name.aqua, NSAppearance.Name.darkAqua]
    )
    func renderList(appearance name: NSAppearance.Name) throws {
        try Self.render(
            HistoryListMock(now: Self.now),
            appearance: name,
            named: "history-list"
        )
    }

    /// Rend une vue en PNG dans `dist/snapshots/`.
    ///
    /// - Note: `ImageRenderer` ne rend pas le contenu d'un `ScrollView` — les vues d'instantané
    ///   sont donc de simples piles, comme `TokenGalleryContent`.
    @MainActor
    static func render(_ content: some View, appearance name: NSAppearance.Name, named: String) throws {
        let appearance = try #require(NSAppearance(named: name))
        let directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("dist/snapshots")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        var data: Data?
        appearance.performAsCurrentDrawingAppearance {
            let renderer = ImageRenderer(
                content: content
                    .environment(\.colorScheme, name == .darkAqua ? .dark : .light)
                    .environment(\.locale, Locale(identifier: "fr_FR"))
            )
            renderer.scale = 2
            guard let image = renderer.nsImage,
                let tiff = image.tiffRepresentation,
                let bitmap = NSBitmapImageRep(data: tiff)
            else { return }
            data = bitmap.representation(using: .png, properties: [:])
        }

        let png = try #require(data, "rendu impossible")
        let suffix = name == .darkAqua ? "dark" : "light"
        try png.write(to: directory.appendingPathComponent("\(named)-\(suffix).png"))
        #expect(png.count > 10_000, "image suspecte : \(png.count) octets")
    }
}

// MARK: - Vues d'instantané

/// Jeu d'éléments de démonstration, un par type de contenu du §2.5.
@MainActor
enum HistoryCellSamples {
    static func all(now: Date, yesterday: Date) -> [(String, ClipItem)] {
        [
            (
                "texte",
                HistoryCellTests.item(
                    subtype: .plain, createdAt: now.addingTimeInterval(-12 * 60),
                    appName: "Mail", characterCount: 78,
                    previewLines: ["Merci pour votre message, je regarde ça dans la journée."]
                )
            ),
            (
                "code",
                HistoryCellTests.item(
                    subtype: .code, createdAt: now.addingTimeInterval(-240),
                    pinned: true, appName: "Xcode", characterCount: 68,
                    previewLines: [
                        "timer = Timer.scheduledTimer(",
                        "withTimeInterval: 0.4, repeats: true) { _ in poll() }"
                    ]
                )
            ),
            (
                "lien",
                HistoryCellTests.item(
                    subtype: .link, createdAt: now.addingTimeInterval(-18 * 60),
                    appName: "Safari", characterCount: 63,
                    previewLines: [
                        "developer.apple.com/design/human-interface-guidelines/materials"
                    ]
                )
            ),
            (
                "chemin",
                HistoryCellTests.item(
                    subtype: .path, createdAt: yesterday, appName: "Finder", characterCount: 58,
                    previewLines: [
                        "~/Developer/copydraft/Sources/CopyDraftCore/ClipboardMonitor.swift"
                    ]
                )
            ),
            (
                "couleur",
                HistoryCellTests.item(
                    subtype: .color, createdAt: yesterday, appName: "Sketch", characterCount: 7,
                    previewLines: ["#0A84FF"]
                )
            ),
            (
                "image",
                HistoryCellTests.item(
                    subtype: .image, kind: .image, createdAt: now.addingTimeInterval(-26 * 60),
                    customName: "Capture d'écran", appName: "Aperçu", byteCount: 1_200_000,
                    pixelSize: CGSize(width: 1_512, height: 982), characterCount: nil,
                    previewLines: []
                )
            ),
            (
                "enrichi",
                HistoryCellTests.item(
                    subtype: .rich, kind: .rich, createdAt: yesterday,
                    appName: "Notes", characterCount: 38,
                    previewLines: ["Sprint 24 — revue de design jeudi 14 h"]
                )
            )
        ]
    }

    /// Aperçu enrichi de démonstration, passé par le RTF comme le fera la popup : le corps de
    /// 24 pt et le violet doivent avoir disparu de l'instantané, l'italique et le gras non.
    static let richPreview: AttributedString? = {
        let source = NSMutableAttributedString()
        source.append(
            NSAttributedString(
                string: "Sprint 24 — ",
                attributes: [
                    .font: NSFont.boldSystemFont(ofSize: 24),
                    .foregroundColor: NSColor.systemPurple
                ]
            )
        )
        let italic = NSFontManager.shared.convert(
            NSFont.systemFont(ofSize: 24), toHaveTrait: .italicFontMask
        )
        source.append(
            NSAttributedString(string: "revue de design", attributes: [.font: italic])
        )
        source.append(
            NSAttributedString(
                string: " jeudi 14 h", attributes: [.font: NSFont.systemFont(ofSize: 24)]
            )
        )
        guard
            let rtf = source.rtf(
                from: NSRange(location: 0, length: source.length), documentAttributes: [:]
            )
        else { return nil }
        return HistoryCell.richPreview(fromRTF: rtf)
    }()

    /// Miniature synthétique : un dégradé suffit à juger du cadrage et du rayon.
    @MainActor
    static let thumbnail: Image = {
        let size = NSSize(width: 151, height: 98)
        let image = NSImage(size: size)
        image.lockFocus()
        NSGradient(starting: .systemTeal, ending: .systemIndigo)?
            .draw(in: NSRect(origin: .zero, size: size), angle: 45)
        image.unlockFocus()
        return Image(nsImage: image)
    }()
}

/// Matrice « types de contenu × états » du §2.5, sur le fond opaque de la popup.
struct HistoryCellGallery: View {
    let now: Date

    private static let states: [(String, Bool, Bool, Bool)] = [
        ("repos", false, false, false),
        ("survol", true, false, false),
        ("sélectionné", false, true, false),
        ("pressé", false, false, true)
    ]

    var body: some View {
        HStack(alignment: .top, spacing: CD.Space.x6) {
            ForEach(Array(Self.states.enumerated()), id: \.offset) { _, state in
                VStack(alignment: .leading, spacing: CD.Space.x1) {
                    Text(state.0)
                        .font(CD.Font.micro)
                        .foregroundStyle(CD.Color.text2)
                    VStack(spacing: CD.Metric.popupCellGap) {
                        ForEach(
                            Array(
                                HistoryCellSamples.all(
                                    now: now, yesterday: HistoryCellTests.yesterday
                                ).enumerated()
                            ),
                            id: \.offset
                        ) { index, sample in
                            HistoryCell(
                                item: sample.1,
                                isSelected: state.2,
                                shortcutIndex: index + 1,
                                showSourceApp: true,
                                thumbnail: sample.1.subtype == .image
                                    ? HistoryCellSamples.thumbnail : nil,
                                appIcon: nil,
                                richPreview: sample.1.subtype == .rich
                                    ? HistoryCellSamples.richPreview : nil,
                                onTogglePin: {}
                            )
                            .hovering(state.1)
                            .historyCellRank(index + 1, of: 7)
                            .environment(\.historyCellIsPressed, state.3)
                        }
                    }
                    .frame(width: CD.Metric.cellWidth)
                }
            }
        }
        .historyCellNow(now)
        .padding(CD.Space.x5)
        .background(CD.Color.bgPopoverSolid)
    }
}

/// Reproduction de la liste de `design-system/screenshots/proto4.png`, à l'échelle 1:1.
struct HistoryListMock: View {
    let now: Date

    var body: some View {
        let samples = HistoryCellSamples.all(now: now, yesterday: HistoryCellTests.yesterday)
        return VStack(alignment: .leading, spacing: CD.Metric.popupCellGap) {
            SectionHeader(title: "Épinglés")
            cell(samples[1], index: 1, isSelected: true)
            SectionHeader(title: "Récents")
            cell(samples[2], index: 2)
            cell(samples[0], index: 3)
            cell(samples[5], index: 4)
            cell(samples[3], index: 5)
            cell(samples[4], index: 6)
            cell(samples[6], index: 7)
        }
        .historyCellNow(now)
        .frame(width: CD.Metric.cellWidth)
        .padding(CD.Metric.popupInnerPadding)
        .background(CD.Color.bgPopoverSolid)
        .clipShape(RoundedRectangle(cornerRadius: CD.Radius.popover, style: .continuous))
        .padding(CD.Space.x5)
        .background(CD.Color.bgWindow)
    }

    private func cell(
        _ sample: (String, ClipItem), index: Int, isSelected: Bool = false
    ) -> some View {
        HistoryCell(
            item: sample.1,
            isSelected: isSelected,
            shortcutIndex: index,
            showSourceApp: true,
            thumbnail: sample.1.subtype == .image ? HistoryCellSamples.thumbnail : nil,
            appIcon: nil,
            richPreview: sample.1.subtype == .rich ? HistoryCellSamples.richPreview : nil,
            onTogglePin: {}
        )
        .historyCellRank(index, of: 7)
    }
}
