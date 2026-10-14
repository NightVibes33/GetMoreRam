#!/usr/bin/env swift
// GetMoreRam app icon assets: 10 named, 1024x1024 true PNG outputs.
// Apple icon switching requires compiled alternate AppIcon sets;
// previews and the Home Screen icon use the same generated design.
import AppKit
import Foundation

struct IconTheme {
    let name: String
    let base: NSColor
    let high: NSColor
    let glow: NSColor
    let rotated: Bool
    let board: Bool
    let orbit: Bool
    let carbon: Bool
    let glass: Bool
}

let themes = [
    IconTheme(name: "Default",  base: NSColor(calibratedRed: 0.005, green: 0.025, blue: 0.08, alpha: 1), high: NSColor(calibratedRed: 0.06, green: 0.20, blue: 0.40, alpha: 1), glow: .systemBlue, rotated: true, board: false, orbit: false, carbon: false, glass: false),
    IconTheme(name: "Blue",     base: NSColor(calibratedRed: 0.01, green: 0.02, blue: 0.17, alpha: 1), high: NSColor(calibratedRed: 0.02, green: 0.10, blue: 0.46, alpha: 1), glow: .cyan, rotated: false, board: false, orbit: false, carbon: false, glass: false),
    IconTheme(name: "Purple",   base: NSColor(calibratedRed: 0.10, green: 0.005, blue: 0.15, alpha: 1), high: NSColor(calibratedRed: 0.37, green: 0.02, blue: 0.37, alpha: 1), glow: .magenta, rotated: false, board: false, orbit: false, carbon: false, glass: false),
    IconTheme(name: "Green",    base: NSColor(calibratedRed: 0.01, green: 0.09, blue: 0.025, alpha: 1), high: NSColor(calibratedRed: 0.02, green: 0.31, blue: 0.05, alpha: 1), glow: .systemGreen, rotated: false, board: false, orbit: false, carbon: false, glass: false),
    IconTheme(name: "Mono",     base: .black, high: NSColor(white: 0.14, alpha: 1), glow: NSColor(white: 0.85, alpha: 1), rotated: false, board: false, orbit: false, carbon: false, glass: false),
    IconTheme(name: "Glass",    base: NSColor(calibratedRed: 0.025, green: 0.13, blue: 0.23, alpha: 1), high: NSColor(calibratedRed: 0.36, green: 0.73, blue: 0.95, alpha: 1), glow: .cyan, rotated: false, board: false, orbit: false, carbon: false, glass: true),
    IconTheme(name: "Orbit",    base: NSColor(calibratedRed: 0.0, green: 0.02, blue: 0.10, alpha: 1), high: NSColor(calibratedRed: 0.0, green: 0.13, blue: 0.36, alpha: 1), glow: .cyan, rotated: true, board: false, orbit: true, carbon: false, glass: false),
    IconTheme(name: "Gradient", base: NSColor(calibratedRed: 0.04, green: 0.48, blue: 0.97, alpha: 1), high: NSColor(calibratedRed: 0.97, green: 0.16, blue: 0.65, alpha: 1), glow: .white, rotated: false, board: false, orbit: false, carbon: false, glass: true),
    IconTheme(name: "Carbon",   base: NSColor(calibratedWhite: 0.015, alpha: 1), high: NSColor(calibratedWhite: 0.16, alpha: 1), glow: NSColor(white: 0.88, alpha: 1), rotated: true, board: false, orbit: false, carbon: true, glass: false),
    IconTheme(name: "Board",    base: NSColor(calibratedRed: 0.00, green: 0.04, blue: 0.12, alpha: 1), high: NSColor(calibratedRed: 0.00, green: 0.14, blue: 0.39, alpha: 1), glow: .cyan, rotated: false, board: true, orbit: false, carbon: false, glass: false)
]

func rounded(_ r: NSRect, _ radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: r, xRadius: radius, yRadius: radius)
}

func paint(_ t: IconTheme) -> Data {
    let size = 1024
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
        isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    ), let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else {
        fatalError("Unable to create icon image bitmap")
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    defer { graphics.flushGraphics(); NSGraphicsContext.restoreGraphicsState() }

    let whole = NSRect(x: 0, y: 0, width: 1024, height: 1024)
    t.base.setFill(); whole.fill()
    if let gradient = NSGradient(starting: t.base, ending: t.high) {
        gradient.draw(in: whole, angle: 55)
    }

    if t.carbon {
        NSColor.white.withAlphaComponent(0.035).setStroke()
        for n in stride(from: -1100, through: 1100, by: 28) {
            let p = NSBezierPath()
            p.move(to: NSPoint(x: CGFloat(n), y: 0))
            p.line(to: NSPoint(x: CGFloat(n) + 1024, y: 1024))
            p.lineWidth = 10; p.stroke()
        }
    }
    if t.board {
        t.glow.withAlphaComponent(0.3).setStroke()
        for x in stride(from: 60, through: 980, by: 92) {
            let path = NSBezierPath()
            path.move(to: NSPoint(x: CGFloat(x), y: 15))
            path.line(to: NSPoint(x: CGFloat(x), y: 1009))
            path.lineWidth = 4
            path.stroke()
        }
        for y in stride(from: 60, through: 980, by: 92) {
            let path = NSBezierPath()
            path.move(to: NSPoint(x: 15, y: CGFloat(y)))
            path.line(to: NSPoint(x: 1009, y: CGFloat(y)))
            path.lineWidth = 4
            path.stroke()
        }
    }
    if t.orbit {
        let orbitPath = NSBezierPath(ovalIn: NSRect(x: 100, y: 375, width: 820, height: 270))
        var orbitTransform = AffineTransform()
        orbitTransform.translate(x: 512, y: 512)
        orbitTransform.rotate(byDegrees: -42)
        orbitTransform.translate(x: -512, y: -512)
        orbitPath.transform(using: orbitTransform)
        t.glow.withAlphaComponent(0.8).setStroke()
        orbitPath.lineWidth = 25
        orbitPath.stroke()
    }

    let chipRect = NSRect(x: 250, y: 250, width: 524, height: 524)
    let transform = NSAffineTransform()
    if t.rotated {
        transform.translateX(by: 512, yBy: 512)
        transform.rotate(byDegrees: -40)
        transform.translateX(by: -512, yBy: -512)
        transform.concat()
    }

    let shadow = NSShadow()
    shadow.shadowColor = t.glow.withAlphaComponent(0.85)
    shadow.shadowBlurRadius = 46
    shadow.set()

    t.glow.setStroke()
    for pos in stride(from: 305, through: 720, by: 83) {
        for pair in [
            (NSPoint(x: CGFloat(pos), y: 185), NSPoint(x: CGFloat(pos), y: 250)),
            (NSPoint(x: CGFloat(pos), y: 774), NSPoint(x: CGFloat(pos), y: 839)),
            (NSPoint(x: 185, y: CGFloat(pos)), NSPoint(x: 250, y: CGFloat(pos))),
            (NSPoint(x: 774, y: CGFloat(pos)), NSPoint(x: 839, y: CGFloat(pos)))
        ] {
            let p = NSBezierPath()
            p.move(to: pair.0); p.line(to: pair.1)
            p.lineWidth = 23; p.lineCapStyle = .round
            p.stroke()
        }
    }

    if t.glass {
        NSColor.white.withAlphaComponent(0.20).setFill()
    } else {
        NSColor(calibratedRed: 0.018, green: 0.037, blue: 0.105, alpha: 1).setFill()
    }
    let chip = rounded(chipRect, 62)
    chip.fill()
    chip.lineWidth = 24
    t.glow.setStroke()
    chip.stroke()

    let bevel = rounded(chipRect.insetBy(dx: 24, dy: 24), 42)
    bevel.lineWidth = 9
    NSColor.white.withAlphaComponent(t.glass ? 0.8 : 0.36).setStroke()
    bevel.stroke()

    NSShadow().set()
    let mark = "\u{F8FF}" as NSString
    let font = NSFont.systemFont(ofSize: 318, weight: .bold)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: t.name == "Mono" || t.name == "Carbon" ? NSColor.black : t.glow
    ]
    let dimensions = mark.size(withAttributes: attrs)
    mark.draw(at: NSPoint(x: 512 - dimensions.width / 2, y: 512 - dimensions.height / 2 - 16), withAttributes: attrs)

    if t.rotated {
        let inverse = NSAffineTransform()
        inverse.translateX(by: 512, yBy: 512)
        inverse.rotate(byDegrees: 40)
        inverse.translateX(by: -512, yBy: -512)
        inverse.concat()
    }

    if let result = bitmap.representation(using: .png, properties: [:]) {
        return result
    }
    fatalError("Cannot encode icon PNG")
}

func writeJSON(_ json: [String: Any], to url: URL) throws {
    let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: url)
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("GetMoreRam/Assets.xcassets")
for theme in themes {
    let data = paint(theme)
    let iconFolderName = theme.name == "Default" ? "AppIcon" : theme.name
    let dir = root.appendingPathComponent("\(iconFolderName).appiconset")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    try data.write(to: dir.appendingPathComponent("icon.png"))
    try writeJSON([
        "images": [["filename": "icon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"]],
        "info": ["author": "xcode", "version": 1]
    ], to: dir.appendingPathComponent("Contents.json"))

    let preview = root.appendingPathComponent("IconPreview-\(theme.name).imageset")
    try FileManager.default.createDirectory(at: preview, withIntermediateDirectories: true)
    try data.write(to: preview.appendingPathComponent("preview.png"))
    try writeJSON([
        "images": [["filename": "preview.png", "idiom": "universal"]],
        "info": ["author": "xcode", "version": 1]
    ], to: preview.appendingPathComponent("Contents.json"))
    print("Built icon: \(theme.name)")
}
