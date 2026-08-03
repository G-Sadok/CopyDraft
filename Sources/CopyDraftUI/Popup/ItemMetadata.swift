import CopyDraftCore
import Foundation

/// Ligne de métadonnées d'une cellule d'historique — « app · horodatage relatif · volume » (§2.5).
///
/// Rien n'est mis en forme à la main : l'horodatage passe par `RelativeDateTimeFormatter`, les
/// nombres par `NumberFormatter`, les volumes par le style d'octets de Foundation. C'est la
/// seule façon d'obtenir « il y a 4 min · 1 512 × 982 · 1,2 Mo » en français et
/// « 4 min. ago · 1,512 × 982 · 1.2 MB » en anglais sans écrire deux fois la même règle.
///
/// Le `Locale` et la date de référence sont **injectés** plutôt que lus depuis `Locale.current`
/// et `Date()` : c'est ce qui rend la ligne vérifiable, à la virgule près, dans les deux langues
/// et sans dépendre de l'heure à laquelle les tests tournent.
public struct ItemMetadata: Sendable {

    // MARK: Séparateurs

    /// « · » encadré d'espaces fines (U+2009), comme le demande le §2.5.
    static let separator = "\u{2009}·\u{2009}"

    /// « × » des dimensions d'image, encadré d'espaces insécables : « 1 512 × 982 » ne doit
    /// jamais se couper.
    static let dimensionSeparator = "\u{00A0}×\u{00A0}"

    /// Virgule qui relie le jour et l'heure d'un horodatage ancien — « hier, 18:42 ».
    static let daySeparator = ", "

    // MARK: Ligne de métadonnées

    /// Construit la ligne affichée sous l'aperçu.
    ///
    /// - Parameters:
    ///   - item: l'élément affiché ; c'est son `createdAt` qui fait foi, comme l'ordre de la
    ///     liste (`HistoryRepository` trie sur `createdAt`).
    ///   - showSourceApp: `false` quand l'utilisateur a masqué l'application source. Une
    ///     application inconnue est de toute façon omise, plutôt que d'écrire un segment vide.
    ///   - now: date de référence de l'horodatage relatif.
    ///   - locale: langue et conventions de nombre de l'utilisateur.
    public static func line(
        for item: ClipItem,
        showSourceApp: Bool,
        now: Date,
        locale: Locale
    ) -> String {
        var segments: [String] = []
        if showSourceApp, !item.source.name.isEmpty {
            segments.append(item.source.name)
        }
        segments.append(timestamp(for: item.createdAt, now: now, locale: locale))
        segments.append(contentsOf: volume(for: item, locale: locale))
        return segments.joined(separator: separator)
    }

    // MARK: Horodatage

    /// Horodatage relatif du §2.5 : « il y a 4 min » dans la journée, « hier, 18:42 » au-delà.
    ///
    /// `RelativeDateTimeFormatter` seul dirait « hier » sans l'heure et « la semaine dernière »
    /// pour un élément de mardi : trop vague pour retrouver une copie. On ne lui laisse donc
    /// que la journée en cours et on repasse à une date courte suivie de l'heure ensuite.
    static func timestamp(for date: Date, now: Date, locale: Locale) -> String {
        var calendar = Calendar.current
        calendar.locale = locale

        let relative = RelativeDateTimeFormatter()
        relative.locale = locale
        relative.unitsStyle = .short
        relative.dateTimeStyle = .named

        if calendar.isDate(date, inSameDayAs: now) {
            return relative.localizedString(for: date, relativeTo: now)
        }

        let time = timeFormatter(locale: locale, calendar: calendar).string(from: date)
        let elapsedDays = calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)
        ).day

        let day: String
        if elapsedDays == 1 {
            // « hier » / « yesterday » : le formateur relatif le nomme, la journée ne suffit pas.
            day = relative.localizedString(from: DateComponents(day: -1))
        } else {
            day = dayFormatter(
                locale: locale,
                calendar: calendar,
                includesYear: !calendar.isDate(date, equalTo: now, toGranularity: .year)
            ).string(from: date)
        }
        return day + daySeparator + time
    }

    private static func timeFormatter(locale: Locale, calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }

    private static func dayFormatter(
        locale: Locale, calendar: Calendar, includesYear: Bool
    ) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        // Gabarit plutôt que format figé : l'ordre jour/mois est celui de la langue.
        formatter.setLocalizedDateFormatFromTemplate(includesYear ? "dMMMy" : "dMMM")
        return formatter
    }

    // MARK: Volume

    /// Segments de volume, propres à chaque sous-type (§2.5, « Types de contenu »).
    ///
    /// Une image en produit deux — ses dimensions puis son poids ; un lien aucun, son adresse
    /// dit déjà tout ; un chemin, une couleur ou du texte enrichi donnent leur nature, que
    /// l'aperçu seul ne trahit pas toujours.
    static func volume(for item: ClipItem, locale: Locale) -> [String] {
        switch item.subtype {
        case .image:
            var segments: [String] = []
            if let size = item.pixelSize, size.width > 0, size.height > 0 {
                segments.append(
                    number(Int(size.width.rounded()), locale: locale)
                        + dimensionSeparator
                        + number(Int(size.height.rounded()), locale: locale)
                )
            }
            if item.byteCount > 0 {
                segments.append(item.byteCount.formatted(.byteCount(style: .file).locale(locale)))
            }
            return segments

        case .plain, .code:
            guard let count = item.characterCount, count > 0 else { return [] }
            return [Vocabulary.characters(count, locale: locale)]

        case .link:
            return []

        case .path, .color, .rich:
            return [Vocabulary.subtypeName(item.subtype, locale: locale)]
        }
    }

    /// Nombre groupé selon la langue : « 1 512 » en français, « 1,512 » en anglais.
    static func number(_ value: Int, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    // MARK: Accessibilité (NFR-12)

    /// Libellé VoiceOver d'une cellule : « type, aperçu, application, horodatage, épinglé ».
    ///
    /// L'ordre est celui du NFR-12 et ne suit pas celui de l'affichage : le type vient d'abord
    /// parce qu'il est ce que l'œil lit d'un coup et que l'oreille, elle, doit qu'on le lui dise.
    public static func accessibilityLabel(
        for item: ClipItem,
        preview: String,
        showSourceApp: Bool,
        now: Date,
        locale: Locale
    ) -> String {
        var parts = [Vocabulary.subtypeName(item.subtype, locale: locale)]
        if !preview.isEmpty { parts.append(preview) }
        if showSourceApp, !item.source.name.isEmpty { parts.append(item.source.name) }
        parts.append(timestamp(for: item.createdAt, now: now, locale: locale))
        if item.pinned { parts.append(Vocabulary.pinned(locale: locale)) }
        return parts.joined(separator: ", ")
    }

    /// Valeur VoiceOver d'une cellule : « rang 3 sur 25 » (NFR-12).
    public static func accessibilityRank(index: Int, total: Int, locale: Locale) -> String {
        Vocabulary.rank(index: index, total: total, locale: locale)
    }

    // MARK: Vocabulaire

    /// Les quelques mots que les formateurs de Foundation ne savent pas produire.
    ///
    /// - Important: table provisoire. Ces chaînes ont vocation à rejoindre
    ///   `Resources/*.lproj/Localizable.strings` dès que ce fichier sera disponible ; elles sont
    ///   ici pour que la cellule se lise correctement en français **et** en anglais sans
    ///   dépendre du catalogue. Aucune autre langue n'est couverte : l'anglais sert de repli.
    enum Vocabulary {
        /// Résout une clé dans la langue demandée.
        ///
        /// Les vues ordinaires passent par `L.t` et suivent la langue du système ; ici, le
        /// `Locale` est un paramètre — les tests doivent pouvoir vérifier le français et
        /// l'anglais sans changer la langue de la machine.
        static func string(_ key: String, locale: Locale) -> String {
            let language = locale.language.languageCode?.identifier == "fr" ? "fr" : "en"
            guard let path = Bundle.module.path(forResource: language, ofType: "lproj"),
                let bundle = Bundle(path: path)
            else { return key }
            return bundle.localizedString(forKey: key, value: nil, table: nil)
        }

        static func characters(_ count: Int, locale: Locale) -> String {
            let value = ItemMetadata.number(count, locale: locale)
            let key = count > 1 ? "item.characters.other %@" : "item.characters.one %@"
            return String(format: string(key, locale: locale), value)
        }

        static func subtypeName(_ subtype: ClipSubtype, locale: Locale) -> String {
            string("subtype.\(subtype.rawValue)", locale: locale)
        }

        /// Nom de type capitalisé, employé comme aperçu de repli d'une image sans nom.
        static func capitalizedSubtypeName(_ subtype: ClipSubtype, locale: Locale) -> String {
            let name = subtypeName(subtype, locale: locale)
            return name.prefix(1).uppercased() + name.dropFirst()
        }

        static func pinned(locale: Locale) -> String {
            string("item.pinned", locale: locale)
        }

        /// Libellé du bouton d'épingle, qui bascule avec l'état.
        static func pinAction(isPinned: Bool, locale: Locale) -> String {
            string(isPinned ? "item.unpin" : "item.pin", locale: locale)
        }

        static func rank(index: Int, total: Int, locale: Locale) -> String {
            String(
                format: string("item.rank %1$@ %2$@", locale: locale),
                ItemMetadata.number(index, locale: locale),
                ItemMetadata.number(total, locale: locale)
            )
        }
    }
}
