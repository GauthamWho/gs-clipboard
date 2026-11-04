// Gautham's Clipboard by GauthamWho. Copyright © 2026 GauthamWho. All rights reserved. See LICENSE.
import AppKit
import ImageIO

/// Downscaled images for the list (thumbnails) and the hover preview, decoded once with
/// ImageIO so scrolling a long history of big screenshots stays smooth.
@MainActor
final class ThumbnailCache {
    static let shared = ThumbnailCache()

    private let cache = NSCache<NSString, NSImage>()
    private var sizes: [URL: CGSize] = [:]

    private init() { cache.countLimit = 300 }

    /// `maxPixel` is the longest side in pixels (points × 2 for Retina).
    func image(for url: URL, maxPixel: Int = 260) -> NSImage? {
        let key = "\(url.path)#\(maxPixel)" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        let img = NSImage(cgImage: cg, size: NSSize(width: CGFloat(cg.width) / 2, height: CGFloat(cg.height) / 2))
        cache.setObject(img, forKey: key)
        return img
    }

    /// Full pixel size of the stored image.
    func pixelSize(for url: URL) -> CGSize? {
        if let s = sizes[url] { return s }
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int, let h = props[kCGImagePropertyPixelHeight] as? Int else { return nil }
        let s = CGSize(width: w, height: h)
        sizes[url] = s
        return s
    }
}
