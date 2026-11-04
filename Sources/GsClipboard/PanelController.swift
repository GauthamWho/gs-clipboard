// Gautham's Clipboard by GauthamWho. Copyright © 2026 GauthamWho. All rights reserved. See LICENSE.
import AppKit
import SwiftUI

/// Borderless floating panel that opens at the pointer, the way Windows+V opens where you work.
final class CursorPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Native window glass: Liquid Glass (`NSGlassEffectView`) on macOS 26, the popover material before.
/// `GSCLIP_NO_GLASS=1` forces the fallback.
@MainActor
func makeGlassHost(_ content: NSView, cornerRadius: CGFloat) -> NSView {
    if #available(macOS 26.0, *), useGlass {
        let glass = NSGlassEffectView()
        glass.cornerRadius = cornerRadius
        // A light veil keeps text calm over busy windows; the desktop still shows through.
        glass.tintColor = NSColor.windowBackgroundColor.withAlphaComponent(0.52)
        glass.contentView = content
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: glass.leadingAnchor), content.trailingAnchor.constraint(equalTo: glass.trailingAnchor),
            content.topAnchor.constraint(equalTo: glass.topAnchor), content.bottomAnchor.constraint(equalTo: glass.bottomAnchor),
        ])
        // Clip the whole window to the same rounded shape, so no square edge or square
        // shadow shows past the glass corners.
        let clip = NSView()
        clip.wantsLayer = true
        clip.layer?.cornerRadius = cornerRadius
        clip.layer?.cornerCurve = .continuous
        clip.layer?.masksToBounds = true
        clip.layer?.backgroundColor = NSColor.clear.cgColor
        glass.translatesAutoresizingMaskIntoConstraints = false
        clip.addSubview(glass)
        NSLayoutConstraint.activate([
            glass.leadingAnchor.constraint(equalTo: clip.leadingAnchor), glass.trailingAnchor.constraint(equalTo: clip.trailingAnchor),
            glass.topAnchor.constraint(equalTo: clip.topAnchor), glass.bottomAnchor.constraint(equalTo: clip.bottomAnchor),
        ])
        return clip
    }
    content.translatesAutoresizingMaskIntoConstraints = false
    let fx = NSVisualEffectView()
    fx.material = .popover
    fx.blendingMode = .behindWindow
    fx.state = .active
    fx.wantsLayer = true
    fx.layer?.cornerRadius = cornerRadius
    fx.layer?.cornerCurve = .continuous
    fx.layer?.masksToBounds = true
    fx.addSubview(content)
    NSLayoutConstraint.activate([
        content.leadingAnchor.constraint(equalTo: fx.leadingAnchor), content.trailingAnchor.constraint(equalTo: fx.trailingAnchor),
        content.topAnchor.constraint(equalTo: fx.topAnchor), content.bottomAnchor.constraint(equalTo: fx.bottomAnchor),
    ])
    return fx
}

@MainActor
final class PanelController {
    private let panel: CursorPanel
    private let hosting: NSView
    private var outsideClickMonitor: Any?
    private var keyMonitor: Any?

    /// Keys the panel handles itself (arrows, return, ⌘1–9…). Return true to swallow.
    var keyHandler: ((NSEvent) -> Bool)?
    var onShow: (() -> Void)?
    var onHide: (() -> Void)?
    /// First real pointer movement after opening.
    var onMouseMoved: (() -> Void)?
    private var moveMonitor: Any?

    /// True when the panel opened below its anchor (so the preview must not rise above it).
    private(set) var opensBelow = true

    var isVisible: Bool { panel.isVisible }
    var frame: NSRect { panel.frame }

    init<Content: View>(@ViewBuilder content: () -> Content) {
        let h = NSHostingView(rootView: content())
        h.sizingOptions = []
        h.frame = NSRect(origin: .zero, size: DS.Size.panel)
        hosting = h
        panel = CursorPanel(contentRect: NSRect(origin: .zero, size: DS.Size.panel),
                            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
                            backing: .buffered, defer: false)
        let host = makeGlassHost(h, cornerRadius: DS.Radius.panel)
        host.frame = h.frame
        panel.contentView = host
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.animationBehavior = .utilityWindow
        panel.becomesKeyOnlyIfNeeded = false
        panel.acceptsMouseMovedEvents = true
    }

    // MARK: Showing

    func show(at anchor: PanelAnchor) {
        position(anchor)
        onShow?()
        NSApp.activate(ignoringOtherApps: true)
        panel.alphaValue = 1
        panel.makeKeyAndOrderFront(nil)
        panel.invalidateShadow()
        installMonitors()
        NotificationCenter.default.post(name: .gsClipboardDidShow, object: nil)
        Diag.log("panel shown at (\(Int(panel.frame.minX)), \(Int(panel.frame.minY))) below=\(opensBelow) key=\(panel.isKeyWindow)")
    }

    func hide() {
        guard panel.isVisible else { return }
        Diag.log("panel hidden")
        panel.orderOut(nil)
        removeMonitors()
        onHide?()
    }

    // MARK: Placement

    /// Next to the anchor, never on it. Caret: just under the line (first row right under your
    /// cursor), or just above it when there's no room below. Menu bar icon: dropped under it.
    private func position(_ anchor: PanelAnchor) {
        let size = panel.frame.size
        let edge: CGFloat = 8
        switch anchor {
        case .statusItem(let icon):
            let screen = NSScreen.screens.first { $0.frame.intersects(icon) } ?? NSScreen.main
            let visible = screen?.visibleFrame ?? icon
            var x = icon.midX - size.width / 2
            x = min(max(x, visible.minX + edge), visible.maxX - size.width - edge)
            opensBelow = true
            panel.setFrameOrigin(NSPoint(x: x, y: visible.maxY - size.height - 6))
        case .caret(let line):
            let p = NSPoint(x: line.midX, y: line.midY)
            let screen = NSScreen.screens.first { NSMouseInRect(p, $0.frame, false) } ?? NSScreen.main
            let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
            let gap: CGFloat = 8
            let roomBelow = line.minY - gap - visible.minY
            let roomAbove = visible.maxY - (line.maxY + gap)
            var y: CGFloat
            if roomBelow >= size.height + edge {
                y = line.minY - gap - size.height; opensBelow = true
            } else if roomAbove >= size.height + edge {
                y = line.maxY + gap; opensBelow = false
            } else {
                // Short screen: take the bigger side and keep the line itself visible.
                opensBelow = roomBelow >= roomAbove
                y = opensBelow ? visible.minY + edge : visible.maxY - size.height - edge
            }
            // The list's text column lines up with your cursor.
            var x = line.minX - 22
            x = min(max(x, visible.minX + edge), visible.maxX - size.width - edge)
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }

    /// Converts a frame in the panel's SwiftUI space (top-left origin) to screen coordinates.
    func screenRect(fromPanel r: CGRect) -> NSRect {
        NSRect(x: panel.frame.minX + r.minX, y: panel.frame.maxY - r.maxY, width: r.width, height: r.height)
    }

    // MARK: Monitors

    private func installMonitors() {
        if outsideClickMonitor == nil {
            outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                Task { @MainActor in self?.hide() }
            }
        }
        if moveMonitor == nil {
            moveMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .scrollWheel]) { [weak self] e in
                self?.onMouseMoved?(); return e
            }
        }
        if keyMonitor == nil {
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
                guard let self, self.panel.isKeyWindow else { return e }
                return (self.keyHandler?(e) ?? false) ? nil : e
            }
        }
    }

    private func removeMonitors() {
        if let m = outsideClickMonitor { NSEvent.removeMonitor(m); outsideClickMonitor = nil }
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
        if let m = moveMonitor { NSEvent.removeMonitor(m); moveMonitor = nil }
    }
}
