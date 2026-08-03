import Foundation

/// Application d'où provient un élément, saisie au moment de la copie (FR-5).
///
/// L'identifiant de bundle sert à l'exclusion (FR-11) ; le nom sert à l'affichage et à la
/// recherche (FR-36). L'icône n'est jamais stockée : elle est résolue à la volée depuis
/// l'identifiant.
public struct SourceApp: Sendable, Hashable, Codable {
    public let bundleIdentifier: String?
    public let name: String

    public init(bundleIdentifier: String?, name: String) {
        self.bundleIdentifier = bundleIdentifier
        self.name = name
    }

    /// Application inconnue — copie provenant d'un processus sans identité utilisable.
    public static let unknown = SourceApp(bundleIdentifier: nil, name: "")

    public var isUnknown: Bool {
        bundleIdentifier == nil && name.isEmpty
    }
}
