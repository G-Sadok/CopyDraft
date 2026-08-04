import AppKit
import CopyDraftCore

// MARK: - Menu d'accès rapide (§6)

/// Une entrée du menu de la barre de menus, indépendante de son rendu AppKit.
///
/// Le menu est décrit avant d'être construit : c'est ce qui permet de vérifier l'ordre, les
/// raccourcis et la troncature du §6 sans ouvrir de `NSMenu`.
public struct QuickMenuItem: Sendable, Equatable {
    public enum Action: Sendable, Equatable {
        /// Un des cinq derniers éléments : le choisir colle comme depuis la popup (FR-41).
        case paste(UUID)
        case openPopup
        case togglePause
        case clearAll
        case openSettings
        case about
        case quit
        case separator
        /// Titre de section « Derniers éléments » du §6 : ni cliquable, ni sélectionnable.
        case sectionHeader
        /// Rouvre l'écran d'autorisation. Présent uniquement quand l'accessibilité manque.
        case grantAccessibility
    }

    public let title: String
    public let action: Action
    public let keyEquivalent: String
    public let modifiers: NSEvent.ModifierFlags
    public let isEnabled: Bool

    public init(
        title: String,
        action: Action,
        keyEquivalent: String = "",
        modifiers: NSEvent.ModifierFlags = [],
        isEnabled: Bool = true
    ) {
        self.title = title
        self.action = action
        self.keyEquivalent = keyEquivalent
        self.modifiers = modifiers
        self.isEnabled = isEnabled
    }
}

/// Compose le menu de la barre de menus à partir de l'historique.
///
/// Volontairement séparé de `StatusItemController` : la composition est pure et testable,
/// l'affichage ne fait plus que traduire le résultat en `NSMenu`.
public struct QuickMenuBuilder: Sendable {
    /// Longueur maximale d'un libellé, en caractères.
    ///
    /// §6 : « chaque libellé tronque à une ligne ». Le design system exprime cette limite en
    /// largeur (252 pt) et non en caractères ; 28 correspond aux libellés de la maquette. À
    /// remplacer par un token dès qu'il en existe un.
    public static let titleCharacterLimit = 28

    public init() {}

    /// Entrées du menu, dans l'ordre du §6.
    ///
    /// `maxItems` plafonne la section « Derniers éléments » : au-delà de cinq, c'est la popup
    /// qui est le bon outil.
    public func items(
        from history: [ClipItem],
        isPaused: Bool,
        needsAccessibility: Bool = false,
        maxItems: Int = Limits.menuItems
    ) -> [QuickMenuItem] {
        var items: [QuickMenuItem] = []

        // Sans autorisation, le collage se replie sur une simple copie. L'entrée est en tête
        // parce qu'elle est le seul chemin permanent vers l'écran d'autorisation : celui-ci
        // ne s'ouvre plus de lui-même à chaque lancement, et l'utilisateur qui a répondu
        // « Plus tard » doit pouvoir revenir sur sa décision.
        if needsAccessibility {
            items.append(
                QuickMenuItem(
                    title: L.t("menubar.grantAccessibility"),
                    action: .grantAccessibility
                )
            )
            items.append(QuickMenuItem(title: "", action: .separator))
        }

        let recent = history.prefix(max(0, maxItems))
        if !recent.isEmpty {
            items.append(
                QuickMenuItem(
                    title: L.t("menubar.section.recent"),
                    action: .sectionHeader,
                    isEnabled: false
                )
            )
            for (index, item) in recent.enumerated() {
                items.append(
                    QuickMenuItem(
                        title: Self.singleLine(item),
                        action: .paste(item.id),
                        keyEquivalent: String(index + 1),
                        modifiers: .command
                    )
                )
            }
            items.append(QuickMenuItem(title: "", action: .separator))
        }

        items.append(
            QuickMenuItem(
                title: L.t("menubar.openPopup"),
                action: .openPopup,
                keyEquivalent: "v",
                modifiers: [.command, .shift]
            )
        )
        // L'intitulé bascule, pas un interrupteur : un menu système ne coche pas une action.
        items.append(
            QuickMenuItem(
                title: L.t(isPaused ? "menubar.resumeCapture" : "menubar.pauseCapture"),
                action: .togglePause
            )
        )
        // Points de suspension : l'action ouvre la confirmation du §9 (FR-12).
        items.append(
            QuickMenuItem(
                title: Self.modalTitle("menubar.clearAll"),
                action: .clearAll,
                isEnabled: !history.isEmpty
            )
        )

        items.append(QuickMenuItem(title: "", action: .separator))
        items.append(
            QuickMenuItem(
                title: Self.modalTitle("menubar.settings"),
                action: .openSettings,
                keyEquivalent: ",",
                modifiers: .command
            )
        )
        items.append(QuickMenuItem(title: L.t("menubar.about"), action: .about))

        items.append(QuickMenuItem(title: "", action: .separator))
        items.append(
            QuickMenuItem(
                title: L.t("menu.quit"),
                action: .quit,
                keyEquivalent: "q",
                modifiers: .command
            )
        )

        return items
    }

    // MARK: Libellés

    /// Libellé d'une action qui ouvre une fenêtre ou une confirmation.
    ///
    /// §6 : « les points de suspension marquent les actions qui ouvrent une confirmation ou
    /// une fenêtre ». La règle est appliquée ici plutôt que laissée au catalogue, où elle
    /// serait invérifiable ; la traduction peut néanmoins les porter, ils ne sont pas doublés.
    static func modalTitle(_ key: String.LocalizationValue) -> String {
        let title = L.t(key)
        return title.hasSuffix("…") ? title : title + "…"
    }

    /// Ramène un élément à une ligne unique, tronquée.
    ///
    /// Le nom donné par l'utilisateur prime sur l'aperçu (FR-52). Le repli en cascade évite
    /// une entrée de menu vide, qui serait indistinguable d'un séparateur.
    static func singleLine(_ item: ClipItem) -> String {
        let candidates = [
            item.customName ?? "",
            item.previewLines.joined(separator: " "),
            item.searchText
        ]
        guard let source = candidates.map(flatten).first(where: { !$0.isEmpty }) else {
            return L.t("menubar.item.noPreview")
        }
        return truncate(source)
    }

    /// Aplatit les retours à la ligne et les blancs consécutifs : un item de menu ne fait
    /// qu'une ligne, un contenu multiligne doit s'y lire d'un trait.
    static func flatten(_ text: String) -> String {
        text
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    /// Tronque en fin de libellé, points de suspension compris dans la limite.
    static func truncate(_ text: String) -> String {
        guard text.count > Self.titleCharacterLimit else { return text }
        let kept = text.prefix(Self.titleCharacterLimit - 1)
        return kept.trimmingCharacters(in: .whitespaces) + "…"
    }
}
