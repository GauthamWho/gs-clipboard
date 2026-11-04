import AppKit
import Combine
import Foundation

/// Checks GitHub Releases for a newer version and installs it in place.
///
/// Privacy: the only network request this app ever makes is a plain GET to
/// GitHub's public release API. It sends no clipboard data, no identifiers,
/// and no analytics. The request is made once per day at most (unless the
/// user presses "Check now").
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    static let repoOwner = "GauthamWho"
    static let repoName = "gs-clipboard"
    static let bundleID = "com.gautham.gsclipboard"
    static let assetName = "GsClipboard.app.zip"

    struct Release {
        let version: String
        let notes: String
        let pageURL: URL
        let downloadURL: URL?
    }

    @Published private(set) var available: Release?
    @Published private(set) var isChecking = false
    @Published private(set) var isInstalling = false
    @Published private(set) var lastMessage: String?

    private var apiURL: URL {
        URL(string: "https://api.github.com/repos/\(Self.repoOwner)/\(Self.repoName)/releases/latest")!
    }

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    var autoCheckEnabled: Bool {
        get {
            let defaults = UserDefaults.standard
            return (defaults.object(forKey: "autoCheckUpdates") as? Bool) ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "autoCheckUpdates")
        }
    }

    private struct GitHubRelease: Decodable {
        struct Asset: Decodable {
            let name: String
            let browser_download_url: String
        }
        let tag_name: String
        let body: String?
        let html_url: String
        let assets: [Asset]
    }

    private enum UpdateError: LocalizedError {
        case badArchive
        case badBundle
        case noPermission
        case downloadFailed(String)

        var errorDescription: String? {
            switch self {
            case .badArchive: return "The downloaded file was not a valid app."
            case .badBundle: return "The downloaded app is not Gautham's Clipboard."
            case .noPermission:
                return "Gautham's Clipboard cannot replace itself in this folder. Please reinstall it with the one-line command from the website."
            case .downloadFailed(let message): return message
            }
        }
    }

    // MARK: - Checking

    func checkIfDue() {
        guard autoCheckEnabled else { return }
        let last = UserDefaults.standard.object(forKey: "lastUpdateCheck") as? Date ?? .distantPast
        guard Date().timeIntervalSince(last) >= 24 * 60 * 60 else { return }
        check()
    }

    func check() {
        guard !isChecking else { return }
        isChecking = true
        lastMessage = nil

        var request = URLRequest(url: apiURL)
        request.timeoutInterval = 15
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("GsClipboard/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }

            func finish(_ body: @escaping () -> Void) {
                DispatchQueue.main.async {
                    self.isChecking = false
                    UserDefaults.standard.set(Date(), forKey: "lastUpdateCheck")
                    body()
                    NSLog("GsClipboard: update check -> \(self.lastMessage ?? "no message")")
                }
            }

            if let error {
                NSLog("GsClipboard: update check failed: \(error.localizedDescription)")
                finish { self.lastMessage = "Could not check for updates" }
                return
            }

            guard let http = response as? HTTPURLResponse else {
                finish { self.lastMessage = "Could not check for updates" }
                return
            }

            // No releases published yet — nothing to do.
            if http.statusCode == 404 {
                finish {
                    self.available = nil
                    self.lastMessage = "You're up to date"
                }
                return
            }

            guard http.statusCode == 200, let data,
                  let release = try? JSONDecoder().decode(GitHubRelease.self, from: data) else {
                finish { self.lastMessage = "Could not check for updates" }
                return
            }

            let remote = release.tag_name
                .replacingOccurrences(of: "v", with: "")
                .trimmingCharacters(in: .whitespaces)
            let asset = release.assets.first { $0.name == Self.assetName }
                ?? release.assets.first { $0.name.hasSuffix(".zip") }

            finish {
                if Self.isNewer(remote, than: self.currentVersion) {
                    self.available = Release(
                        version: remote,
                        notes: release.body ?? "",
                        pageURL: URL(string: release.html_url) ?? self.apiURL,
                        downloadURL: asset.flatMap { URL(string: $0.browser_download_url) }
                    )
                    self.lastMessage = "Update available"
                } else {
                    self.available = nil
                    self.lastMessage = "You're up to date"
                }
            }
        }.resume()
    }

    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let a = candidate.split(separator: ".").map { Int($0.prefix(while: \.isNumber)) ?? 0 }
        let b = current.split(separator: ".").map { Int($0.prefix(while: \.isNumber)) ?? 0 }
        for index in 0..<max(a.count, b.count) {
            let left = index < a.count ? a[index] : 0
            let right = index < b.count ? b[index] : 0
            if left != right { return left > right }
        }
        return false
    }

    // MARK: - Installing

    func installAvailable() {
        guard let release = available, !isInstalling else { return }

        let alert = NSAlert()
        alert.messageText = "Update to Gautham's Clipboard \(release.version)?"
        alert.informativeText = "The app will close, install the new version, and reopen. Your clipboard history stays where it is."
        alert.addButton(withTitle: "Install Update")
        alert.addButton(withTitle: "Later")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        guard let url = release.downloadURL else {
            NSWorkspace.shared.open(release.pageURL)
            return
        }

        isInstalling = true
        URLSession.shared.downloadTask(with: url) { [weak self] location, _, error in
            guard let self else { return }
            guard let location, error == nil else {
                DispatchQueue.main.async {
                    self.isInstalling = false
                    self.presentInstallFailure(error?.localizedDescription ?? "Download failed")
                }
                return
            }
            let zip = FileManager.default.temporaryDirectory
                .appendingPathComponent("GsClipboard-\(release.version).zip")
            try? FileManager.default.removeItem(at: zip)
            do {
                try FileManager.default.moveItem(at: location, to: zip)
            } catch {
                DispatchQueue.main.async {
                    self.isInstalling = false
                    self.presentInstallFailure(error.localizedDescription)
                }
                return
            }
            DispatchQueue.main.async {
                self.applyUpdate(zipURL: zip, destination: nil)
            }
        }.resume()
    }

    /// Unpacks `zipURL`, swaps it in for the running app, and relaunches.
    /// Terminates the current process once the helper script is running.
    func applyUpdate(zipURL: URL, destination: String?) {
        let fm = FileManager.default
        let work = fm.temporaryDirectory
            .appendingPathComponent("GsClipboardUpdate-\(UUID().uuidString)", isDirectory: true)

        do {
            try fm.createDirectory(at: work, withIntermediateDirectories: true)
            let unpack = work.appendingPathComponent("unpack", isDirectory: true)
            try fm.createDirectory(at: unpack, withIntermediateDirectories: true)

            try runProcess("/usr/bin/ditto", ["-x", "-k", zipURL.path, unpack.path])

            guard let appName = try fm.contentsOfDirectory(atPath: unpack.path)
                .first(where: { $0.hasSuffix(".app") }) else {
                throw UpdateError.badArchive
            }
            let source = unpack.appendingPathComponent(appName)
            guard Bundle(url: source)?.bundleIdentifier == Self.bundleID else {
                throw UpdateError.badBundle
            }

            let target = destination ?? Bundle.main.bundlePath
            let parent = (target as NSString).deletingLastPathComponent
            guard fm.isWritableFile(atPath: parent) else { throw UpdateError.noPermission }

            let log = work.appendingPathComponent("install.log")
            let backup = work.appendingPathComponent("previous.app")
            let script = work.appendingPathComponent("install.sh")

            let scriptText = """
            #!/bin/bash
            exec >>\(shellQuote(log.path)) 2>&1
            echo "=== update started $(date) ==="
            APP_PID=\(ProcessInfo.processInfo.processIdentifier)
            while kill -0 "$APP_PID" 2>/dev/null; do sleep 0.4; done

            SRC=\(shellQuote(source.path))
            DEST=\(shellQuote(target))
            BACKUP=\(shellQuote(backup.path))

            rm -rf "$BACKUP"
            cp -R "$DEST" "$BACKUP" 2>/dev/null || true
            rm -rf "$DEST"

            if cp -R "$SRC" "$DEST"; then
                xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true
                echo "installed $(date)"
                open "$DEST"
            else
                echo "install failed; restoring previous version"
                rm -rf "$DEST"
                [ -d "$BACKUP" ] && cp -R "$BACKUP" "$DEST"
                open "$DEST"
            fi
            """

            try scriptText.write(to: script, atomically: true, encoding: .utf8)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)

            let helper = Process()
            helper.executableURL = URL(fileURLWithPath: "/bin/bash")
            helper.arguments = [script.path]
            try helper.run()

            NSLog("GsClipboard: update staged, relaunching")
            NSApp.terminate(nil)
        } catch {
            isInstalling = false
            presentInstallFailure(error.localizedDescription)
        }
    }

    private func presentInstallFailure(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Could not install the update"
        alert.informativeText = message
        alert.addButton(withTitle: "Open Download Page")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn,
           let release = available {
            NSWorkspace.shared.open(release.pageURL)
        }
    }

    private func runProcess(_ path: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw UpdateError.badArchive }
    }

    private func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
