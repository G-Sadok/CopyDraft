import AppKit
import CopyDraftCore
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Ouvre la popup. `⇧⌘V` par défaut, valeur du design system (§7, §8).
    public static let openPopup = Self(
        "openPopup",
        default: .init(.v, modifiers: [.command, .shift])
    )

    /// Ouvre la popup en mode « coller sans mise en forme ». `⌥⇧⌘V` par défaut (FR-30).
    public static let openPopupPlainText = Self(
        "openPopupPlainText",
        default: .init(.v, modifiers: [.command, .shift, .option])
    )
}

/// Raccourcis globaux de CopyDraft (FR-28 à FR-31).
///
/// La bibliothèque `KeyboardShortcuts` s'appuie sur l'API Carbon `RegisterEventHotKey` :
/// contrairement au tap clavier de la popup, elle **ne demande aucune autorisation** — le
/// raccourci fonctionne donc même sans accès à l'accessibilité, seul le collage se replie.
///
/// Elle fournit aussi le composant d'enregistrement utilisé dans les réglages, avec sa
/// gestion des combinaisons réservées par le système (FR-29).
@MainActor
public final class ShortcutService {
    public var onOpenPopup: (() -> Void)?
    public var onOpenPopupPlainText: (() -> Void)?

    public private(set) var isListening = false

    public init() {}

    /// Met les raccourcis à l'écoute. Idempotent.
    public func start() {
        guard !isListening else { return }
        isListening = true

        KeyboardShortcuts.onKeyUp(for: .openPopup) { [weak self] in
            self?.onOpenPopup?()
        }
        KeyboardShortcuts.onKeyUp(for: .openPopupPlainText) { [weak self] in
            self?.onOpenPopupPlainText?()
        }
    }

    /// Suspend l'écoute sans effacer les raccourcis enregistrés par l'utilisateur.
    public func pause() {
        KeyboardShortcuts.disable(.openPopup, .openPopupPlainText)
    }

    public func resume() {
        KeyboardShortcuts.enable(.openPopup, .openPopupPlainText)
    }

    /// Raccourci actuellement défini, pour l'afficher dans l'onboarding et les réglages.
    public func shortcut(for name: KeyboardShortcuts.Name) -> KeyboardShortcuts.Shortcut? {
        KeyboardShortcuts.getShortcut(for: name)
    }

    /// Vrai si un raccourci d'ouverture est défini : sans lui, seule l'icône de barre de
    /// menus ouvre la popup (FR-31).
    public var hasOpenPopupShortcut: Bool {
        KeyboardShortcuts.getShortcut(for: .openPopup) != nil
    }

    /// Rétablit les valeurs par défaut du design system.
    public func resetToDefaults() {
        KeyboardShortcuts.reset(.openPopup, .openPopupPlainText)
    }
}
