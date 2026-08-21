import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Deterministically renders the 9f Holder app icon from its SVG geometry.
///
/// Usage:
/// `swift -module-cache-path /tmp/holder-icon-module-cache DesignAssets/render-holder-app-icon.swift <output-directory>`
/// `swift -module-cache-path /tmp/holder-icon-module-cache DesignAssets/render-holder-app-icon.swift <output-directory> --contact-sheet /tmp/holder-icon-9f-contact-sheet.png`
///
/// The output filenames deliberately match `AppIcon.appiconset/Contents.json`.
/// The optional sheet is a visual QA artifact: left to right it enlarges the
/// exact 16, 29, 40, 60, and 1024 px variants. It is not part of the app.
let arguments = Array(CommandLine.arguments.dropFirst())

guard arguments.count == 1 || (arguments.count == 3 && arguments[1] == "--contact-sheet") else {
    fputs("Usage: render-holder-app-icon.swift <output-directory> [--contact-sheet <path>]\\n", stderr)
    exit(64)
}

let outputDirectory = URL(fileURLWithPath: arguments[0], isDirectory: true)
let contactSheetURL = arguments.count == 3
    ? URL(fileURLWithPath: arguments[2])
    : nil
let sizes = [16, 20, 29, 32, 40, 50, 57, 58, 60, 64, 72, 76, 80, 87, 100, 114, 120, 128, 144, 152, 167, 180, 256, 512, 1024]

let canvas = CGFloat(1024)
let ink = CGColor(srgbRed: 16.0 / 255.0, green: 43.0 / 255.0, blue: 37.0 / 255.0, alpha: 1)
let white = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
let mutedWhite = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.24)
let emeraldMint = CGColor(srgbRed: 57.0 / 255.0, green: 217.0 / 255.0, blue: 138.0 / 255.0, alpha: 1)

func fillRoundedRect(_ context: CGContext, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, radius: CGFloat, color: CGColor) {
    context.setFillColor(color)
    context.addPath(CGPath(roundedRect: CGRect(x: x, y: y, width: width, height: height), cornerWidth: radius, cornerHeight: radius, transform: nil))
    context.fillPath()
}

func makeIcon(size: Int) throws -> CGImage {
    let scale = CGFloat(size) / canvas
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else {
        throw NSError(domain: "HolderIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create drawing context."])
    }

    context.interpolationQuality = .high
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)

    // Match SVG's top-left coordinate system so the values below directly
    // correspond to `holder-app-icon-9f.svg` and the Redesign 9f spec.
    context.translateBy(x: 0, y: CGFloat(size))
    context.scaleBy(x: scale, y: -scale)

    context.setFillColor(ink)
    context.fill(CGRect(x: 0, y: 0, width: canvas, height: canvas))

    fillRoundedRect(context, x: 192, y: 288, width: 640, height: 64, radius: 32, color: mutedWhite)
    fillRoundedRect(context, x: 192, y: 640, width: 448, height: 64, radius: 32, color: mutedWhite)

    for x in [240, 400, 560] {
        context.setFillColor(white)
        context.fillEllipse(in: CGRect(x: CGFloat(x - 48), y: 464, width: 96, height: 96))
    }
    context.setFillColor(emeraldMint)
    context.fillEllipse(in: CGRect(x: 672, y: 464, width: 96, height: 96))

    guard let image = context.makeImage() else {
        throw NSError(domain: "HolderIcon", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not create icon image."])
    }
    return image
}

func writePNG(_ image: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "HolderIcon", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not create output at \(url.path)."])
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "HolderIcon", code: 4, userInfo: [NSLocalizedDescriptionKey: "Could not write \(url.path)."])
    }
}

func makeContactSheet() throws -> CGImage {
    let auditSizes = [16, 29, 40, 60, 1024]
    let tile = 256
    let gap = 24
    let margin = 24
    let width = (tile * auditSizes.count) + (gap * (auditSizes.count - 1)) + (margin * 2)
    let height = tile + (margin * 2)
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else {
        throw NSError(domain: "HolderIcon", code: 5, userInfo: [NSLocalizedDescriptionKey: "Could not create contact sheet context."])
    }

    context.setFillColor(CGColor(srgbRed: 0.92, green: 0.96, blue: 0.94, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))

    for (index, size) in auditSizes.enumerated() {
        let originX = margin + index * (tile + gap)
        let frame = CGRect(x: originX, y: margin, width: tile, height: tile)
        context.setFillColor(CGColor(srgbRed: 0.68, green: 0.75, blue: 0.71, alpha: 1))
        context.fill(frame.insetBy(dx: -2, dy: -2))
        context.interpolationQuality = size <= 60 ? .none : .high
        context.draw(try makeIcon(size: size), in: frame)
    }

    guard let sheet = context.makeImage() else {
        throw NSError(domain: "HolderIcon", code: 6, userInfo: [NSLocalizedDescriptionKey: "Could not create contact sheet image."])
    }
    return sheet
}

for size in sizes {
    let url = outputDirectory.appendingPathComponent("\(size).png")
    let image = try makeIcon(size: size)
    try writePNG(image, to: url)
}

if let contactSheetURL {
    try writePNG(try makeContactSheet(), to: contactSheetURL)
}
