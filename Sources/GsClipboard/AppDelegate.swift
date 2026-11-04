import AppKit
import SwiftUI
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: PanelController!
    private var model: AppModel!
    private let hotKey = HotKeyManager()
    private let updates = UpdateChecker.shared
    private var previousApp: NSRunningApplication?
    private var state: PanelState!
    private var preview: PreviewController!
    private var aboutWindow: NSWindow?
    private var settingsWindow: NSWindow?

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // CLI helpers used by the installer and release tooling.
        BrandAssets.runIfRequested()
        if CommandLine.arguments.contains("--version") {
            print("Gautham's Clipboard \(version)")
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

        #if DEBUG
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
        #endif

        #if DEBUG
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
        #endif

        #if DEBUG
        // Debug helper: install a local zip as an update (used for testing).
        if let flag = CommandLine.arguments.firstIndex(of: "--install-update"),
           flag + 1 < CommandLine.arguments.count {
            let zip = URL(fileURLWithPath: CommandLine.arguments[flag + 1])
            let destination = ProcessInfo.processInfo.environment["GS_UPDATE_DEST"]
            updates.applyUpdate(zipURL: zip, destination: destination)
            return
        }
        #endif

        state = PanelState(model: model)
        state.onPick = { [weak self] item, paste in self?.pick(item, paste: paste) }
        state.onClose = { [weak self] in self?.closePanel() }
        state.onPickEmojiText = { [weak self] text, type in self?.pickEmoji(text, type: type) }
        state.onOpenSettings = { [weak self] in self?.showSettings() }
        panel = PanelController { [unowned self] in
            ContentView(state: self.state, model: self.model, updates: self.updates)
        }
        panel.keyHandler = { [weak self] e in self?.state.handle(e) ?? false }
        panel.onShow = { [weak self] in self?.state.prepareForShow() }
        panel.onMouseMoved = { [weak self] in
            guard let s = self?.state, !s.hoverArmed else { return }
            s.hoverArmed = true
        }
        panel.onHide = { [weak self] in self?.preview.hide() }
        preview = PreviewController(state: state, panel: panel)
        model.startCare { [weak self] in self?.panel.isVisible ?? false }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = MenuBarMark.image()
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "Gautham's Clipboard — ⌥V"
        }

        hotKey.onPressed = { [weak self] in
            self?.togglePanel(from: nil)
        }
        hotKey.register()

        // Check for updates quietly a few seconds after launch (once per day).
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            self?.updates.checkIfDue()
        }

        if CommandLine.arguments.contains("--show") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self else { return }
                self.showPanel(at: .caret(NSRect(x: 900, y: 700, width: 4, height: 20)))
                // Debug: `--show --filter Images` opens on a filter (used for screenshots).
                let args = CommandLine.arguments
                if let i = args.firstIndex(of: "--filter"), i + 1 < args.count,
                   let f = PanelState.Filter(rawValue: args[i + 1]) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        self.state.filter = f
                        self.state.selectedID = self.state.visible.first?.id
                    }
                }
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
            togglePanel(from: statusItem.button)
        }
    }

    private func showStatusMenu() {
        if panel.isVisible { closePanel() }

        let menu = NSMenu()

        let about = NSMenuItem(title: "About Gautham's Clipboard", action: #selector(showAbout), keyEquivalent: "")
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

        let quit = NSMenuItem(title: "Quit Gautham's Clipboard", action: #selector(quitFromMenu), keyEquivalent: "q")
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
            window.title = "About Gautham's Clipboard"
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
            window.title = "Gautham's Clipboard Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSLog("GsClipboard: settings window shown")
    }

    // MARK: - Panel

    /// Menu bar icon: drop down under it. Shortcut: open right next to your text cursor.
    private func togglePanel(from button: NSStatusBarButton?) {
        if panel.isVisible { closePanel(); return }
        // Find the caret before we take focus, while your app still has it.
        if let button, let window = button.window {
            showPanel(at: .statusItem(window.convertToScreen(button.convert(button.bounds, to: nil))))
        } else {
            showPanel(at: Caret.anchor())
        }
    }

    private func showPanel(at anchor: PanelAnchor) {
        if !panel.isVisible {
            previousApp = NSWorkspace.shared.frontmostApplication
        }
        panel.show(at: anchor)
    }

    private func closePanel() {
        panel.hide()
        restorePreviousApp()
    }

    /// Puts the item on the clipboard, closes the panel, hands focus back to the app you were
    /// in, then (if allowed) presses ⌘V there so it lands where your cursor was.
    private func pick(_ item: ClipItem, paste: Bool) {
        model.copy(item)
        let target = previousApp
        closePanel()
        Diag.log("picked \(item.kind.rawValue) paste=\(paste) trusted=\(Paster.isTrusted) target=\(target?.localizedName ?? "?")")
        if paste && Paster.enabled { Paster.paste(into: target) }
    }

    /// Emoji are typed directly (the clipboard keeps what you had). Without Accessibility,
    /// or with ⌥↩, the emoji is copied instead.
    private func pickEmoji(_ text: String, type: Bool) {
        let target = previousApp
        closePanel()
        if type && Paster.enabled && Paster.isTrusted {
            Paster.type(text, into: target)
        } else {
            model.monitor.ignoreNextChange = true
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
    }

    /// Hands focus back so the paste lands in whatever app you were using.
    private func restorePreviousApp() {
        guard let previousApp, previousApp.bundleIdentifier != Bundle.main.bundleIdentifier, !previousApp.isTerminated else { return }
        if #available(macOS 14.0, *) { NSApp.yieldActivation(to: previousApp) }
        previousApp.activate(options: [])
    }
}
