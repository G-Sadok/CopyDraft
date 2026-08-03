import AppKit

/// Confirmation « Tout effacer » (§9, FR-12).
///
/// Alerte **système** et non fenêtre maison : effacer tout l'historique est irréversible, et
/// l'utilisateur doit reconnaître le geste au premier coup d'œil. Le décompte est explicite —
/// « 25 éléments seront supprimés définitivement » — parce qu'un « tout » ne dit rien de ce
/// qu'on perd.
@MainActor
public enum ClearAllAlert {
    /// Ce que l'utilisateur a répondu.
    public struct Result: Sendable, Equatable {
        public let confirmed: Bool
        public let keepsPinned: Bool

        public init(confirmed: Bool, keepsPinned: Bool) {
            self.confirmed = confirmed
            self.keepsPinned = keepsPinned
        }
    }

    /// Ouvre l'alerte et rend la réponse.
    ///
    /// - Parameters:
    ///   - itemCount: nombre total d'éléments concernés, épinglés compris.
    ///   - pinnedCount: nombre d'éléments épinglés ; la case n'apparaît qu'à partir de un.
    public static func run(itemCount: Int, pinnedCount: Int) -> Result {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title()
        alert.informativeText = message(itemCount: itemCount)

        // Premier bouton ajouté = bouton par défaut, tracé en rouge par `hasDestructiveAction`.
        let confirm = alert.addButton(withTitle: confirmTitle())
        confirm.hasDestructiveAction = true

        let cancel = alert.addButton(withTitle: cancelTitle())
        // `Échap` annule, toujours (§9).
        cancel.keyEquivalent = "\u{1B}"

        let checkbox = pinnedCount > 0 ? makeCheckbox(pinnedCount: pinnedCount) : nil
        alert.accessoryView = checkbox

        let response = alert.runModal()
        return Result(
            confirmed: response == .alertFirstButtonReturn,
            keepsPinned: checkbox?.state == .on
        )
    }

    // MARK: Libellés

    static func title(language: String? = nil) -> String {
        LocalizedTable.string("clearAll.title", table: .feedback, language: language)
    }

    /// « 25 éléments seront supprimés définitivement. Cette action est irréversible. »
    static func message(itemCount: Int, language: String? = nil) -> String {
        let key = LocalizedTable.isSingular(itemCount, language: language)
            ? "clearAll.message.one" : "clearAll.message.other"
        return LocalizedTable.format(key, table: .feedback, language: language, itemCount)
    }

    /// « Conserver le 1 élément épinglé » / « Conserver les 3 éléments épinglés ».
    static func keepPinnedTitle(pinnedCount: Int, language: String? = nil) -> String {
        let key = LocalizedTable.isSingular(pinnedCount, language: language)
            ? "clearAll.keepPinned.one" : "clearAll.keepPinned.other"
        return LocalizedTable.format(key, table: .feedback, language: language, pinnedCount)
    }

    static func confirmTitle(language: String? = nil) -> String {
        LocalizedTable.string("clearAll.confirm", table: .feedback, language: language)
    }

    static func cancelTitle(language: String? = nil) -> String {
        LocalizedTable.string("clearAll.cancel", table: .feedback, language: language)
    }

    // MARK: Case à cocher

    /// Case « Conserver le(s) *n* élément(s) épinglé(s) », **cochée par défaut** (FR-12) : le
    /// geste par défaut ne doit jamais faire perdre ce que l'utilisateur a mis de côté.
    private static func makeCheckbox(pinnedCount: Int) -> NSButton {
        let checkbox = NSButton(
            checkboxWithTitle: keepPinnedTitle(pinnedCount: pinnedCount), target: nil, action: nil
        )
        checkbox.state = .on
        checkbox.sizeToFit()
        // `NSAlert` n'élargit sa vue accessoire que si celle-ci le demande.
        checkbox.frame = NSRect(
            x: 0, y: 0,
            width: max(checkbox.fittingSize.width, CD.Metric.menuWidth),
            height: checkbox.fittingSize.height
        )
        return checkbox
    }
}
