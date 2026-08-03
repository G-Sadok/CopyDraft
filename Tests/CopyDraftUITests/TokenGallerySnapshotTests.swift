import AppKit
import SwiftUI
import Testing

@testable import CopyDraftUI

/// Rend la galerie de tokens en PNG, en clair et en sombre.
///
/// Contrôle visuel du design system sans dépendre d'une capture d'écran. Désactivé par
/// défaut : `CD_SNAPSHOTS=1 swift test` écrit les images dans `dist/snapshots/`.
@Suite("Instantanés de la galerie de tokens")
struct TokenGallerySnapshotTests {
    @MainActor
    @Test(
        "Rendu clair et sombre",
        .enabled(if: ProcessInfo.processInfo.environment["CD_SNAPSHOTS"] == "1"),
        arguments: [NSAppearance.Name.aqua, NSAppearance.Name.darkAqua]
    )
    func renderGallery(appearance name: NSAppearance.Name) throws {
        let appearance = try #require(NSAppearance(named: name))
        let outputDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("dist/snapshots")
        try FileManager.default.createDirectory(
            at: outputDirectory, withIntermediateDirectories: true
        )

        var data: Data?
        appearance.performAsCurrentDrawingAppearance {
            let renderer = ImageRenderer(
                content: TokenGalleryContent()
                    .frame(width: 720, height: 1400)
                    .environment(\.colorScheme, name == .darkAqua ? .dark : .light)
            )
            renderer.scale = 2
            guard let image = renderer.nsImage,
                let tiff = image.tiffRepresentation,
                let bitmap = NSBitmapImageRep(data: tiff)
            else { return }
            data = bitmap.representation(using: .png, properties: [:])
        }

        let png = try #require(data, "rendu impossible")
        let file = outputDirectory.appendingPathComponent(
            name == .darkAqua ? "tokens-dark.png" : "tokens-light.png"
        )
        try png.write(to: file)
        #expect(png.count > 10_000, "image suspecte : \(png.count) octets")
    }
}
