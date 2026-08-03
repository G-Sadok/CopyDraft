import AppKit
import Foundation
import Testing

@testable import CopyDraftUI

/// Vérifie le gabarit de l'icône de barre de menus (§6, FR-40) et produit des agrandissements
/// de contrôle visuel.
@Suite("Icône de barre de menus")
struct StatusItemIconTests {
    @MainActor
    @Test("Gabarit de 18 × 18", arguments: [false, true])
    func templateSize(paused: Bool) {
        let image = StatusItemIcon.image(paused: paused)
        #expect(image.size.width == CD.Metric.statusIconTemplate)
        #expect(image.size.height == CD.Metric.statusIconTemplate)
        #expect(image.size.width == 18)
    }

    @MainActor
    @Test("Rendue en template image : macOS choisit le noir, le blanc et l'inversion")
    func isTemplate() {
        #expect(StatusItemIcon.image(paused: false).isTemplate)
        #expect(StatusItemIcon.image(paused: true).isTemplate)
    }

    @MainActor
    @Test("L'état de pause change réellement le rendu")
    func pausedVariantDiffers() throws {
        // Agrandi : à 18 pt, deux barres de 1,5 pt ne pèsent que quelques pixels.
        let normal = try #require(Self.pixels(paused: false))
        let paused = try #require(Self.pixels(paused: true))

        #expect(normal != paused)
        // Le glyphe atténué à 40 % couvre moins d'encre, les barres n'en rendent pas autant.
        #expect(Self.ink(paused) < Self.ink(normal))
        #expect(Self.ink(paused) > 0)
    }

    @MainActor
    @Test(
        "Instantanés de contrôle",
        .enabled(if: ProcessInfo.processInfo.environment["CD_SNAPSHOTS"] == "1"),
        arguments: [false, true]
    )
    func renderSnapshot(paused: Bool) throws {
        let outputDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("dist/snapshots")
        try FileManager.default.createDirectory(
            at: outputDirectory, withIntermediateDirectories: true
        )

        let png = try #require(Self.png(paused: paused, side: 288))
        try png.write(
            to: outputDirectory.appendingPathComponent(
                paused ? "status-icon-paused.png" : "status-icon.png"
            )
        )
        #expect(png.count > 200)
    }

    // MARK: Outils

    /// Rendu agrandi ×16, sur fond blanc pour que le glyphe noir du template se voie.
    @MainActor
    private static func bitmap(paused: Bool, side: CGFloat) -> NSBitmapImageRep? {
        let glyph = StatusItemIcon.image(paused: paused, side: side)
        let canvas = NSImage(size: NSSize(width: side, height: side))
        canvas.lockFocus()
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: side, height: side).fill()
        glyph.draw(in: NSRect(x: 0, y: 0, width: side, height: side))
        canvas.unlockFocus()

        guard let tiff = canvas.tiffRepresentation else { return nil }
        return NSBitmapImageRep(data: tiff)
    }

    @MainActor
    private static func pixels(paused: Bool) -> Data? {
        bitmap(paused: paused, side: 288)?.representation(using: .png, properties: [:])
    }

    @MainActor
    private static func png(paused: Bool, side: CGFloat) -> Data? {
        bitmap(paused: paused, side: side)?.representation(using: .png, properties: [:])
    }

    /// Quantité d'encre déposée — proxy stable de l'opacité du glyphe.
    private static func ink(_ png: Data) -> Double {
        guard let rep = NSBitmapImageRep(data: png) else { return 0 }
        var total = 0.0
        for y in stride(from: 0, to: rep.pixelsHigh, by: 2) {
            for x in stride(from: 0, to: rep.pixelsWide, by: 2) {
                guard let color = rep.colorAt(x: x, y: y) else { continue }
                total += 1 - Double(color.brightnessComponent)
            }
        }
        return total
    }
}
