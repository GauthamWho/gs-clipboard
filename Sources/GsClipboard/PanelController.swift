import AppKit
import SwiftUI

/// A borderless floating panel that opens **at the mouse pointer**, the way
/// Windows+V opens near where you are working instead of at the top of the
/// screen.
///
/// macOS only exposes the text caret position to apps that hold the
/// Accessibility permission. G's Clipboard deliberately asks for no
/// permissions, so the pointer is used as the anchor — it is already where the
/// user is looking and clicking.
final class CursorPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Rounded card + shadow drawn around the SwiftUI content. The window itself is
/// transparent so the corners and shadow are real, not square.
struct PanelChrome<Content: View>: View {
    static var margin: CGFloat { 12 }

    let content: Content

    var body: some View {
        content
            .background(Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.28), radius: 16, x: 0, y: 6)
            .padding(Self.margin)
    }
}

@MainActor
final class PanelController {
    /// Size of the visible card (matches `ContentView`'s frame).
    static let cardSize = NSSize(width: 320, height: 440)

    private let panel: CursorPanel
    private var outsideClickMonitor: Any?

    /// Called when the panel closes, so the app can hand focus back.
    var onHide: (() -> Void)?

    var isVisible: Bool { panel.isVisible }

    var frame: NSRect { panel.frame }

    init<Content: View>(@ViewBuilder content: () -> Content) {
        let hosting = NSHostingController(rootView: PanelChrome(content: content()))
        panel = CursorPanel(contentViewController: hosting)
        panel.styleMask = [.borderless, .nonactivatingPanel, .fullSizeContentView]
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.animationBehavior = .utilityWindow
        panel.becomesKeyOnlyIfNeeded = false

        let outer = NSSize(
            width: Self.cardSize.width + PanelChrome<EmptyView>.margin * 2,
            height: Self.cardSize.height + PanelChrome<EmptyView>.margin * 2
        )
        panel.setContentSize(outer)
    }

    // MARK: - Showing

    func show(near point: NSPoint? = nil) {
        position(near: point ?? NSEvent.mouseLocation)

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        installOutsideClickMonitor()

        NotificationCenter.default.post(name: .gsClipboardDidShow, object: nil)

        let origin = panel.frame.origin
        Diag.log("panel shown at (\(Int(origin.x)), \(Int(origin.y))) "
                 + "size=\(Int(panel.frame.width))x\(Int(panel.frame.height)) "
                 + "screen=\(screenName()) key=\(panel.isKeyWindow)")

        // Confirm the panel really took keyboard focus (needed for the search
        // field and Escape), and report it if it did not.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            Diag.log("panel focus key=\(self.panel.isKeyWindow) visible=\(self.panel.isVisible)")
        }
    }

    func hide() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        removeOutsideClickMonitor()
        onHide?()
    }

    func toggle() {
        if panel.isVisible { hide() } else { show() }
    }

    // MARK: - Placement

    /// Puts the card just below-right of the pointer, flipping above it when
    /// there is not enough room, and keeping it fully on the current screen.
    private func position(near mouse: NSPoint) {
        let size = panel.frame.size
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
        let visible = screen?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        let gap: CGFloat = 12
        let edge: CGFloat = 8

        // Top-left corner starts at the pointer, so the first item lands right
        // under the cursor.
        var x = mouse.x - gap
        var top = mouse.y - gap
        var y = top - size.height

        if y < visible.minY + edge {
            // No room below: open above the pointer instead.
            y = mouse.y + gap
            top = y + size.height
        }

        x = min(max(x, visible.minX + edge), visible.maxX - size.width - edge)
        y = min(max(y, visible.minY + edge), visible.maxY - size.height - edge)

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func screenName() -> String {
        let mid = NSPoint(x: panel.frame.midX, y: panel.frame.midY)
        return NSScreen.screens.first { NSMouseInRect(mid, $0.frame, false) }?.localizedName ?? "?"
    }

    // MARK: - Dismissal

    /// A borderless panel does not close itself the way a popover does, so a
    /// click in any other app dismisses it.
    private func installOutsideClickMonitor() {
        guard outsideClickMonitor == nil else { return }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in self?.hide() }
        }
    }

    private func removeOutsideClickMonitor() {
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
    }

    // MARK: - Testing

    /// Renders the panel's content to a PNG without needing Screen Recording.
    func snapshot(to url: URL) {
        guard let view = panel.contentViewController?.view else { return }
        view.layoutSubtreeIfNeeded()
        let bounds = view.bounds
        guard let rep = view.bitmapImageRepForCachingDisplay(in: bounds) else { return }
        view.cacheDisplay(in: bounds, to: rep)
        if let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: url)
            Diag.log("snapshot \(Int(bounds.width))x\(Int(bounds.height)) -> \(url.lastPathComponent)")
        }
    }
}
