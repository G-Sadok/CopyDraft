import Foundation
import Testing

@testable import CopyDraftCore

@Suite("Table de raccourcis de la popup")
struct PopupCommandTests {
    private let mapper = KeyCommandMapper()

    private func command(
        _ keyCode: UInt16,
        _ characters: String = "",
        _ modifiers: KeyModifiers = [],
        searchEmpty: Bool = true,
        quickPaste: Bool = true
    ) -> PopupCommand? {
        mapper.command(
            keyCode: keyCode, characters: characters, modifiers: modifiers,
            isSearchEmpty: searchEmpty, quickPasteEnabled: quickPaste
        )
    }

    // MARK: Navigation

    @Test("Les flèches déplacent la sélection")
    func arrows() {
        #expect(command(KeyCode.arrowUp) == .moveUp)
        #expect(command(KeyCode.arrowDown) == .moveDown)
    }

    @Test("⌥ + flèches saute aux extrémités de la liste")
    func optionArrows() {
        #expect(command(KeyCode.arrowUp, "", [.option]) == .jumpToStart)
        #expect(command(KeyCode.arrowDown, "", [.option]) == .jumpToEnd)
    }

    // MARK: Collage

    @Test("↩︎ colle, ⇧↩︎ colle sans mise en forme")
    func returnKey() {
        #expect(command(KeyCode.returnKey) == .paste)
        #expect(command(KeyCode.returnKey, "", [.shift]) == .pastePlainText)
    }

    @Test(
        "⌘1 à ⌘9 collent les rangs 1 à 9",
        arguments: [("1", 1), ("2", 2), ("5", 5), ("9", 9)]
    )
    func quickPasteDigits(character: String, rank: Int) {
        #expect(command(0, character, [.command]) == .quickPaste(rank: rank))
    }

    @Test("⌘0 colle le dixième élément")
    func quickPasteZero() {
        #expect(command(0, "0", [.command]) == .quickPaste(rank: 10))
    }

    @Test("Le collage rapide se désactive par réglage")
    func quickPasteCanBeDisabled() {
        #expect(command(0, "3", [.command], quickPaste: false) == nil)
    }

    @Test("Un chiffre sans ⌘ alimente la recherche au lieu de coller")
    func digitWithoutCommandGoesToSearch() {
        #expect(command(0, "3") == .appendToSearch("3"))
    }

    // MARK: Actions sur l'élément

    @Test("⌘P épingle, ⌘C copie")
    func itemShortcuts() {
        #expect(command(0, "p", [.command]) == .togglePin)
        #expect(command(0, "P", [.command]) == .togglePin)
        #expect(command(0, "c", [.command]) == .copy)
    }

    /// Règle du §3 : ⌫ ne supprime un élément que si la recherche est vide, sinon il
    /// corrige la saisie.
    @Test("⌫ supprime l'élément seulement quand la recherche est vide")
    func deleteDependsOnSearch() {
        #expect(command(KeyCode.delete, "", [], searchEmpty: true) == .deleteSelection)
        #expect(command(KeyCode.delete, "", [], searchEmpty: false) == .deleteSearchCharacter)
    }

    // MARK: Fermeture et focus

    @Test("Échap ferme, ⇥ fait circuler le focus")
    func dismissAndFocus() {
        #expect(command(KeyCode.escape) == .dismiss)
        #expect(command(KeyCode.tab) == .cycleFocus)
    }

    // MARK: Recherche

    @Test("Les lettres alimentent la recherche sans quitter la liste")
    func lettersFeedSearch() {
        #expect(command(0, "s") == .appendToSearch("s"))
        #expect(command(0, "É") == .appendToSearch("É"))
        #expect(command(0, " ") == .appendToSearch(" "))
    }

    @Test("Les combinaisons avec modificateur ne polluent pas la recherche")
    func modifiedKeysDoNotFeedSearch() {
        #expect(command(0, "a", [.command]) == nil)
        #expect(command(0, "a", [.control]) == nil)
        #expect(command(0, "a", [.option]) == nil)
    }

    @Test("Une touche sans caractère imprimable est ignorée")
    func nonPrintableIsIgnored() {
        #expect(command(0, "") == nil)
        #expect(command(0, "\u{1B}") == nil)
        #expect(command(KeyCode.arrowLeft) == nil, "les flèches latérales ne servent pas ici")
    }

    /// Toutes les touches de la table du §3 doivent être couvertes : ce test échoue si une
    /// ligne du design system disparaît de la table.
    @Test("Toute la table du design system est couverte")
    func fullTableIsCovered() {
        let expected: [PopupCommand] = [
            .moveUp, .moveDown, .jumpToStart, .jumpToEnd, .paste, .pastePlainText,
            .quickPaste(rank: 1), .togglePin, .deleteSelection, .cycleFocus, .dismiss,
            .appendToSearch("a")
        ]
        let produced: [PopupCommand?] = [
            command(KeyCode.arrowUp), command(KeyCode.arrowDown),
            command(KeyCode.arrowUp, "", [.option]), command(KeyCode.arrowDown, "", [.option]),
            command(KeyCode.returnKey), command(KeyCode.returnKey, "", [.shift]),
            command(0, "1", [.command]), command(0, "p", [.command]),
            command(KeyCode.delete), command(KeyCode.tab), command(KeyCode.escape),
            command(0, "a")
        ]
        #expect(produced.compactMap { $0 } == expected)
    }
}

@MainActor
@Suite("Acheminement des frappes")
struct KeyEventRouterTests {
    private struct StubPermission: AccessibilityPermissionChecking {
        let granted: Bool
        func isGranted() -> Bool { granted }
    }

    @Test("Sans autorisation, le routeur bascule en mode fenêtre clé")
    func fallsBackWithoutPermission() {
        let router = KeyEventRouter(permission: StubPermission(granted: false))
        #expect(router.start() == .keyWindow)
        #expect(router.isActive)
        router.stop()
        #expect(router.isActive == false)
    }

    @Test("Une commande reconnue est transmise et consommée")
    func dispatchesCommand() {
        let router = KeyEventRouter(permission: StubPermission(granted: false))
        var received: [PopupCommand] = []
        router.onCommand = { command in
            received.append(command)
            return true
        }

        #expect(router.handle(keyCode: KeyCode.arrowDown, characters: "", modifiers: []))
        #expect(received == [.moveDown])
    }

    @Test("Une frappe sans commande n'est pas consommée")
    func passesThroughUnknownKeys() {
        let router = KeyEventRouter(permission: StubPermission(granted: false))
        router.onCommand = { _ in true }

        #expect(router.handle(keyCode: KeyCode.arrowLeft, characters: "", modifiers: []) == false)
    }

    @Test("Le contexte de la popup pilote le double sens de ⌫")
    func contextDrivesDelete() {
        let router = KeyEventRouter(permission: StubPermission(granted: false))
        var received: [PopupCommand] = []
        router.onCommand = { received.append($0); return true }

        router.isSearchEmpty = { false }
        _ = router.handle(keyCode: KeyCode.delete, characters: "", modifiers: [])

        router.isSearchEmpty = { true }
        _ = router.handle(keyCode: KeyCode.delete, characters: "", modifiers: [])

        #expect(received == [.deleteSearchCharacter, .deleteSelection])
    }
}
