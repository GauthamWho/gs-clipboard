import AppKit

/// Caches downscaled thumbnails so scrolling a long history of large
/// screenshots doesn't re-decode full-resolution images on every frame.
@MainActor
final class ThumbnailCache {
    static let shared = ThumbnailCache()

    private let cache = NSCache<NSURL, NSImage>()

    private init() {
        cache.countLimit = 400
    }

    func image(for url: URL, maxPixel: CGFloat = 176) -> NSImage? {
        let key = url as NSURL
        if let cached = cache.object(forKey: key) { return cached }
        guard let source = NSImage(contentsOf: url) else { return nil }
        let size = source.size
        guard size.width > 0, size.height > 0 else { return nil }

        let factor = min(1, maxPixel / max(size.width, size.height))
        let target = NSSize(width: max(1, size.width * factor),
                            height: max(1, size.height * factor))

        let thumb = NSImage(size: target)
        thumb.lockFocus()
        source.draw(in: NSRect(origin: .zero, size: target),
                    from: NSRect(origin: .zero, size: size),
                    operation: .copy,
                    fraction: 1)
        thumb.unlockFocus()

        cache.setObject(thumb, forKey: key)
        return thumb
    }
}
