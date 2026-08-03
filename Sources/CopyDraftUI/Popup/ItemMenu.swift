import CopyDraftCore
import SwiftUI

/// Menu contextuel d'un élément (§9).
///
/// Les raccourcis affichés sont ceux de la popup : le menu ne fait que les rappeler, il ne
/// les enregistre pas — c'est le tap clavier qui les traite (ADR-6).
public struct ItemMenu: View {
    private let item: ClipItem
    private let onPaste: () -> Void
    private let onPastePlain: () -> Void
    private let onTogglePin: () -> Void
    private let onCopy: () -> Void
    private let onDelete: () -> Void
    private let onExcludeApp: () -> Void

    public init(
        item: ClipItem,
        onPaste: @escaping () -> Void,
        onPastePlain: @escaping () -> Void,
        onTogglePin: @escaping () -> Void,
        onCopy: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onExcludeApp: @escaping () -> Void
    ) {
        self.item = item
        self.onPaste = onPaste
        self.onPastePlain = onPastePlain
        self.onTogglePin = onTogglePin
        self.onCopy = onCopy
        self.onDelete = onDelete
        self.onExcludeApp = onExcludeApp
    }

    public var body: some View {
        Button(L.t("item.paste"), action: onPaste)
        Button(L.t("item.pastePlain"), action: onPastePlain)

        Divider()

        // Le libellé bascule selon l'état : « Épingler » ou « Désépingler » (§9).
        Button(L.t(item.pinned ? "item.unpin" : "item.pin"), action: onTogglePin)
        Button(L.t("item.copy"), action: onCopy)

        Divider()

        Button(L.t("item.delete"), role: .destructive, action: onDelete)

        if let name = item.source.name.isEmpty ? nil : item.source.name {
            Divider()
            // L'exclusion nomme l'application source de l'élément visé (§9).
            Button(String(format: L.t("item.neverRecord %@"), name), action: onExcludeApp)
        }
    }
}
