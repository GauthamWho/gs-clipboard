// Gautham's Clipboard by GauthamWho. Copyright © 2026 GauthamWho. All rights reserved. See LICENSE.
import AppKit
import ApplicationServices

/// Where the panel should open. It always sits next to this spot and never on top of it.
enum PanelAnchor {
    /// The text cursor (or the line you clicked), in screen coordinates.
    case caret(NSRect)
    /// The menu bar icon: drop down under it like any menu bar app.
    case statusItem(NSRect)
}

/// Finds the text cursor in the app you are typing in. Uses Accessibility (the same permission
/// as paste); without it, the mouse pointer stands in, since you just clicked the field.
@MainActor
enum Caret {
    static func anchor() -> PanelAnchor {
        if Paster.isTrusted, let r = caretRect() { return .caret(r) }
        let m = NSEvent.mouseLocation
        // The clicked line: about one text line tall around the pointer.
        return .caret(NSRect(x: m.x - 2, y: m.y - 10, width: 4, height: 20))
    }

    private static func caretRect() -> NSRect? {
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.15)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let f = focused, CFGetTypeID(f) == AXUIElementGetTypeID() else { return nil }
        let element = f as! AXUIElement

        var range: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &range) == .success, let range {
            var bounds: CFTypeRef?
            if AXUIElementCopyParameterizedAttributeValue(element, kAXBoundsForRangeParameterizedAttribute as CFString, range, &bounds) == .success,
               let b = bounds, CFGetTypeID(b) == AXValueGetTypeID() {
                var rect = CGRect.zero
                if AXValueGetValue(b as! AXValue, .cgRect, &rect), rect.height > 2, rect.height < 200 {
                    return cocoa(rect)
                }
            }
        }
        // No caret bounds (some web and Electron fields): use the field itself if it is a single line.
        var pos: CFTypeRef?, size: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &pos) == .success,
           AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size) == .success,
           let pos, let size {
            var p = CGPoint.zero, s = CGSize.zero
            AXValueGetValue(pos as! AXValue, .cgPoint, &p)
            AXValueGetValue(size as! AXValue, .cgSize, &s)
            if s.height > 2, s.height < 60 {
                // Keep the pointer's x if it is inside the field, so the panel lands where you clicked.
                let m = NSEvent.mouseLocation
                var r = cocoa(CGRect(origin: p, size: s))
                if m.x > r.minX, m.x < r.maxX { r = NSRect(x: m.x - 2, y: r.minY, width: 4, height: r.height) }
                return r
            }
        }
        return nil
    }

    /// Accessibility uses a top-left origin on the main screen; AppKit uses bottom-left.
    private static func cocoa(_ r: CGRect) -> NSRect {
        let h = NSScreen.screens.first?.frame.maxY ?? 0
        return NSRect(x: r.minX, y: h - r.maxY, width: r.width, height: r.height)
    }
}
