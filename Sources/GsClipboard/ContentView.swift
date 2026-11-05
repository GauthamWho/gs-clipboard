// Gautham's Clipboard by GauthamWho. Copyright © 2026 GauthamWho. All rights reserved. See LICENSE.
import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var state: PanelState
    @ObservedObject var model: AppModel
    @ObservedObject var updates: UpdateChecker
    @ObservedObject private var hotKey = HotKeyManager.shared
    @FocusState private var searchFocused: Bool
    @State private var arrived = false
    @Namespace private var selection
    @Environment(\.accessibilityReduceMotion) private var reduce

    var body: some View { panelBody }

    private var panelBody: some View {
        let items = state.visible
        return VStack(spacing: DS.Space.s) {
            searchBar
            chips
            if state.showPermissionCard { PermissionCard(state: state).transition(.rise) }
            if state.filter == .emoji { EmojiGrid(state: state).frame(maxHeight: .infinity) } else { list(items) }
            footer
        }
        .padding(DS.Space.m)
        .frame(width: DS.Size.panel.width, height: DS.Size.panel.height)
        .animation(Motion.arrive, value: state.showPermissionCard)
        .onReceive(NotificationCenter.default.publisher(for: .gsClipboardDidShow)) { _ in
            arrived = false
            DispatchQueue.main.async {
                withAnimation(reduce ? nil : Motion.arrive) { arrived = true }
                searchFocused = true
            }
        }
        .onChange(of: state.search) { _, _ in state.selectedID = state.visible.first?.id; state.emojiIndex = 0 }
        .onChange(of: state.filter) { _, _ in state.selectedID = state.visible.first?.id }
        .coordinateSpace(name: "panel")
        .onPreferenceChange(RowFrameKey.self) { frames in
            MainActor.assumeIsolated { state.rowFrames = frames }
        }
    }

    // MARK: Search and filters

    private var searchBar: some View {
        HStack(spacing: DS.Space.s) {
            Image(systemName: "magnifyingglass").font(.system(size: 12, weight: .medium)).foregroundStyle(DS.Palette.meta)
            TextField(state.filter == .emoji ? "Search emoji" : "Search your clipboard", text: $state.search)
                .textFieldStyle(.plain)
                .font(DS.Text.search)
                .focused($searchFocused)
            if state.search.isEmpty {
                Text(hotKey.display).font(DS.Text.badge).foregroundStyle(DS.Palette.meta)
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .background(DS.Palette.fill, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            } else {
                Button { state.search = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).foregroundStyle(DS.Palette.meta)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(DS.Palette.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var chips: some View {
        HStack(spacing: DS.Space.xs) {
            ForEach(PanelState.Filter.allCases) { f in
                FilterChip(title: f.rawValue, on: state.filter == f, ns: selection) {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) { state.filter = f }
                }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: List

    @ViewBuilder
    private func list(_ items: [ClipItem]) -> some View {
        if items.isEmpty {
            EmptyState(hasHistory: !model.store.items.isEmpty, query: state.search)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                            ClipRow(item: item, index: i, state: state, selected: state.selectedID == item.id,
                                    blobsDir: model.store.blobsDir, ns: selection)
                                .id(item.id)
                                .opacity(arrived ? 1 : 0)
                                .offset(y: arrived ? 0 : 8)
                                .animation(reduce ? nil : Motion.arrive.delay(min(0.2, Double(i) * 0.025)), value: arrived)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.never)
                .frame(maxHeight: .infinity)
                .onChange(of: state.keyboardMove) { _, _ in
                    if let id = state.selectedID { withAnimation(Motion.quick) { proxy.scrollTo(id, anchor: nil) } }
                }
                .onReceive(NotificationCenter.default.publisher(for: .gsClipboardDidShow)) { _ in
                    if let first = items.first { proxy.scrollTo(first.id, anchor: .top) }
                }
            }
        }
    }

    // MARK: Footer

    private var footerHint: String {
        if state.filter == .emoji {
            let list = state.emojiList
            let raw = list.indices.contains(state.emojiIndex) ? list[state.emojiIndex].name : ""
            let name = raw.prefix(1).uppercased() + raw.dropFirst()
            let verb = Paster.willPaste ? "↩ Type" : "↩ Copy"
            return name.isEmpty ? verb : "\(name) · \(verb)"
        }
        return Paster.willPaste ? "↩ Paste · ⌥↩ Copy · ⌘1–9 · ⌘E Emoji" : "↩ Copy · ⌘1–9 · ⌘E Emoji"
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Rectangle().fill(DS.Palette.separator).frame(height: 0.5)
            HStack(spacing: DS.Space.s) {
                Text(footerHint)
                    .font(DS.Text.meta).foregroundStyle(DS.Palette.meta).lineLimit(1)
                Spacer()
                if let version = updates.available?.version {
                    Button { updates.installAvailable() } label: {
                        Text("Update \(version)").font(DS.Text.chip)
                    }
                    .buttonStyle(.plain).foregroundStyle(DS.Palette.tint)
                }
                Text("\(model.store.items.count) items").font(DS.Text.meta).foregroundStyle(DS.Palette.meta)
                Menu {
                    Button("Settings…") { state.onClose(); state.onOpenSettings() }
                    Button("Clear history (keeps pins)") { model.store.clearAll() }
                    Divider()
                    Button("Quit \(Brand.name)") { NSApp.terminate(nil) }
                } label: {
                    Image(systemName: "gearshape").font(.system(size: 11, weight: .medium))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .foregroundStyle(DS.Palette.secondary)
                .magnetic(pull: 2, grow: 1.1)
            }
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - Row

struct RowFrameKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

struct ClipRow: View {
    let item: ClipItem
    let index: Int
    @ObservedObject var state: PanelState
    let selected: Bool
    let blobsDir: URL
    let ns: Namespace.ID
    @State private var hovering = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            leading
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(item.kind == .image ? DS.Text.name : DS.Text.row)
                    .foregroundStyle(DS.Palette.label)
                    .lineLimit(item.kind == .text ? 2 : 1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let dims { Text(dims).font(DS.Text.meta).foregroundStyle(DS.Palette.secondary) }
                HStack(spacing: 4) {
                    if item.pinned { Image(systemName: "pin.fill").font(.system(size: 8.5)).foregroundStyle(DS.Palette.pin) }
                    Text(meta).lineLimit(1)
                }
                .font(DS.Text.meta).foregroundStyle(DS.Palette.secondary)
            }
            trailing
        }
        .padding(.horizontal, 10)
        .padding(.vertical, item.kind == .image ? 7 : 8)
        .background {
            if selected {
                RoundedRectangle(cornerRadius: DS.Radius.row, style: .continuous)
                    .fill(DS.wash(scheme))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.row, style: .continuous)
                        .strokeBorder(DS.washEdge(scheme), lineWidth: 0.5))
                    .matchedGeometryEffect(id: "selection", in: ns)
            }
        }
        .pointerGlow(.white, radius: 120, strength: scheme == .dark ? 0.16 : 0.5, corner: DS.Radius.row)
        .contentShape(RoundedRectangle(cornerRadius: DS.Radius.row, style: .continuous))
        .offset(y: hovering ? -1 : 0)
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: selected)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hovering)
        .onHover { h in
            hovering = h
            if h { state.hover(item.id) }
        }
        .onTapGesture { state.onPick(item, true) }
        .background(GeometryReader { g in
            Color.clear.preference(key: RowFrameKey.self, value: [item.id: g.frame(in: .named("panel"))])
        })
        .contextMenu {
            Button("Paste") { state.onPick(item, true) }
            Button("Copy only") { state.onPick(item, false) }
            Button(item.pinned ? "Unpin" : "Pin") { state.model.store.togglePin(item) }
            Divider()
            Button("Delete", role: .destructive) { state.delete(item) }
        }
        .help(item.kind == .text ? String((item.text ?? "").prefix(600)) : "")
    }

    // MARK: Parts

    @ViewBuilder
    private var leading: some View {
        if item.kind == .image, let name = item.blobName,
           let img = ThumbnailCache.shared.image(for: blobsDir.appendingPathComponent(name), maxPixel: 260) {
            Image(nsImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: DS.Size.thumb.width, height: DS.Size.thumb.height)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.thumb, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.thumb, style: .continuous)
                    .strokeBorder(DS.Palette.separator, lineWidth: 0.5))
                .shadow(color: .black.opacity(0.10), radius: 2, y: 1)
                .scaleEffect(hovering ? 1.03 : 1)
        } else if item.kind == .file, let path = item.text?.split(separator: "\n").first {
            Image(nsImage: NSWorkspace.shared.icon(forFile: String(path)))
                .resizable().frame(width: DS.Size.tile, height: DS.Size.tile)
        } else {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DS.Palette.secondary)
                .frame(width: DS.Size.tile, height: DS.Size.tile)
                .background(DS.Palette.fill, in: RoundedRectangle(cornerRadius: DS.Radius.tile, style: .continuous))
        }
    }

    @ViewBuilder
    private var trailing: some View {
        ZStack(alignment: .trailing) {
            if hovering {
                HStack(spacing: 2) {
                    iconButton(item.pinned ? "pin.slash" : "pin", help: item.pinned ? "Unpin" : "Pin",
                               color: item.pinned ? DS.Palette.pin : DS.Palette.secondary) { state.model.store.togglePin(item) }
                    iconButton("trash", help: "Delete", color: DS.Palette.secondary) { state.delete(item) }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else if index < 9 {
                Text("⌘\(index + 1)").font(DS.Text.badge).foregroundStyle(selected ? DS.Palette.secondary : DS.Palette.meta)
                    .transition(.opacity)
            }
        }
        .frame(width: 46, alignment: .trailing)
        .animation(Motion.quick, value: hovering)
    }

    private func iconButton(_ symbol: String, help: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 10.5, weight: .medium))
                .frame(width: 22, height: 22).contentShape(Rectangle())
        }
        .buttonStyle(PressSquish())
        .foregroundStyle(color)
        .help(help)
    }

    // MARK: Text

    private var isLink: Bool {
        guard item.kind == .text, let t = item.text?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
        return !t.contains(" ") && (t.hasPrefix("http://") || t.hasPrefix("https://"))
    }

    private var symbol: String {
        switch item.kind {
        case .text: isLink ? "link" : "text.alignleft"
        case .image: "photo"
        case .file: "doc"
        }
    }

    private var title: String {
        switch item.kind {
        case .image: isScreenshot ? "Screenshot" : "Image"
        default: item.preview.isEmpty ? "(empty)" : item.preview
        }
    }

    private var isScreenshot: Bool {
        let s = item.sourceApp?.lowercased() ?? ""
        return s.contains("screenshot") || s.contains("screencapture")
    }

    private var dims: String? {
        guard item.kind == .image, let name = item.blobName,
              let s = ThumbnailCache.shared.pixelSize(for: blobsDir.appendingPathComponent(name)) else { return nil }
        return "\(Int(s.width)) × \(Int(s.height))"
    }

    private var meta: String {
        var parts: [String] = []
        if item.kind == .file, let t = item.text {
            let n = t.split(separator: "\n").count
            parts.append(n == 1 ? "1 file" : "\(n) files")
        }
        parts.append(Fmt.ago(item.createdAt))
        if let s = item.sourceApp { parts.append(s) }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Small parts

struct FilterChip: View {
    let title: String
    let on: Bool
    let ns: Namespace.ID
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DS.Text.chip)
                .foregroundStyle(on ? DS.Palette.tint : (hovering ? DS.Palette.label : DS.Palette.secondary))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background {
                    if on { Capsule().fill(DS.Palette.tint.opacity(0.16)).matchedGeometryEffect(id: "chip", in: ns) }
                    else if hovering { Capsule().fill(DS.Palette.fill) }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(PressSquish())
        .onHover { hovering = $0 }
    }
}

struct PermissionCard: View {
    @ObservedObject var state: PanelState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "cursorarrow.click.2").font(.system(size: 11, weight: .medium)).foregroundStyle(DS.Palette.tint)
                Text("Paste right where you clicked").font(DS.Text.name)
            }
            Text("macOS needs your OK once: turn on \(Brand.name) in Privacy & Security › Accessibility. It lets \(HotKeyManager.shared.display) open the clipboard and paste where you clicked. Until then, picks are copied and you press ⌘V.")
                .font(DS.Text.meta).foregroundStyle(DS.Palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                Button("Open Settings") { Paster.openAccessibilitySettings(); state.onClose() }
                    .glassButton(prominent: true, tint: DS.Palette.tint)
                Button("Not now") {
                    UserDefaults.standard.set(true, forKey: "permissionCardDismissed")
                    state.showPermissionCard = false
                }
                .glassButton()
            }
            .controlSize(.small)
            .padding(.top, 2)
        }
        .padding(DS.Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Brand.pink.opacity(0.14), Brand.pink.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous).strokeBorder(Brand.pink.opacity(0.30), lineWidth: 0.5))
        .pointerGlow(.white, radius: 160, strength: 0.35, corner: DS.Radius.card)
    }
}

struct EmptyState: View {
    let hasHistory: Bool
    let query: String

    var body: some View {
        VStack(spacing: DS.Space.s) {
            ClipMark(size: 52)
                .opacity(hasHistory ? 0.5 : 1)
                .tiltAndFling(8)
            Text(hasHistory ? (query.isEmpty ? "Nothing in this filter" : "No match for \"\(query)\"") : "Nothing here yet")
                .font(DS.Text.title).foregroundStyle(DS.Palette.label)
            if !hasHistory {
                Text("Copy text, links or screenshots.\nPress \(HotKeyManager.shared.display) to bring them back.")
                    .font(DS.Text.meta).foregroundStyle(DS.Palette.secondary).multilineTextAlignment(.center)
            }
        }
    }
}

enum Fmt {
    static func ago(_ d: Date) -> String {
        let s = max(0, Date().timeIntervalSince(d))
        if s < 45 { return "now" }
        if s < 3600 { return "\(Int(s / 60 + 0.5))m" }
        if s < 86_400 { return "\(Int(s / 3600))h" }
        if s < 7 * 86_400 { return "\(Int(s / 86_400))d" }
        return d.formatted(.dateTime.day().month(.abbreviated))
    }

    static func agoLong(_ d: Date) -> String {
        let f = RelativeDateTimeFormatter(); f.unitsStyle = .short
        return Date().timeIntervalSince(d) < 45 ? "just now" : f.localizedString(for: d, relativeTo: Date())
    }
}
