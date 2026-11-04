// Gautham's Clipboard by GauthamWho. Copyright © 2026 GauthamWho. All rights reserved. See LICENSE.
import AppKit
import ApplicationServices

/// Types the pick into the app you were using, like every Mac clipboard manager:
/// put it on the clipboard, hand focus back, then press ⌘V for you.
///
/// Pressing keys in another app needs the Accessibility permission. The app never turns
/// it on itself; it only opens the right Settings page so you can.
@MainActor
enum Paster {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// User setting, on by default.
    static var enabled: Bool {
        get { UserDefaults.standard.object(forKey: "pasteAfterPick") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "pasteAfterPick") }
    }

    /// Whether a pick will really be pasted (setting on and permission given).
    static var willPaste: Bool { enabled && isTrusted }

    static func openAccessibilitySettings() {
        // Registers the app in the Accessibility list (switched off) so it is there to tick.
        _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary)
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    /// Waits until `app` is frontmost again (max ~0.6 s), then sends ⌘V.
    static func paste(into app: NSRunningApplication?) {
        guard isTrusted else { Diag.log("paste skipped: Accessibility not allowed"); return }
        var tries = 0
        func attempt() {
            let front = NSWorkspace.shared.frontmostApplication
            let ready = app == nil || front?.processIdentifier == app?.processIdentifier
            if !ready && tries >= 12 {
                // Never press ⌘V in some other app; the pick stays on the clipboard.
                Diag.log("paste skipped: \(app?.localizedName ?? "?") did not come back to the front"); return
            }
            if ready {
                // A short beat so the target window has focused its text field again.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    sendCommandV()
                    Diag.log("pasted into \(front?.localizedName ?? "?") after \(tries) waits")
                }
                return
            }
            tries += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { attempt() }
        }
        attempt()
    }

    /// Types text straight into the app you were using, without touching the clipboard.
    static func type(_ text: String, into app: NSRunningApplication?) {
        guard isTrusted else { return }
        var tries = 0
        func attempt() {
            let ready = app == nil || NSWorkspace.shared.frontmostApplication?.processIdentifier == app?.processIdentifier
            if !ready && tries >= 12 { return }
            if ready {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    let src = CGEventSource(stateID: .combinedSessionState)
                    let units = Array(text.utf16)
                    for (down, ev) in [(true, CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: true)),
                                       (false, CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: false))] {
                        ev?.flags = []
                        units.withUnsafeBufferPointer { ev?.keyboardSetUnicodeString(stringLength: down ? units.count : 0, unicodeString: $0.baseAddress) }
                        ev?.post(tap: .cgAnnotatedSessionEventTap)
                    }
                }
                return
            }
            tries += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { attempt() }
        }
        attempt()
    }

    private static func sendCommandV() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let v: CGKeyCode = 9 // kVK_ANSI_V
        let down = CGEvent(keyboardEventSource: src, virtualKey: v, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: v, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cgAnnotatedSessionEventTap)
        up?.post(tap: .cgAnnotatedSessionEventTap)
    }
}
