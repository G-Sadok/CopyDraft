import AppKit
import CopyDraftCore
import SwiftUI

/// La popup elle-même (§3) : recherche, liste en deux sections, pied.
///
/// Assemblage seulement — la logique vit dans `PopupViewModel`, le rendu d'un élément dans
/// `HistoryCell`, les contrôles dans `Components/`. Cette vue décide de la structure et des
/// marges, rien d'autre.
public struct PopupView: View {
    @Bindable private var model: PopupViewModel
    private let store: HistoryStore
    private let preferences: Preferences
    private let onResumeCapture: () -> Void
    private let onOpenSettings: () -> Void
    private let onClearAll: () -> Void
    private let onContentHeight: (CGFloat) -> Void

    /// Vignettes déjà déchiffrées, indexées par élément : la cellule ne va jamais lire
    /// le disque elle-même.
    @State private var thumbnails: [UUID: Image] = [:]

    public init(
        model: PopupViewModel,
        store: HistoryStore,
        preferences: Preferences,
        onResumeCapture: @escaping () -> Void = {},
        onOpenSettings: @escaping () -> Void = {},
        onClearAll: @escaping () -> Void = {},
        onContentHeight: @escaping (CGFloat) -> Void = { _ in }
    ) {
        self.model = model
        self.store = store
        self.preferences = preferences
        self.onResumeCapture = onResumeCapture
        self.onOpenSettings = onOpenSettings
        self.onClearAll = onClearAll
        self.onContentHeight = onContentHeight
    }

    public var body: some View {
        VStack(spacing: CD.Space.x1_5) {
            if !preferences.captureEnabled {
                CDPauseBanner(onResume: onResumeCapture)
            }

            CDSearchField(
                text: $model.query,
                isEnabled: !model.isEmpty,
                placeholderKey: "popup.search.placeholder"
            )

            content

            FooterBar(
                itemCount: model.isSearching ? model.visibleItems.count : store.items.count,
                totalCount: store.items.count,
                pinnedCount: store.items.filter(\.pinned).count,
                isSearching: model.isSearching,
                isPaused: !preferences.captureEnabled,
                onTogglePause: onResumeCapture,
                onOpenSettings: onOpenSettings,
                onClearAll: onClearAll
            )
        }
        .padding(CD.Space.x1_5)
        .frame(width: CD.Metric.popupWidth)
        .background(popupBackground)
        .clipShape(RoundedRectangle(cornerRadius: CD.Radius.popover, style: .continuous))
        .environment(\.locale, L.locale)
        .task(id: store.items.map(\.id)) { await loadThumbnails() }
    }

    // MARK: Contenu

    @ViewBuilder
    private var content: some View {
        if store.isRestoring {
            CDEmptyState(
                symbolName: "clock",
                titleKey: "popup.restoring.title",
                messageKey: "popup.restoring.message"
            )
            .frame(maxWidth: .infinity)
        } else if model.isEmpty {
            CDEmptyState(
                symbolName: "doc.on.clipboard",
                titleKey: "popup.empty.title",
                messageKey: "popup.empty.message"
            )
            .frame(maxWidth: .infinity)
        } else if model.hasNoResults {
            CDEmptyState(
                symbolName: "magnifyingglass",
                titleKey: "popup.empty.search.title",
                messageKey: "popup.empty.search.message",
                actionTitleKey: "search.clear",
                action: { model.query = "" }
            )
            .frame(maxWidth: .infinity)
        } else {
            list
        }
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: CD.Space.x0_5) {
                    if !model.pinnedItems.isEmpty {
                        SectionHeader(title: L.t("popup.section.pinned"))
                        rows(model.pinnedItems, offset: 0)
                    }
                    if !model.recentItems.isEmpty {
                        if !model.pinnedItems.isEmpty {
                            SectionHeader(title: L.t("popup.section.recent"))
                        }
                        rows(model.recentItems, offset: model.pinnedItems.count)
                    }
                }
                // Hauteur réellement occupée par les cellules : l'estimation d'ouverture
                // dimensionne la fenêtre d'un coup, cette mesure la corrige au pixel avant
                // la fin du fondu (§3, FR-20).
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: PopupContentHeightKey.self, value: proxy.size.height
                        )
                    }
                )
            }
            .onPreferenceChange(PopupContentHeightKey.self) { height in
                onContentHeight(height)
            }
            .scrollIndicators(.automatic)
            .onChange(of: model.selectedID) { _, selected in
                guard let selected else { return }
                withAnimation(CD.Motion.animation(CD.Motion.selection)) {
                    proxy.scrollTo(selected, anchor: nil)
                }
            }
        }
    }

    @ViewBuilder
    private func rows(_ items: [ClipItem], offset: Int) -> some View {
        let total = model.visibleItems.count
        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
            Button {
                model.select(item.id)
                model.handle(.paste)
            } label: {
                HistoryCell(
                    item: item,
                    isSelected: model.selectedID == item.id,
                    shortcutIndex: model.shortcutIndex(for: item),
                    showSourceApp: preferences.showSourceApp,
                    thumbnail: thumbnails[item.id],
                    appIcon: Self.appIcon(for: item.source),
                    onTogglePin: { Task { await store.togglePin(item.id) } }
                )
            }
            .buttonStyle(.historyCell)
            .historyCellRank(offset + index + 1, of: total)
            .id(item.id)
            .contextMenu {
                ItemMenu(
                    item: item,
                    onPaste: { model.select(item.id); model.handle(.paste) },
                    onPastePlain: { model.select(item.id); model.handle(.pastePlainText) },
                    onTogglePin: { Task { await store.togglePin(item.id) } },
                    onCopy: { model.select(item.id); model.handle(.copy) },
                    onDelete: { model.select(item.id); model.handle(.deleteSelection) },
                    onExcludeApp: { model.actions.excludeApp(item.source) }
                )
            }
        }
    }

    // MARK: Matériau

    @ViewBuilder
    private var popupBackground: some View {
        if preferences.translucentBackground && !CD.Material.isReduced {
            PopupBackground()
        } else {
            CD.Color.bgPopoverSolid
        }
    }

    // MARK: Ressources

    /// Icône de l'application source, résolue à la volée : jamais stockée (FR-5).
    private static func appIcon(for source: SourceApp) -> Image? {
        guard let bundleIdentifier = source.bundleIdentifier,
            let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
        else { return nil }
        return Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
    }

    /// Charge les vignettes des seuls éléments image affichés.
    private func loadThumbnails() async {
        for item in store.items where item.kind == .image && thumbnails[item.id] == nil {
            guard let data = await store.thumbnail(for: item.id),
                let image = NSImage(data: data)
            else { continue }
            thumbnails[item.id] = Image(nsImage: image)
        }
    }
}

/// Hauteur du contenu de la liste, remontée depuis la vue.
struct PopupContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Rendu hors écran

/// Même structure que `PopupView`, sans `ScrollView` ni `TextField`.
///
/// `ImageRenderer` ne dessine ni l'un ni l'autre : cette variante existe uniquement pour que
/// les instantanés de contrôle montrent la popup telle qu'elle s'affiche.
struct PopupContentPreview: View {
    let model: PopupViewModel
    let store: HistoryStore
    let preferences: Preferences

    var body: some View {
        VStack(spacing: CD.Space.x1_5) {
            if !preferences.captureEnabled {
                CDPauseBanner(onResume: {})
            }

            CDSearchFieldBody(
                isEnabled: !model.isEmpty,
                isFocused: !model.query.isEmpty,
                hasText: !model.query.isEmpty,
                onClear: {}
            ) {
                Text(
                    model.query.isEmpty
                        ? L.t("popup.search.placeholder") : model.query
                )
                .font(CD.Font.body)
                .foregroundStyle(model.query.isEmpty ? CD.Color.text3 : CD.Color.text1)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if model.isEmpty {
                CDEmptyState(
                    symbolName: "doc.on.clipboard",
                    titleKey: "popup.empty.title",
                    messageKey: "popup.empty.message"
                )
                .frame(maxWidth: .infinity)
            } else if model.hasNoResults {
                CDEmptyState(
                    symbolName: "magnifyingglass",
                    titleKey: "popup.empty.search.title",
                    messageKey: "popup.empty.search.message",
                    actionTitleKey: "search.clear",
                    action: {}
                )
                .frame(maxWidth: .infinity)
            } else {
                LazyVStack(alignment: .leading, spacing: CD.Space.x0_5) {
                    if !model.pinnedItems.isEmpty {
                        SectionHeader(title: L.t("popup.section.pinned"))
                        cells(model.pinnedItems, offset: 0)
                    }
                    if !model.recentItems.isEmpty {
                        if !model.pinnedItems.isEmpty {
                            SectionHeader(title: L.t("popup.section.recent"))
                        }
                        cells(model.recentItems, offset: model.pinnedItems.count)
                    }
                }
            }

            FooterBar(
                itemCount: model.visibleItems.count,
                totalCount: store.items.count,
                pinnedCount: store.items.filter(\.pinned).count,
                isSearching: model.isSearching,
                isPaused: !preferences.captureEnabled,
                onTogglePause: {},
                onOpenSettings: {},
                onClearAll: {}
            )
        }
        .padding(CD.Space.x1_5)
        .frame(width: CD.Metric.popupWidth)
        .background(CD.Color.bgPopoverSolid)
        .clipShape(RoundedRectangle(cornerRadius: CD.Radius.popover, style: .continuous))
        .environment(\.locale, L.locale)
    }

    @ViewBuilder
    private func cells(_ items: [ClipItem], offset: Int) -> some View {
        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
            HistoryCell(
                item: item,
                isSelected: model.selectedID == item.id,
                shortcutIndex: model.shortcutIndex(for: item),
                showSourceApp: preferences.showSourceApp,
                thumbnail: nil,
                appIcon: nil,
                onTogglePin: {}
            )
            .historyCellRank(offset + index + 1, of: model.visibleItems.count)
        }
    }
}
