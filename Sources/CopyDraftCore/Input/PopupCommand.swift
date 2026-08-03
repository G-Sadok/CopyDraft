import Foundation

/// Action déclenchée par une frappe dans la popup (§3 du design system, FR-32).
public enum PopupCommand: Sendable, Equatable {
    /// Déplacement de la sélection, sans rebouclage aux extrémités.
    case moveUp
    case moveDown
    /// `⌥↑` / `⌥↓` : début et fin de liste.
    case jumpToStart
    case jumpToEnd
    /// `↩︎` : colle dans l'application active et ferme.
    case paste
    /// `⇧↩︎` : colle sans mise en forme.
    case pastePlainText
    /// `⌘1`–`⌘9` puis `⌘0` : colle directement le n-ième élément (rang 1 à 10).
    case quickPaste(rank: Int)
    /// `⌘P` : épingle ou désépingle la sélection.
    case togglePin
    /// `⌘C` : copie sans coller.
    case copy
    /// `⌫` : supprime la sélection, uniquement si la recherche est vide.
    case deleteSelection
    /// `⌫` avec une recherche en cours : efface le dernier caractère saisi.
    case deleteSearchCharacter
    /// `⇥` : recherche → liste → pied → recherche.
    case cycleFocus
    /// `Échap` : vide la recherche, puis ferme au second appui.
    case dismiss
    /// Toute frappe imprimable alimente la recherche sans quitter la liste.
    case appendToSearch(String)
}

/// Modificateurs, réduits à ce dont la popup a besoin.
public struct KeyModifiers: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let command = KeyModifiers(rawValue: 1 << 0)
    public static let shift = KeyModifiers(rawValue: 1 << 1)
    public static let option = KeyModifiers(rawValue: 1 << 2)
    public static let control = KeyModifiers(rawValue: 1 << 3)
}

/// Codes des touches utilisées par la popup, sur un clavier ANSI.
public enum KeyCode {
    public static let returnKey: UInt16 = 36
    public static let tab: UInt16 = 48
    public static let escape: UInt16 = 53
    public static let delete: UInt16 = 51
    public static let arrowLeft: UInt16 = 123
    public static let arrowRight: UInt16 = 124
    public static let arrowDown: UInt16 = 125
    public static let arrowUp: UInt16 = 126
}

/// Traduit une frappe en action de la popup.
///
/// Fonction pure : c'est elle qui porte toute la table de raccourcis du §3, et elle se teste
/// sans tap d'événements ni fenêtre. Le routeur qui l'utilise n'a plus qu'à transmettre.
public struct KeyCommandMapper: Sendable {
    public init() {}

    /// - Parameters:
    ///   - keyCode: code de touche matériel.
    ///   - characters: caractères produits, modificateurs appliqués.
    ///   - modifiers: modificateurs enfoncés.
    ///   - isSearchEmpty: pilote le double sens de `⌫` et d'`Échap`.
    ///   - quickPasteEnabled: réglage « Activer ⌘1 à ⌘9 dans la popup ».
    public func command(
        keyCode: UInt16,
        characters: String,
        modifiers: KeyModifiers,
        isSearchEmpty: Bool,
        quickPasteEnabled: Bool = true
    ) -> PopupCommand? {
        // ⌘ : collage rapide, épinglage, copie.
        if modifiers.contains(.command) {
            if quickPasteEnabled, let digit = Int(characters), (0...9).contains(digit) {
                // ⌘1 vaut le rang 1 … ⌘9 le rang 9, ⌘0 le dixième.
                return .quickPaste(rank: digit == 0 ? 10 : digit)
            }
            switch characters.lowercased() {
            case "p": return .togglePin
            case "c": return .copy
            default: break
            }
        }

        switch keyCode {
        case KeyCode.arrowUp:
            return modifiers.contains(.option) ? .jumpToStart : .moveUp
        case KeyCode.arrowDown:
            return modifiers.contains(.option) ? .jumpToEnd : .moveDown
        case KeyCode.returnKey:
            return modifiers.contains(.shift) ? .pastePlainText : .paste
        case KeyCode.escape:
            return .dismiss
        case KeyCode.tab:
            return .cycleFocus
        case KeyCode.delete:
            // La suppression d'un élément ne doit jamais surprendre l'utilisateur en train
            // de corriger sa recherche : tant qu'il y a du texte, ⌫ efface un caractère.
            return isSearchEmpty ? .deleteSelection : .deleteSearchCharacter
        default:
            break
        }

        // Toute frappe imprimable alimente la recherche, sans quitter la liste.
        guard !modifiers.contains(.command), !modifiers.contains(.control),
            !modifiers.contains(.option), !characters.isEmpty,
            characters.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) })
        else { return nil }

        return .appendToSearch(characters)
    }
}
