import AppKit
import CopyDraftCore
import CryptoKit
import Foundation
import SwiftUI
import Testing

@testable import CopyDraftUI

/// Rendu de la popup complète, à comparer à `design-system/screenshots/proto4.png`.
///
/// `CD_SNAPSHOTS=1 swift test` écrit les images dans `dist/snapshots/`.
@MainActor
@Suite("Instantanés de la popup")
struct PopupSnapshotTests {
    private static let referenceDate = Date(timeIntervalSince1970: 1_754_222_640)

    private func makeStore() async throws -> (HistoryStore, Preferences, URL) {
        let cipher = Cipher(key: SymmetricKey(size: .bits256))
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("copydraft-popupsnap-\(UUID().uuidString)", isDirectory: true)

        let suite = "com.copydraft.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let preferences = Preferences(defaults: defaults)

        let store = HistoryStore(
            repository: HistoryRepository(
                queue: try HistoryDatabase.openInMemory(), cipher: cipher
            ),
            imageStore: ImageStore(paths: AppPaths(root: root), cipher: cipher),
            preferences: preferences
        )

        // Le jeu d'éléments de la maquette §3.
        let fixtures:
            [(String, ClipSubtype, String, TimeInterval, Bool)] = [
                (
                    "let items = try store.fetch(\n    ClipItem.recent(limit: 25))", .code,
                    "Xcode", -240, true
                ),
                ("developer.apple.com/design/human-interface/materials", .link, "Safari", -1_080, false),
                ("Merci pour votre message, je regarde ça dès que possible.", .plain, "Mail", -720, false),
                ("SELECT id, created_at FROM clip_items WHERE pinned = 1", .code, "TablePlus", -2_040, false),
                ("~/Developer/copydraft/Sources/CopyDraftCore/ClipboardMonitor.swift", .path, "Finder", -50_000, false),
                ("#0A84FF", .color, "Sketch", -60_000, false)
            ]

        for (index, fixture) in fixtures.enumerated() {
            let (text, subtype, app, offset, pinned) = fixture
            await store.ingest(
                item: ClipItem(
                    kind: .text,
                    subtype: subtype,
                    createdAt: Self.referenceDate.addingTimeInterval(offset),
                    pinned: pinned,
                    source: SourceApp(bundleIdentifier: "com.test.\(app)", name: app),
                    byteCount: text.utf8.count,
                    characterCount: text.count,
                    searchText: text,
                    previewLines: text.split(separator: "\n").prefix(2).map(String.init)
                ),
                content: StoredContent(text: text),
                contentHash: Data([UInt8(index)]) + Data(repeating: 0, count: 31)
            )
        }

        return (store, preferences, root)
    }

    private func render(
        _ view: some View, named name: String, appearance: NSAppearance.Name
    ) throws {
        let directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("dist/snapshots")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        var data: Data?
        try #require(NSAppearance(named: appearance)).performAsCurrentDrawingAppearance {
            let renderer = ImageRenderer(
                content:
                    view
                    .environment(\.colorScheme, appearance == .darkAqua ? .dark : .light)
                    .historyCellNow(Self.referenceDate)
                    .frame(width: CD.Metric.popupWidth)
            )
            renderer.scale = 2
            guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
                let bitmap = NSBitmapImageRep(data: tiff)
            else { return }
            data = bitmap.representation(using: .png, properties: [:])
        }

        let png = try #require(data, "rendu impossible")
        try png.write(to: directory.appendingPathComponent("\(name).png"))
        #expect(png.count > 5_000)
    }

    @Test(
        "Popup garnie, claire et sombre",
        .enabled(if: ProcessInfo.processInfo.environment["CD_SNAPSHOTS"] == "1"),
        arguments: [NSAppearance.Name.aqua, NSAppearance.Name.darkAqua]
    )
    func filledPopup(appearance: NSAppearance.Name) async throws {
        let (store, preferences, root) = try await makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let model = PopupViewModel(store: store, preferences: preferences)
        model.prepareForDisplay()

        try render(
            PopupContentPreview(model: model, store: store, preferences: preferences),
            named: appearance == .darkAqua ? "popup-dark" : "popup-light",
            appearance: appearance
        )
    }

    @Test(
        "États vides et pause",
        .enabled(if: ProcessInfo.processInfo.environment["CD_SNAPSHOTS"] == "1"),
        arguments: ["empty", "no-results", "paused"]
    )
    func states(kind: String) async throws {
        let (store, preferences, root) = try await makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        if kind == "empty" { await store.clearAll(keepingPinned: false) }
        if kind == "paused" { preferences.captureEnabled = false }

        let model = PopupViewModel(store: store, preferences: preferences)
        model.prepareForDisplay()
        if kind == "no-results" { model.query = "facture" }

        try render(
            PopupContentPreview(model: model, store: store, preferences: preferences),
            named: "popup-\(kind)",
            appearance: .aqua
        )
    }
}
