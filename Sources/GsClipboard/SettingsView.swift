import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("maxItems") private var maxItems: Int = 0
    @AppStorage("autoCheckUpdates") private var autoCheckUpdates: Bool = true
    @State private var launchAtLogin: Bool = (SMAppService.mainApp.status == .enabled)
    @ObservedObject private var updates = UpdateChecker.shared

    private let blue = Color(red: 0.10, green: 0.42, blue: 0.98)

    var body: some View {
        Form {
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
            } header: {
                Text("History")
            }

            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
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
                        Text("G's Clipboard")
                            .font(.system(.body, design: .rounded).weight(.semibold))
                        Text("by Gautam Who")
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
                Text("© 2026 Gautam Who. All rights reserved.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } header: {
                Text("About")
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 660)
        .onAppear {
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
        }
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
