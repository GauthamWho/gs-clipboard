import Foundation

/// Tiny local-only diagnostic log.
///
/// Written to `~/Library/Logs/G's Clipboard.log` so problems like "my copy did
/// not show up" can be diagnosed without a debugger. It records clipboard
/// change counts, the kind of item captured, and panel show/hide events.
/// Nothing is ever sent anywhere. Delete the file at any time.
enum Diag {
    private static let queue = DispatchQueue(label: "com.gautham.gsclipboard.diag", qos: .utility)

    static var logURL: URL {
        let base = FileManager.default
            .urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("G's Clipboard.log")
    }

    static func log(_ message: String) {
        NSLog("GsClipboard: %@", message)
        let line = "[\(timestamp())] \(message)\n"
        queue.async {
            let url = logURL
            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                handle.seekToEndOfFile()
                if let data = line.data(using: .utf8) {
                    handle.write(data)
                }
            } else {
                try? line.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter.string(from: Date())
    }
}
