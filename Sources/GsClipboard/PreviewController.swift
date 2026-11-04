// Gautham's Clipboard by GauthamWho. Copyright © 2026 GauthamWho. All rights reserved. See LICENSE.
import AppKit
import Combine
import SwiftUI

/// The large image preview that opens beside the panel when an image row is hovered or
/// selected with the arrow keys. Never takes focus or clicks.
@MainActor
final class PreviewController {
    private let window: NSPanel
    private let hosting: NSHostingView<PreviewCard>
    private let state: PanelState
    private let panel: PanelController
    private var bag: Set<AnyCancellable> = []
    private var shownID: UUID?

    init(state: PanelState, panel: PanelController) {
        self.state = state
        self.panel = panel
        hosting = NSHostingView(rootView: PreviewCard(model: nil))
        window = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        window.contentView = makeGlassHost(hosting, cornerRadius: DS.Radius.preview)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .transient]
        window.animationBehavior = .none

        // Short dwell so skimming the list doesn't flash previews.
        state.$selectedID
            .removeDuplicates()
            .handleEvents(receiveOutput: { [weak self] id in if id != self?.shownID { self?.fadeOut() } })
            .debounce(for: .milliseconds(260), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.update() }
            .store(in: &bag)
    }

    func hide() { shownID = nil; window.orderOut(nil) }

    private func fadeOut() {
        guard window.isVisible else { return }
        shownID = nil
        NSAnimationContext.runAnimationGroup({ $0.duration = 0.12; window.animator().alphaValue = 0 },
                                             completionHandler: { [weak self] in
            MainActor.assumeIsolated { if self?.shownID == nil { self?.window.orderOut(nil) } }
        })
    }

    private func update() {
        guard panel.isVisible, let id = state.selectedID,
              let item = state.visible.first(where: { $0.id == id }), item.kind == .image,
              let name = item.blobName, let row = state.rowFrames[id] else { return }
        let url = state.model.store.blobsDir.appendingPathComponent(name)
        guard let image = ThumbnailCache.shared.image(for: url, maxPixel: Int(DS.Size.previewMax.width * 2)) else { return }
        let px = ThumbnailCache.shared.pixelSize(for: url) ?? image.size

        // Fit the image in the max box, never upscaled past its own size.
        let maxW = DS.Size.previewMax.width, maxH = DS.Size.previewMax.height
        let scale = min(maxW / image.size.width, maxH / image.size.height, 1)
        let imgSize = CGSize(width: max(340, image.size.width * scale), height: max(120, image.size.height * scale))
        let size = CGSize(width: imgSize.width + 20, height: imgSize.height + 20 + 26)

        hosting.rootView = PreviewCard(model: .init(image: image, imageSize: imgSize,
                                                    caption: "\(Int(px.width)) × \(Int(px.height))"
                                                        + (item.sourceApp.map { " · \($0)" } ?? "") + " · " + Fmt.agoLong(item.createdAt)))

        // Beside the panel (right if it fits, else left), centred on the row, kept on screen.
        let p = panel.frame
        let rowScreen = panel.screenRect(fromPanel: row)
        let screen = NSScreen.screens.first { $0.frame.intersects(p) }?.visibleFrame ?? p
        let gap: CGFloat = 10
        var x = p.maxX + gap
        if x + size.width > screen.maxX - 8 { x = p.minX - gap - size.width }
        x = max(screen.minX + 8, x)
        var y = rowScreen.midY - size.height / 2
        y = min(max(y, screen.minY + 8), screen.maxY - size.height - 8)
        // Never reach past the panel's edge that faces your text line, so the line stays visible.
        if panel.opensBelow { y = min(y, p.maxY - size.height) } else { y = max(y, p.minY) }
        let target = NSRect(x: x, y: y, width: size.width, height: size.height)

        shownID = id
        let wasVisible = window.isVisible && window.alphaValue > 0.5
        if !wasVisible {
            // Grow in from slightly smaller, anchored toward the panel.
            let from = target.insetBy(dx: size.width * 0.03, dy: size.height * 0.03)
            window.setFrame(from, display: false)
            window.alphaValue = 0
            window.orderFront(nil)
        }
        window.invalidateShadow()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = wasVisible ? 0.18 : 0.22
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1.05)
            window.animator().setFrame(target, display: true)
            window.animator().alphaValue = 1
        }
    }
}

struct PreviewCard: View {
    struct Model {
        let image: NSImage
        let imageSize: CGSize
        let caption: String
    }
    let model: Model?

    var body: some View {
        if let model {
            VStack(spacing: 0) {
                Image(nsImage: model.image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: model.imageSize.width, height: model.imageSize.height)
                    .background(Color.white.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(DS.Palette.separator, lineWidth: 0.5))
                HStack {
                    Text(model.caption).lineLimit(1)
                    Spacer(minLength: DS.Space.s)
                    Text(Paster.willPaste ? "↩ Paste · ⌥↩ Copy" : "↩ Copy").foregroundStyle(DS.Palette.meta)
                }
                .font(DS.Text.meta)
                .foregroundStyle(DS.Palette.secondary)
                .padding(.horizontal, 4)
                .frame(height: 26)
            }
            .padding([.horizontal, .top], 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else {
            Color.clear
        }
    }
}
