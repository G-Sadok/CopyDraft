import AppKit
import CopyDraftCore
import Foundation
import SwiftUI
import Testing

@testable import CopyDraftUI

// MARK: - Doublure de permission

/// Permission pilotée à la main : c'est elle qui joue le passage par les Réglages système.
private final class MutablePermission: AccessibilityPermissionChecking, @unchecked Sendable {
    private let lock = NSLock()
    private var _granted: Bool

    init(granted: Bool) { _granted = granted }

    var granted: Bool {
        get { lock.withLock { _granted } }
        set { lock.withLock { _granted = newValue } }
    }

    func isGranted() -> Bool { granted }
}

// MARK: - Contenu des deux états

@Suite("Onboarding — contenu")
@MainActor
struct OnboardingContentTests {
    @Test("L'état « non accordée » porte ses quatre étapes, l'indicateur et la note de repli")
    func deniedState() {
        let content = OnboardingContent.make(isGranted: false, language: "fr")

        #expect(content.isGranted == false)
        #expect(content.title == "Une autorisation à donner")
        #expect(content.items.count == (content.isGranted ? 3 : 4))
        #expect(content.items[0] == "Ouvrez Réglages système → Confidentialité et sécurité → Accessibilité")
        #expect(content.items[1] == "Activez l'interrupteur en face de CopyDraft")
        #expect(content.items[2] == "Revenez ici — la fenêtre se met à jour toute seule")
        #expect(content.statusLabel == "Permission non accordée")
        #expect(content.primaryTitle == "Ouvrir les Réglages système")
        #expect(content.secondaryTitle == "Plus tard")
        #expect(
            content.footnote
                == "Sans cette autorisation, CopyDraft copie l'élément dans le presse-papiers ; le collage reste à votre charge avec ⌘V."
        )
        // Le rappel de raccourci n'existe que dans l'état accordé (§8).
        #expect(content.shortcutKeys.isEmpty)
    }

    @Test("L'état « accordée » porte le raccourci en touches et les trois confirmations")
    func grantedState() {
        let content = OnboardingContent.make(isGranted: true, shortcut: "⇧⌘V", language: "fr")

        #expect(content.isGranted)
        #expect(content.title == "CopyDraft est prêt")
        #expect(
            content.body
                == "L'historique se remplit dès votre prochaine copie. Appelez-le de n'importe où avec :"
        )
        #expect(content.items == [
            "Collage automatique dans l'application active",
            "Icône ajoutée à la barre de menus",
            "Mots de passe et contenus confidentiels ignorés"
        ])
        #expect(content.primaryTitle == "Commencer")
        #expect(content.shortcutKeys == ["⇧", "⌘", "V"])
        // Ni indicateur ni note de repli : la pastille verte de l'icône suffit (§8).
        #expect(content.statusLabel == nil)
        #expect(content.footnote == nil)
    }

    @Test("Le raccourci est découpé en capuchons, jamais affiché comme du texte")
    func shortcutKeys() {
        #expect(OnboardingContent.keys(from: "⇧⌘V") == ["⇧", "⌘", "V"])
        #expect(OnboardingContent.keys(from: "⌥⇧⌘V") == ["⌥", "⇧", "⌘", "V"])
        // Sans raccourci enregistré, on retombe sur celui du design system.
        #expect(OnboardingContent.keys(from: "") == ["⇧", "⌘", "V"])
    }

    @Test("Les deux états proposent toujours un primaire et un secondaire", arguments: [false, true])
    func bothStatesHaveTwoButtons(isGranted: Bool) {
        let content = OnboardingContent.make(isGranted: isGranted, language: "fr")
        #expect(!content.primaryTitle.isEmpty)
        #expect(!content.secondaryTitle.isEmpty)
    }
}

// MARK: - Bascule automatique (FR-48)

@Suite("Onboarding — bascule automatique")
@MainActor
struct OnboardingSwitchTests {
    @Test("L'octroi bascule l'écran sans aucune action dans la fenêtre")
    func switchesWithoutInteraction() {
        let checker = MutablePermission(granted: false)
        let monitor = AccessibilityPermissionMonitor(checker: checker)
        let model = OnboardingModel(permission: monitor)

        #expect(model.content.isGranted == false)
        #expect(model.content.statusLabel != nil)

        // L'utilisateur bascule l'interrupteur dans les Réglages système ; côté CopyDraft, seul
        // le sondage périodique se produit — c'est exactement ce que `refresh()` exécute.
        checker.granted = true
        monitor.refresh()

        #expect(model.content.isGranted)
        #expect(model.content.title == OnboardingContent.make(isGranted: true).title)
        #expect(model.content.statusLabel == nil)
        #expect(model.content.footnote == nil)
    }

    @Test("Une révocation ramène l'écran à l'état « non accordée »")
    func revocationSwitchesBack() {
        let checker = MutablePermission(granted: true)
        let monitor = AccessibilityPermissionMonitor(checker: checker)
        let model = OnboardingModel(permission: monitor)

        #expect(model.content.isGranted)

        checker.granted = false
        monitor.refresh()

        #expect(model.content.isGranted == false)
        #expect(model.content.footnote != nil)
    }

    @Test("La fenêtre n'existe pas tant qu'elle n'a pas été demandée (FR-39)")
    func noWindowBeforeShow() {
        let monitor = AccessibilityPermissionMonitor(checker: MutablePermission(granted: false))
        let controller = OnboardingWindowController(permission: monitor)

        #expect(controller.isVisible == false)
        // Refermer une fenêtre jamais ouverte ne doit rien coûter.
        controller.close()
        #expect(controller.isVisible == false)
    }

    @Test("Le modèle n'évince pas l'abonné déjà branché sur le moniteur")
    func preservesExistingSubscriber() {
        let checker = MutablePermission(granted: false)
        let monitor = AccessibilityPermissionMonitor(checker: checker)

        var seen: [Bool] = []
        monitor.onChange = { seen.append($0) }

        let model = OnboardingModel(permission: monitor)
        checker.granted = true
        monitor.refresh()

        #expect(seen == [true], "l'application entière suit cet état, pas seulement l'onboarding")
        #expect(model.content.isGranted)
    }
}

// MARK: - Catalogue

@Suite("Onboarding — localisation")
struct OnboardingLocalizationTests {
    /// Toutes les clés de `Onboarding.strings`.
    static let keys = [
        "window.title",
        "denied.title", "denied.body",
        "denied.step.1", "denied.step.2", "denied.step.3",
        "denied.status", "denied.primary", "denied.secondary", "denied.footnote",
        "granted.title", "granted.body",
        "granted.point.1", "granted.point.2", "granted.point.3",
        "granted.primary", "granted.secondary",
        "step.accessibilityLabel", "shortcut.accessibilityLabel",
        "appMark.accessibilityLabel", "appMark.granted.accessibilityLabel"
    ]

    @Test("Chaque clé existe en français et en anglais", arguments: ["fr", "en"])
    func everyKeyIsTranslated(language: String) throws {
        let bundle = try #require(
            Bundle.module.path(forResource: language, ofType: "lproj").map(Bundle.init(path:)) ?? nil,
            "catalogue \(language).lproj introuvable"
        )

        for key in Self.keys {
            let value = bundle.localizedString(
                forKey: key, value: nil, table: L.Table.onboarding.rawValue
            )
            #expect(value != key, "clé « \(key) » non traduite en \(language)")
            #expect(!value.isEmpty)
        }
    }

    @MainActor
    @Test("Le français reprend le §8 mot pour mot")
    func frenchWordingMatchesDesignSystem() {
        let denied = OnboardingContent.make(isGranted: false, language: "fr")
        #expect(
            denied.body
                == "Pour coller dans l'application active, CopyDraft a besoin de l'accès aux fonctions d'accessibilité de macOS. C'est la seule permission demandée, et rien ne quitte votre Mac."
        )

        let granted = OnboardingContent.make(isGranted: true, language: "fr")
        #expect(granted.secondaryTitle == "Ouvrir les réglages")
    }

    @MainActor
    @Test("Les deux états existent aussi en anglais", arguments: [false, true])
    func englishIsComplete(isGranted: Bool) {
        let content = OnboardingContent.make(isGranted: isGranted, language: "en")
        #expect(content.title.first?.isUppercase == true)
        #expect(content.items.allSatisfy { !$0.isEmpty })
        #expect(content.items.count == (content.isGranted ? 3 : 4))
    }
}

// MARK: - Écriture des instantanés

/// Rendu PNG d'une vue, sur le modèle de `TokenGallerySnapshotTests`.
///
/// Partagé par les instantanés du §8 et du §9. `ImageRenderer` ne sait rendre ni `ScrollView`,
/// ni `TextField`, ni une vue AppKit hébergée : les planches n'en contiennent aucune.
enum SnapshotWriter {
    @MainActor
    static func png(
        of view: some View,
        size: CGSize,
        appearance: NSAppearance
    ) -> Data? {
        var data: Data?
        appearance.performAsCurrentDrawingAppearance {
            let renderer = ImageRenderer(
                content: view
                    .frame(width: size.width, height: size.height)
                    .environment(
                        \.colorScheme, appearance.name == .darkAqua ? .dark : .light
                    )
            )
            renderer.scale = 2
            guard let image = renderer.nsImage,
                let tiff = image.tiffRepresentation,
                let bitmap = NSBitmapImageRep(data: tiff)
            else { return }
            data = bitmap.representation(using: .png, properties: [:])
        }
        return data
    }

    static func write(_ png: Data, named name: String) throws {
        let directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("dist/snapshots")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try png.write(to: directory.appendingPathComponent("\(name).png"))
    }
}

// MARK: - Instantanés

/// Rend les deux états du §8 à leur cote réelle, en clair et en sombre.
///
/// Désactivé par défaut : `CD_SNAPSHOTS=1 swift test` écrit les images dans `dist/snapshots/`.
@Suite("Instantanés de l'onboarding")
struct OnboardingSnapshotTests {
    struct Case: Sendable, CustomStringConvertible {
        let isGranted: Bool
        let appearance: NSAppearance.Name

        var description: String {
            "\(isGranted ? "granted" : "denied")-\(appearance == .darkAqua ? "dark" : "light")"
        }
    }

    static let cases: [Case] = [false, true].flatMap { granted in
        [NSAppearance.Name.aqua, .darkAqua].map { Case(isGranted: granted, appearance: $0) }
    }

    @MainActor
    @Test(
        "Rendu clair et sombre",
        .enabled(if: ProcessInfo.processInfo.environment["CD_SNAPSHOTS"] == "1"),
        arguments: OnboardingSnapshotTests.cases
    )
    func render(_ testCase: Case) throws {
        let appearance = try #require(NSAppearance(named: testCase.appearance))
        let content = OnboardingContent.make(
            isGranted: testCase.isGranted, shortcut: "⇧⌘V", language: "fr"
        )

        let png = try #require(
            SnapshotWriter.png(
                of: OnboardingView(content: content, onPrimary: {}, onSecondary: {}),
                size: CGSize(width: CD.Metric.onboardingWidth, height: CD.Metric.onboardingHeight),
                appearance: appearance
            ),
            "rendu impossible"
        )
        try SnapshotWriter.write(png, named: "onboarding-\(testCase)")
        #expect(png.count > 5_000, "image suspecte : \(png.count) octets")
    }
}
