import AppKit
import Combine
import CryptoKit

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
        supportDir = base.appendingPathComponent("G's Clipboard", isDirectory: true)
        blobsDir = supportDir.appendingPathComponent("blobs", isDirectory: true)
        indexURL = supportDir.appendingPathComponent("index.json")
        try? fm.createDirectory(at: blobsDir, withIntermediateDirectories: true)
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
