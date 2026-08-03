import AppKit
import CopyDraftCore
import Foundation
import SwiftUI
import Testing

@testable import CopyDraftUI

// MARK: - Toasts (§9, FR-34, FR-35)

@Suite("Toasts — libellés")
struct ToastMessageTests {
    @Test("Les quatre libellés du §9, en français")
    func frenchLabels() {
        #expect(ToastKind.pasted(appName: "Xcode").message(language: "fr") == "Collé dans Xcode")
        #expect(ToastKind.pastedPlainText.message(language: "fr") == "Collé en texte brut")
        #expect(ToastKind.pinned.message(language: "fr") == "Élément épinglé")
        #expect(ToastKind.copiedOnly.message(language: "fr") == "Copié — collez avec ⌘V")
    }

    @Test("Les quatre libellés du §9, en anglais")
    func englishLabels() {
        #expect(ToastKind.pasted(appName: "Xcode").message(language: "en") == "Pasted into Xcode")
        #expect(ToastKind.pastedPlainText.message(language: "en") == "Pasted as plain text")
        #expect(ToastKind.pinned.message(language: "en") == "Item pinned")
        #expect(ToastKind.copiedOnly.message(language: "en") == "Copied — paste with ⌘V")
    }

    @Test(
        "Le nom de l'application cible est interpolé tel quel",
        arguments: ["Mail", "Safari", "Terminal", "Google Chrome"]
    )
    func interpolatesAppName(name: String) {
        #expect(ToastKind.pasted(appName: name).message(language: "fr") == "Collé dans \(name)")
        #expect(ToastKind.pasted(appName: name).message(language: "en") == "Pasted into \(name)")
    }

    @Test("Chaque résultat de collage a son toast (FR-35)")
    func mapsEveryPasteOutcome() {
        #expect(ToastKind(PasteOutcome.pasted(appName: "Notes")) == .pasted(appName: "Notes"))
        // « Collé en texte brut » ne nomme pas l'application : le §9 met en avant la
        // transformation, pas la destination.
        #expect(ToastKind(PasteOutcome.pastedPlainText(appName: "Notes")) == .pastedPlainText)
        #expect(ToastKind(PasteOutcome.copiedOnly) == .copiedOnly)
    }

    @Test("Le repli sans permission est le seul à porter un signe d'alerte (FR-34)")
    func fallbackIsTheOnlyWarning() {
        #expect(ToastKind.copiedOnly.symbolName == "exclamationmark.circle")
        #expect(ToastKind.pasted(appName: "Xcode").symbolName == "checkmark")
        #expect(ToastKind.pinned.symbolName == "pin.fill")
        #expect(ToastKind.pastedPlainText.symbolName == "textformat")
    }
}

@Suite("Toasts — géométrie et durées")
struct ToastGeometryTests {
    /// Écran fictif : la géométrie ne dépend d'aucun matériel.
    private static let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)

    @Test("Le toast est centré, 24 pt au-dessus du bas de l'écran actif (§9)")
    func position() {
        let size = CGSize(width: 180, height: 30)
        let frame = ToastPositioner().frame(size: size, in: Self.screen)

        #expect(frame.midX == Self.screen.midX)
        #expect(frame.minY == Self.screen.minY + CD.Metric.toastBottomInset)
        #expect(frame.size == size)
    }

    @Test("Un second écran ne déplace pas le toast hors de l'écran actif")
    func positionOnSecondScreen() {
        let secondary = CGRect(x: 1440, y: 120, width: 1280, height: 800)
        let frame = ToastPositioner().frame(size: CGSize(width: 200, height: 30), in: secondary)

        #expect(secondary.contains(frame))
        #expect(frame.minY == secondary.minY + CD.Metric.toastBottomInset)
    }

    @Test("Les durées sont celles du §9 : 180 ms, 1,4 s, 120 ms")
    func durations() {
        #expect(CD.Motion.toastIn == 0.180)
        #expect(CD.Motion.toastDwell == 1.400)
        #expect(CD.Motion.toastOut == 0.120)
        #expect(ToastMetrics.travel == 8)
    }
}

@Suite("Toasts — présentation")
@MainActor
struct ToastPresenterTests {
    @Test("Deux toasts rapprochés ne se superposent pas : le second remplace le premier")
    func secondToastReplacesTheFirst() {
        let presenter = ToastPresenter()

        presenter.showPinned()
        #expect(presenter.message == ToastKind.pinned.message())
        let first = presenter.panel

        presenter.show(PasteOutcome.pasted(appName: "Xcode"))
        #expect(presenter.message == ToastKind.pasted(appName: "Xcode").message())
        // Même fenêtre : c'est ce qui rend l'empilement impossible (§9).
        #expect(presenter.panel === first)

        presenter.dismiss()
    }

    @Test("Le repli sans permission passe par le même présentateur (FR-34)")
    func fallbackOutcome() {
        let presenter = ToastPresenter()
        presenter.show(PasteOutcome.copiedOnly)

        #expect(presenter.isVisible)
        #expect(presenter.message == ToastKind.copiedOnly.message())

        presenter.dismiss()
        #expect(presenter.isVisible == false)
        #expect(presenter.message == nil)
    }

    @Test("La fenêtre du toast ne prend jamais le focus et n'intercepte aucun clic (§9)")
    func panelIsInertAndFocusFree() throws {
        let presenter = ToastPresenter()
        presenter.showPinned()

        let panel = try #require(presenter.panel)
        #expect(panel.ignoresMouseEvents)
        #expect(panel.canBecomeKey == false)
        #expect(panel.canBecomeMain == false)

        presenter.dismiss()
    }
}

// MARK: - Confirmation « Tout effacer » (§9, FR-12)

@Suite("Confirmation « Tout effacer »")
struct ClearAllAlertTests {
    @MainActor
    @Test("Le titre est celui du §9")
    func title() {
        #expect(ClearAllAlert.title(language: "fr") == "Effacer tout l'historique ?")
        #expect(ClearAllAlert.title(language: "en") == "Clear all history?")
    }

    @MainActor
    @Test(
        "Le décompte des éléments s'accorde en français",
        arguments: [
            (0, "0 élément sera supprimé définitivement. Cette action est irréversible."),
            (1, "1 élément sera supprimé définitivement. Cette action est irréversible."),
            (2, "2 éléments seront supprimés définitivement. Cette action est irréversible."),
            (25, "25 éléments seront supprimés définitivement. Cette action est irréversible.")
        ]
    )
    func frenchItemCount(count: Int, expected: String) {
        #expect(ClearAllAlert.message(itemCount: count, language: "fr") == expected)
    }

    @MainActor
    @Test(
        "Le décompte des éléments s'accorde en anglais",
        arguments: [
            (0, "0 items will be permanently deleted. This action cannot be undone."),
            (1, "1 item will be permanently deleted. This action cannot be undone."),
            (2, "2 items will be permanently deleted. This action cannot be undone."),
            (25, "25 items will be permanently deleted. This action cannot be undone.")
        ]
    )
    func englishItemCount(count: Int, expected: String) {
        #expect(ClearAllAlert.message(itemCount: count, language: "en") == expected)
    }

    @MainActor
    @Test(
        "La case des épinglés s'accorde en français",
        arguments: [
            (0, "Conserver le 0 élément épinglé"),
            (1, "Conserver le 1 élément épinglé"),
            (3, "Conserver les 3 éléments épinglés")
        ]
    )
    func frenchPinnedCount(count: Int, expected: String) {
        #expect(ClearAllAlert.keepPinnedTitle(pinnedCount: count, language: "fr") == expected)
    }

    @MainActor
    @Test(
        "La case des épinglés s'accorde en anglais",
        arguments: [
            (0, "Keep the 0 pinned items"),
            (1, "Keep the 1 pinned item"),
            (3, "Keep the 3 pinned items")
        ]
    )
    func englishPinnedCount(count: Int, expected: String) {
        #expect(ClearAllAlert.keepPinnedTitle(pinnedCount: count, language: "en") == expected)
    }

    @Test("Le français range 0 et 1 au singulier, l'anglais seulement 1")
    func pluralRule() {
        #expect(LocalizedTable.isSingular(0, language: "fr"))
        #expect(LocalizedTable.isSingular(1, language: "fr"))
        #expect(LocalizedTable.isSingular(2, language: "fr") == false)

        #expect(LocalizedTable.isSingular(0, language: "en") == false)
        #expect(LocalizedTable.isSingular(1, language: "en"))
        #expect(LocalizedTable.isSingular(2, language: "en") == false)
    }

    @MainActor
    @Test("Les deux boutons du §9 sont nommés")
    func buttons() {
        #expect(ClearAllAlert.confirmTitle(language: "fr") == "Tout effacer")
        #expect(ClearAllAlert.cancelTitle(language: "fr") == "Annuler")
        #expect(ClearAllAlert.confirmTitle(language: "en") == "Clear All")
        #expect(ClearAllAlert.cancelTitle(language: "en") == "Cancel")
    }

    @Test("Le résultat porte les deux décisions")
    func result() {
        let kept = ClearAllAlert.Result(confirmed: true, keepsPinned: true)
        #expect(kept == ClearAllAlert.Result(confirmed: true, keepsPinned: true))
        #expect(kept != ClearAllAlert.Result(confirmed: true, keepsPinned: false))
    }
}

// MARK: - Menu contextuel d'un élément (§9, FR-38)

@Suite("Menu contextuel d'un élément")
struct ItemContextMenuTests {
    private static func entries(
        isPinned: Bool = false,
        app: String? = "Mail"
    ) -> [ItemMenuEntry] {
        ItemContextMenuBuilder.elements(isPinned: isPinned, sourceAppName: app, language: "fr")
            .compactMap { if case .entry(let entry) = $0 { entry } else { nil } }
    }

    @Test("L'ordre des actions est celui du §9")
    func order() {
        #expect(
            Self.entries().map(\.action) == [
                .paste, .pastePlainText, .togglePin, .rename, .copy, .delete, .excludeApp
            ]
        )
    }

    @Test("Les séparateurs découpent le menu en trois groupes")
    func separators() {
        let elements = ItemContextMenuBuilder.elements(
            isPinned: false, sourceAppName: "Mail", language: "fr"
        )
        let separatorIndexes = elements.indices.filter { elements[$0] == .separator }
        // Coller / Coller sans mise en forme ┊ Épingler / Renommer / Copier ┊ Supprimer / Exclure
        #expect(separatorIndexes == [2, 6])
    }

    @Test("Les libellés français sont ceux du §9")
    func frenchTitles() {
        #expect(
            Self.entries().map(\.title) == [
                "Coller",
                "Coller sans mise en forme",
                "Épingler",
                "Renommer…",
                "Copier",
                "Supprimer",
                "Ne jamais enregistrer Mail…"
            ]
        )
    }

    @Test("Les raccourcis affichés sont ceux du §9")
    func shortcutSymbols() {
        #expect(Self.entries().map(\.shortcutSymbol) == ["↩︎", "⇧↩︎", "⌘P", "", "⌘C", "⌫", ""])
    }

    @Test("Les équivalents clavier correspondent aux symboles")
    func keyEquivalents() {
        let entries = Self.entries()
        #expect(entries[0].keyEquivalent == "\r")
        #expect(entries[0].modifiers.isEmpty)
        #expect(entries[1].keyEquivalent == "\r")
        #expect(entries[1].modifiers == .shift)
        #expect(entries[2].keyEquivalent == "p")
        #expect(entries[2].modifiers == .command)
        #expect(entries[4].keyEquivalent == "c")
        #expect(entries[4].modifiers == .command)
        #expect(entries[5].keyEquivalent == "\u{8}")
        #expect(entries[5].modifiers.isEmpty)
    }

    @Test("Le libellé bascule Épingler / Désépingler selon l'état")
    func pinLabelToggles() {
        #expect(Self.entries(isPinned: false)[2].title == "Épingler")
        #expect(Self.entries(isPinned: true)[2].title == "Désépingler")
        // Le raccourci, lui, ne bouge pas : c'est la même touche dans les deux sens (FR-38).
        #expect(Self.entries(isPinned: true)[2].keyEquivalent == "p")
        #expect(Self.entries(isPinned: true)[2].shortcutSymbol == "⌘P")
    }

    @Test(
        "L'exclusion nomme l'application source de l'élément visé",
        arguments: ["Mail", "Safari", "1Password"]
    )
    func exclusionNamesSourceApp(app: String) {
        let entries = Self.entries(app: app)
        #expect(entries.last?.action == .excludeApp)
        #expect(entries.last?.title == "Ne jamais enregistrer \(app)…")
    }

    @Test("Sans application source, il n'y a personne à exclure")
    func noSourceAppNoExclusion() {
        #expect(Self.entries(app: nil).map(\.action).contains(.excludeApp) == false)
        #expect(Self.entries(app: "").count == 6)
    }

    @Test("Les libellés anglais existent aussi")
    func englishTitles() {
        let entries = ItemContextMenuBuilder
            .elements(isPinned: true, sourceAppName: "Mail", language: "en")
            .compactMap { if case .entry(let entry) = $0 { entry } else { nil } }
        #expect(entries[0].title == "Paste")
        #expect(entries[2].title == "Unpin")
        #expect(entries.last?.title == "Never Save Mail…")
    }

    @MainActor
    @Test("Le NSMenu reprend l'ordre, les séparateurs et les raccourcis")
    func nsMenuMirrorsTheDescriptors() throws {
        var performed: [ItemMenuAction] = []
        let menu = ItemContextMenuBuilder.makeMenu(
            isPinned: false, sourceAppName: "Mail", perform: { performed.append($0) }
        )

        #expect(menu.items.count == 9)
        #expect(menu.items[2].isSeparatorItem)
        #expect(menu.items[6].isSeparatorItem)
        #expect(menu.items[3].keyEquivalent == "p")
        #expect(menu.items[3].keyEquivalentModifierMask == .command)
        #expect(menu.items[7].keyEquivalent == "\u{8}")

        // La cible est retenue par l'entrée : sans cela, l'action serait perdue avant même
        // que le menu s'ouvre.
        let item = menu.items[0]
        let target = try #require(item.target as? NSObject)
        let action = try #require(item.action)
        target.perform(action, with: item)
        #expect(performed == [.paste])
    }
}

// MARK: - À propos (§9)

@Suite("À propos")
struct AboutTests {
    @Test("La phrase de positionnement est celle du §9")
    func tagline() {
        #expect(
            AboutStrings.tagline(language: "fr")
                == "Historique de presse-papiers pour macOS. Traitement 100 % local, aucune donnée transmise."
        )
        #expect(AboutStrings.tagline(language: "en").hasPrefix("Clipboard history for macOS."))
    }

    @Test("La version reprend le couple version / build")
    func version() {
        #expect(AboutStrings.version(short: "1.0.4", build: "412", language: "fr") == "Version 1.0.4 (412)")
        #expect(AboutStrings.version(short: "1.0.4", build: "412", language: "en") == "Version 1.0.4 (412)")
    }

    @Test("Les deux liens et le copyright sont nommés")
    func linksAndCopyright() {
        #expect(AboutStrings.website(language: "fr") == "Site web")
        #expect(AboutStrings.licenses(language: "fr") == "Licences")
        #expect(AboutStrings.copyright(year: 2026, language: "fr") == "© 2026 — Tous droits réservés")
        #expect(AboutStrings.copyright(year: 2026, language: "en") == "© 2026 — All rights reserved")
    }
}

// MARK: - Catalogue

@Suite("Retours — localisation")
struct FeedbackLocalizationTests {
    /// Toutes les clés de `Feedback.strings`.
    static let keys = [
        "toast.pasted", "toast.pastedPlainText", "toast.pinned", "toast.copiedOnly",
        "clearAll.title", "clearAll.message.one", "clearAll.message.other",
        "clearAll.keepPinned.one", "clearAll.keepPinned.other",
        "clearAll.confirm", "clearAll.cancel",
        "itemMenu.paste", "itemMenu.pastePlainText", "itemMenu.pin", "itemMenu.unpin",
        "itemMenu.rename", "itemMenu.copy", "itemMenu.delete", "itemMenu.excludeApp",
        "about.title", "about.version", "about.tagline", "about.website", "about.licenses",
        "about.copyright"
    ]

    @Test("Chaque clé existe en français et en anglais", arguments: ["fr", "en"])
    func everyKeyIsTranslated(language: String) throws {
        let bundle = try #require(
            Bundle.module.path(forResource: language, ofType: "lproj").map(Bundle.init(path:)) ?? nil,
            "catalogue \(language).lproj introuvable"
        )

        for key in Self.keys {
            let value = bundle.localizedString(
                forKey: key, value: nil, table: L.Table.feedback.rawValue
            )
            #expect(value != key, "clé « \(key) » non traduite en \(language)")
            #expect(!value.isEmpty)
        }
    }
}

// MARK: - Instantanés

/// Planche des quatre toasts du §9, posée sur le fond opaque : `ImageRenderer` ne rend pas le
/// matériau translucide, qui est une vue AppKit hébergée.
struct ToastBoard: View {
    static let kinds: [ToastKind] = [
        .pasted(appName: "Xcode"), .pastedPlainText, .pinned, .copiedOnly
    ]

    var body: some View {
        VStack(spacing: CD.Space.x3) {
            ForEach(Array(Self.kinds.enumerated()), id: \.offset) { _, kind in
                ToastBody(kind: kind, message: kind.message(language: "fr"), usesMaterial: false)
            }
        }
        .padding(CD.Space.x6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CD.Color.bgWindow)
    }
}

@Suite("Instantanés des retours")
struct FeedbackSnapshotTests {
    static let isEnabled = ProcessInfo.processInfo.environment["CD_SNAPSHOTS"] == "1"

    enum Board: String, CaseIterable, Sendable {
        case toasts, about

        var size: CGSize {
            switch self {
            case .toasts: CGSize(width: 320, height: 220)
            case .about: CGSize(width: 280, height: 320)
            }
        }

        @MainActor
        @ViewBuilder
        var content: some View {
            switch self {
            case .toasts: ToastBoard()
            case .about:
                AboutView(
                    website: URL(string: "https://example.invalid"),
                    licenses: URL(string: "https://example.invalid/licences"),
                    language: "fr"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(CD.Color.bgWindow)
            }
        }
    }

    struct Case: Sendable, CustomStringConvertible {
        let board: Board
        let appearance: NSAppearance.Name

        var description: String {
            "\(board.rawValue)-\(appearance == .darkAqua ? "dark" : "light")"
        }
    }

    static let cases: [Case] = Board.allCases.flatMap { board in
        [NSAppearance.Name.aqua, .darkAqua].map { Case(board: board, appearance: $0) }
    }

    @MainActor
    @Test(
        "Rendu clair et sombre",
        .enabled(if: FeedbackSnapshotTests.isEnabled),
        arguments: FeedbackSnapshotTests.cases
    )
    func render(_ testCase: Case) throws {
        let appearance = try #require(NSAppearance(named: testCase.appearance))
        let png = try #require(
            SnapshotWriter.png(
                of: testCase.board.content, size: testCase.board.size, appearance: appearance
            ),
            "rendu impossible"
        )
        try SnapshotWriter.write(png, named: "feedback-\(testCase)")
        #expect(png.count > 3_000, "image suspecte : \(png.count) octets")
    }
}
