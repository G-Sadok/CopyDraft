import AppKit
import CopyDraftCore
import SwiftUI

// MARK: - Cellule d'historique (§2.5)

/// Cellule d'historique — le composant central (§2.5, FR-23, FR-24).
///
/// Vignette, un à deux aperçus, métadonnées, épingle, indice `⌘n` : cinq zones dans 348 pt de
/// large et 44 à 60 pt de haut. La hauteur est posée en `min-height` et jamais fixée, pour
/// qu'une taille de texte agrandie fasse grandir la cellule au lieu de rogner l'aperçu.
///
/// La cellule ne décide de rien : elle ne sait ni si elle est sélectionnée, ni quel est son
/// rang, ni quelle heure il est. Tout lui est donné — c'est ce qui la rend rendue à l'identique
/// par `ImageRenderer` dans les instantanés, et ce qui laisse à la popup la maîtrise du clavier.
/// Seul le survol, qui n'intéresse personne d'autre, est suivi localement.
public struct HistoryCell: View {

    // MARK: Valeurs du §2.5 absentes de `CD`

    /// Métadonnées sur fond accent — « #FFF 78 % » du tableau des spécifications d'état.
    ///
    /// - Important: à remonter dans `CD.Color` (`Colors.swift` ne m'appartient pas).
    private static let onAccentSecondary: Double = 0.78
    /// Fond de vignette sur fond accent — « vignette #FFF 22 % ».
    private static let onAccentFill: Double = 0.22
    /// Échelle de l'état pressé — `scale(0.985)`.
    private static let pressedScale: CGFloat = 0.985
    /// `--accent-pressed` de `design-system/tokens.json`, non transcrit dans `CD.Color`.
    private static let accentPressed = SwiftUI.Color(
        nsColor: NSColor.dynamic(light: 0x00_60_DF, dark: 0x0A_6F_D8)
    )

    // MARK: Entrées

    private let item: ClipItem
    private let isSelected: Bool
    private let shortcutIndex: Int?
    private let showSourceApp: Bool
    private let thumbnail: Image?
    private let appIcon: Image?
    private let richPreview: AttributedString?
    private let onTogglePin: () -> Void

    @Environment(\.locale) private var locale
    @Environment(\.historyCellNow) private var now
    @Environment(\.historyCellRank) private var rank
    @Environment(\.historyCellIsPressed) private var isPressed

    @State private var isHovering = false

    /// - Parameters:
    ///   - item: l'élément à afficher.
    ///   - isSelected: sélection courante de la liste ; l'emporte toujours sur le survol.
    ///   - shortcutIndex: rang 1…9 puis 0 de l'indice `⌘n`, `nil` dès qu'une recherche est
    ///     active — la numérotation ne suivrait plus (§2.4).
    ///   - showSourceApp: affichage du nom de l'application source dans les métadonnées.
    ///   - thumbnail: miniature d'image déjà décodée, sinon `nil`.
    ///   - appIcon: icône de l'application source, sinon `nil`.
    ///   - richPreview: aperçu enrichi construit depuis le RTF, gras et italique seulement.
    ///     `ClipItem` ne porte pas le RTF ; l'appelant le tire de `StoredContent.rtfData` et
    ///     passe par ``HistoryCell/richPreview(fromRTF:)``.
    ///   - onTogglePin: bascule d'épinglage, déclenchée par l'épingle seule — jamais par le
    ///     reste de la cellule.
    public init(
        item: ClipItem,
        isSelected: Bool,
        shortcutIndex: Int?,
        showSourceApp: Bool,
        thumbnail: Image?,
        appIcon: Image?,
        richPreview: AttributedString? = nil,
        onTogglePin: @escaping () -> Void
    ) {
        self.item = item
        self.isSelected = isSelected
        self.shortcutIndex = shortcutIndex
        self.showSourceApp = showSourceApp
        self.thumbnail = thumbnail
        self.appIcon = appIcon
        self.richPreview = richPreview
        self.onTogglePin = onTogglePin
    }

    // MARK: États

    /// Les quatre états du §2.5, dans leur ordre de priorité : survol et sélection ne se
    /// cumulent pas, la sélection l'emporte ; un appui l'emporte sur tout.
    enum Appearance {
        case rest, hover, selected, pressed

        var isOnAccent: Bool { self == .selected || self == .pressed }
    }

    var appearance: Appearance {
        if isPressed { return .pressed }
        if isSelected { return .selected }
        if isHovering { return .hover }
        return .rest
    }

    /// Amorce l'état de survol.
    ///
    /// Le survol est le seul état que la cellule suit elle-même, et `ImageRenderer` ne survole
    /// rien : sans cette amorce, l'instantané de l'état « survol » du §2.5 serait impossible à
    /// produire. Réservé aux instantanés et aux aperçus — en usage réel, la souris suffit.
    func hovering(_ value: Bool) -> HistoryCell {
        var copy = self
        copy._isHovering = State(initialValue: value)
        return copy
    }

    // MARK: Corps

    public var body: some View {
        HStack(alignment: .center, spacing: CD.Space.x2_5) {
            thumbnailView
            textColumn
            Spacer(minLength: CD.Space.x1)
            trailingControls
        }
        .padding(.horizontal, CD.Metric.cellPadding)
        // Le « pad 8 » du §2.5 est celui de la vignette : dans une cellule de 44 pt, les 8 pt
        // au-dessus et au-dessous de ses 28 pt viennent du centrage. La colonne de texte, elle,
        // ne peut prendre que 6 pt — sinon aperçu et métadonnées ne tiendraient plus dans 44.
        .padding(.vertical, CD.Space.x1_5)
        .frame(
            maxWidth: .infinity,
            minHeight: CD.Metric.cellHeightMin,
            alignment: .leading
        )
        .background(
            RoundedRectangle(cornerRadius: CD.Radius.cell, style: .continuous)
                .fill(backgroundFill)
        )
        .contentShape(RoundedRectangle(cornerRadius: CD.Radius.cell, style: .continuous))
        .scaleEffect(appearance == .pressed ? Self.pressedScale : 1)
        .onHover { isHovering = $0 }
        .animation(CD.Motion.animation(CD.Motion.hover), value: isHovering)
        .animation(CD.Motion.animation(CD.Motion.selection), value: isSelected)
        .animation(CD.Motion.animation(CD.Motion.press), value: isPressed)
    }

    private var backgroundFill: SwiftUI.Color {
        switch appearance {
        case .rest: .clear
        case .hover: CD.Color.fillHover
        case .selected: CD.Color.accent
        case .pressed: Self.accentPressed
        }
    }

    // MARK: 1 · Vignette

    /// 28 × 28, rayon 6. Icône de l'application source, sinon glyphe de type, sinon miniature
    /// pour une image — la miniature passe devant, une capture d'écran se reconnaît d'abord à
    /// ce qu'elle montre.
    @ViewBuilder
    private var thumbnailView: some View {
        Group {
            if item.subtype == .image, let thumbnail {
                thumbnail
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if let appIcon {
                appIcon
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .background(thumbnailFill)
            } else {
                Image(systemName: item.subtype.fallbackSymbolName)
                    .imageScale(.small)
                    .foregroundStyle(glyphColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(thumbnailFill)
            }
        }
        .frame(width: CD.Metric.cellThumbnail, height: CD.Metric.cellThumbnail)
        .clipShape(RoundedRectangle(cornerRadius: CD.Radius.cell, style: .continuous))
        .accessibilityHidden(true)
    }

    private var thumbnailFill: SwiftUI.Color {
        appearance.isOnAccent
            ? CD.Color.textOnAccent.opacity(Self.onAccentFill)
            : CD.Color.fill1
    }

    private var glyphColor: SwiftUI.Color {
        appearance.isOnAccent ? CD.Color.textOnAccent : CD.Color.text2
    }

    // MARK: 2 et 3 · Aperçu et métadonnées

    private var textColumn: some View {
        VStack(alignment: .leading, spacing: CD.Space.x0_5) {
            previewView
            Text(metadataLine)
                .font(CD.Font.small)
                .foregroundStyle(metadataColor)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
    }

    /// Un à deux aperçus.
    ///
    /// Le texte enrichi et le contenu déjà aplati tiennent dans un seul `Text` que l'on laisse
    /// courir sur deux lignes : `PreviewBuilder` n'aplatit pas pour rien, c'est la vue qui
    /// connaît la largeur disponible. Seul le code arrive en plusieurs lignes, et chacune garde
    /// alors sa propre troncature — l'indentation relative y porte du sens.
    @ViewBuilder
    private var previewView: some View {
        if let richPreview, item.subtype == .rich, item.customName == nil {
            styledPreview(Text(richPreview), lineLimit: previewLineLimit)
        } else {
            let lines = previewLines
            if lines.count > 1 {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        styledPreview(Text(line), lineLimit: 1, isCustomName: index == 0 && hasCustomName)
                    }
                }
            } else {
                styledPreview(
                    Text(lines.first ?? ""),
                    lineLimit: previewLineLimit,
                    isCustomName: hasCustomName
                )
            }
        }
    }

    /// Une ligne repliée sur une seule ligne d'affichage tronque **au milieu** pour les liens
    /// et les chemins (§1.2) : leur fin — le fichier, la page — est ce qui les distingue.
    private var previewLineLimit: Int {
        item.subtype.truncatesInMiddle ? 1 : ClipItem.previewLineLimit
    }

    /// - Note: l'interligne du §1.2 (13/17, 11,5/16) n'est **pas** posé par `cdFont` ici.
    ///   Ce modificateur réclame la taille en points, que `CD` n'expose pas — il faudrait
    ///   l'écrire en dur — et l'écart de 4 pt qu'il ajoute entre deux lignes ferait passer une
    ///   cellule de deux lignes à 63 pt, au-delà du plafond de 60 pt du §2.5. L'interligne
    ///   naturel de SF Pro (≈ 16 pt à 13 pt) tient la cellule à 59 pt.
    private func styledPreview(
        _ text: Text, lineLimit: Int, isCustomName: Bool = false
    ) -> some View {
        text
            .font(isCustomName || !item.subtype.usesMonospacedPreview ? CD.Font.body : CD.Font.code)
            .foregroundStyle(previewColor)
            .lineLimit(lineLimit)
            .truncationMode(item.subtype.truncatesInMiddle ? .middle : .tail)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var hasCustomName: Bool {
        !(item.customName ?? "").isEmpty
    }

    /// Lignes affichées : celles de l'élément, dont la première cède la place au nom donné par
    /// l'utilisateur (FR-52). Une image sans nom n'a aucune ligne d'aperçu — on lui donne son
    /// type, sans quoi il ne resterait que les métadonnées.
    var previewLines: [String] {
        var lines = item.previewLines
        if let name = item.customName, !name.isEmpty {
            if lines.isEmpty { lines = [name] } else { lines[0] = name }
        }
        if lines.isEmpty {
            lines = [ItemMetadata.Vocabulary.capitalizedSubtypeName(item.subtype, locale: locale)]
        }
        return lines
    }

    private var previewColor: SwiftUI.Color {
        if appearance.isOnAccent { return CD.Color.textOnAccent }
        // Une URL prend la couleur d'accent : c'est le seul contenu qui s'annonce comme un lien.
        return item.subtype == .link ? CD.Color.accent : CD.Color.text1
    }

    private var metadataColor: SwiftUI.Color {
        appearance.isOnAccent
            ? CD.Color.textOnAccent.opacity(Self.onAccentSecondary)
            : CD.Color.text2
    }

    var metadataLine: String {
        ItemMetadata.line(for: item, showSourceApp: showSourceApp, now: now, locale: locale)
    }

    // MARK: 4 et 5 · Épingle et indice ⌘n

    private var trailingControls: some View {
        HStack(spacing: CD.Space.x1_5) {
            pinButton
            shortcutBadge
        }
    }

    /// L'épingle est un bouton à part entière : la cliquer épingle sans coller l'élément, et
    /// sa cible de 22 pt reste attrapable à la souris même si le glyphe n'en fait que 14 (§1.5).
    /// Au survol, une épingle fantôme en `text3` dit qu'il y a quelque chose à cliquer.
    private var pinButton: some View {
        Button(action: onTogglePin) {
            Image(systemName: "pin.fill")
                .font(.system(size: CD.Metric.cellPin))
                .foregroundStyle(pinColor)
                .opacity(pinOpacity)
                .frame(width: CD.Metric.hitTargetMin, height: CD.Metric.hitTargetMin)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .allowsHitTesting(item.pinned || isHovering)
        .accessibilityLabel(
            ItemMetadata.Vocabulary.pinAction(isPinned: item.pinned, locale: locale)
        )
        .animation(CD.Motion.fade(CD.Motion.hover), value: isHovering)
        .animation(CD.Motion.fade(CD.Motion.reorder), value: item.pinned)
    }

    private var pinColor: SwiftUI.Color {
        if appearance.isOnAccent {
            return CD.Color.textOnAccent
                .opacity(item.pinned ? 1 : Self.onAccentSecondary)
        }
        return item.pinned ? CD.Color.accent : CD.Color.text3
    }

    private var pinOpacity: Double {
        if item.pinned { return 1 }
        return isHovering ? 1 : 0
    }

    /// Indice `⌘n` : rangs 1 à 9 puis `⌘0`, masqué dès qu'une recherche est active (§2.4).
    @ViewBuilder
    private var shortcutBadge: some View {
        if let shortcutIndex, let symbol = Self.shortcutSymbol(for: shortcutIndex) {
            Text(symbol)
                .font(CD.Font.shortcut)
                .foregroundStyle(badgeForeground)
                .padding(.horizontal, CD.Space.x1)
                .frame(
                    minWidth: CD.Metric.cellShortcutBadgeWidth,
                    minHeight: CD.Metric.cellShortcutBadgeHeight
                )
                .background(
                    RoundedRectangle(cornerRadius: CD.Radius.badge, style: .continuous)
                        .fill(badgeFill)
                )
                .accessibilityHidden(true)
        }
    }

    /// « ⌘1 »… « ⌘9 » puis « ⌘0 » ; au-delà de dix éléments, plus d'indice.
    static func shortcutSymbol(for index: Int) -> String? {
        switch index {
        case 1...9: "⌘\(index)"
        case 10: "⌘0"
        default: nil
        }
    }

    private var badgeFill: SwiftUI.Color {
        appearance.isOnAccent
            ? CD.Color.textOnAccent.opacity(Self.onAccentFill)
            : CD.Color.fill3
    }

    private var badgeForeground: SwiftUI.Color {
        appearance.isOnAccent ? CD.Color.textOnAccent : CD.Color.text2
    }

    // MARK: Accessibilité (NFR-12)

    private var accessibilityLabel: String {
        ItemMetadata.accessibilityLabel(
            for: item,
            preview: previewLines.joined(separator: " "),
            showSourceApp: showSourceApp,
            now: now,
            locale: locale
        )
    }

    private var accessibilityValue: String {
        guard let rank else { return "" }
        return ItemMetadata.accessibilityRank(
            index: rank.index, total: rank.total, locale: locale
        )
    }
}

// MARK: - Aperçu du texte enrichi

extension HistoryCell {
    /// Construit l'aperçu d'un élément enrichi depuis son RTF, **gras et italique seulement**.
    ///
    /// Le §2.5 est net : « le texte enrichi conserve gras et italique dans l'aperçu, rien
    /// d'autre — pas de couleur ni de corps hérités ». Une note collée depuis une page web
    /// arriverait sinon en Times 18 pt violet au milieu d'une liste de 13 pt. On ne garde donc
    /// que l'intention de présentation, que `Text` réinterprète avec la police de la cellule.
    ///
    /// Les blancs sont ramenés à une espace simple, comme le fait `PreviewBuilder` pour le
    /// texte brut : la mise en page d'origine ne survit pas à 348 pt de large.
    public static func richPreview(fromRTF data: Data) -> AttributedString? {
        guard
            let source = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            ), source.length > 0
        else { return nil }

        var result = AttributedString()
        source.enumerateAttribute(
            .font, in: NSRange(location: 0, length: source.length)
        ) { value, range, _ in
            let text = collapsedWhitespace(source.attributedSubstring(from: range).string)
            guard !text.isEmpty else { return }

            var run = AttributedString(text)
            let traits = (value as? NSFont)?.fontDescriptor.symbolicTraits ?? []
            var intent: InlinePresentationIntent = []
            if traits.contains(.bold) { intent.insert(.stronglyEmphasized) }
            if traits.contains(.italic) { intent.insert(.emphasized) }
            if !intent.isEmpty { run.inlinePresentationIntent = intent }
            result.append(run)
        }

        result = trimmed(result)
        guard !result.characters.isEmpty else { return nil }
        if result.characters.count > PreviewBuilder.lineCharacterLimit {
            let end = result.index(
                result.startIndex, offsetByCharacters: PreviewBuilder.lineCharacterLimit
            )
            result = AttributedString(result[result.startIndex..<end])
        }
        return result
    }

    /// Ramène toute suite de blancs à une espace simple, sans toucher aux bords : les espaces
    /// de bord portent la séparation entre deux fragments de mise en forme voisins.
    static func collapsedWhitespace(_ text: String) -> String {
        var out = ""
        var pending = false
        for character in text {
            if character.isWhitespace {
                pending = true
                continue
            }
            if pending, !out.isEmpty || text.first?.isWhitespace == true {
                out.append(" ")
            }
            pending = false
            out.append(character)
        }
        if pending, !out.isEmpty { out.append(" ") }
        return out
    }

    private static func trimmed(_ value: AttributedString) -> AttributedString {
        var result = value
        while let first = result.characters.first, first.isWhitespace {
            result.removeSubrange(result.startIndex..<result.index(afterCharacter: result.startIndex))
        }
        while let last = result.characters.last, last.isWhitespace {
            result.removeSubrange(result.index(beforeCharacter: result.endIndex)..<result.endIndex)
        }
        return result
    }
}

// MARK: - Rang, appui et heure de référence

/// Rang d'une cellule dans la liste, annoncé par VoiceOver — « rang 3 sur 25 » (NFR-12).
///
/// Le rang ne figure pas dans l'initialiseur de ``HistoryCell`` : il n'appartient pas à
/// l'élément mais à la liste qui l'affiche, et il change à chaque filtrage sans que la cellule
/// change. Il passe donc par l'environnement, où la popup le pose une fois par ligne.
public struct HistoryCellRank: Sendable, Equatable {
    public let index: Int
    public let total: Int

    public init(index: Int, total: Int) {
        self.index = index
        self.total = total
    }
}

private struct HistoryCellRankKey: EnvironmentKey {
    static let defaultValue: HistoryCellRank? = nil
}

private struct HistoryCellPressedKey: EnvironmentKey {
    static let defaultValue = false
}

private struct HistoryCellNowKey: EnvironmentKey {
    static var defaultValue: Date { Date() }
}

extension EnvironmentValues {
    public var historyCellRank: HistoryCellRank? {
        get { self[HistoryCellRankKey.self] }
        set { self[HistoryCellRankKey.self] = newValue }
    }

    /// État d'appui, posé par ``HistoryCellButtonStyle``.
    public var historyCellIsPressed: Bool {
        get { self[HistoryCellPressedKey.self] }
        set { self[HistoryCellPressedKey.self] = newValue }
    }

    /// Date de référence des horodatages relatifs. `Date()` en usage réel ; fixée dans les
    /// instantanés pour qu'ils ne changent pas d'une minute à l'autre.
    public var historyCellNow: Date {
        get { self[HistoryCellNowKey.self] }
        set { self[HistoryCellNowKey.self] = newValue }
    }
}

extension View {
    /// Annonce le rang de la cellule à VoiceOver (NFR-12).
    public func historyCellRank(_ index: Int, of total: Int) -> some View {
        environment(\.historyCellRank, HistoryCellRank(index: index, total: total))
    }

    /// Fixe la date de référence des horodatages relatifs.
    public func historyCellNow(_ date: Date) -> some View {
        environment(\.historyCellNow, date)
    }
}

/// Style de bouton à appliquer autour d'une ``HistoryCell`` cliquable.
///
/// C'est lui qui transmet l'appui à la cellule : l'état pressé du §2.5 appartient au bouton qui
/// enveloppe la cellule, pas à la cellule, qui ne sait pas ce qu'un clic déclenche.
public struct HistoryCellButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .environment(\.historyCellIsPressed, configuration.isPressed)
    }
}

extension ButtonStyle where Self == HistoryCellButtonStyle {
    public static var historyCell: HistoryCellButtonStyle { HistoryCellButtonStyle() }
}
