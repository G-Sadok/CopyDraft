import AppKit

// MARK: - Descripteurs (§9, FR-38)

/// Les sept actions du menu contextuel d'un élément (§9).
public enum ItemMenuAction: String, Sendable, CaseIterable {
    case paste
    case pastePlainText
    case togglePin
    case rename
    case copy
    case delete
    case excludeApp
}

/// Une entrée du menu : libellé résolu, équivalent clavier et symbole affiché.
///
/// `keyEquivalent` et `modifiers` alimentent `NSMenuItem` ; `shortcutSymbol` est le rendu du
/// §9 (« ↩︎ », « ⇧↩︎ », « ⌘P »…), que le menu contextuel de la popup dessine lui-même.
public struct ItemMenuEntry: Sendable, Equatable {
    public let action: ItemMenuAction
    public let title: String
    public let keyEquivalent: String
    public let modifiers: NSEvent.ModifierFlags
    public let shortcutSymbol: String
}

/// Une ligne du menu : une entrée, ou un séparateur.
public enum ItemMenuElement: Sendable, Equatable {
    case entry(ItemMenuEntry)
    case separator
}

// MARK: - Construction

/// Compose le menu contextuel d'un élément (§9, FR-38).
///
/// Le menu est d'abord une **suite de descripteurs**, pas un `NSMenu` : l'ordre des actions,
/// la bascule Épingler/Désépingler et le nom de l'application exclue se relisent alors sans
/// instancier AppKit, ce qu'un menu contextuel ne permet pas autrement.
public enum ItemContextMenuBuilder {
    /// Touches non imprimables utilisées par le menu.
    private enum Key {
        /// `↩︎` — coller.
        static let `return` = "\r"
        /// `⌫` — supprimer.
        static let delete = "\u{8}"
    }

    /// - Parameters:
    ///   - isPinned: état d'épinglage de l'élément visé ; le libellé bascule (§9).
    ///   - sourceAppName: application d'origine de l'élément. Sans elle, il n'y a personne à
    ///     exclure : la dernière entrée disparaît.
    public static func elements(
        isPinned: Bool,
        sourceAppName: String?,
        language: String? = nil
    ) -> [ItemMenuElement] {
        func title(_ key: String) -> String {
            LocalizedTable.string(key, table: .feedback, language: language)
        }

        var elements: [ItemMenuElement] = [
            .entry(
                ItemMenuEntry(
                    action: .paste,
                    title: title("itemMenu.paste"),
                    keyEquivalent: Key.return,
                    modifiers: [],
                    shortcutSymbol: "↩︎"
                )
            ),
            .entry(
                ItemMenuEntry(
                    action: .pastePlainText,
                    title: title("itemMenu.pastePlainText"),
                    keyEquivalent: Key.return,
                    modifiers: .shift,
                    shortcutSymbol: "⇧↩︎"
                )
            ),
            .separator,
            .entry(
                ItemMenuEntry(
                    action: .togglePin,
                    title: title(isPinned ? "itemMenu.unpin" : "itemMenu.pin"),
                    keyEquivalent: "p",
                    modifiers: .command,
                    shortcutSymbol: "⌘P"
                )
            ),
            .entry(
                ItemMenuEntry(
                    action: .rename,
                    title: title("itemMenu.rename"),
                    keyEquivalent: "",
                    modifiers: [],
                    shortcutSymbol: ""
                )
            ),
            .entry(
                ItemMenuEntry(
                    action: .copy,
                    title: title("itemMenu.copy"),
                    keyEquivalent: "c",
                    modifiers: .command,
                    shortcutSymbol: "⌘C"
                )
            ),
            .separator,
            .entry(
                ItemMenuEntry(
                    action: .delete,
                    title: title("itemMenu.delete"),
                    keyEquivalent: Key.delete,
                    modifiers: [],
                    shortcutSymbol: "⌫"
                )
            )
        ]

        if let sourceAppName, !sourceAppName.isEmpty {
            elements.append(
                .entry(
                    ItemMenuEntry(
                        action: .excludeApp,
                        title: LocalizedTable.format(
                            "itemMenu.excludeApp", table: .feedback, language: language,
                            sourceAppName
                        ),
                        keyEquivalent: "",
                        modifiers: [],
                        shortcutSymbol: ""
                    )
                )
            )
        }

        return elements
    }

    /// Fabrique le `NSMenu` correspondant.
    ///
    /// - Parameter perform: appelé avec l'action choisie.
    @MainActor
    public static func makeMenu(
        isPinned: Bool,
        sourceAppName: String?,
        perform: @escaping (ItemMenuAction) -> Void
    ) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        for element in elements(isPinned: isPinned, sourceAppName: sourceAppName) {
            switch element {
            case .separator:
                menu.addItem(.separator())

            case .entry(let entry):
                let item = NSMenuItem(
                    title: entry.title, action: #selector(ItemMenuTarget.fire(_:)), keyEquivalent: ""
                )
                item.keyEquivalent = entry.keyEquivalent
                item.keyEquivalentModifierMask = entry.modifiers
                item.isEnabled = true

                let target = ItemMenuTarget(action: entry.action, perform: perform)
                item.target = target
                // `NSMenuItem.target` est faible : c'est `representedObject` qui retient la
                // cible pour la durée de vie du menu.
                item.representedObject = target

                menu.addItem(item)
            }
        }

        return menu
    }
}

/// Cible d'une entrée de menu : `NSMenuItem` exige un objet Objective-C, pas une fermeture.
@MainActor
private final class ItemMenuTarget: NSObject {
    private let action: ItemMenuAction
    private let perform: (ItemMenuAction) -> Void

    init(action: ItemMenuAction, perform: @escaping (ItemMenuAction) -> Void) {
        self.action = action
        self.perform = perform
    }

    @objc func fire(_ sender: Any?) {
        perform(action)
    }
}
