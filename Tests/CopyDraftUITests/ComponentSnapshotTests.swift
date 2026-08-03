import AppKit
import SwiftUI
import Testing

@testable import CopyDraftUI

// MARK: - Planches de contrôle

/// Une planche de composants : les cinq styles de bouton dans leurs cinq états (§2.1).
struct ButtonBoard: View {
    private static let styles: [(String, CDButtonStyle, String)] = [
        ("primary", .primary, "Ouvrir les Réglages"),
        ("secondary", .secondary, "Plus tard"),
        ("quiet", .quiet, "Réinitialiser"),
        ("destructive", .destructive, "Tout effacer"),
        ("destructiveQuiet", .destructiveQuiet, "Supprimer")
    ]

    private static let states: [(String, Bool, Bool, Bool, Bool)] = [
        ("repos", true, false, false, false),
        ("survol", true, true, false, false),
        ("pressé", true, false, true, false),
        ("focus", true, false, false, true),
        ("désactivé", false, false, false, false)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: CD.Space.x5) {
            ForEach(Self.styles, id: \.0) { name, style, title in
                VStack(alignment: .leading, spacing: CD.Space.x2_5) {
                    Text(name).font(CD.Font.micro).foregroundStyle(CD.Color.text2)
                    HStack(spacing: CD.Space.x6) {
                        ForEach(Self.states, id: \.0) { label, enabled, hover, pressed, focused in
                            VStack(spacing: CD.Space.x2) {
                                CDButtonSurface(
                                    style: style,
                                    isEnabled: enabled,
                                    isHovering: hover,
                                    isPressed: pressed,
                                    isFocused: focused
                                ) {
                                    Text(title)
                                }
                                Text(label).font(CD.Font.small).foregroundStyle(CD.Color.text3)
                            }
                        }
                    }
                }
            }
        }
        .padding(CD.Space.x6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(CD.Color.bgWindow)
    }
}

/// Les quatre états du champ de recherche (§2.3), avec un `Text` à la place du `TextField`.
struct SearchBoard: View {
    private struct Row: Identifiable {
        let id: String
        let enabled: Bool
        let focused: Bool
        let value: String
    }

    private static let rows = [
        Row(id: "repos — placeholder", enabled: true, focused: false, value: ""),
        Row(id: "focus", enabled: true, focused: true, value: ""),
        Row(id: "saisie", enabled: true, focused: true, value: "pasteboard"),
        Row(id: "inactif — historique vide", enabled: false, focused: false, value: "")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: CD.Space.x5) {
            ForEach(Self.rows) { row in
                VStack(alignment: .leading, spacing: CD.Space.x2) {
                    CDSearchFieldBody(
                        isEnabled: row.enabled,
                        isFocused: row.focused,
                        hasText: !row.value.isEmpty,
                        onClear: {}
                    ) {
                        Text(row.value.isEmpty ? L.t("popup.search.placeholder") : row.value)
                            .font(CD.Font.body)
                            .foregroundStyle(
                                row.value.isEmpty ? CD.Color.text3 : CD.Color.text1
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Text(row.id).font(CD.Font.small).foregroundStyle(CD.Color.text3)
                }
            }
        }
        .padding(CD.Space.x6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(CD.Color.bgPopoverSolid)
    }
}

/// Indices ⌘n et badges d'information (§2.4).
struct BadgeBoard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: CD.Space.x5) {
            VStack(alignment: .leading, spacing: CD.Space.x2_5) {
                Text("indices").font(CD.Font.micro).foregroundStyle(CD.Color.text2)
                HStack(spacing: CD.Space.x6) {
                    VStack(spacing: CD.Space.x2) {
                        CDShortcutBadge(index: 1, isSelected: false)
                        Text("⌘1 sur matériau")
                            .font(CD.Font.small).foregroundStyle(CD.Color.text3)
                    }
                    VStack(spacing: CD.Space.x2) {
                        CDShortcutBadge(index: 10, isSelected: false)
                        Text("⌘0 — dixième")
                            .font(CD.Font.small).foregroundStyle(CD.Color.text3)
                    }
                    VStack(spacing: CD.Space.x2) {
                        CDShortcutBadge(index: 1, isSelected: true)
                            .padding(CD.Space.x2)
                            .background(CD.Color.selection, in: RoundedRectangle(cornerRadius: CD.Radius.cell))
                        Text("⌘1 sur sélection")
                            .font(CD.Font.small).foregroundStyle(CD.Color.text3)
                    }
                }
            }

            VStack(alignment: .leading, spacing: CD.Space.x2_5) {
                Text("indicateurs").font(CD.Font.micro).foregroundStyle(CD.Color.text2)
                HStack(spacing: CD.Space.x6) {
                    CDBadge("IMAGE")
                    CDBadge("1,2 Mo")
                    CDBadge(L.t("badge.paused"), emphasis: .warning)
                    CDBadge("IMAGE", emphasis: .onSelection)
                        .padding(CD.Space.x2)
                        .background(CD.Color.selection, in: RoundedRectangle(cornerRadius: CD.Radius.cell))
                }
            }
        }
        .padding(CD.Space.x6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(CD.Color.bgPopoverSolid)
    }
}

/// États particuliers : état vide, état vide avec action, bandeau de pause (§5).
struct StateBoard: View {
    var body: some View {
        VStack(spacing: CD.Space.x5) {
            CDPauseBanner(onResume: {})

            CDEmptyState(
                symbolName: "doc.on.clipboard",
                titleKey: "popup.empty.title",
                messageKey: "popup.empty.message"
            )

            CDEmptyState(
                symbolName: "magnifyingglass",
                titleKey: "popup.empty.search.title",
                messageKey: "popup.empty.search.message",
                actionTitleKey: "search.clear",
                action: {}
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(CD.Color.bgPopoverSolid)
    }
}

// MARK: - Instantanés

/// Rend chaque composant en PNG, en clair et en sombre.
///
/// Seul contrôle visuel possible sans capture d'écran. Désactivé par défaut :
/// `CD_SNAPSHOTS=1 swift test` écrit les images dans `dist/snapshots/`.
@Suite("Instantanés des composants")
struct ComponentSnapshotTests {
    static let isEnabled = ProcessInfo.processInfo.environment["CD_SNAPSHOTS"] == "1"

    /// Une planche par famille de composants, avec sa cote de rendu.
    enum Board: String, CaseIterable, Sendable {
        case buttons, search, badges, states

        var size: CGSize {
            switch self {
            case .buttons: CGSize(width: 980, height: 520)
            case .search: CGSize(width: 408, height: 300)
            case .badges: CGSize(width: 520, height: 260)
            case .states: CGSize(width: 360, height: 620)
            }
        }

        @MainActor
        @ViewBuilder
        var content: some View {
            switch self {
            case .buttons: ButtonBoard()
            case .search: SearchBoard()
            case .badges: BadgeBoard()
            case .states: StateBoard()
            }
        }
    }

    struct Case: Sendable, CustomStringConvertible {
        let board: Board
        let appearance: NSAppearance.Name

        var description: String { "\(board.rawValue)-\(appearance == .darkAqua ? "dark" : "light")" }
    }

    static let cases: [Case] = Board.allCases.flatMap { board in
        [NSAppearance.Name.aqua, .darkAqua].map { Case(board: board, appearance: $0) }
    }

    @MainActor
    @Test(
        "Rendu clair et sombre",
        .enabled(if: ComponentSnapshotTests.isEnabled),
        arguments: ComponentSnapshotTests.cases
    )
    func renderBoard(_ testCase: Case) throws {
        let appearance = try #require(NSAppearance(named: testCase.appearance))
        let outputDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("dist/snapshots")
        try FileManager.default.createDirectory(
            at: outputDirectory, withIntermediateDirectories: true
        )

        let size = testCase.board.size
        var data: Data?
        appearance.performAsCurrentDrawingAppearance {
            let renderer = ImageRenderer(
                content: testCase.board.content
                    .frame(width: size.width, height: size.height)
                    .environment(\.colorScheme, testCase.appearance == .darkAqua ? .dark : .light)
            )
            renderer.scale = 2
            guard let image = renderer.nsImage,
                let tiff = image.tiffRepresentation,
                let bitmap = NSBitmapImageRep(data: tiff)
            else { return }
            data = bitmap.representation(using: .png, properties: [:])
        }

        let png = try #require(data, "rendu impossible")
        let file = outputDirectory.appendingPathComponent("component-\(testCase).png")
        try png.write(to: file)
        #expect(png.count > 5_000, "image suspecte : \(png.count) octets")
    }
}

// MARK: - Contrôles non graphiques

@Suite("Composants — comportement")
struct ComponentBehaviourTests {
    @Test(
        "L'indice ⌘n numérote 1…9 puis 0 pour le dixième",
        arguments: [(1, "⌘1"), (2, "⌘2"), (9, "⌘9"), (10, "⌘0")]
    )
    func shortcutLabel(index: Int, expected: String) {
        #expect(CDShortcutBadge.label(for: index) == expected)
    }

    /// Clés ajoutées par la bibliothèque de composants (§2.3, §2.4, §5).
    static let keys = [
        "popup.search.placeholder",
        "search.clear",
        "popup.shortcut.accessibilityLabel %lld",
        "badge.paused",
        "popup.pause.banner",
        "popup.pause.resume",
        "popup.empty.title",
        "popup.empty.message",
        "popup.empty.search.title",
        "popup.empty.search.message"
    ]

    @Test("Chaque clé des composants existe en français et en anglais", arguments: ["fr", "en"])
    func everyComponentKeyIsTranslated(language: String) throws {
        let bundle = try #require(
            Bundle.module.path(forResource: language, ofType: "lproj").map(Bundle.init(path:)) ?? nil,
            "catalogue \(language).lproj introuvable"
        )

        for key in Self.keys {
            let value = bundle.localizedString(forKey: key, value: nil, table: nil)
            #expect(value != key, "clé « \(key) » non traduite en \(language)")
            #expect(!value.isEmpty)
        }
    }

    @Test("Les textes du design system sont repris mot pour mot")
    func frenchWordingMatchesDesignSystem() throws {
        let bundle = try #require(
            Bundle.module.path(forResource: "fr", ofType: "lproj").map(Bundle.init(path:)) ?? nil
        )
        #expect(
            bundle.localizedString(forKey: "popup.pause.banner", value: nil, table: nil)
                == "Capture suspendue — rien n'est enregistré."
        )
        #expect(
            bundle.localizedString(forKey: "popup.empty.title", value: nil, table: nil)
                == "Rien à coller pour l'instant"
        )
        #expect(
            bundle.localizedString(forKey: "popup.search.placeholder", value: nil, table: nil)
                == "Rechercher dans l'historique"
        )
    }

    @MainActor
    @Test("L'indice interpolé se résout dans le catalogue")
    func shortcutAccessibilityLabelResolves() {
        let label = L.t("popup.shortcut.accessibilityLabel \(1)")
        #expect(label != "popup.shortcut.accessibilityLabel 1")
        #expect(label.contains("1"))
    }
}
