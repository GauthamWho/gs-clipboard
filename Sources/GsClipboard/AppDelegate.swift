import AppKit
import SwiftUI
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var model: AppModel!
    private let hotKey = HotKeyManager()
    private let updates = UpdateChecker.shared
    private var previousApp: NSRunningApplication?
    private var aboutWindow: NSWindow?
    private var settingsWindow: NSWindow?

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // CLI helpers used by the installer and release tooling.
        if CommandLine.arguments.contains("--version") {
            print("G's Clipboard \(version)")
            NSApp.terminate(nil)
            return
        }

        if CommandLine.arguments.contains("--register-login") {
            do {
                try SMAppService.mainApp.register()
                NSLog("GsClipboard: login item registered")
            } catch {
                NSLog("GsClipboard: register login item failed: \(error)")
            }
            NSApp.terminate(nil)
            return
        }

        if CommandLine.arguments.contains("--unregister-login") {
            do {
                try SMAppService.mainApp.unregister()
                NSLog("GsClipboard: login item unregistered")
            } catch {
                NSLog("GsClipboard: unregister login item failed: \(error)")
            }
            NSApp.terminate(nil)
            return
        }

        NSApp.setActivationPolicy(.accessory)

        // Single-instance guard: if another copy is already running, hand over and quit.
        let bundleID = Bundle.main.bundleIdentifier ?? UpdateChecker.bundleID
        let others = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleID)
            .filter { $0 != NSRunningApplication.current }
        if let other = others.first {
            other.activate(options: [])
            NSApp.terminate(nil)
            return
        }

        model = AppModel()
        configureLoginItemIfNeeded()

        // Debug helper: copy the newest item back to the pasteboard and report
        // what landed there, then exit. Used to verify text and image restore.
        if CommandLine.arguments.contains("--selftest") {
            if let item = model.store.items.first {
                model.copy(item)
                let pb = NSPasteboard.general
                let types = pb.types?.map(\.rawValue).joined(separator: ",") ?? "none"
                Diag.log("selftest kind=\(item.kind.rawValue) types=\(types)")
            } else {
                Diag.log("selftest no items")
            }
            NSApp.terminate(nil)
            return
        }

        // Debug helper: print the newest history items and exit. Used to confirm
        // that a copy really was captured.
        if CommandLine.arguments.contains("--dump") {
            Diag.log("dump: \(model.store.items.count) items")
            for item in model.store.items.prefix(10) {
                print("[\(item.kind.rawValue)] \(item.preview)")
            }
            NSApp.terminate(nil)
            return
        }

        // Debug helper: install a local zip as an update (used for testing).
        if let flag = CommandLine.arguments.firstIndex(of: "--install-update"),
           flag + 1 < CommandLine.arguments.count {
            let zip = URL(fileURLWithPath: CommandLine.arguments[flag + 1])
            let destination = ProcessInfo.processInfo.environment["GS_UPDATE_DEST"]
            updates.applyUpdate(zipURL: zip, destination: destination)
            return
        }

        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 400, height: 520)
        popover.contentViewController = NSHostingController(
            rootView: ContentView(
                model: model,
                updates: updates,
                onClose: { [weak self] in self?.closePopover() },
                onOpenSettings: { [weak self] in self?.showSettings() }
            )
        )

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard",
                                   accessibilityDescription: "G's Clipboard")
            button.image?.isTemplate = true
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "G's Clipboard — ⌥V"
        }

        hotKey.onPressed = { [weak self] in
            self?.togglePopover(nil)
        }
        hotKey.register()

        // Check for updates quietly a few seconds after launch (once per day).
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            self?.updates.checkIfDue()
        }

        if CommandLine.arguments.contains("--show") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showPopover()
            }
        }

        if CommandLine.arguments.contains("--show-about") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showAbout()
            }
        }

        if CommandLine.arguments.contains("--show-settings") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showSettings()
            }
        }
    }

    // MARK: - Login item

    /// First launch: turn on "launch at login" automatically, once.
    private func configureLoginItemIfNeeded() {
        guard Bundle.main.bundlePath.hasPrefix("/Applications/") else { return }
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: "didSetupLoginItem") == nil else { return }
        defaults.set(true, forKey: "didSetupLoginItem")
        guard SMAppService.mainApp.status != .enabled else { return }
        do {
            try SMAppService.mainApp.register()
            NSLog("GsClipboard: first-run login item registered")
        } catch {
            NSLog("GsClipboard: first-run login item failed: \(error)")
        }
    }

    // MARK: - Status item

    @objc private func statusItemClicked(_ sender: Any?) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showStatusMenu()
        } else {
            togglePopover(sender)
        }
    }

    private func showStatusMenu() {
        if popover.isShown { closePopover() }

        let menu = NSMenu()

        let about = NSMenuItem(title: "About G's Clipboard", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        if let version = updates.available?.version {
            let install = NSMenuItem(title: "Install Update \(version)…", action: #selector(installUpdate), keyEquivalent: "")
            install.target = self
            menu.addItem(install)
        } else {
            let check = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
            check.target = self
            menu.addItem(check)
        }

        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettingsFromMenu), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit G's Clipboard", action: #selector(quitFromMenu), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        if let button = statusItem.button {
            menu.popUp(positioning: nil,
                       at: NSPoint(x: 0, y: button.bounds.height + 6),
                       in: button)
        }
    }

    @objc private func checkForUpdates() {
        updates.check()
    }

    @objc private func installUpdate() {
        updates.installAvailable()
    }

    @objc private func openSettingsFromMenu() {
        showSettings()
    }

    @objc private func quitFromMenu() {
        NSApp.terminate(nil)
    }

    // MARK: - Windows

    @objc func showAbout() {
        if aboutWindow == nil {
            let hosting = NSHostingController(rootView: AboutView())
            let window = NSWindow(contentViewController: hosting)
            window.title = "About G's Clipboard"
            window.styleMask = [.titled, .closable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.backgroundColor = .windowBackgroundColor
            aboutWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        aboutWindow?.center()
        aboutWindow?.makeKeyAndOrderFront(nil)
        NSLog("GsClipboard: about window shown")
    }

    private func showSettings() {
        if settingsWindow == nil {
            let hosting = NSHostingController(rootView: SettingsView())
            let window = NSWindow(contentViewController: hosting)
            window.title = "G's Clipboard Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSLog("GsClipboard: settings window shown")
    }

    // MARK: - Popover

    @objc private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        if !popover.isShown {
            previousApp = NSWorkspace.shared.frontmostApplication
        }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .gsClipboardDidShow, object: nil)
        if let window = popover.contentViewController?.view.window {
            window.makeKey()
            Diag.log("popover shown items=\(model.store.items.count) key=\(window.isKeyWindow)")
        }
    }

    private func closePopover() {
        popover.performClose(nil)
        // Hand focus back so the next ⌘V lands in whatever app you were using.
        if let previousApp, previousApp.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApp.activate(options: [])
        }
    }
}
