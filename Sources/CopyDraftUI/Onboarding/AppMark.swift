import SwiftUI

/// Icône de CopyDraft dessinée en vecteur, telle que le §9 la décrit : « deux feuilles
/// décalées — l'ancienne, l'actuelle — l'histoire du presse-papiers en un glyphe ».
///
/// Elle est dessinée plutôt que chargée : l'onboarding et « À propos » s'affichent aussi quand
/// l'exécutable tourne hors de `CopyDraft.app`, où `NSApp.applicationIconImage` retomberait sur
/// l'icône générique de macOS.
struct AppMark: View {
    /// Côté du gabarit, en points.
    let size: CGFloat
    /// Pastille de confirmation verte posée en bas à droite — état « permission accordée » (§8).
    var isConfirmed = false

    var body: some View {
        tile
            .overlay(alignment: .bottomTrailing) {
                if isConfirmed { badge }
            }
            .accessibilityElement()
            .accessibilityLabel(
                Text(
                    L.t(
                        isConfirmed
                            ? "appMark.granted.accessibilityLabel" : "appMark.accessibilityLabel",
                        table: .onboarding
                    )
                )
            )
    }

    // MARK: Gabarit

    private var tile: some View {
        RoundedRectangle(cornerRadius: size * AppMarkStyle.cornerRatio, style: .continuous)
            .fill(AppMarkStyle.gradient)
            .frame(width: size, height: size)
            .overlay(alignment: .top) {
                // Liseré supérieur blanc à 25 % : le relief du gabarit macOS (§9).
                RoundedRectangle(cornerRadius: size * AppMarkStyle.cornerRatio, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(AppMarkStyle.rimOpacity), .white.opacity(0)
                            ],
                            startPoint: .top,
                            endPoint: .center
                        ),
                        lineWidth: AppMarkStyle.rimWidth
                    )
            }
            .overlay { sheets }
    }

    /// Les deux feuilles, à l'échelle du gabarit de 30 unités du design system.
    private var sheets: some View {
        let unit = size / AppMarkStyle.glyphBox
        let sheet = CGSize(width: 13 * unit, height: 17 * unit)
        let radius = 3 * unit
        let stroke = AppMarkStyle.glyphStroke * unit

        return ZStack {
            // Feuille ancienne, en retrait.
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(.white.opacity(AppMarkStyle.backSheetOpacity), lineWidth: stroke)
                .frame(width: sheet.width, height: sheet.height)
                .offset(x: -1.5 * unit, y: -2 * unit)

            // Feuille actuelle, opaque, avec ses deux lignes de texte.
            ZStack {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(AppMarkStyle.ink)
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(.white, lineWidth: stroke)
                VStack(alignment: .leading, spacing: 3.4 * unit) {
                    Capsule().fill(.white).frame(width: 6.8 * unit, height: stroke)
                    Capsule().fill(.white).frame(width: 4.4 * unit, height: stroke)
                }
                .padding(.leading, 3.1 * unit)
                .frame(width: sheet.width, alignment: .leading)
            }
            .frame(width: sheet.width, height: sheet.height)
            .offset(x: 1.5 * unit, y: 2 * unit)
        }
    }

    // MARK: Pastille de confirmation

    private var badge: some View {
        let side = size * AppMarkStyle.badgeRatio
        return Image(systemName: "checkmark")
            .font(.system(size: side * AppMarkStyle.badgeGlyphRatio, weight: .bold))
            .foregroundStyle(CD.Color.textOnAccent)
            .frame(width: side, height: side)
            .background(CD.Color.success, in: Circle())
            .overlay {
                Circle().strokeBorder(CD.Color.bgWindow, lineWidth: side * AppMarkStyle.badgeRim)
            }
            .offset(x: side * AppMarkStyle.badgeOffset, y: side * AppMarkStyle.badgeOffset)
    }
}

/// Cotes et couleurs de l'icône d'application (§9). Elles n'appartiennent pas au système de
/// couleurs sémantiques : ce sont les teintes de la marque, pas des rôles d'interface.
enum AppMarkStyle {
    /// Rayon du gabarit macOS : 24 % du côté.
    static let cornerRatio: CGFloat = 0.24
    /// Le glyphe du design system est tracé dans une boîte de 30 unités.
    static let glyphBox: CGFloat = 30
    /// Épaisseur des traits du glyphe, dans cette même boîte.
    static let glyphStroke: CGFloat = 1.6
    /// Feuille ancienne : blanc à 55 %.
    static let backSheetOpacity: Double = 0.55
    /// Liseré supérieur : blanc à 25 %.
    static let rimOpacity: Double = 0.25
    static let rimWidth: CGFloat = 1
    /// Pastille de confirmation : 37,5 % du côté du gabarit.
    static let badgeRatio: CGFloat = 0.375
    static let badgeGlyphRatio: CGFloat = 0.54
    static let badgeRim: CGFloat = 0.1
    /// Débord de la pastille hors du gabarit.
    static let badgeOffset: CGFloat = 0.2

    /// Bleu-ardoise du §9, incliné à 165°.
    static let gradient = LinearGradient(
        colors: [Color(red: 0.290, green: 0.357, blue: 0.494), ink],
        startPoint: UnitPoint(x: 0.371, y: 0.017),
        endPoint: UnitPoint(x: 0.629, y: 0.983)
    )

    /// Fond de la feuille actuelle — l'extrémité sombre du dégradé.
    static let ink = Color(red: 0.137, green: 0.169, blue: 0.251)
}
