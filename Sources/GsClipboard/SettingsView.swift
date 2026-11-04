import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("maxItems") private var maxItems: Int = 0
    @AppStorage("autoCheckUpdates") private var autoCheckUpdates: Bool = true
    @State private var launchAtLogin: Bool = (SMAppService.mainApp.status == .enabled)
    @ObservedObject private var updates = UpdateChecker.shared
    @AppStorage("pasteAfterPick") private var pasteAfterPick: Bool = true
    @AppStorage("smartCleanup") private var smartCleanup: Bool = true
    @State private var storage = "…"
    @State private var trusted = Paster.isTrusted
    private let tick = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    private let blue = Color(red: 0.10, green: 0.42, blue: 0.98)

    var body: some View {
        Form {
            Section {
                Toggle("Paste into the app I was using", isOn: $pasteAfterPick)
                Text("Picks are typed where your cursor was. Needs Accessibility.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Label(trusted ? "Allowed" : "Not allowed yet",
                          systemImage: trusted ? "checkmark.circle.fill" : "exclamationmark.circle")
                        .foregroundStyle(trusted ? Color.green : Color.orange)
                    Spacer()
                    if !trusted {
                        Button("Open Settings") { Paster.openAccessibilitySettings() }
                    }
                }
                .font(.callout)
            } header: {
                Text("Paste")
            }

            Section {
                HStack {
                    Text("Maximum history items")
                    Spacer()
                    TextField("0", value: $maxItems, format: .number)
                        .frame(width: 90)
                        .multilineTextAlignment(.trailing)
                }
                Text("0 means unlimited. Pinned items are never removed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Smart cleanup", isOn: $smartCleanup)
                Text("Unused screenshots go after 10 days, text after 45; anything you paste again stays much longer. One-time codes go after 20 minutes. Password-manager copies are never saved. Old screenshots are shrunk to HEIC.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Stored only in ~/Library/Application Support/Gautham's Clipboard · \(storage) of images · kept out of Time Machine and Spotlight")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text("History")
            }

            Section {
                Toggle("Open at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        updateLoginItem(newValue)
                    }
                Toggle("Automatically check for updates", isOn: $autoCheckUpdates)
            } header: {
                Text("General")
            }

            Section {
                HStack {
                    Button(updates.isChecking ? "Checking…" : "Check now") {
                        updates.check()
                    }
                    .disabled(updates.isChecking)

                    Spacer()

                    if let version = updates.available?.version {
                        Button("Install \(version)") {
                            updates.installAvailable()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                if let message = updates.lastMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("Version \(updates.currentVersion) · Only a version number is fetched from GitHub. No personal data is sent.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } header: {
                Text("Updates")
            }

            Section {
                HStack(spacing: 12) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Gautham's Clipboard")
                            .font(.system(.body, design: .rounded).weight(.semibold))
                        Text("by GauthamWho")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                Link("Instagram — @gautamwho", destination: URL(string: "https://instagram.com/gautamwho")!)
                Link("GitHub — GauthamWho/gs-clipboard", destination: URL(string: "https://github.com/GauthamWho/gs-clipboard")!)
                Link("License — free personal use", destination: URL(string: "https://github.com/GauthamWho/gs-clipboard/blob/main/LICENSE")!)

                Text("Everything stays on this Mac. Your clipboard history is never uploaded or shared.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("© 2026 GauthamWho. All rights reserved.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } header: {
                Text("About")
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 820)
        .onReceive(tick) { _ in trusted = Paster.isTrusted }
        .onAppear {
            trusted = Paster.isTrusted
            storage = ByteCountFormatter.string(fromByteCount: Int64(SettingsView.imageBytes()), countStyle: .file)
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
        }
    }

    static func imageBytes() -> Int {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Gautham's Clipboard/blobs")
        let files = (try? FileManager.default.contentsOfDirectory(at: base, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        return files.reduce(0) { $0 + ((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
    }

    private func updateLoginItem(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("GsClipboard: login item error \(error)")
        }
    }
}
