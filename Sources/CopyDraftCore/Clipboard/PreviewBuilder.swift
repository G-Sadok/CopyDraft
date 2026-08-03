import Foundation

/// Fabrique la projection de recherche et les lignes d'aperçu d'un contenu capturé (FR-24).
///
/// Deux sorties, deux usages. La **projection de recherche** est ce sur quoi le filtrage
/// portera : une trace en clair, aplatie et bornée, conservée en mémoire (ADR-3) — jamais le
/// contenu intégral, qui reste chiffré sur disque. Les **lignes d'aperçu** sont ce que la
/// cellule affichera.
///
/// Ce composant ne décide pas de la mise en forme : il ne tronque pas au caractère près, ne
/// pose pas d'ellipsis et ne connaît rien du gras ni de l'italique du texte enrichi — c'est
/// la vue qui, seule, connaît la largeur disponible et la règle de troncature (fin de ligne,
/// ou milieu pour les liens et les chemins, §1.2). Ici on ne fait que borner raisonnablement.
public struct PreviewBuilder: Sendable {

    // MARK: Seuils

    /// Fenêtre de texte brut lue avant normalisation, en caractères.
    ///
    /// La normalisation des blancs ne fait jamais grandir un texte : seize fois la limite de
    /// recherche laisse largement de quoi remplir 2 048 caractères, même si le contenu
    /// s'ouvre sur un mur de lignes vides ou d'indentation, sans parcourir les quatre
    /// mégaoctets d'un élément de taille maximale (FR-7).
    private static let analysisWindow = ClipItem.searchTextLimit * 16

    /// Longueur maximale d'une ligne d'aperçu, en caractères.
    ///
    /// Borne de sécurité, pas une troncature d'affichage. 512 caractères dépassent de très
    /// loin ce qu'une cellule de 360 pt peut montrer — l'ellipsis tombera bien avant, posée
    /// par la vue — mais évitent de transporter en mémoire la ligne unique d'un fichier
    /// JavaScript minifié pour chaque élément de l'historique.
    public static let lineCharacterLimit = 512

    public init() {}

    // MARK: Projection de recherche

    /// Projection en clair sur laquelle la recherche porte, blancs normalisés et longueur
    /// plafonnée à ``ClipItem/searchTextLimit``.
    ///
    /// Une image renvoie une chaîne vide : ses pixels ne se cherchent pas. La recherche la
    /// retrouve par son application source et par le nom que l'utilisateur lui a donné
    /// (FR-52), pas par son contenu.
    public func searchText(for content: CapturedContent) -> String {
        guard content.kind != .image, let text = content.text else { return "" }
        let window = String(text.prefix(Self.analysisWindow))
        return String(Self.flattened(window).prefix(ClipItem.searchTextLimit))
    }

    // MARK: Lignes d'aperçu

    /// Lignes que la cellule affichera, au plus ``ClipItem/previewLineLimit``.
    ///
    /// - Une image ne produit **aucune** ligne : sa cellule montre sa vignette, son nom et
    ///   ses dimensions (§2.5).
    /// - Le code garde ses deux premières lignes non vides telles quelles, désindentées de
    ///   leur préfixe commun : pour du code, la mise en page *est* l'information, l'aplatir
    ///   la détruirait. Même traitement pour un chemin qui, exceptionnellement, arriverait
    ///   sur plusieurs lignes.
    /// - Tout le reste est aplati en une seule chaîne : c'est la vue qui la répartira sur une
    ///   ou deux lignes selon la largeur dont elle dispose.
    ///
    /// Aucune ligne vide n'est jamais renvoyée.
    public func previewLines(for content: CapturedContent, subtype: ClipSubtype) -> [String] {
        guard content.kind != .image, subtype != .image, let text = content.text else { return [] }
        let window = String(text.prefix(Self.analysisWindow))

        let lines = Self.nonEmptyLines(of: window)
        if subtype == .code || (subtype == .path && lines.count > 1) {
            return Self.dedented(Array(lines.prefix(ClipItem.previewLineLimit)))
                .map { Self.bounded($0).trimmingTrailingWhitespace() }
                .filter { !$0.isEmpty }
        }

        let flattened = Self.bounded(Self.flattened(window))
        return flattened.isEmpty ? [] : [flattened]
    }

    // MARK: Outils

    /// Ramène tout blanc — retour à la ligne, tabulation, espaces consécutifs, espace
    /// insécable — à une espace simple, et retire ceux des extrémités.
    static func flattened(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// Découpe en lignes, fins de ligne Windows comprises, et écarte celles qui ne portent
    /// que du blanc.
    static func nonEmptyLines(of text: String) -> [String] {
        ContentClassifier.normalizingNewlines(text)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    /// Retire aux lignes leur préfixe de blancs commun.
    ///
    /// Un extrait pris au fond d'une fonction arrive indenté de huit ou douze espaces ; les
    /// afficher tels quels laisserait une cellule à moitié vide. Seul le préfixe *commun*
    /// part : l'indentation relative entre les deux lignes, elle, porte du sens.
    static func dedented(_ lines: [String]) -> [String] {
        guard let first = lines.first else { return [] }
        var common = Array(first.prefix(while: \.isWhitespace))

        for line in lines.dropFirst() {
            var shared: [Character] = []
            for (reference, candidate) in zip(common, line.prefix(while: \.isWhitespace)) {
                guard reference == candidate else { break }
                shared.append(reference)
            }
            common = shared
            if common.isEmpty { break }
        }

        guard !common.isEmpty else { return lines }
        return lines.map { String($0.dropFirst(common.count)) }
    }

    /// Applique la borne de sécurité par ligne.
    static func bounded(_ line: String) -> String {
        String(line.prefix(lineCharacterLimit))
    }
}
