// Gautham's Clipboard by GauthamWho. Copyright © 2026 GauthamWho. All rights reserved. See LICENSE.
import AppKit
import Carbon.HIToolbox
import SwiftUI

extension Notification.Name {
    /// Posted every time the panel opens: clear search, jump to the newest item, replay the arrival.
    static let gsClipboardDidShow = Notification.Name("gsClipboardDidShow")
}

/// What the panel shows and which row is selected. Shared by the list, the key handler
/// and the hover preview.
@MainActor
final class PanelState: ObservableObject {
    enum Filter: String, CaseIterable, Identifiable {
        case all = "All", text = "Text", images = "Images", files = "Files", pinned = "Pinned", emoji = "Emoji"
        var id: String { rawValue }
    }

    let model: AppModel
    @Published var search = ""
    @Published var filter: Filter = .all
    @Published var selectedID: UUID?
    @Published var showPermissionCard = false
    /// Selected cell in the emoji grid (index into `emojiList`).
    @Published var emojiIndex = 0
    var emojiList: [Emoji] { EmojiCatalog.visible(query: search) }
    var onPickEmojiText: (String, _ type: Bool) -> Void = { _, _ in }

    /// Bumped on keyboard moves so the list scrolls the selection into view.
    @Published var keyboardMove = 0

    /// Row frames in panel coordinates (top-left origin). Not published: read on demand.
    var rowFrames: [UUID: CGRect] = [:]
    /// Ignore hover briefly after a keyboard move, so a list scrolling under a still pointer
    /// doesn't steal the selection.
    var lastKeyMove = Date.distantPast
    /// Hover is ignored after opening until the pointer really moves, so a panel opening under a
    /// still pointer keeps the first row selected.
    var hoverArmed = false

    /// Set by AppDelegate.
    var onPick: (ClipItem, _ paste: Bool) -> Void = { _, _ in }
    var onClose: () -> Void = {}
    var onOpenSettings: () -> Void = {}

    init(model: AppModel) { self.model = model }

    var visible: [ClipItem] {
        var items = model.store.items
        switch filter {
        case .all: break
        case .text: items = items.filter { $0.kind == .text }
        case .images: items = items.filter { $0.kind == .image }
        case .files: items = items.filter { $0.kind == .file }
        case .pinned: items = items.filter(\.pinned)
        case .emoji: return []
        }
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return items }
        return items.filter { $0.preview.lowercased().contains(q) || ($0.text?.lowercased().contains(q) ?? false)
            || ($0.sourceApp?.lowercased().contains(q) ?? false) }
    }

    var selected: ClipItem? {
        let v = visible
        return v.first { $0.id == selectedID } ?? v.first
    }

    func prepareForShow() {
        search = ""
        filter = .all
        selectedID = model.store.items.first?.id
        emojiIndex = 0
        hoverArmed = false
        showPermissionCard = Paster.enabled && !Paster.isTrusted
            && !UserDefaults.standard.bool(forKey: "permissionCardDismissed")
    }

    func hover(_ id: UUID) {
        guard hoverArmed, Date().timeIntervalSince(lastKeyMove) > 0.35, selectedID != id else { return }
        withAnimation(Motion.slide) { selectedID = id }
    }

    private func jump(_ to: Int) {
        let v = visible
        guard !v.isEmpty else { return }
        withAnimation(Motion.slide) { selectedID = v[min(max(to, 0), v.count - 1)].id }
        lastKeyMove = Date(); keyboardMove += 1
    }

    private func move(_ delta: Int) {
        let v = visible
        guard !v.isEmpty else { return }
        let i = v.firstIndex { $0.id == selectedID } ?? -1
        let next = min(max(i + delta, 0), v.count - 1)
        withAnimation(Motion.slide) { selectedID = v[next].id }
        lastKeyMove = Date()
        keyboardMove += 1
    }

    /// Mac-standard keys. Returns true when the key was used.
    func handle(_ e: NSEvent) -> Bool {
        let mods = e.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let cmd = mods.contains(.command), opt = mods.contains(.option)
        if cmd && Int(e.keyCode) == kVK_ANSI_E {
            withAnimation(Motion.slide) { filter = filter == .emoji ? .all : .emoji }
            emojiIndex = 0
            return true
        }
        if filter == .emoji, let used = handleEmoji(e, opt: opt) { return used }
        switch Int(e.keyCode) {
        case kVK_DownArrow: move(cmd ? 10_000 : 1); return true
        case kVK_UpArrow: move(cmd ? -10_000 : -1); return true
        case kVK_Return, kVK_ANSI_KeypadEnter:
            if let item = selected { onPick(item, !opt) }
            return true
        case kVK_Escape:
            if !search.isEmpty { search = "" } else if filter != .all { filter = .all } else { onClose() }
            return true
        case kVK_Delete where cmd && search.isEmpty:
            if let item = selected { delete(item) }
            return true
        case kVK_ANSI_C where cmd && search.isEmpty:
            if let item = selected { onPick(item, false) }
            return true
        case kVK_ANSI_W where cmd:
            onClose(); return true
        case kVK_Home: jump(0); return true
        case kVK_End: jump(.max); return true
        case kVK_PageUp: move(-6); return true
        case kVK_PageDown: move(6); return true
        case kVK_ANSI_P where cmd:
            if let item = selected { model.store.togglePin(item) }
            return true
        case kVK_ANSI_Comma where cmd:
            onClose(); onOpenSettings(); return true
        case kVK_Tab:
            let all = Filter.allCases
            let i = all.firstIndex(of: filter) ?? 0
            filter = all[(i + (mods.contains(.shift) ? all.count - 1 : 1)) % all.count]
            selectedID = visible.first?.id
            return true
        default:
            break
        }
        if cmd, filter != .emoji, let n = Self.digit(e.keyCode) {
            let v = visible
            if n <= v.count { onPick(v[n - 1], !opt) }
            return true
        }
        return false
    }

    private func handleEmoji(_ e: NSEvent, opt: Bool) -> Bool? {
        let n = emojiList.count
        func go(_ d: Int) {
            guard n > 0 else { return }
            emojiIndex = min(max(emojiIndex + d, 0), n - 1)
            lastKeyMove = Date(); keyboardMove += 1
        }
        switch Int(e.keyCode) {
        case kVK_LeftArrow, kVK_RightArrow:
            // While typing a search, ← → move the text cursor as usual.
            guard search.isEmpty else { return nil }
            go(Int(e.keyCode) == kVK_LeftArrow ? -1 : 1); return true
        case kVK_UpArrow:
            if emojiIndex - EmojiGrid.columns >= 0 { go(-EmojiGrid.columns) }
            return true
        case kVK_DownArrow: go(EmojiGrid.columns); return true
        case kVK_Return, kVK_ANSI_KeypadEnter:
            if emojiList.indices.contains(emojiIndex) { pickEmoji(emojiList[emojiIndex], type: !opt) }
            return true
        default: return nil
        }
    }

    func hoverEmoji(_ i: Int) {
        guard hoverArmed, Date().timeIntervalSince(lastKeyMove) > 0.35 else { return }
        emojiIndex = i
    }

    func pickEmoji(_ e: Emoji, type: Bool = true) {
        EmojiCatalog.used(e)
        onPickEmojiText(e.char, type)
    }

    func delete(_ item: ClipItem) {
        let v = visible
        if item.id == selectedID, let i = v.firstIndex(of: item) {
            selectedID = v.indices.contains(i + 1) ? v[i + 1].id : (i > 0 ? v[i - 1].id : nil)
        }
        withAnimation(Motion.arrive) { model.store.delete(item) }
    }

    private static func digit(_ code: UInt16) -> Int? {
        [kVK_ANSI_1: 1, kVK_ANSI_2: 2, kVK_ANSI_3: 3, kVK_ANSI_4: 4, kVK_ANSI_5: 5,
         kVK_ANSI_6: 6, kVK_ANSI_7: 7, kVK_ANSI_8: 8, kVK_ANSI_9: 9][Int(code)]
    }
}
