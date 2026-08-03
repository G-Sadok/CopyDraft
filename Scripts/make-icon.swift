// Génère l'icône d'application de CopyDraft d'après le design system §9.
//
// « Deux feuilles décalées : l'ancienne, l'actuelle — l'histoire du presse-papiers en un
// glyphe. Dégradé bleu-ardoise 165°, liseré supérieur blanc 25 %. Gabarit macOS : 824 × 824
// dans un canevas de 1024, rayon 24 %. À 16 pt, une seule feuille : la superposition devient
// illisible. »
//
// Usage : swift Scripts/make-icon.swift <dossier de sortie>

import AppKit
import CoreGraphics
import Foundation

// MARK: Cotes du design system

/// Gabarit macOS : le carré peint occupe 824 pt d'un canevas de 1024.
let templateRatio: CGFloat = 824.0 / 1024.0
/// Rayon exprimé en fraction du côté peint.
let cornerRatio: CGFloat = 0.24
/// Angle du dégradé, en degrés, sens horaire depuis le haut.
let gradientAngle: CGFloat = 165

// MARK: Palette

/// Bleu système en haut, ardoise en bas.
let gradientTop = CGColor(srgbRed: 0.10, green: 0.52, blue: 1.00, alpha: 1)
let gradientBottom = CGColor(srgbRed: 0.17, green: 0.24, blue: 0.38, alpha: 1)

func makeIcon(size: CGFloat) -> CGImage? {
    guard
        let context = CGContext(
            data: nil,
            width: Int(size),
            height: Int(size),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    else { return nil }

    let painted = size * templateRatio
    let inset = (size - painted) / 2
    let square = CGRect(x: inset, y: inset, width: painted, height: painted)
    let radius = painted * cornerRatio

    // Fond arrondi, découpe du dégradé.
    let squircle = CGPath(roundedRect: square, cornerWidth: radius, cornerHeight: radius, transform: nil)
    context.saveGState()
    context.addPath(squircle)
    context.clip()

    let radians = gradientAngle * .pi / 180
    let half = painted / 2
    let center = CGPoint(x: square.midX, y: square.midY)
    let start = CGPoint(
        x: center.x - sin(radians) * half, y: center.y + cos(radians) * half
    )
    let end = CGPoint(
        x: center.x + sin(radians) * half, y: center.y - cos(radians) * half
    )

    if let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [gradientTop, gradientBottom] as CFArray,
        locations: [0, 1]
    ) {
        // Sans ces options, tout ce qui dépasse la bande du dégradé reste transparent :
        // à 165°, deux coins opposés se retrouvent vides.
        context.drawLinearGradient(
            gradient, start: start, end: end,
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
    }

    // Les deux feuilles : l'ancienne en retrait, l'actuelle devant.
    // Sous 32 px, la superposition devient illisible : une seule feuille (§9).
    let showsBothSheets = size >= 32

    let sheetWidth = painted * 0.40
    let sheetHeight = painted * 0.52
    let sheetRadius = sheetWidth * 0.14
    let offset = painted * 0.075

    let frontRect = CGRect(
        x: square.midX - sheetWidth / 2 - (showsBothSheets ? offset / 2 : 0),
        y: square.midY - sheetHeight / 2 - (showsBothSheets ? offset / 2 : 0),
        width: sheetWidth,
        height: sheetHeight
    )

    if showsBothSheets {
        let backRect = frontRect.offsetBy(dx: offset, dy: offset)
        context.setFillColor(CGColor(gray: 1, alpha: 0.38))
        context.addPath(
            CGPath(
                roundedRect: backRect, cornerWidth: sheetRadius, cornerHeight: sheetRadius,
                transform: nil
            )
        )
        context.fillPath()
    }

    context.setFillColor(CGColor(gray: 1, alpha: 0.96))
    context.addPath(
        CGPath(
            roundedRect: frontRect, cornerWidth: sheetRadius, cornerHeight: sheetRadius,
            transform: nil
        )
    )
    context.fillPath()

    // Lignes de contenu sur la feuille de devant, seulement quand elles restent lisibles.
    if size >= 64 {
        let lineHeight = sheetHeight * 0.055
        let lineInset = sheetWidth * 0.16
        let widths: [CGFloat] = [0.68, 0.52, 0.60]
        context.setFillColor(CGColor(srgbRed: 0.17, green: 0.24, blue: 0.38, alpha: 0.55))

        for (index, ratio) in widths.enumerated() {
            let y = frontRect.maxY - sheetHeight * (0.30 + CGFloat(index) * 0.17)
            let rect = CGRect(
                x: frontRect.minX + lineInset,
                y: y,
                width: (sheetWidth - 2 * lineInset) * ratio,
                height: lineHeight
            )
            context.addPath(
                CGPath(
                    roundedRect: rect, cornerWidth: lineHeight / 2, cornerHeight: lineHeight / 2,
                    transform: nil
                )
            )
            context.fillPath()
        }
    }

    context.restoreGState()

    // Liseré supérieur blanc à 25 % : ce qui donne le relief des icônes macOS.
    context.saveGState()
    context.addPath(squircle)
    context.clip()
    context.setStrokeColor(CGColor(gray: 1, alpha: 0.25))
    context.setLineWidth(max(1, painted * 0.006))
    context.addPath(
        CGPath(
            roundedRect: square.insetBy(dx: painted * 0.003, dy: painted * 0.003),
            cornerWidth: radius, cornerHeight: radius, transform: nil
        )
    )
    context.strokePath()
    context.restoreGState()

    return context.makeImage()
}

// MARK: Écriture

let arguments = CommandLine.arguments
let outputDirectory = URL(
    fileURLWithPath: arguments.count > 1 ? arguments[1] : "dist/AppIcon.iconset"
)
try? FileManager.default.createDirectory(
    at: outputDirectory, withIntermediateDirectories: true
)

/// Tailles exigées par `iconutil`.
let variants: [(name: String, size: CGFloat)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1_024)
]

for variant in variants {
    guard let image = makeIcon(size: variant.size) else {
        FileHandle.standardError.write(Data("rendu impossible : \(variant.name)\n".utf8))
        exit(1)
    }
    let url = outputDirectory.appendingPathComponent("\(variant.name).png")
    guard
        let destination = CGImageDestinationCreateWithURL(
            url as CFURL, "public.png" as CFString, 1, nil
        )
    else { exit(1) }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { exit(1) }
}

print("✓ \(variants.count) tailles écrites dans \(outputDirectory.path)")
