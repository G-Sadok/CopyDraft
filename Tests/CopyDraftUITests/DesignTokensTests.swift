import AppKit
import Foundation
import Testing

@testable import CopyDraftUI

/// `design-system/tokens.json` est la source de vérité ; `CD` en est la transcription.
/// Ces tests échouent dès que l'un des deux bouge sans l'autre.
@Suite("Tokens du design system")
struct DesignTokensTests {
    /// Relu à chaque appel : un dictionnaire hétérogène ne peut pas être une constante
    /// globale en concurrence stricte, et la lecture d'un fichier de 3 ko est indolore.
    static func tokens() throws -> [String: Any] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CopyDraftUITests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // racine du dépôt
            .appendingPathComponent("design-system/tokens.json")
        let data = try Data(contentsOf: url)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    static func group(_ name: String) -> [String: Any] {
        ((try? tokens())?[name] as? [String: Any]) ?? [:]
    }

    static func number(_ group: String, _ key: String) -> Double? {
        (Self.group(group)[key] as? NSNumber)?.doubleValue
    }

    // MARK: Espacements

    @Test(
        "Les espacements suivent le JSON",
        arguments: [
            ("0.5", CD.Space.x0_5), ("1", CD.Space.x1), ("1.5", CD.Space.x1_5),
            ("2", CD.Space.x2), ("2.5", CD.Space.x2_5), ("3", CD.Space.x3),
            ("4", CD.Space.x4), ("5", CD.Space.x5), ("6", CD.Space.x6), ("8", CD.Space.x8)
        ]
    )
    func spacing(key: String, value: CGFloat) throws {
        #expect(try #require(Self.number("space", key)) == Double(value))
    }

    /// Base 4 pt : seuls 2 et 6 sont des demi-pas tolérés (densité de la popup).
    @Test("Les espacements respectent la base 4 pt")
    func spacingGrid() {
        let values = [
            CD.Space.x1, CD.Space.x2, CD.Space.x3, CD.Space.x4,
            CD.Space.x5, CD.Space.x6, CD.Space.x8
        ]
        for value in values {
            #expect(value.truncatingRemainder(dividingBy: 4) == 0, "\(value) hors grille")
        }
        #expect(CD.Space.x0_5 == 2)
        #expect(CD.Space.x1_5 == 6)
    }

    // MARK: Rayons

    @Test(
        "Les rayons suivent le JSON",
        arguments: [
            ("popover", CD.Radius.popover), ("window", CD.Radius.window),
            ("menu", CD.Radius.menu), ("cell", CD.Radius.cell),
            ("field", CD.Radius.field), ("button", CD.Radius.button),
            ("badge", CD.Radius.badge), ("thumbnail", CD.Radius.thumbnail)
        ]
    )
    func radius(key: String, value: CGFloat) throws {
        #expect(try #require(Self.number("radius", key)) == Double(value))
    }

    // MARK: Cotes

    @Test(
        "Les cotes des surfaces suivent le JSON",
        arguments: [
            ("popup.width", CD.Metric.popupWidth),
            ("popup.height.min", CD.Metric.popupHeightMin),
            ("popup.height.max", CD.Metric.popupHeightMax),
            ("popup.height.screenFraction", CD.Metric.popupHeightScreenFraction),
            ("popup.cursorOffset", CD.Metric.popupCursorOffset),
            ("popup.screenMargin", CD.Metric.popupScreenMargin),
            ("popup.innerPadding", CD.Metric.popupInnerPadding),
            ("popup.cellGap", CD.Metric.popupCellGap),
            ("popup.sectionHeader", CD.Metric.popupSectionHeader),
            ("cell.width", CD.Metric.cellWidth),
            ("cell.height.min", CD.Metric.cellHeightMin),
            ("cell.height.max", CD.Metric.cellHeightMax),
            ("cell.thumbnail", CD.Metric.cellThumbnail),
            ("cell.thumbnailGap", CD.Metric.cellThumbnailGap),
            ("cell.padding", CD.Metric.cellPadding),
            ("cell.pin", CD.Metric.cellPin),
            ("cell.shortcutBadge.width", CD.Metric.cellShortcutBadgeWidth),
            ("cell.shortcutBadge.height", CD.Metric.cellShortcutBadgeHeight),
            ("search.height", CD.Metric.searchHeight),
            ("footer.height", CD.Metric.footerHeight),
            ("icon.box", CD.Metric.iconBox),
            ("hitTarget.min", CD.Metric.hitTargetMin),
            ("button.height", CD.Metric.buttonHeight),
            ("button.paddingHorizontal", CD.Metric.buttonPaddingHorizontal),
            ("menu.width", CD.Metric.menuWidth),
            ("menu.itemHeight", CD.Metric.menuItemHeight),
            ("statusIcon.template", CD.Metric.statusIconTemplate),
            ("statusIcon.box", CD.Metric.statusIconBox),
            ("settings.width", CD.Metric.settingsWidth),
            ("settings.labelColumn", CD.Metric.settingsLabelColumn),
            ("settings.gutter", CD.Metric.settingsGutter),
            ("onboarding.width", CD.Metric.onboardingWidth),
            ("onboarding.height", CD.Metric.onboardingHeight),
            ("toast.bottomInset", CD.Metric.toastBottomInset)
        ]
    )
    func metric(key: String, value: CGFloat) throws {
        #expect(try #require(Self.number("metric", key)) == Double(value))
    }

    @Test(
        "Les nombres de lignes visibles suivent le JSON",
        arguments: [
            ("rows.visible", CD.Metric.rowsVisible),
            ("rows.visible.min", CD.Metric.rowsVisibleMin),
            ("rows.visible.max", CD.Metric.rowsVisibleMax)
        ]
    )
    func rowCount(key: String, value: Int) throws {
        #expect(try #require(Self.number("metric", key)) == Double(value))
    }

    // MARK: Mouvement

    @Test(
        "Les durées suivent le JSON, exprimées en secondes",
        arguments: [
            ("popup.in", CD.Motion.popupIn), ("popup.out", CD.Motion.popupOut),
            ("selection", CD.Motion.selection), ("hover", CD.Motion.hover),
            ("press", CD.Motion.press), ("reorder", CD.Motion.reorder),
            ("delete", CD.Motion.delete), ("search", CD.Motion.search),
            ("toast.in", CD.Motion.toastIn), ("toast.out", CD.Motion.toastOut),
            ("theme", CD.Motion.theme), ("tooltip.delay", CD.Motion.tooltipDelay),
            ("toast.dwell", CD.Motion.toastDwell),
            ("reduceMotion.fade", CD.Motion.reducedFade)
        ]
    )
    func motion(key: String, seconds: TimeInterval) throws {
        let milliseconds = try #require(Self.number("motion", key))
        #expect(abs(milliseconds / 1000 - seconds) < 0.0005)
    }

    /// « Rien ne dure plus de 180 ms » (§10).
    @Test("Aucune transition ne dépasse 180 ms")
    func motionCeiling() {
        let transitions = [
            CD.Motion.popupIn, CD.Motion.popupOut, CD.Motion.selection, CD.Motion.hover,
            CD.Motion.press, CD.Motion.reorder, CD.Motion.delete,
            CD.Motion.toastIn, CD.Motion.toastOut
        ]
        for duration in transitions {
            #expect(duration <= 0.180)
        }
    }

    /// Une durée nulle ne produit jamais d'animation, quel que soit le réglage système.
    @Test("Une durée nulle ne produit aucune animation")
    func zeroDurationHasNoAnimation() {
        #expect(CD.Motion.animation(0) == nil)
        #expect(CD.Motion.fade(0) == nil)
    }

    // MARK: Typographie

    @Test(
        "Les tailles typographiques suivent le JSON",
        arguments: [
            ("title.lg", CD.LineHeight.titleLarge), ("title.1", CD.LineHeight.title1),
            ("title.2", CD.LineHeight.title2), ("title.3", CD.LineHeight.title3),
            ("emphasis", CD.LineHeight.emphasis), ("body", CD.LineHeight.body),
            ("code", CD.LineHeight.code), ("caption", CD.LineHeight.caption),
            ("small", CD.LineHeight.small), ("shortcut", CD.LineHeight.shortcut),
            ("micro", CD.LineHeight.micro)
        ]
    )
    func lineHeight(role: String, value: CGFloat) throws {
        let spec = try #require(Self.group("typography")[role] as? [String: Any])
        #expect((spec["lineHeight"] as? NSNumber)?.doubleValue == Double(value))
    }

    /// « Aucun texte en dessous de 10 pt » (§1.2).
    @Test("Aucune taille de texte sous 10 pt")
    func minimumTextSize() throws {
        for (_, spec) in Self.group("typography") {
            let size = try #require((spec as? [String: Any])?["size"] as? NSNumber)
            #expect(size.doubleValue >= 10)
        }
    }

    // MARK: Couleurs

    /// Les rôles adossés au système doivent le rester : c'est ce qui fait suivre l'accent
    /// choisi par l'utilisateur et le mode clair/sombre.
    @Test("Les rôles clés restent adossés aux couleurs système")
    func systemBackedRoles() {
        #expect(CD.Palette.accent == NSColor.controlAccentColor)
        #expect(CD.Palette.selection == NSColor.selectedContentBackgroundColor)
        #expect(CD.Palette.separator == NSColor.separatorColor)
        #expect(CD.Palette.text1 == NSColor.labelColor)
        #expect(CD.Palette.text2 == NSColor.secondaryLabelColor)
        #expect(CD.Palette.text3 == NSColor.tertiaryLabelColor)
    }

    @Test("Les couleurs dynamiques reprennent les valeurs du JSON")
    func dynamicColorsMatchJSON() throws {
        let solid = try #require(
            (Self.group("color")["bg.popover.solid"] as? [String: Any])?["light"] as? String
        )
        #expect(solid == "#F6F6F6")

        let light = CD.Palette.bgPopoverSolid.resolved(for: .aqua)
        #expect(abs(light.redComponent - 0xF6 / 255.0) < 0.005)
        #expect(abs(light.greenComponent - 0xF6 / 255.0) < 0.005)
        #expect(abs(light.blueComponent - 0xF6 / 255.0) < 0.005)

        let dark = CD.Palette.bgPopoverSolid.resolved(for: .darkAqua)
        #expect(abs(dark.redComponent - 0x2C / 255.0) < 0.005)
        #expect(abs(dark.blueComponent - 0x2E / 255.0) < 0.005)
    }

    @Test("Le champ de recherche garde ses alphas du §1.1")
    func fieldAlpha() {
        #expect(abs(CD.Palette.bgField.resolved(for: .aqua).alphaComponent - 0.05) < 0.005)
        #expect(abs(CD.Palette.bgField.resolved(for: .darkAqua).alphaComponent - 0.07) < 0.005)
    }
}

extension NSColor {
    /// Résout une couleur dynamique dans une apparence donnée, en sRGB.
    fileprivate func resolved(for name: NSAppearance.Name) -> NSColor {
        var resolved = self
        NSAppearance(named: name)?.performAsCurrentDrawingAppearance {
            resolved = self.usingColorSpace(.sRGB) ?? self
        }
        return resolved
    }
}
