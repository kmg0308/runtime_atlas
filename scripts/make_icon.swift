import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: swift scripts/make_icon.swift <output.icns>\n", stderr)
    exit(64)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let iconsetURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("RuntimeAtlas-\(UUID().uuidString).iconset", isDirectory: true)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: iconsetURL) }

func atlasImage(side: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: side, height: side))
    image.lockFocus()
    defer { image.unlockFocus() }

    NSGraphicsContext.current?.imageInterpolation = .high
    let bounds = NSRect(x: 0, y: 0, width: side, height: side)
    let outer = NSBezierPath(
        roundedRect: bounds.insetBy(dx: side * 0.055, dy: side * 0.055),
        xRadius: side * 0.19,
        yRadius: side * 0.19
    )
    NSColor(calibratedRed: 0.025, green: 0.040, blue: 0.060, alpha: 1).setFill()
    outer.fill()

    let inset = side * 0.19
    let mapBounds = bounds.insetBy(dx: inset, dy: inset)
    let gridColor = NSColor(calibratedRed: 0.27, green: 0.49, blue: 0.61, alpha: 0.32)
    gridColor.setStroke()
    for fraction in [0.25, 0.50, 0.75] as [CGFloat] {
        let horizontal = NSBezierPath()
        horizontal.move(to: NSPoint(x: mapBounds.minX, y: mapBounds.minY + mapBounds.height * fraction))
        horizontal.line(to: NSPoint(x: mapBounds.maxX, y: mapBounds.minY + mapBounds.height * fraction))
        horizontal.lineWidth = max(1, side * 0.008)
        horizontal.stroke()

        let vertical = NSBezierPath()
        vertical.move(to: NSPoint(x: mapBounds.minX + mapBounds.width * fraction, y: mapBounds.minY))
        vertical.line(to: NSPoint(x: mapBounds.minX + mapBounds.width * fraction, y: mapBounds.maxY))
        vertical.lineWidth = max(1, side * 0.008)
        vertical.stroke()
    }

    let points = [
        NSPoint(x: mapBounds.minX + mapBounds.width * 0.14, y: mapBounds.minY + mapBounds.height * 0.69),
        NSPoint(x: mapBounds.minX + mapBounds.width * 0.51, y: mapBounds.minY + mapBounds.height * 0.38),
        NSPoint(x: mapBounds.minX + mapBounds.width * 0.84, y: mapBounds.minY + mapBounds.height * 0.66)
    ]
    let rail = NSBezierPath()
    rail.move(to: points[0])
    rail.line(to: points[1])
    rail.line(to: points[2])
    rail.lineWidth = max(2, side * 0.045)
    rail.lineCapStyle = .round
    rail.lineJoinStyle = .round
    NSColor(calibratedRed: 0.42, green: 0.78, blue: 0.96, alpha: 1).setStroke()
    rail.stroke()

    let nodeColors = [
        NSColor(calibratedRed: 0.42, green: 0.78, blue: 0.96, alpha: 1),
        NSColor(calibratedRed: 0.46, green: 0.88, blue: 0.68, alpha: 1),
        NSColor(calibratedRed: 1.0, green: 0.73, blue: 0.32, alpha: 1)
    ]
    for (point, color) in zip(points, nodeColors) {
        let radius = side * 0.082
        let node = NSBezierPath(ovalIn: NSRect(
            x: point.x - radius,
            y: point.y - radius,
            width: radius * 2,
            height: radius * 2
        ))
        NSColor(calibratedRed: 0.025, green: 0.040, blue: 0.060, alpha: 1).setFill()
        node.fill()
        color.setStroke()
        node.lineWidth = max(2, side * 0.026)
        node.stroke()
    }

    return image
}

func writePNG(pixelSize: Int, filename: String) throws {
    let image = atlasImage(side: CGFloat(pixelSize))
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "RuntimeAtlasIcon", code: 1)
    }
    try png.write(to: iconsetURL.appendingPathComponent(filename), options: .atomic)
}

for size in [16, 32, 128, 256, 512] {
    try writePNG(pixelSize: size, filename: "icon_\(size)x\(size).png")
    try writePNG(pixelSize: size * 2, filename: "icon_\(size)x\(size)@2x.png")
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", outputURL.path]
try process.run()
process.waitUntilExit()
guard process.terminationStatus == 0 else { exit(process.terminationStatus) }
