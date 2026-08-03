import AppKit
import CopyDraftCore
import SwiftUI

// MARK: - Libellés (§9)

/// Textes du panneau « À propos ». Regroupés pour être relus langue par langue, comme le
/// décompte de la confirmation.
enum AboutStrings {
    static func title(language: String? = nil) -> String {
        LocalizedTable.string("about.title", table: .feedback, language: language)
    }

    /// « Version 1.0.4 (412) » — version marketing et numéro de build, lus depuis `AppInfo`.
    static func version(
        short: String = AppInfo.shortVersion,
        build: String = AppInfo.buildNumber,
        language: String? = nil
    ) -> String {
        LocalizedTable.format("about.version", table: .feedback, language: language, short, build)
    }

    static func tagline(language: String? = nil) -> String {
        LocalizedTable.string("about.tagline", table: .feedback, language: language)
    }

    static func website(language: String? = nil) -> String {
        LocalizedTable.string("about.website", table: .feedback, language: language)
    }

    static func licenses(language: String? = nil) -> String {
        LocalizedTable.string("about.licenses", table: .feedback, language: language)
    }

    /// L'année est calculée : un millésime figé dans le catalogue vieillirait tout seul.
    static func copyright(year: Int = AboutStrings.currentYear, language: String? = nil) -> String {
        LocalizedTable.format(
            "about.copyright", table: .feedback, language: language, String(year)
        )
    }

    static var currentYear: Int {
        Calendar(identifier: .gregorian).component(.year, from: Date())
    }
}

// MARK: - Cotes (§9)

/// Cotes du panneau « À propos », absentes de `CD`.
enum AboutMetrics {
    static let width: CGFloat = 280
    /// Icône d'application, plus grande qu'à l'onboarding : c'est le sujet du panneau.
    static let mark: CGFloat = 72
    static let titleBarInset: CGFloat = 28
}

// MARK: - Vue

/// Panneau « À propos » du §9 : identité, version, phrase de positionnement, liens, copyright.
///
/// Rien d'autre. Le §9 en fait une carte de visite, pas un écran d'aide : la seule information
/// qui compte au support est le couple version / build.
struct AboutView: View {
    var website: URL?
    var licenses: URL?
    /// Langue forcée — seuls les instantanés s'en servent, pour comparer au §9 en français.
    var language: String?

    var body: some View {
        VStack(spacing: CD.Space.x2_5) {
            AppMark(size: AboutMetrics.mark)

            VStack(spacing: CD.Space.x0_5) {
                Text(AppInfo.name)
                    .font(CD.Font.title2)
                    .foregroundStyle(CD.Color.text1)

                Text(AboutStrings.version(language: language))
                    .font(CD.Font.detail)
                    .foregroundStyle(CD.Color.text2)
            }

            Text(AboutStrings.tagline(language: language))
                .font(CD.Font.small)
                .foregroundStyle(CD.Color.text2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: CD.Space.x4) {
                link(AboutStrings.website(language: language), url: website)
                link(AboutStrings.licenses(language: language), url: licenses)
            }

            Text(AboutStrings.copyright(language: language))
                .font(CD.Font.micro)
                .fontWeight(.regular)
                .foregroundStyle(CD.Color.text3)
        }
        .padding(.horizontal, CD.Space.x6)
        .padding(.top, AboutMetrics.titleBarInset)
        .padding(.bottom, CD.Space.x6)
        .frame(width: AboutMetrics.width)
        .background(CD.Color.bgWindow)
        .accessibilityElement(children: .contain)
    }

    /// Lien en accent. Sans adresse, il reste affiché mais éteint : le §9 prévoit les deux
    /// liens, et une destination manquante est un défaut de configuration, pas un choix.
    @ViewBuilder
    private func link(_ title: String, url: URL?) -> some View {
        if let url {
            Link(destination: url) {
                Text(title).font(CD.Font.detail).foregroundStyle(CD.Color.accent)
            }
            .buttonStyle(.plain)
        } else {
            Text(title)
                .font(CD.Font.detail)
                .foregroundStyle(CD.Color.textDisabled)
                .accessibilityRemoveTraits(.isButton)
        }
    }
}

// MARK: - Fenêtre

/// Fenêtre « À propos » (§9).
@MainActor
public final class AboutPanel {
    private let website: URL?
    private let licenses: URL?
    private var window: NSWindow?

    /// - Parameters:
    ///   - website: adresse du site de CopyDraft. Aucune valeur par défaut : le projet n'en
    ///     publie pas encore, et un lien inventé serait pire qu'un lien éteint.
    ///   - licenses: adresse des licences des dépendances.
    public init(website: URL? = nil, licenses: URL? = nil) {
        self.website = website
        self.licenses = licenses
    }

    public var isVisible: Bool { window?.isVisible ?? false }

    public func show() {
        let window = self.window ?? makeWindow()
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func close() {
        window?.orderOut(nil)
    }

    private func makeWindow() -> NSWindow {
        let hostingView = NSHostingView(
            rootView: AboutView(website: website, licenses: licenses)
        )
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: hostingView.fittingSize),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = AboutStrings.title()
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.isExcludedFromWindowsMenu = true
        window.contentView = hostingView

        self.window = window
        return window
    }
}
