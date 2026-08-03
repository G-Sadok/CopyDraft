import AppKit
import CopyDraftCore
import Foundation
import Testing

@testable import CopyDraftUI

/// Vérifie que le menu de la barre de menus est exactement celui du §6 : contenu, ordre,
/// raccourcis, séparateurs et troncature.
@Suite("Menu d'accès rapide")
struct QuickMenuBuilderTests {
    // MARK: Fixtures

    static func item(_ preview: String, name: String? = nil) -> ClipItem {
        ClipItem(
            kind: .text,
            subtype: .plain,
            createdAt: Date(timeIntervalSince1970: 0),
            customName: name,
            source: SourceApp(bundleIdentifier: "com.apple.dt.Xcode", name: "Xcode"),
            byteCount: preview.utf8.count,
            searchText: preview,
            previewLines: [preview]
        )
    }

    static func history(_ count: Int) -> [ClipItem] {
        (1...count).map { item("Élément \($0)") }
    }

    /// Les seules entrées d'élément, dans l'ordre du menu.
    static func pasteEntries(_ items: [QuickMenuItem]) -> [QuickMenuItem] {
        items.filter {
            if case .paste = $0.action { return true }
            return false
        }
    }

    let builder = QuickMenuBuilder()

    // MARK: Section « Derniers éléments »

    @Test("Cinq éléments au maximum, quelle que soit la taille de l'historique")
    func capsAtFiveItems() {
        let pasted = Self.pasteEntries(builder.items(from: Self.history(10), isPaused: false))
        #expect(pasted.count == Limits.menuItems)
        #expect(pasted.count == 5)
    }

    @Test("Les rangs ⌘1 à ⌘5 correspondent aux cinq premiers éléments de l'historique")
    func shortcutsFollowHistoryOrder() {
        let history = Self.history(10)
        let pasted = Self.pasteEntries(builder.items(from: history, isPaused: false))
        let identifiers = pasted.compactMap { entry -> UUID? in
            guard case .paste(let id) = entry.action else { return nil }
            return id
        }

        #expect(identifiers == history.prefix(5).map(\.id))
        #expect(pasted.map(\.keyEquivalent) == ["1", "2", "3", "4", "5"])
        #expect(pasted.allSatisfy { $0.modifiers == .command })
    }

    @Test("Un titre de section précède les éléments")
    func sectionHeaderPrecedesItems() throws {
        let items = builder.items(from: Self.history(3), isPaused: false)
        #expect(items.first?.action == .sectionHeader)
        #expect(items.first?.isEnabled == false)

        let firstPaste = try #require(items.firstIndex { Self.pasteEntries([$0]).count == 1 })
        #expect(firstPaste == 1)
    }

    @Test("Historique vide : aucune section d'éléments, le menu reste utilisable")
    func emptyHistoryKeepsMenuUsable() {
        let items = builder.items(from: [], isPaused: false)

        #expect(Self.pasteEntries(items).isEmpty)
        #expect(!items.contains { $0.action == .sectionHeader })
        #expect(items.first?.action == .openPopup)
        #expect(items.map(\.action).filter { $0 == .separator }.count == 2)

        for action in [QuickMenuItem.Action.openPopup, .togglePause, .openSettings, .about, .quit] {
            #expect(items.contains { $0.action == action }, "\(action) manquant")
        }
    }

    @Test("« Tout effacer » est inactif quand il n'y a rien à effacer")
    func clearAllDisabledOnEmptyHistory() throws {
        let empty = try #require(
            builder.items(from: [], isPaused: false).first { $0.action == .clearAll }
        )
        #expect(empty.isEnabled == false)

        let filled = try #require(
            builder.items(from: Self.history(1), isPaused: false).first { $0.action == .clearAll }
        )
        #expect(filled.isEnabled)
    }

    // MARK: Ordre et raccourcis du §6

    @Test("Ordre complet du §6 avec les séparateurs aux bons endroits")
    func matchesSectionSixLayout() {
        let items = builder.items(from: Self.history(5), isPaused: false)
        let history = items.prefix(7).map(\.action)

        #expect(history.first == .sectionHeader)
        #expect(history.last == .separator)
        #expect(
            items.dropFirst(7).map(\.action) == [
                .openPopup,
                .togglePause,
                .clearAll,
                .separator,
                .openSettings,
                .about,
                .separator,
                .quit
            ]
        )
    }

    @Test("Raccourcis des actions permanentes")
    func permanentShortcuts() throws {
        let items = builder.items(from: [], isPaused: false)

        func entry(_ action: QuickMenuItem.Action) throws -> QuickMenuItem {
            try #require(items.first { $0.action == action })
        }

        let popup = try entry(.openPopup)
        #expect(popup.keyEquivalent == "v")
        #expect(popup.modifiers == [.command, .shift])

        let settings = try entry(.openSettings)
        #expect(settings.keyEquivalent == ",")
        #expect(settings.modifiers == .command)

        let quit = try entry(.quit)
        #expect(quit.keyEquivalent == "q")
        #expect(quit.modifiers == .command)

        // Aucun raccourci sur les actions qui n'en portent pas au §6.
        for action in [QuickMenuItem.Action.togglePause, .clearAll, .about] {
            let item = try entry(action)
            #expect(item.keyEquivalent.isEmpty)
            #expect(item.modifiers.isEmpty)
        }
    }

    @Test("Les points de suspension ne marquent que les actions qui ouvrent une surface")
    func ellipsisMarksModalActions() throws {
        let items = builder.items(from: Self.history(1), isPaused: false)

        func title(_ action: QuickMenuItem.Action) throws -> String {
            try #require(items.first { $0.action == action }).title
        }

        #expect(try title(.clearAll).hasSuffix("…"))
        #expect(try title(.openSettings).hasSuffix("…"))
        // Une traduction qui porte déjà les points de suspension ne les voit pas doublés.
        #expect(try !title(.clearAll).hasSuffix("……"))
        #expect(try !title(.openSettings).hasSuffix("……"))
        #expect(try !title(.about).hasSuffix("…"))
        #expect(try !title(.openPopup).hasSuffix("…"))
        #expect(try !title(.togglePause).hasSuffix("…"))
        #expect(try !title(.quit).hasSuffix("…"))
    }

    // MARK: Pause

    @Test("Le libellé de pause bascule, sans interrupteur")
    func pauseLabelToggles() throws {
        func label(isPaused: Bool) throws -> String {
            try #require(
                builder.items(from: [], isPaused: isPaused).first { $0.action == .togglePause }
            ).title
        }

        let running = try label(isPaused: false)
        let paused = try label(isPaused: true)
        #expect(running != paused)
        #expect(running == L.t("menubar.pauseCapture"))
        #expect(paused == L.t("menubar.resumeCapture"))
    }

    // MARK: Libellés

    @Test("Un contenu multiligne tient sur une seule ligne")
    func multilineContentCollapsesToOneLine() throws {
        let item = ClipItem(
            kind: .text,
            subtype: .code,
            createdAt: Date(timeIntervalSince1970: 0),
            source: .unknown,
            byteCount: 0,
            searchText: "let a = 1\nlet b = 2",
            previewLines: ["let a = 1", "  let b = 2"]
        )

        let title = try #require(
            Self.pasteEntries(builder.items(from: [item], isPaused: false)).first
        ).title

        #expect(!title.contains("\n"))
        #expect(!title.contains("  "))
        #expect(title == "let a = 1 let b = 2")
    }

    @Test("Un libellé trop long est tronqué en fin avec des points de suspension")
    func longTitlesAreTruncated() throws {
        let long = String(repeating: "a", count: 200)
        let title = try #require(
            Self.pasteEntries(builder.items(from: [Self.item(long)], isPaused: false)).first
        ).title

        #expect(title.count == QuickMenuBuilder.titleCharacterLimit)
        #expect(title.hasSuffix("…"))
    }

    @Test("Le nom donné par l'utilisateur prime sur l'aperçu")
    func customNameWins() throws {
        let item = Self.item("SELECT id FROM clip_items", name: "Requête épinglés")
        let title = try #require(
            Self.pasteEntries(builder.items(from: [item], isPaused: false)).first
        ).title
        #expect(title == "Requête épinglés")
    }

    @Test("maxItems borne la section sans casser le reste du menu")
    func honoursCustomMaxItems() {
        let items = builder.items(from: Self.history(10), isPaused: false, maxItems: 2)
        #expect(Self.pasteEntries(items).count == 2)
        #expect(items.last?.action == .quit)
    }
}
