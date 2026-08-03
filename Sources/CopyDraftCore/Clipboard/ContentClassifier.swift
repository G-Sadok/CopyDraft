import Foundation

/// Déduction du sous-type d'un contenu capturé (FR-4).
///
/// La classification est **purement cosmétique** : elle ne pilote que la vignette, la police
/// de l'aperçu et la règle de troncature (§2.5). Se tromper coûte un pictogramme, jamais un
/// collage — d'où des règles délibérément conservatrices, qui préfèrent `.plain` au doute.
/// Un faux positif est plus gênant qu'un faux négatif : voir une phrase française s'afficher
/// en chasse fixe surprend, alors qu'un extrait de code affiché en police courante reste
/// lisible.
///
/// L'ordre d'examen est fixe et documenté : image, lien, chemin, couleur, code, enrichi,
/// texte. Les quatre premières formes se reconnaissent à coup sûr sur une ligne courte ; le
/// code, lui, ne se reconnaît qu'à un faisceau d'indices, donc il passe en dernier.
public struct ContentClassifier: Sendable {

    // MARK: Seuils

    /// Longueur maximale, en caractères, d'un lien, d'un chemin ou d'une couleur.
    ///
    /// Ces trois formes tiennent en une ligne courte destinée à être lue dans une cellule de
    /// 360 pt. Au-delà, le contenu est autre chose qui commence par « https:// » — un
    /// document, un journal — et l'analyse caractère par caractère n'apporterait rien.
    private static let singleLineLimit = 2_048

    /// Fenêtre analysée, en caractères, quelle que soit la taille du contenu.
    ///
    /// Les indices de code sont denses : mots-clés, accolades et indentation apparaissent
    /// dans les premières lignes ou pas du tout. Analyser 4 096 caractères borne le coût de
    /// la classification pour un élément qui peut peser jusqu'à 4 Mo (FR-7), et laisse une
    /// marge confortable au-dessus de `singleLineLimit`.
    private static let analysisLimit = 4_096

    /// Somme d'indices à partir de laquelle un texte est tenu pour du code.
    ///
    /// Trois. Un indice isolé ne prouve rien : une phrase française contenant « return »
    /// marque 1, une phrase contenant « return » *et* « import » marque 2, et toutes deux
    /// restent du texte. En revanche deux indices forts — un mot-clé plus une accolade en
    /// fin de ligne — ou trois mots-clés distincts — `SELECT … FROM … WHERE` — ne se
    /// rencontrent pas dans de la prose. Le barème complet est dans ``codeScore(for:)``.
    private static let codeThreshold = 3

    public init() {}

    // MARK: Classification

    /// Déduit le sous-type d'affichage d'un contenu capturé.
    public func classify(_ content: CapturedContent) -> ClipSubtype {
        // Une image se reconnaît à son type de stockage, jamais à son contenu.
        if content.kind == .image { return .image }

        // Repli commun : un contenu qui n'entre dans aucune catégorie garde son type de base.
        let fallback: ClipSubtype = content.kind == .rich ? .rich : .plain

        guard let rawText = content.text else { return fallback }

        // Fenêtre bornée : `prefix(limit + 1)` suffit à savoir si le contenu déborde, sans
        // parcourir les quatre mégaoctets d'un élément de taille maximale.
        let probe = String(rawText.prefix(Self.analysisLimit + 1))
        let isTruncated = probe.count > Self.analysisLimit
        let window = isTruncated ? String(probe.prefix(Self.analysisLimit)) : probe

        let text = Self.normalizingNewlines(window)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return fallback }

        // Un contenu tronqué compte comme multiligne : il est de toute façon trop long pour
        // être un lien, un chemin ou une couleur.
        let isSingleLine = !isTruncated && !text.contains("\n")
        if isSingleLine, text.count <= Self.singleLineLimit {
            if Self.isLink(text) { return .link }
            if Self.isPath(text) { return .path }
            if Self.isColor(text) { return .color }
        }

        if Self.codeScore(for: text) >= Self.codeThreshold { return .code }

        return fallback
    }

    // MARK: Lien

    /// Vrai si la ligne est **entièrement** une URL.
    ///
    /// L'absence totale de blanc est la règle qui écarte « va voir https://exemple.fr pour
    /// les détails » : une phrase contenant une URL n'est pas un lien, c'est du texte.
    private static func isLink(_ line: String) -> Bool {
        guard !line.contains(where: \.isWhitespace) else { return false }
        let lower = line.lowercased()

        if lower.hasPrefix("mailto:") {
            let address = lower.dropFirst("mailto:".count)
            guard let at = address.firstIndex(of: "@") else { return false }
            return at != address.startIndex && address.index(after: at) != address.endIndex
        }

        if let scheme = ["https://", "http://", "ftps://", "ftp://"]
            .first(where: { lower.hasPrefix($0) }) {
            return lower.count > scheme.count
        }

        // « www.apple.com » : forme sans schéma, tolérée parce qu'elle est omniprésente. On
        // exige un domaine puis une extension, faute de quoi « www.  » suffirait.
        guard lower.hasPrefix("www.") else { return false }
        let rest = lower.dropFirst("www.".count)
        guard let dot = rest.firstIndex(of: ".") else { return false }
        return dot != rest.startIndex && rest.index(after: dot) != rest.endIndex
    }

    // MARK: Chemin

    /// Vrai si la ligne est un chemin de fichier POSIX ou une URL `file://`.
    ///
    /// Volontairement limité aux chemins **absolus** : « Documents/notes.md » est
    /// indiscernable d'un fragment de phrase. Un chemin Windows (`C:\…`) n'est pas reconnu —
    /// il ne désigne rien sur macOS et l'ouvrir depuis l'aperçu échouerait.
    private static func isPath(_ line: String) -> Bool {
        if line.lowercased().hasPrefix("file://") { return line.count > "file://".count }
        if line.hasPrefix("~/") { return line.count > 2 }
        // « // » ouvre un commentaire dans la moitié des langages et ne désigne aucun chemin
        // utile sur macOS : sans cette exception, « // TODO: relire » passerait pour un chemin.
        guard line.hasPrefix("/"), !line.hasPrefix("//"), line.count > 1 else { return false }

        // Un chemin peut contenir des espaces (« /Users/moi/Mes documents/note.txt »), mais
        // une phrase commençant par « / » aussi. On n'accepte les espaces qu'à partir de deux
        // séparateurs : la prose n'en aligne pas deux, un vrai chemin profond toujours.
        guard line.contains(where: \.isWhitespace) else { return true }
        return line.count(where: { $0 == "/" }) >= 2
    }

    // MARK: Couleur

    /// Vrai si la ligne est une notation de couleur CSS.
    ///
    /// Hexadécimal à 3, 6 ou 8 chiffres, ou fonction `rgb`/`rgba`/`hsl`/`hsla`. Le contrôle
    /// strict des chiffres hexadécimaux est ce qui distingue `#0A84FF` d'un titre Markdown
    /// « # Rapport » ou d'un mot-dièse.
    private static func isColor(_ line: String) -> Bool {
        if line.hasPrefix("#") {
            let digits = line.dropFirst()
            guard digits.count == 3 || digits.count == 6 || digits.count == 8 else { return false }
            return digits.allSatisfy(\.isHexDigit)
        }

        let lower = line.lowercased()
        guard lower.hasSuffix(")"),
            let function = ["rgba(", "rgb(", "hsla(", "hsl("].first(where: { lower.hasPrefix($0) })
        else { return false }

        // Les unités d'angle sont retirées avant l'analyse : « hsl(211deg 100% 50%) » est la
        // même couleur que « hsl(211, 100%, 50%) ». « grad » avant « rad », sinon il en
        // resterait un « g ».
        var body = String(lower.dropFirst(function.count).dropLast())
        for unit in ["grad", "turn", "deg", "rad"] {
            body = body.replacingOccurrences(of: unit, with: "")
        }

        // Trois composantes, ou quatre avec l'alpha ; séparateur virgule, barre oblique ou
        // espace, les trois syntaxes CSS étant en usage.
        let components = body.split { $0 == "," || $0 == "/" || $0.isWhitespace }
        guard (3...4).contains(components.count) else { return false }
        return components.allSatisfy { component in
            guard let first = component.first, first.isNumber || "+-.".contains(first) else {
                return false
            }
            return component.allSatisfy { $0.isNumber || "+-.%".contains($0) }
        }
    }

    // MARK: Code

    /// Mots-clés reconnus, à la casse près.
    ///
    /// Liste volontairement courte et *curée* : tout mot également français en a été écarté
    /// (« public », « privé », « final », « table », « insert »), parce qu'un mot-clé qui se
    /// déclenche sur de la prose transforme un compte-rendu de réunion en extrait de code.
    /// Les mots-clés SQL sont admis dans les deux casses — aucun n'est un mot français — ce
    /// qui couvre aussi bien `SELECT … FROM` que `select … from`.
    private static let keywords: Set<String> = [
        // Swift et langages à accolades
        "func", "let", "var", "guard", "struct", "enum", "protocol", "extension",
        "class", "static", "throws", "async", "await", "return", "const", "function",
        "typedef", "namespace", "void", "int", "bool", "null", "nil", "true", "false",
        "new", "else", "while", "switch", "case", "print",
        "#include", "#define", "#import", "#pragma",
        // Python
        "def", "import", "lambda", "self", "elif", "None", "True", "False",
        // SQL
        "SELECT", "select", "FROM", "from", "WHERE", "where", "JOIN", "join",
        "INSERT", "UPDATE", "DELETE", "VALUES", "CREATE", "TABLE", "INTO",
        "GROUP", "ORDER", "HAVING", "DISTINCT", "LIMIT",
    ]

    /// Opérateurs composés absents de la prose, quelle que soit la langue.
    private static let operators = ["==", "!=", "=>", "->", "::", "&&", "||", "+=", "<=", ">="]

    /// Somme les indices de code du texte. Barème :
    ///
    /// | Indice | Poids |
    /// |---|---|
    /// | Mot-clé distinct reconnu, plafonné à trois | +1 chacun |
    /// | Une ligne se termine par `{`, `}` ou `;` | +2 |
    /// | Un identifiant est immédiatement suivi de `(` | +1 |
    /// | Une ligne est indentée sous une ligne qui ne l'est pas | +1 |
    /// | Un opérateur composé est présent | +1 |
    /// | Le contenu entier est un bloc `{…}` ou `[…]` | +1 |
    ///
    /// Les poids ne sont pas arbitraires : l'accolade ou le point-virgule en fin de ligne
    /// vaut double parce qu'aucune langue naturelle ne ponctue ainsi, tandis que l'appel de
    /// fonction ne vaut que 1 — le français écrit « le(s) service(s) », « cher(e) collègue »,
    /// et ces parenthèses-là suivent bien un identifiant.
    private static func codeScore(for text: String) -> Int {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingTrailingWhitespace() }
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !lines.isEmpty else { return 0 }

        var score = min(distinctKeywordCount(in: text), 3)

        if lines.contains(where: { line in
            guard let last = line.last else { return false }
            return last == "{" || last == "}" || last == ";"
        }) {
            score += 2
        }

        if containsCallSyntax(text) { score += 1 }

        let hasIndentedLine = lines.contains { $0.hasPrefix("\t") || $0.hasPrefix("  ") }
        let hasFlushLine = lines.contains { !($0.first?.isWhitespace ?? true) }
        if hasIndentedLine && hasFlushLine { score += 1 }

        if operators.contains(where: text.contains) { score += 1 }

        if text.count > 2,
            (text.hasPrefix("{") && text.hasSuffix("}"))
                || (text.hasPrefix("[") && text.hasSuffix("]")) {
            score += 1
        }

        return score
    }

    /// Nombre de mots-clés **distincts** trouvés. Distincts, parce qu'un `let` répété vingt
    /// fois dans une liste à puces ne doit pas peser vingt fois.
    private static func distinctKeywordCount(in text: String) -> Int {
        let tokens = text.split { !$0.isLetter && !$0.isNumber && $0 != "_" && $0 != "#" }
        var found = Set<String>()
        for token in tokens {
            let word = String(token)
            if keywords.contains(word) { found.insert(word) }
        }
        return found.count
    }

    /// Vrai si une parenthèse ouvrante suit immédiatement un identifiant — la signature d'un
    /// appel ou d'une déclaration de fonction.
    private static func containsCallSyntax(_ text: String) -> Bool {
        var previousIsIdentifier = false
        for character in text {
            if character == "(" && previousIsIdentifier { return true }
            previousIsIdentifier = character.isLetter || character.isNumber || character == "_"
        }
        return false
    }

    // MARK: Outils

    /// Ramène les fins de ligne Windows et classiques Mac à `\n`, pour que le découpage en
    /// lignes ne dépende pas de la provenance du texte.
    static func normalizingNewlines(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }
}

extension StringProtocol {
    /// Retire les blancs de fin, en laissant l'indentation de début intacte.
    func trimmingTrailingWhitespace() -> String {
        var result = String(self)
        while let last = result.last, last.isWhitespace { result.removeLast() }
        return result
    }
}
