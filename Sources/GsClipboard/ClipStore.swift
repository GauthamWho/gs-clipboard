import AppKit
import Combine
import CryptoKit
import ImageIO

enum ClipKind: String, Codable {
    case text
    case image
    case file
}

struct ClipItem: Identifiable, Codable, Equatable {
    var id: UUID
    var kind: ClipKind
    var text: String?
    var preview: String
    var blobName: String?
    var hash: String
    var createdAt: Date
    var pinned: Bool
    var sourceApp: String?
    /// How often it was pasted again, and when. Drives smart cleanup.
    var useCount: Int?
    var lastUsed: Date?
}

@MainActor
final class ClipStore: ObservableObject {
    @Published private(set) var items: [ClipItem] = []

    let supportDir: URL
    let blobsDir: URL
    private let indexURL: URL
    private let saveQueue = DispatchQueue(label: "com.gautham.clipvault.save", qos: .utility)

    /// 0 = unlimited
    var maxItems: Int {
        get { UserDefaults.standard.integer(forKey: "maxItems") }
        set {
            UserDefaults.standard.set(newValue, forKey: "maxItems")
            trim()
            save()
        }
    }

    init() {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        supportDir = base.appendingPathComponent("Gautham's Clipboard", isDirectory: true)
        // Keep history from the old "G's Clipboard" name.
        let legacy = base.appendingPathComponent("G's Clipboard", isDirectory: true)
        if !fm.fileExists(atPath: supportDir.path), fm.fileExists(atPath: legacy.path) {
            try? fm.moveItem(at: legacy, to: supportDir)
        }
        blobsDir = supportDir.appendingPathComponent("blobs", isDirectory: true)
        indexURL = supportDir.appendingPathComponent("index.json")
        try? fm.createDirectory(at: blobsDir, withIntermediateDirectories: true)
        Self.keepOutOfTheWay(supportDir)
        load()
    }

    private func load() {
        guard let data = try? Data(contentsOf: indexURL),
              let decoded = try? JSONDecoder().decode([ClipItem].self, from: data) else {
            return
        }
        items = decoded.sorted(by: sortComparator)
    }

    func save() {
        let snapshot = items
        let url = indexURL
        saveQueue.async {
            do {
                let data = try JSONEncoder().encode(snapshot)
                try data.write(to: url, options: [.atomic])
            } catch {
                NSLog("GsClipboard: failed to save history: \(error)")
            }
        }
    }

    func addText(_ text: String, source: String?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        insert(kind: .text,
               text: text,
               preview: Self.makePreview(text),
               blobName: nil,
               hash: Self.sha256(Data(text.utf8)),
               source: source)
    }

    func addImage(png: Data, source: String?) {
        guard let image = NSImage(data: png) else { return }
        let hash = Self.sha256(png)
        let name = "\(UUID().uuidString).png"
        do {
            try png.write(to: blobsDir.appendingPathComponent(name))
        } catch {
            NSLog("GsClipboard: failed to write image: \(error)")
            return
        }
        let size = image.size
        insert(kind: .image,
               text: nil,
               preview: "Image \(Int(size.width))×\(Int(size.height))",
               blobName: name,
               hash: hash,
               source: source)
    }

    func addFiles(_ urls: [URL], source: String?) {
        guard !urls.isEmpty else { return }
        let text = urls.map(\.path).joined(separator: "\n")
        let preview = urls.count == 1 ? urls[0].lastPathComponent : "\(urls.count) files"
        insert(kind: .file,
               text: text,
               preview: preview,
               blobName: nil,
               hash: Self.sha256(Data(text.utf8)),
               source: source)
    }

    private func insert(kind: ClipKind, text: String?, preview: String, blobName: String?, hash: String, source: String?) {
        if let index = items.firstIndex(where: { $0.hash == hash }) {
            var existing = items.remove(at: index)
            existing.createdAt = Date()
            if let source { existing.sourceApp = source }
            items.append(existing)
        } else {
            items.append(ClipItem(id: UUID(),
                                  kind: kind,
                                  text: text,
                                  preview: preview,
                                  blobName: blobName,
                                  hash: hash,
                                  createdAt: Date(),
                                  pinned: false,
                                  sourceApp: source))
        }
        trim()
        items.sort(by: sortComparator)
        save()
    }

    /// Called when an item is pasted again: it moves to the top and lives longer.
    func markUsed(_ item: ClipItem) {
        guard let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[i].useCount = (items[i].useCount ?? 0) + 1
        items[i].lastUsed = Date()
        items[i].createdAt = Date()
        items.sort(by: sortComparator)
        save()
    }

    func togglePin(_ item: ClipItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].pinned.toggle()
        items.sort(by: sortComparator)
        save()
    }

    func delete(_ item: ClipItem) {
        items.removeAll { $0.id == item.id }
        removeBlob(item)
        save()
    }

    func clearAll(keepPinned: Bool = true) {
        if keepPinned {
            let toRemove = items.filter { !$0.pinned }
            toRemove.forEach(removeBlob)
            items.removeAll { !$0.pinned }
        } else {
            items.forEach(removeBlob)
            items.removeAll()
        }
        save()
    }

    func copyToPasteboard(_ item: ClipItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch item.kind {
        case .text:
            pb.setString(item.text ?? "", forType: .string)
        case .file:
            guard let text = item.text else { return }
            let urls = text.split(separator: "\n").map { URL(fileURLWithPath: String($0)) }
            pb.writeObjects(urls as [NSURL])
        case .image:
            guard let name = item.blobName,
                  let data = try? Data(contentsOf: blobsDir.appendingPathComponent(name)),
                  let image = NSImage(data: data) else { return }
            pb.writeObjects([image])
        }
    }

    private func trim() {
        let limit = maxItems
        guard limit > 0 else { return }
        let unpinned = items.filter { !$0.pinned }
        guard unpinned.count > limit else { return }
        let overflow = unpinned.count - limit
        let toRemove = unpinned.sorted(by: sortComparator).suffix(overflow)
        let ids = Set(toRemove.map(\.id))
        toRemove.forEach(removeBlob)
        items.removeAll { ids.contains($0.id) }
    }

    // MARK: - Smart care

    /// History lives only in ~/Library/Application Support/Gautham's Clipboard. It is kept out of
    /// Time Machine and Spotlight so it never bloats backups or shows up in searches.
    private static func keepOutOfTheWay(_ dir: URL) {
        var url = dir
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
        let marker = dir.appendingPathComponent(".metadata_never_index")
        if !FileManager.default.fileExists(atPath: marker.path) {
            FileManager.default.createFile(atPath: marker.path, contents: nil)
        }
    }

    static var smartCleanup: Bool {
        get { UserDefaults.standard.object(forKey: "smartCleanup") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "smartCleanup") }
    }

    /// How long an item stays when you never come back to it. Every paste-again buys more time.
    /// Pinned items always stay.
    static func lifetime(of item: ClipItem) -> TimeInterval {
        let day: TimeInterval = 86_400
        let uses = Double(item.useCount ?? 0)
        if item.kind == .text, let t = item.text, isOneTimeCode(t) { return 20 * 60 }
        let base: TimeInterval = item.kind == .image ? 10 * day : 45 * day
        return base * (1 + uses * 2)
    }

    /// "483 920", "G-519302": codes that are useless minutes later.
    static func isOneTimeCode(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count <= 12 else { return false }
        let digits = t.filter(\.isNumber)
        let rest = t.filter { !$0.isNumber && $0 != " " && $0 != "-" }
        return (5...8).contains(digits.count) && rest.count <= 2 && !t.contains(".") && !t.contains(":")
    }

    /// Removes what you are not going to use again, then shrinks old screenshots.
    /// Runs at launch and every hour, quietly, never while you are looking at the panel.
    func cleanUp() {
        guard Self.smartCleanup else { return }
        let now = Date()
        let expired = items.filter { !$0.pinned && now.timeIntervalSince($0.lastUsed ?? $0.createdAt) > Self.lifetime(of: $0) }
        if !expired.isEmpty {
            let ids = Set(expired.map(\.id))
            expired.forEach(removeBlob)
            items.removeAll { ids.contains($0.id) }
            Diag.log("cleanup removed \(expired.count) unused item(s)")
        }
        // Storage ceiling: if images pass 1.5 GB, the oldest unused images go first.
        var bytes = imageBytes()
        if bytes > 1_500_000_000 {
            for item in items.reversed() where item.kind == .image && !item.pinned && (item.useCount ?? 0) == 0 {
                guard bytes > 1_200_000_000 else { break }
                bytes -= blobSize(item)
                removeBlob(item)
                items.removeAll { $0.id == item.id }
            }
        }
        compactOldImages()
        save()
    }

    /// Screenshots older than two days are re-saved as high-quality HEIC (about a tenth of the
    /// size, same look). Recent and pinned ones keep their original pixels.
    private func compactOldImages() {
        let cutoff = Date().addingTimeInterval(-2 * 86_400)
        for i in items.indices where items[i].kind == .image && !items[i].pinned && items[i].createdAt < cutoff {
            guard let name = items[i].blobName, name.hasSuffix(".png") else { continue }
            let src = blobsDir.appendingPathComponent(name)
            let heicName = name.replacingOccurrences(of: ".png", with: ".heic")
            let dst = blobsDir.appendingPathComponent(heicName)
            guard let source = CGImageSourceCreateWithURL(src as CFURL, nil),
                  let cg = CGImageSourceCreateImageAtIndex(source, 0, nil),
                  let dest = CGImageDestinationCreateWithURL(dst as CFURL, "public.heic" as CFString, 1, nil) else { continue }
            CGImageDestinationAddImage(dest, cg, [kCGImageDestinationLossyCompressionQuality: 0.86] as CFDictionary)
            guard CGImageDestinationFinalize(dest) else { try? FileManager.default.removeItem(at: dst); continue }
            items[i].blobName = heicName
            try? FileManager.default.removeItem(at: src)
        }
    }

    func imageBytes() -> Int { items.filter { $0.kind == .image }.reduce(0) { $0 + blobSize($1) } }

    private func blobSize(_ item: ClipItem) -> Int {
        guard let name = item.blobName,
              let size = try? blobsDir.appendingPathComponent(name).resourceValues(forKeys: [.fileSizeKey]).fileSize else { return 0 }
        return size
    }

    private func removeBlob(_ item: ClipItem) {
        guard let name = item.blobName else { return }
        try? FileManager.default.removeItem(at: blobsDir.appendingPathComponent(name))
    }

    private func sortComparator(_ lhs: ClipItem, _ rhs: ClipItem) -> Bool {
        if lhs.pinned != rhs.pinned { return lhs.pinned }
        return lhs.createdAt > rhs.createdAt
    }

    private static func makePreview(_ text: String) -> String {
        let single = text.replacingOccurrences(of: "\n", with: " ")
        return String(single.prefix(200))
    }

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
