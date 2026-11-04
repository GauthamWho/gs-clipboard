import SwiftUI

struct AboutView: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    private let blue = Color(red: 0.10, green: 0.42, blue: 0.98)
    private let deepBlue = Color(red: 0.04, green: 0.22, blue: 0.66)

    var body: some View {
        VStack(spacing: 0) {
            header
            VStack(alignment: .leading, spacing: 14) {
                Text("Version \(version) · Free forever")
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .foregroundStyle(.secondary)

                Text("A free clipboard history for macOS. Copy text or screenshots, press ⌥V, and everything you copied is right there — no account, no subscription.")
                    .font(.system(.body, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                linkRow("Made by", value: "GauthamWho", url: "https://instagram.com/gautamwho")
                linkRow("Instagram", value: "@gautamwho", url: "https://instagram.com/gautamwho")
                linkRow("GitHub", value: "GauthamWho/gs-clipboard", url: "https://github.com/GauthamWho/gs-clipboard")
                linkRow("License", value: "Free personal use", url: "https://github.com/GauthamWho/gs-clipboard/blob/main/LICENSE")

                Divider()

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(blue)
                    Text("Everything stays on this Mac. No clipboard data is uploaded, no account is needed, and nothing is tracked. The only network request is a daily version check against GitHub.")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text("© 2026 GauthamWho. All rights reserved.")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
            .padding(20)
        }
        .frame(width: 440)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        ZStack {
            LinearGradient(colors: [deepBlue, blue],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
            HStack(spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 76, height: 76)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Gautham's Clipboard")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Copy once. Find it forever.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
            }
            .padding(.horizontal, 22)
        }
        .frame(height: 132)
    }

    private func linkRow(_ label: String, value: String, url: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 74, alignment: .leading)
            Link(value, destination: URL(string: url)!)
                .font(.system(.caption, design: .rounded).weight(.medium))
                .foregroundStyle(blue)
        }
    }
}
