import AppKit
import SwiftUI

/// Galerie de contrôle des tokens : toutes les valeurs de `CD` affichées côte à côte, pour
/// vérifier à l'œil la conformité au design system en clair et en sombre.
///
/// Surface de développement, ouverte depuis le menu de la barre de menus en configuration
/// debug. Elle n'est jamais montrée à l'utilisateur : ses libellés ne sont pas localisés.
public struct TokenGalleryView: View {
    public init() {}

    public var body: some View {
        ScrollView { TokenGalleryContent() }
            .background(CD.Color.bgWindow)
    }
}

/// Contenu de la galerie, hors défilement : rendu tel quel par `ImageRenderer` pour les
/// instantanés de contrôle (un `ScrollView` ne se rend pas hors écran).
public struct TokenGalleryContent: View {
    public init() {}

    private let colors: [(String, SwiftUI.Color)] = [
        ("bgWindow", CD.Color.bgWindow),
        ("bgContent", CD.Color.bgContent),
        ("bgPopoverSolid", CD.Color.bgPopoverSolid),
        ("bgField", CD.Color.bgField),
        ("fill1", CD.Color.fill1),
        ("fillHover", CD.Color.fillHover),
        ("fill3", CD.Color.fill3),
        ("text1", CD.Color.text1),
        ("text2", CD.Color.text2),
        ("text3", CD.Color.text3),
        ("textDisabled", CD.Color.textDisabled),
        ("separator", CD.Color.separator),
        ("hairline", CD.Color.hairline),
        ("accent", CD.Color.accent),
        ("selection", CD.Color.selection),
        ("selectionUnemph.", CD.Color.selectionUnemphasized),
        ("success", CD.Color.success),
        ("warning", CD.Color.warning),
        ("danger", CD.Color.danger)
    ]

    private let typeSpecimens: [(String, SwiftUI.Font, CGFloat)] = [
        ("titleLarge 26/32", CD.Font.titleLarge, CD.LineHeight.titleLarge),
        ("title1 22/26", CD.Font.title1, CD.LineHeight.title1),
        ("title2 17/22", CD.Font.title2, CD.LineHeight.title2),
        ("title3 15/20", CD.Font.title3, CD.LineHeight.title3),
        ("emphasis 13/17", CD.Font.emphasis, CD.LineHeight.emphasis),
        ("body 13/17", CD.Font.body, CD.LineHeight.body),
        ("code 11,5/16", CD.Font.code, CD.LineHeight.code),
        ("caption 12/16", CD.Font.caption, CD.LineHeight.caption),
        ("small 11/14", CD.Font.small, CD.LineHeight.small),
        ("shortcut 11/11", CD.Font.shortcut, CD.LineHeight.shortcut),
        ("micro 10/13", CD.Font.micro, CD.LineHeight.micro)
    ]

    private let spaces: [(String, CGFloat)] = [
        ("x0_5", CD.Space.x0_5), ("x1", CD.Space.x1), ("x1_5", CD.Space.x1_5),
        ("x2", CD.Space.x2), ("x2_5", CD.Space.x2_5), ("x3", CD.Space.x3),
        ("x4", CD.Space.x4), ("x5", CD.Space.x5), ("x6", CD.Space.x6), ("x8", CD.Space.x8)
    ]

    private let radii: [(String, CGFloat)] = [
        ("popover", CD.Radius.popover), ("window", CD.Radius.window),
        ("menu · cell · field · button", CD.Radius.menu),
        ("badge · thumbnail", CD.Radius.badge)
    ]

    private let motions: [(String, TimeInterval)] = [
        ("popupIn", CD.Motion.popupIn), ("popupOut", CD.Motion.popupOut),
        ("selection", CD.Motion.selection), ("hover", CD.Motion.hover),
        ("press", CD.Motion.press), ("reorder", CD.Motion.reorder),
        ("delete", CD.Motion.delete), ("toastIn", CD.Motion.toastIn),
        ("toastOut", CD.Motion.toastOut), ("search", CD.Motion.search)
    ]

    public var body: some View {
        VStack(alignment: .leading, spacing: CD.Space.x6) {
                section("1.1 Couleurs sémantiques") {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: CD.Space.x2), count: 4),
                        spacing: CD.Space.x2
                    ) {
                        ForEach(colors, id: \.0) { name, color in
                            VStack(alignment: .leading, spacing: CD.Space.x0_5) {
                                RoundedRectangle(cornerRadius: CD.Radius.badge)
                                    .fill(color)
                                    .frame(height: 28)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: CD.Radius.badge)
                                            .strokeBorder(CD.Color.separator)
                                    )
                                Text(name).font(CD.Font.small).foregroundStyle(CD.Color.text2)
                            }
                        }
                    }
                }

                section("1.2 Typographie") {
                    VStack(alignment: .leading, spacing: CD.Space.x2) {
                        ForEach(typeSpecimens, id: \.0) { name, font, lineHeight in
                            HStack(alignment: .firstTextBaseline, spacing: CD.Space.x3) {
                                Text("Historique du presse-papiers")
                                    .font(font)
                                    .lineSpacing(max(0, lineHeight - 13))
                                    .foregroundStyle(CD.Color.text1)
                                Spacer(minLength: CD.Space.x2)
                                Text(name).font(CD.Font.small).foregroundStyle(CD.Color.text3)
                            }
                        }
                    }
                }

                section("1.3 Espacements") {
                    VStack(alignment: .leading, spacing: CD.Space.x1) {
                        ForEach(spaces, id: \.0) { name, value in
                            HStack(spacing: CD.Space.x2) {
                                Text(name)
                                    .font(CD.Font.small)
                                    .foregroundStyle(CD.Color.text2)
                                    .frame(width: 44, alignment: .leading)
                                Rectangle().fill(CD.Color.accent).frame(width: value, height: 8)
                                Text("\(Int(value)) pt")
                                    .font(CD.Font.small)
                                    .foregroundStyle(CD.Color.text3)
                            }
                        }
                    }
                }

                section("1.4 Rayons") {
                    HStack(spacing: CD.Space.x3) {
                        ForEach(radii, id: \.0) { name, value in
                            VStack(spacing: CD.Space.x1) {
                                RoundedRectangle(cornerRadius: value)
                                    .fill(CD.Color.fillHover)
                                    .frame(width: 64, height: 44)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: value)
                                            .strokeBorder(CD.Color.separator)
                                    )
                                Text("\(name) · \(Int(value))")
                                    .font(CD.Font.small)
                                    .foregroundStyle(CD.Color.text2)
                            }
                        }
                    }
                }

                section("10 Mouvement") {
                    VStack(alignment: .leading, spacing: CD.Space.x1) {
                        ForEach(motions, id: \.0) { name, duration in
                            HStack(spacing: CD.Space.x2) {
                                Text(name)
                                    .font(CD.Font.small)
                                    .foregroundStyle(CD.Color.text2)
                                    .frame(width: 80, alignment: .leading)
                                Text("\(Int(duration * 1000)) ms")
                                    .font(CD.Font.shortcut)
                                    .foregroundStyle(CD.Color.text1)
                            }
                        }
                        Text(
                            CD.Motion.isReduced
                                ? "« Réduire les animations » actif : durées à 0, fondus à 80 ms."
                                : "Courbe unique cubic-bezier(.2, .8, .3, 1)."
                        )
                        .font(CD.Font.small)
                        .foregroundStyle(CD.Color.text3)
                    }
                }

                section("Cotes clés") {
                    VStack(alignment: .leading, spacing: CD.Space.x0_5) {
                        metric("popup", "\(Int(CD.Metric.popupWidth)) × \(Int(CD.Metric.popupHeightMin))–\(Int(CD.Metric.popupHeightMax))")
                        metric("cellule", "\(Int(CD.Metric.cellWidth)) × \(Int(CD.Metric.cellHeightMin))/\(Int(CD.Metric.cellHeightMax))")
                        metric("recherche · pied", "\(Int(CD.Metric.searchHeight)) · \(Int(CD.Metric.footerHeight))")
                        metric("menu", "\(Int(CD.Metric.menuWidth)) × \(Int(CD.Metric.menuItemHeight))")
                        metric("réglages", "\(Int(CD.Metric.settingsWidth)) · colonne \(Int(CD.Metric.settingsLabelColumn)) + \(Int(CD.Metric.settingsGutter))")
                        metric("onboarding", "\(Int(CD.Metric.onboardingWidth)) × \(Int(CD.Metric.onboardingHeight))")
                    }
                }
        }
        .padding(CD.Space.x6)
        .background(CD.Color.bgWindow)
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: CD.Space.x3) {
            Text(title).font(CD.Font.title2).foregroundStyle(CD.Color.text1)
            content()
        }
    }

    private func metric(_ name: String, _ value: String) -> some View {
        HStack(spacing: CD.Space.x2) {
            Text(name)
                .font(CD.Font.small)
                .foregroundStyle(CD.Color.text2)
                .frame(width: 130, alignment: .leading)
            Text(value).font(CD.Font.shortcut).foregroundStyle(CD.Color.text1)
        }
    }
}

/// Fenêtre hôte de la galerie, retenue tant qu'elle est ouverte.
@MainActor
public final class TokenGalleryWindowController {
    private var window: NSWindow?

    public init() {}

    public func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 720),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "CopyDraft — galerie de tokens"
        window.contentView = NSHostingView(rootView: TokenGalleryView())
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }
}
