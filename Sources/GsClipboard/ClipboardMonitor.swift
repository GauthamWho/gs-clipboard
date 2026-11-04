import AppKit

@MainActor
final class ClipboardMonitor {
    private let store: ClipStore
    private var timer: Timer?
    private var lastChangeCount: Int
    var ignoreNextChange = false

    init(store: ClipStore) {
        self.store = store
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    func start() {
        lastChangeCount = NSPasteboard.general.changeCount
        let timer = Timer(timeInterval: 0.4, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        let pasteboard = NSPasteboard.general
        let count = pasteboard.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count
        if ignoreNextChange {
            ignoreNextChange = false
            return
        }
        capture(pasteboard)
    }

    private func capture(_ pasteboard: NSPasteboard) {
        let source = NSWorkspace.shared.frontmostApplication?.localizedName

        if let data = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff),
           let image = NSImage(data: data),
           let png = image.pngData() {
            store.addImage(png: png, source: source)
            return
        }

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self],
                                             options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty {
            store.addFiles(urls, source: source)
            return
        }

        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            store.addText(text, source: source)
        }
    }
}

extension NSImage {
    func pngData() -> Data? {
        guard let tiff = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
