import Foundation

/// Nature d'un élément capturé, telle qu'elle est stockée (FR-2).
public enum ClipKind: String, Sendable, CaseIterable {
    /// Texte brut.
    case text
    /// Texte enrichi : RTF et/ou HTML, avec une projection texte pour la recherche.
    case rich
    /// Image bitmap.
    case image
}

/// Sous-type de contenu, déduit par heuristique (FR-4).
///
/// Sans effet fonctionnel : il ne pilote que la vignette, la police de l'aperçu et la règle
/// de troncature (§2.5 du design system).
public enum ClipSubtype: String, Sendable, CaseIterable {
    /// Texte courant.
    case plain
    /// Extrait de code — aperçu en SF Mono.
    case code
    /// URL — aperçu en couleur d'accent, troncature au milieu.
    case link
    /// Chemin de fichier — troncature au milieu.
    case path
    /// Couleur écrite en toutes lettres (`#0A84FF`, `rgb(…)`).
    case color
    /// Texte enrichi — gras et italique conservés dans l'aperçu.
    case rich
    /// Image — vignette et dimensions.
    case image

    /// Vrai si le contenu tronque **au milieu** pour garder la fin lisible (§1.2).
    public var truncatesInMiddle: Bool {
        self == .link || self == .path
    }

    /// Vrai si l'aperçu s'affiche en police à chasse fixe (§2.5).
    public var usesMonospacedPreview: Bool {
        self == .code || self == .path
    }

    /// Glyphe SF Symbol de repli quand l'icône de l'application source est inconnue (§1.5).
    public var fallbackSymbolName: String {
        switch self {
        case .plain: "textformat"
        case .code: "curlybraces"
        case .link: "link"
        case .path: "doc.on.doc"
        case .color: "eyedropper"
        case .rich: "doc.richtext"
        case .image: "photo"
        }
    }
}
