import AppKit
import CopyDraftCore
import OSLog
import SwiftUI

/// Ouvre et ferme la popup (FR-19 à FR-25, NFR-3).
///
/// Le panneau et son hôte SwiftUI sont créés **au lancement** puis réutilisés : ouvrir se
/// réduit alors à positionner, afficher et fondre — condition pour tenir les 150 ms perçus.
@MainActor
public final class PopupController {
    /// Raisons de fermeture, utiles au diagnostic et aux tests.
    public enum DismissReason: Sendable, Equatable {
        case escape
        case clickedOutside
        case selection
        case screenChanged
        case programmatic
    }

    public private(set) var isVisible = false
    /// Application qui recevra le collage : celle qui était active avant l'ouverture.
    public var pasteTarget: PasteTarget? { frontmostApp.target }
    /// Mode d'acheminement clavier réellement obtenu à la dernière ouverture.
    public private(set) var keyRoutingMode: KeyEventRouter.Mode = .keyWindow

    /// Journal d'ouverture : mode d'acheminement clavier réellement obtenu, indispensable
    /// pour comprendre pourquoi une frappe n'arrive pas.
    private static let log = Logger(subsystem: AppInfo.bundleIdentifier, category: "popup")

    private let panel: PopupPanel
    private let hostingView: NSHostingView<AnyView>
    private let positioner = PopupPositioner()
    private let preferences: Preferences
    private let frontmostApp = FrontmostAppTracker()
    private let keyRouter: KeyEventRouter

    private var outsideClickMonitor: Any?
    private var resignObserver: NSObjectProtocol?

    /// Cadre de l'icône de barre de menus, pour la position « sous l'icône ».
    public var statusItemFrame: (() -> CGRect?)?
    /// Appelé quand la popup se ferme, quelle qu'en soit la raison.
    public var onDismiss: ((DismissReason) -> Void)?
    /// Commandes clavier acheminées vers la vue.
    public var onCommand: ((PopupCommand) -> Bool)?
    /// Hauteur souhaitée à l'ouverture, estimée avant tout affichage.
    public var preferredHeight: (() -> CGFloat)?
    /// Habillage à ajouter à la hauteur du contenu mesuré : recherche, pied et marges.
    public var chromeHeight: (() -> CGFloat)?

    public init(
        preferences: Preferences,
        keyRouter: KeyEventRouter = KeyEventRouter(),
        content: AnyView = AnyView(EmptyView())
    ) {
        self.preferences = preferences
        self.keyRouter = keyRouter

        hostingView = NSHostingView(rootView: content)
        hostingView.frame = NSRect(
            x: 0, y: 0, width: CD.Metric.popupWidth, height: CD.Metric.popupHeightMin
        )
        panel = PopupPanel(contentView: hostingView)

        keyRouter.isSearchEmpty = { true }
        keyRouter.quickPasteEnabled = { [weak self] in self?.preferences.quickPasteEnabled ?? true }
        keyRouter.onCommand = { [weak self] command in
            guard let self else { return false }
            if command == .dismiss, self.onCommand == nil {
                self.hide(reason: .escape)
                return true
            }
            return self.onCommand?(command) ?? false
        }
    }

    /// Remplace le contenu affiché. Appelé une fois au démarrage.
    public func setContent(_ content: some View) {
        hostingView.rootView = AnyView(content)
    }

    /// Renseigne la popup sur l'état de sa recherche, dont dépend le double sens de `⌫`.
    public func setSearchEmptyProvider(_ provider: @escaping () -> Bool) {
        keyRouter.isSearchEmpty = provider
    }

    // MARK: Ouverture

    /// Affiche la popup à la position réglée par l'utilisateur.
    public func show() {
        guard !isVisible else { return }

        // Mémorisé **avant** l'affichage : c'est cette application qui recevra le collage.
        frontmostApp.capture()

        let cursor = NSEvent.mouseLocation
        let visibleFrame = Self.visibleFrame(containing: cursor)
        let size = CGSize(
            width: CD.Metric.popupWidth,
            height: preferredHeight?() ?? CD.Metric.popupHeightMin
        )

        let frame = positioner.frame(
            size: size,
            position: preferences.popupPosition,
            cursor: cursor,
            visibleFrame: visibleFrame,
            statusItemFrame: statusItemFrame?()
        )

        keyRoutingMode = keyRouter.start()
        panel.acceptsKeyStatus = keyRoutingMode == .keyWindow

        panel.setFrame(frame, display: false)
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        if panel.acceptsKeyStatus {
            // Mode replié : un panneau non activant a beau devenir fenêtre clé, il ne reçoit
            // rien tant que l'application n'est pas active — c'est le système qui dirige les
            // frappes vers l'application au premier plan. Sans autorisation d'accessibilité,
            // il faut donc activer CopyDraft, puis rendre le focus à sa fermeture (FR-34).
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
        }

        Self.log.notice(
            "popup ouverte — mode \(String(describing: self.keyRoutingMode), privacy: .public), clé \(self.panel.acceptsKeyStatus), active \(NSApp.isActive)"
        )

        animateIn()
        installDismissMonitors()
        announce(L.t("popup.accessibility.opened"))
        isVisible = true
    }

    /// Ouvre la popup sous l'icône de barre de menus (⌥-clic sur l'icône).
    public func showUnderStatusItem() {
        let saved = preferences.popupPosition
        preferences.popupPosition = .menuBar
        show()
        preferences.popupPosition = saved
    }

    /// Ajuste la fenêtre à la hauteur réellement occupée par la liste.
    ///
    /// L'estimation d'ouverture évite tout repositionnement visible ; cette correction, elle,
    /// se produit dans les 140 ms du fondu, donc invisible aussi.
    public func applyContentHeight(_ contentHeight: CGFloat) {
        guard isVisible, contentHeight > 0 else { return }
        let chrome = chromeHeight?() ?? 0
        let ceiling = min(
            CD.Metric.popupHeightMax,
            Self.visibleFrame(containing: CGPoint(x: panel.frame.midX, y: panel.frame.midY))
                .height * CD.Metric.popupHeightScreenFraction
        )
        let target = min(max(contentHeight + chrome, CD.Metric.popupHeightMin), ceiling)

        var frame = panel.frame
        guard abs(frame.height - target) > 0.5 else { return }

        // Le coin supérieur reste en place : la popup grandit et rétrécit vers le bas.
        frame.origin.y += frame.height - target
        frame.size.height = target
        panel.setFrame(frame, display: true)
    }

    /// Ajuste la hauteur pendant que la popup est ouverte : la liste change avec la recherche.
    public func updateHeight() {
        guard isVisible, let height = preferredHeight?() else { return }
        var frame = panel.frame
        let delta = height - frame.height
        guard abs(delta) > 0.5 else { return }

        // Le coin supérieur reste en place : la popup pousse vers le bas, jamais vers le haut.
        frame.origin.y -= delta
        frame.size.height = height
        panel.setFrame(
            positioner.frame(
                size: frame.size,
                position: preferences.popupPosition,
                cursor: CGPoint(x: frame.minX, y: frame.maxY),
                visibleFrame: Self.visibleFrame(containing: CGPoint(x: frame.midX, y: frame.midY)),
                statusItemFrame: statusItemFrame?()
            ),
            display: true
        )
    }

    // MARK: Fermeture

    public func hide(reason: DismissReason = .programmatic) {
        guard isVisible else { return }
        isVisible = false

        removeDismissMonitors()
        // Le tap clavier ne survit jamais à l'affichage (ADR-6, argument de confiance).
        keyRouter.stop()

        // Mode replié : l'application avait dû passer au premier plan pour recevoir les
        // frappes, on rend la main à celle que l'utilisateur avait sous les yeux.
        if panel.acceptsKeyStatus, let target = frontmostApp.target {
            NSRunningApplication(processIdentifier: target.processIdentifier)?.activate()
        }

        animateOut()
        announce(L.t("popup.accessibility.closed"))

        onDismiss?(reason)
    }

    /// Ferme si ouverte, ouvre sinon — comportement du raccourci global.
    public func toggle() {
        isVisible ? hide(reason: .programmatic) : show()
    }

    // MARK: Mouvement (§10)

    private func animateIn() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = CD.Motion.isReduced ? CD.Motion.reducedFade : CD.Motion.popupIn
            context.timingFunction = CAMediaTimingFunction(
                controlPoints: 0.2, 0.8, 0.3, 1.0
            )
            panel.animator().alphaValue = 1
        }
    }

    private func animateOut() {
        let panel = self.panel
        NSAnimationContext.runAnimationGroup { context in
            context.duration = CD.Motion.isReduced ? CD.Motion.reducedFade : CD.Motion.popupOut
            context.timingFunction = CAMediaTimingFunction(
                controlPoints: 0.2, 0.8, 0.3, 1.0
            )
            panel.animator().alphaValue = 0
        } completionHandler: {
            MainActor.assumeIsolated { panel.orderOut(nil) }
        }
    }

    // MARK: Fermetures automatiques (FR-25)

    private func installDismissMonitors() {
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.hide(reason: .clickedOutside) }
        }

        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.hide(reason: .screenChanged) }
        }
    }

    private func removeDismissMonitors() {
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
        outsideClickMonitor = nil
        resignObserver = nil
    }

    // MARK: Accessibilité (NFR-12)

    /// Annonce l'ouverture et la fermeture à VoiceOver.
    ///
    /// La popup ne prend pas le focus système : sans annonce explicite, un utilisateur de
    /// VoiceOver ne saurait pas qu'elle vient de s'ouvrir. À la fermeture, le focus reste
    /// où il était — dans l'application active — ce qui est précisément la promesse du §3.
    private func announce(_ message: String) {
        NSAccessibility.post(
            element: panel,
            notification: .announcementRequested,
            userInfo: [
                .announcement: message,
                .priority: NSAccessibilityPriorityLevel.medium.rawValue
            ]
        )
    }

    // MARK: Écrans

    /// Zone utile de l'écran du curseur, barre de menus et Dock exclus.
    public static func visibleFrame(containing point: CGPoint) -> CGRect {
        let screens = NSScreen.screens
        let screen = screens.first { $0.frame.contains(point) } ?? NSScreen.main ?? screens.first
        return screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1_440, height: 900)
    }
}
