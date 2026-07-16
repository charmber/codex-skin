#!/usr/bin/env swift

import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: GenerateAppIcon.swift OUTPUT.iconset\n".utf8))
    exit(2)
}

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

let variants: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

func drawIcon(pixels: Int) throws -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "CodexDreamSkinIcon", code: 1)
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    defer { NSGraphicsContext.restoreGraphicsState() }
    context.imageInterpolation = .high

    let scale = CGFloat(pixels)
    let outer = NSRect(x: scale * 0.04, y: scale * 0.04, width: scale * 0.92, height: scale * 0.92)
    let background = NSBezierPath(roundedRect: outer, xRadius: scale * 0.22, yRadius: scale * 0.22)
    NSColor(calibratedRed: 0.055, green: 0.067, blue: 0.075, alpha: 1).setFill()
    background.fill()

    let border = NSBezierPath(roundedRect: outer.insetBy(dx: scale * 0.025, dy: scale * 0.025), xRadius: scale * 0.19, yRadius: scale * 0.19)
    border.lineWidth = max(1, scale * 0.025)
    NSColor(calibratedRed: 0.224, green: 0.773, blue: 0.733, alpha: 1).setStroke()
    border.stroke()

    let paletteRect = NSRect(x: scale * 0.18, y: scale * 0.20, width: scale * 0.64, height: scale * 0.62)
    let palette = NSBezierPath(ovalIn: paletteRect)
    NSColor(calibratedWhite: 0.94, alpha: 1).setFill()
    palette.fill()

    let thumbHole = NSBezierPath(ovalIn: NSRect(x: scale * 0.57, y: scale * 0.22, width: scale * 0.18, height: scale * 0.18))
    NSColor(calibratedRed: 0.055, green: 0.067, blue: 0.075, alpha: 1).setFill()
    thumbHole.fill()

    let wells: [(CGFloat, CGFloat, NSColor)] = [
        (0.31, 0.59, NSColor(calibratedRed: 0.224, green: 0.773, blue: 0.733, alpha: 1)),
        (0.48, 0.67, NSColor(calibratedRed: 0.263, green: 0.655, blue: 0.918, alpha: 1)),
        (0.65, 0.58, NSColor(calibratedRed: 0.937, green: 0.388, blue: 0.596, alpha: 1)),
        (0.38, 0.41, NSColor(calibratedRed: 0.486, green: 0.843, blue: 0.286, alpha: 1))
    ]
    for (x, y, color) in wells {
        let diameter = scale * 0.105
        let well = NSBezierPath(ovalIn: NSRect(x: scale * x, y: scale * y, width: diameter, height: diameter))
        color.setFill()
        well.fill()
    }

    let brush = NSBezierPath()
    brush.move(to: NSPoint(x: scale * 0.56, y: scale * 0.35))
    brush.line(to: NSPoint(x: scale * 0.78, y: scale * 0.76))
    brush.lineWidth = max(2, scale * 0.055)
    brush.lineCapStyle = .round
    NSColor(calibratedRed: 0.937, green: 0.388, blue: 0.596, alpha: 1).setStroke()
    brush.stroke()

    context.flushGraphics()
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "CodexDreamSkinIcon", code: 2)
    }
    return png
}

for variant in variants {
    let data = try drawIcon(pixels: variant.pixels)
    try data.write(to: output.appendingPathComponent(variant.name), options: .atomic)
}
