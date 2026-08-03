import CopyDraftCore
import Foundation
import KeyboardShortcuts

/// Tout ce que l'écran d'onboarding affiche, pour un état de la permission donné (§8).
///
/// Le contenu est une valeur, pas une vue : les deux états du §8 — leurs titres, leurs listes,
/// leurs boutons — se relisent alors sans rien afficher, et la vue n'a plus qu'à les poser.
public struct OnboardingContent: Sendable, Equatable {
    public let isGranted: Bool
    public let title: String
    public let body: String
    /// Trois étapes numérotées quand la permission manque, trois points de confirmation sinon.
    public let items: [String]
    public let primaryTitle: String
    public let secondaryTitle: String
    /// Indicateur « Permission non accordée ». Absent quand elle est accordée : la pastille
    /// verte de l'icône dit déjà tout (§8).
    public let statusLabel: String?
    /// Note de repli du §8, présente seulement quand la permission manque (FR-34).
    public let footnote: String?
    /// Touches du raccourci d'ouverture, une par capuchon — « ⇧ », « ⌘ », « V » (§8).
    public let shortcutKeys: [String]

    /// Compose l'état correspondant à la permission.
    ///
    /// - Parameter shortcut: raccourci d'ouverture affiché en touches. Par défaut celui que
    ///   l'utilisateur a réglé (FR-31), qui n'est pas forcément `⇧⌘V`.
    @MainActor
    public static func make(
        isGranted: Bool,
        shortcut: String? = nil,
        language: String? = nil
    ) -> OnboardingContent {
        func text(_ key: String) -> String {
            LocalizedTable.string(key, table: .onboarding, language: language)
        }

        if isGranted {
            return OnboardingContent(
                isGranted: true,
                title: text("granted.title"),
                body: text("granted.body"),
                items: (1...3).map { text("granted.point.\($0)") },
                primaryTitle: text("granted.primary"),
                secondaryTitle: text("granted.secondary"),
                statusLabel: nil,
                footnote: nil,
                shortcutKeys: keys(from: shortcut ?? currentShortcut())
            )
        }

        return OnboardingContent(
            isGranted: false,
            title: text("denied.title"),
            body: text("denied.body"),
            // Quatre étapes et non trois : la quatrième couvre le piège le plus courant —
            // l'interrupteur déjà activé qui ne change rien, parce que l'autorisation est
            // liée à une signature précise et qu'une entrée périmée la bloque.
            items: (1...4).map { text("denied.step.\($0)") },
            primaryTitle: text("denied.primary"),
            secondaryTitle: text("denied.secondary"),
            statusLabel: text("denied.status"),
            footnote: text("denied.footnote"),
            shortcutKeys: []
        )
    }

    /// Découpe un raccourci en capuchons : « ⇧⌘V » devient « ⇧ », « ⌘ », « V ».
    ///
    /// Le §8 dessine des touches, jamais une chaîne de texte : chaque symbole doit donc être
    /// isolable.
    static func keys(from shortcut: String) -> [String] {
        let keys = shortcut.map(String.init).filter { !$0.isEmpty && $0 != " " }
        return keys.isEmpty ? OnboardingDefaults.shortcutKeys : keys
    }

    /// Raccourci d'ouverture actuellement enregistré, ou celui du design system à défaut.
    @MainActor
    private static func currentShortcut() -> String {
        KeyboardShortcuts.getShortcut(for: .openPopup)?.description
            ?? OnboardingDefaults.shortcutKeys.joined()
    }
}

/// Valeurs de repli du §8.
enum OnboardingDefaults {
    /// `⇧⌘V` — raccourci d'ouverture par défaut (§7, §8).
    static let shortcutKeys = ["⇧", "⌘", "V"]
}
