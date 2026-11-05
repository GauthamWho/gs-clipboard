// Gautham's Clipboard by GauthamWho. Copyright © 2026 GauthamWho. All rights reserved. See LICENSE.
import AppKit
import SwiftUI

/// Click, press the keys you want, done. Esc cancels. Needs fn, ⌃, ⌥ or ⌘; standard shortcuts like ⌘V are refused.
struct ShortcutRecorder: View {
    @ObservedObject private var hotKey = HotKeyManager.shared
    @State private var recording = false
    @State private var monitor: Any?
    @State private var held = ""

    var body: some View {
        HStack(spacing: 8) {
            Button { recording ? stop() : start() } label: {
                Text(recording ? (held.isEmpty ? "Press keys…" : held + "…") : hotKey.display)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .frame(minWidth: 96)
            }
            .buttonStyle(.bordered)
            .tint(recording ? DS.Palette.tint : nil)
            .help(recording ? "Press the new shortcut, or Esc to cancel" : "Click to change the shortcut")
            if Shortcut.current != .defaultValue && !recording {
                Button("Reset to fn V") { hotKey.apply(.defaultValue) }
                    .buttonStyle(.link)
            }
        }
        .onDisappear(perform: stop)
    }

    private func start() {
        recording = true
        held = ""
        hotKey.paused = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { e in
            if e.type == .flagsChanged {
                held = Shortcut(keyCode: 0, command: e.modifierFlags.contains(.command), option: e.modifierFlags.contains(.option),
                                control: e.modifierFlags.contains(.control), shift: e.modifierFlags.contains(.shift),
                                function: e.modifierFlags.contains(.function)).display.dropLast(1).description
                return e
            }
            let s = Shortcut(event: e)
            if Int(e.keyCode) == 53, !s.hasModifier { stop(); return nil } // Esc cancels
            guard s.isAllowed else { NSSound.beep(); return nil }
            hotKey.apply(s)
            stop()
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = false
        held = ""
        hotKey.paused = false
    }
}
