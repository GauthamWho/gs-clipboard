// Gautham's Clipboard by GauthamWho. Copyright © 2026 GauthamWho. All rights reserved. See LICENSE.
import SwiftUI
import AppKit

/// "Quiet instrument", clipboard edition. Visual reference: design/stylesheet.html.
/// Wording: design/CONTENT.md. Every view reads tokens from here.
enum DS {
    enum Palette {
        static let label = Color(nsColor: .labelColor)
        static let secondary = Color(nsColor: .secondaryLabelColor)
        static let tertiary = Color(nsColor: .tertiaryLabelColor)
        static let separator = Color(nsColor: .separatorColor)
        static let fill = Color.primary.opacity(0.045)
        /// Readable quiet text (hints, counts, badges): ≥4.5:1 on the panel, unlike tertiary grey.
        static let meta = Color(nsColor: NSColor(name: "meta") { a in
            a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(white: 1, alpha: 0.56) : NSColor(srgbRed: 0.43, green: 0.43, blue: 0.45, alpha: 1)
        })
        /// Candy pink. Bright on dark glass, deeper on light glass so small text stays readable (≥4.5:1).
        static let tint = Color(nsColor: NSColor(name: "tint") { a in
            a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(srgbRed: 1.0, green: 0.44, blue: 0.70, alpha: 1)   // #FF70B3
                : NSColor(srgbRed: 0.80, green: 0.10, blue: 0.45, alpha: 1)  // #CC1A73
        })
        static let pin = Color(nsColor: .systemOrange)
        static let critical = Color(nsColor: .systemRed)
    }

    enum Space {
        static let xs: CGFloat = 4, s: CGFloat = 8, m: CGFloat = 12, l: CGFloat = 16, xl: CGFloat = 20
    }

    enum Radius {
        static let thumb: CGFloat = 8, tile: CGFloat = 7, row: CGFloat = 10, card: CGFloat = 14, preview: CGFloat = 18, panel: CGFloat = 20
    }

    enum Size {
        static let panel = CGSize(width: 380, height: 540)
        static let tile: CGFloat = 28
        static let thumb = CGSize(width: 120, height: 76)
        static let previewMax = CGSize(width: 520, height: 400)
    }

    /// Regular and medium only; never bold.
    enum Text {
        static let title = Font.system(size: 15, weight: .medium)
        static let search = Font.system(size: 13)
        static let row = Font.system(size: 12.5)
        static let name = Font.system(size: 12.5, weight: .medium)
        static let meta = Font.system(size: 11)
        static let chip = Font.system(size: 11, weight: .medium)
        static let badge = Font.system(size: 10.5, weight: .medium, design: .rounded)
        static let overline = Font.system(size: 11, weight: .medium)
    }

    static func wash(_ scheme: ColorScheme) -> Color { Palette.tint.opacity(scheme == .dark ? 0.17 : 0.10) }
    static func washEdge(_ scheme: ColorScheme) -> Color { Palette.tint.opacity(scheme == .dark ? 0.40 : 0.30) }
}

enum Brand {
    static let blue = Color(red: 0.12, green: 0.42, blue: 1.0)      // #1F6BFF
    static let deep = Color(red: 0.04, green: 0.24, blue: 0.80)     // #0A3DCC
    static let sky = Color(red: 0.56, green: 0.80, blue: 1.0)       // #8FCCFF
    static let pink = Color(red: 1.0, green: 0.37, blue: 0.66)      // #FF5FA8, UI accent
    static let paperEdge = Color(red: 0.78, green: 0.84, blue: 0.95) // #C7D6F2
    static let name = "Gautham's Clipboard"
    static let maker = "GauthamWho"
    static let copyright = "© 2026 GauthamWho. All rights reserved."
}

/// Small uppercase section label.
struct Overline: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased()).font(DS.Text.overline).tracking(0.7).foregroundStyle(DS.Palette.meta)
    }
}

// MARK: - Brand mark

/// The G from G.ai Token Tray: a ring opened at the top right, a crossbar, a dot at the tip.
/// Drawn on a 24-point grid.
struct GLetterShape: Shape {
    var dot = true
    func path(in r: CGRect) -> Path {
        let s = min(r.width, r.height) / 24
        let o = CGPoint(x: r.midX - 12 * s, y: r.midY - 12 * s)
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: o.x + x * s, y: o.y + y * s) }
        var g = Path()
        g.addArc(center: p(12, 12), radius: 7.2 * s, startAngle: .degrees(-45), endAngle: .degrees(0), clockwise: true)
        g.addLine(to: p(12.6, 12))
        var out = g.strokedPath(StrokeStyle(lineWidth: 2.6 * s, lineCap: .round, lineJoin: .round))
        if dot { out = out.union(Path(ellipseIn: CGRect(x: o.x + 15.0 * s, y: o.y + 4.8 * s, width: 4.2 * s, height: 4.2 * s))) }
        return out
    }
}

/// The two-sheet copy shape: a plain white sheet behind, a blue sheet with the white G in front.
/// `plate` adds the macOS icon squircle (app icon); without it the sheets sit on glass (panel header).
struct ClipMark: View {
    var size: CGFloat = 22
    var plate = false

    var body: some View {
        Canvas { ctx, canvas in
            let u = canvas.width / 1024
            func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect { CGRect(x: x * u, y: y * u, width: w * u, height: h * u) }
            // Without the plate the sheets grow to fill the frame.
            let back = plate ? r(250, 215, 400, 500) : r(150, 70, 520, 650)
            let front = plate ? r(374, 309, 400, 500) : r(354, 304, 520, 650)
            let sheetR = (plate ? 64 : 92) * u

            if plate {
                let body = Path(roundedRect: r(100, 100, 824, 824), cornerRadius: 185 * u, style: .continuous)
                ctx.fill(body, with: .linearGradient(Gradient(colors: [.white, Color(red: 0.87, green: 0.91, blue: 1)]),
                                                     startPoint: .init(x: 100 * u, y: 100 * u), endPoint: .init(x: 924 * u, y: 924 * u)))
                ctx.stroke(body, with: .color(.black.opacity(0.06)), lineWidth: max(0.5, 2 * u))
            }

            var shadowed = ctx
            shadowed.addFilter(.shadow(color: Brand.deep.opacity(plate ? 0.22 : 0.18), radius: (plate ? 22 : 14) * u, x: 0, y: (plate ? 18 : 10) * u))
            let backPath = Path(roundedRect: back, cornerRadius: sheetR, style: .continuous)
            shadowed.fill(backPath, with: .color(.white))
            ctx.stroke(backPath, with: .color(Brand.paperEdge), lineWidth: max(0.75, 7 * u))

            let frontPath = Path(roundedRect: front, cornerRadius: sheetR, style: .continuous)
            shadowed.fill(frontPath, with: .linearGradient(Gradient(colors: [Brand.blue, Brand.deep]),
                                                           startPoint: front.origin, endPoint: CGPoint(x: front.maxX, y: front.maxY)))
            ctx.stroke(Path(roundedRect: front.insetBy(dx: 2 * u, dy: 2 * u), cornerRadius: sheetR - 2 * u, style: .continuous),
                       with: .color(.white.opacity(0.22)), lineWidth: max(0.5, 3 * u))

            let g = front.width * 0.9
            let gRect = CGRect(x: front.midX - g / 2, y: front.midY - g / 2, width: g, height: g)
            ctx.fill(GLetterShape(dot: false).path(in: gRect), with: .color(.white))
            let s = g / 24
            ctx.fill(Path(ellipseIn: CGRect(x: gRect.minX + 15.0 * s, y: gRect.minY + 4.8 * s, width: 4.2 * s, height: 4.2 * s)),
                     with: .color(Brand.sky))
        }
        .frame(width: size, height: size)
    }
}

/// Menu bar template: back sheet outline, front sheet filled, the G cut out of it.
struct MenuBarMark: View {
    var body: some View {
        Canvas { ctx, canvas in
            let u = canvas.width / 24
            func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect { CGRect(x: x * u, y: y * u, width: w * u, height: h * u) }
            ctx.stroke(Path(roundedRect: r(2.6, 2.2, 11.6, 14.2), cornerRadius: 2.6 * u, style: .continuous),
                       with: .color(.black), lineWidth: 1.6 * u)
            let front = r(7.4, 6.6, 13.6, 15.6)
            // Clear a thin gap around the front sheet so the two sheets read apart.
            ctx.blendMode = .destinationOut
            ctx.fill(Path(roundedRect: front.insetBy(dx: -1.3 * u, dy: -1.3 * u), cornerRadius: 3.8 * u, style: .continuous), with: .color(.black))
            ctx.blendMode = .normal
            ctx.fill(Path(roundedRect: front, cornerRadius: 2.8 * u, style: .continuous), with: .color(.black))
            ctx.blendMode = .destinationOut
            let g = front.width * 1.02
            ctx.fill(GLetterShape(dot: true).path(in: CGRect(x: front.midX - g / 2, y: front.midY - g / 2, width: g, height: g)),
                     with: .color(.black))
        }
        .frame(width: 18, height: 18)
    }

    @MainActor static func image() -> NSImage {
        let renderer = ImageRenderer(content: MenuBarMark())
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        let img = renderer.nsImage ?? NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)!
        img.size = NSSize(width: 18, height: 18)
        img.isTemplate = true
        img.accessibilityDescription = Brand.name
        return img
    }
}

// MARK: - Still images

/// `GsClipboard --brand-assets <dir>` writes the app iconset, a 1024 logo and menu bar PNGs, then exits.
enum BrandAssets {
    @MainActor static func runIfRequested() {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--brand-assets"), i + 1 < args.count else { return }
        let dir = URL(fileURLWithPath: args[i + 1], isDirectory: true)
        let iconset = dir.appendingPathComponent("AppIcon.iconset")
        try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
        func save<V: View>(_ v: V, _ url: URL, scale: CGFloat) {
            let r = ImageRenderer(content: v); r.scale = scale
            guard let img = r.nsImage, let t = img.tiffRepresentation,
                  let png = NSBitmapImageRep(data: t)?.representation(using: .png, properties: [:]) else { return }
            try? png.write(to: url)
        }
        for pt in [16, 32, 128, 256, 512] {
            for sc in [1, 2] {
                let name = sc == 1 ? "icon_\(pt)x\(pt).png" : "icon_\(pt)x\(pt)@2x.png"
                save(ClipMark(size: CGFloat(pt), plate: true), iconset.appendingPathComponent(name), scale: CGFloat(sc))
            }
        }
        save(ClipMark(size: 512, plate: true), dir.appendingPathComponent("AppIcon-1024.png"), scale: 2)
        save(MenuBarMark().padding(3).background(Color(white: 0.92)), dir.appendingPathComponent("menubar-light.png"), scale: 6)
        save(MenuBarMark().colorInvert().padding(3).background(Color(white: 0.12)), dir.appendingPathComponent("menubar-dark.png"), scale: 6)
        exit(0)
    }
}
