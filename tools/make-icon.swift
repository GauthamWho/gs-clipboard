#!/usr/bin/env swift
// Generates the G's Clipboard app icon (blue + white) into Resources/AppIcon.iconset
// and compiles it to Resources/AppIcon.icns.
//
//   swift tools/make-icon.swift
//
// Uses SF Pro Rounded (the modern Apple display face) and a blue/white palette.

import AppKit

let outDir = URL(fileURLWithPath: "Resources/AppIcon.iconset", isDirectory: true)
try? FileManager.default.removeItem(at: outDir)
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let size = 1024.0

func srgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

let deepBlue = srgb(8, 45, 130)
let brightBlue = srgb(28, 108, 255)
let royalBlue = srgb(10, 74, 215)

func roundedFont(_ pointSize: CGFloat, weight: NSFont.Weight) -> NSFont {
    let base = NSFont.systemFont(ofSize: pointSize, weight: weight)
    let descriptor = base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor
    return NSFont(descriptor: descriptor, size: pointSize) ?? base
}

func drawIcon() -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    let canvas = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    canvas.fill()

    // Soft squircle body with a blue gradient.
    let bodyRect = NSInsetRect(canvas, 34, 34)
    let body = NSBezierPath(roundedRect: bodyRect, xRadius: 226, yRadius: 226)

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.30)
    shadow.shadowBlurRadius = 30
    shadow.shadowOffset = NSSize(width: 0, height: -16)
    shadow.set()
    NSColor.white.setFill()
    body.fill()

    NSGraphicsContext.current?.saveGraphicsState()
    body.addClip()
    let gradient = NSGradient(colors: [deepBlue, brightBlue])!
    gradient.draw(in: body, angle: -64)
    NSGraphicsContext.current?.restoreGraphicsState()

    // Clipboard board.
    let boardRect = NSRect(x: 262, y: 186, width: 500, height: 620)
    let board = NSBezierPath(roundedRect: boardRect, xRadius: 92, yRadius: 92)

    let boardShadow = NSShadow()
    boardShadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
    boardShadow.shadowBlurRadius = 34
    boardShadow.shadowOffset = NSSize(width: 0, height: -14)
    boardShadow.set()
    NSColor.white.setFill()
    board.fill()

    // The "G" — the owner's initial.
    let gFont = roundedFont(430, weight: .heavy)
    let gAttrs: [NSAttributedString.Key: Any] = [
        .font: gFont,
        .foregroundColor: royalBlue
    ]
    let gString = NSAttributedString(string: "G", attributes: gAttrs)
    let gSize = gString.size()
    gString.draw(at: NSPoint(x: boardRect.midX - gSize.width / 2,
                             y: boardRect.midY - gSize.height / 2 - 18))

    // Clipboard clip on top.
    let clipRect = NSRect(x: 412, y: 752, width: 200, height: 100)
    let clip = NSBezierPath(roundedRect: clipRect, xRadius: 34, yRadius: 34)
    let clipGradient = NSGradient(colors: [brightBlue, deepBlue])!
    clipGradient.draw(in: clip, angle: -90)

    let slotRect = NSRect(x: 448, y: 790, width: 128, height: 20)
    NSColor.white.withAlphaComponent(0.92).setFill()
    NSBezierPath(roundedRect: slotRect, xRadius: 10, yRadius: 10).fill()

    return image
}

let master = drawIcon()

guard let tiff = master.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff) else {
    fatalError("Could not render icon")
}

func writePNG(pixels: Int, name: String) {
    let target = NSImage(size: NSSize(width: pixels, height: pixels))
    target.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    master.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    target.unlockFocus()

    guard let t = target.tiffRepresentation,
          let b = NSBitmapImageRep(data: t),
          let png = b.representation(using: .png, properties: [:]) else { return }
    try? png.write(to: outDir.appendingPathComponent(name))
}

writePNG(pixels: 16, name: "icon_16x16.png")
writePNG(pixels: 32, name: "icon_16x16@2x.png")
writePNG(pixels: 32, name: "icon_32x32.png")
writePNG(pixels: 64, name: "icon_32x32@2x.png")
writePNG(pixels: 128, name: "icon_128x128.png")
writePNG(pixels: 256, name: "icon_128x128@2x.png")
writePNG(pixels: 256, name: "icon_256x256.png")
writePNG(pixels: 512, name: "icon_256x256@2x.png")
writePNG(pixels: 512, name: "icon_512x512.png")
writePNG(pixels: 1024, name: "icon_512x512@2x.png")

// Save the big one for the README / GitHub social preview.
try? rep.representation(using: .png, properties: [:])?
    .write(to: URL(fileURLWithPath: "Resources/AppIcon-1024.png"))

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", outDir.path, "-o", "Resources/AppIcon.icns"]
try iconutil.run()
iconutil.waitUntilExit()

print(iconutil.terminationStatus == 0 ? "Icon written to Resources/AppIcon.icns" : "iconutil failed")
