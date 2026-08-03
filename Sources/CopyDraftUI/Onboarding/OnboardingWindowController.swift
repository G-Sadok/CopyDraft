import AppKit
import CopyDraftCore
import SwiftUI

/// État observable de l'écran d'onboarding.
///
/// Il ne connaît que le moniteur de permission : c'est lui, et non un geste de l'utilisateur,
/// qui décide de l'état affiché (FR-48).
@MainActor
@Observable
final class OnboardingModel {
    private(set) var content: OnboardingContent

    @ObservationIgnored private let permission: AccessibilityPermissionMonitor
    @ObservationIgnored private var previousChangeHandler: ((Bool) -> Void)?

    init(permission: AccessibilityPermissionMonitor) {
        self.permission = permission
        self.content = OnboardingContent.make(isGranted: permission.isGranted)

        // On s'insère dans la chaîne de notification sans en évincer l'abonné précédent :
        // l'application entière suit cet état, pas seulement l'onboarding.
        previousChangeHandler = permission.onChange
        permission.onChange = { [weak self] granted in
            self?.previousChangeHandler?(granted)
            self?.refresh(isGranted: granted)
        }
    }

    /// Relit l'état de la permission — au retour au premier plan, notamment.
    func refresh() {
        permission.refresh()
        refresh(isGranted: permission.isGranted)
    }

    private func refresh(isGranted: Bool) {
        guard isGranted != content.isGranted else { return }
        content = OnboardingContent.make(isGranted: isGranted)
    }
}

/// Fenêtre d'onboarding (§8, FR-47).
///
/// Seul écran plein de CopyDraft : 560 × 420, centré, **non redimensionnable**. Il s'affiche au
/// premier lancement et réapparaît à toute révocation de la permission ; l'application n'a
/// aucune autre fenêtre au lancement (FR-39).
@MainActor
public final class OnboardingWindowController {
    private let permission: AccessibilityPermissionMonitor
    private let model: OnboardingModel
    private var window: NSWindow?

    /// Appelé quand l'utilisateur en a fini : « Commencer » ou « Plus tard ».
    public var onFinished: (() -> Void)?

    /// Ouvre les réglages de CopyDraft depuis l'état accordé. Tant qu'il n'est pas raccordé,
    /// le bouton secondaire reste désactivé plutôt que muet.
    public var onOpenSettings: (() -> Void)?

    public init(permission: AccessibilityPermissionMonitor) {
        self.permission = permission
        self.model = OnboardingModel(permission: permission)
    }

    public var isVisible: Bool { window?.isVisible ?? false }

    public func show() {
        // Invite système au moment où l'on explique la demande : c'est elle qui inscrit
        // CopyDraft dans la liste des Réglages système avec la bonne exigence de signature.
        // Sans elle, l'utilisateur ajoute l'application à la main et peut tomber sur une
        // entrée héritée d'une signature précédente, qu'aucune bascule ne réveille.
        AccessibilityPermissionMonitor.requestWithSystemPrompt()

        // Le sondage de la permission est ce qui fait basculer la fenêtre toute seule (FR-48).
        permission.start()
        model.refresh()

        let window = self.window ?? makeWindow()
        window.center()
        window.makeKeyAndOrderFront(nil)
        // L'application est un agent : sans activation explicite, la fenêtre s'ouvrirait
        // derrière celle de l'utilisateur.
        NSApp.activate(ignoringOtherApps: true)
    }

    public func close() {
        window?.orderOut(nil)
    }

    // MARK: Fenêtre

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(
                x: 0, y: 0,
                width: CD.Metric.onboardingWidth, height: CD.Metric.onboardingHeight
            ),
            // `fullSizeContentView` : le contenu occupe tout le cadre, qui mesure alors
            // exactement les 560 × 420 du §8, feux tricolores compris.
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = L.t("window.title", table: .onboarding)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.isExcludedFromWindowsMenu = true
        window.contentView = NSHostingView(rootView: rootView)

        self.window = window
        return window
    }

    private var rootView: some View {
        OnboardingRootView(
            model: model,
            onPrimary: { [weak self] in self?.performPrimary() },
            onSecondary: { [weak self] in self?.performSecondary() },
            isSecondaryEnabled: { [weak self] in
                guard let self else { return false }
                return !model.content.isGranted || onOpenSettings != nil
            }
        )
    }

    // MARK: Actions

    /// Primaire : ouvrir les Réglages système tant que la permission manque, terminer sinon.
    private func performPrimary() {
        if model.content.isGranted {
            finish()
        } else {
            AccessibilityPermissionMonitor.openSystemSettings()
        }
    }

    /// Secondaire : « Plus tard » referme sans rien exiger (FR-34), « Ouvrir les réglages »
    /// passe la main à la fenêtre de préférences.
    private func performSecondary() {
        if model.content.isGranted {
            onOpenSettings?()
        } else {
            finish()
        }
    }

    private func finish() {
        close()
        onFinished?()
    }
}

/// Racine hébergée : elle observe le modèle et redessine l'état courant.
private struct OnboardingRootView: View {
    let model: OnboardingModel
    let onPrimary: () -> Void
    let onSecondary: () -> Void
    let isSecondaryEnabled: () -> Bool

    var body: some View {
        OnboardingView(
            content: model.content,
            onPrimary: onPrimary,
            onSecondary: onSecondary,
            isSecondaryEnabled: isSecondaryEnabled()
        )
    }
}
