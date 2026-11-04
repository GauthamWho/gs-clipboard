// Gautham's Clipboard by GauthamWho. Copyright © 2026 GauthamWho. All rights reserved. See LICENSE.
import AppKit
import SwiftUI

struct Emoji: Identifiable, Hashable {
    let char: String
    let name: String
    let group: Int
    var id: String { char }
}

/// Every emoji this Mac can draw, built from the system's own Unicode data (so it matches the
/// keyboard's set on this macOS), grouped like the emoji keyboard, searchable by name.
enum EmojiCatalog {
    static let groups = ["Recent", "Smileys & People", "Animals & Nature", "Food & Drink", "Activity",
                         "Travel & Places", "Objects", "Symbols", "Flags"]

    static let all: [Emoji] = build()

    /// Keyboard-like order: each row is (scalar range, group); earlier rows sort first.
    private static let table: [(ClosedRange<UInt32>, Int)] = [
        (0x1F600...0x1F637, 1), (0x1F641...0x1F644, 1), (0x1F910...0x1F915, 1), (0x1F917...0x1F92F, 1), (0x1F970...0x1F97A, 1),
        (0x1FAE0...0x1FAE8, 1), (0x1F9D0...0x1F9D0, 1), (0x1F638...0x1F640, 1), (0x1F645...0x1F64F, 1), (0x263A...0x263A, 1),
        (0x2639...0x2639, 1), (0x1F479...0x1F47F, 1), (0x1F480...0x1F480, 1), (0x1F4A9...0x1F4A9, 1), (0x1F916...0x1F916, 1),
        (0x1F44A...0x1F450, 1), (0x1F590...0x1F596, 1), (0x270A...0x270D, 1), (0x261D...0x261D, 1), (0x1F918...0x1F91F, 1),
        (0x1FAF0...0x1FAFF, 1), (0x1F440...0x1F449, 1), (0x1F9B5...0x1F9BB, 1), (0x1F9E0...0x1F9E1, 1), (0x1F466...0x1F478, 1),
        (0x1F481...0x1F487, 1), (0x1F930...0x1F939, 1), (0x1F9CD...0x1F9DF, 1), (0x1F574...0x1F57A, 1), (0x1F48B...0x1F48F, 1),
        (0x1F451...0x1F465, 1),
        (0x1F400...0x1F43F, 2), (0x1F980...0x1F9AE, 2), (0x1FAB0...0x1FABF, 2), (0x1F330...0x1F344, 2), (0x1F490...0x1F490, 2),
        (0x1F300...0x1F32F, 2), (0x2600...0x2604, 2), (0x2614...0x2614, 2), (0x26A1...0x26A1, 2), (0x26C4...0x26C8, 2), (0x2744...0x2744, 2),
        (0x1F345...0x1F37F, 3), (0x1F950...0x1F96F, 3), (0x1F9C0...0x1F9CB, 3), (0x1FAD0...0x1FADF, 3), (0x2615...0x2615, 3),
        (0x1F380...0x1F3CF, 4), (0x1F93A...0x1F94F, 4), (0x1F3D0...0x1F3D3, 4), (0x1F3F8...0x1F3FA, 4), (0x1FA80...0x1FA8F, 4),
        (0x26BD...0x26BE, 4), (0x26F3...0x26F8, 4),
        (0x1F680...0x1F6FF, 5), (0x1F3D4...0x1F3F7, 5), (0x1F5FA...0x1F5FF, 5), (0x26E9...0x26FD, 5), (0x2708...0x2708, 5),
        (0x1F4A0...0x1F4FF, 6), (0x1F500...0x1F573, 6), (0x1F57B...0x1F58F, 6), (0x1F597...0x1F5F9, 6), (0x1FA70...0x1FA7F, 6),
        (0x1FA90...0x1FAAF, 6), (0x231A...0x231B, 6), (0x2328...0x2328, 6), (0x23F0...0x23F3, 6), (0x260E...0x260E, 6),
        (0x2702...0x2702, 6), (0x2709...0x270F, 6),
    ]

    /// (group, rank) for sorting; anything not listed is a symbol.
    private static func place(of v: UInt32) -> (Int, Int) {
        for (i, row) in table.enumerated() where row.0.contains(v) { return (row.1, i) }
        return (7, table.count)
    }

    /// Faces, hearts and hands in the emoji keyboard's own order; everything else follows by group.
    private static let keyboardHead: [String] = Array("""
    😀😃😄😁😆😅🤣😂🙂🙃🫠😉😊😇🥰😍🤩😘😗☺️😚😙🥲😋😛😜🤪😝🤑🤗🤭🫢🫣🤫🤔🫡🤐🤨😐😑😶🫥😶‍🌫️😏😒🙄😬😮‍💨🤥🫨😌😔😪🤤😴😷🤒🤕🤢🤮🤧🥵🥶🥴😵😵‍💫🤯🤠🥳🥸😎🤓🧐😕🫤😟🙁☹️😮😯😲😳🥺🥹😦😧😨😰😥😢😭😱😖😣😞😓😩😫🥱😤😡😠🤬😈👿💀☠️💩🤡👹👺👻👽👾🤖😺😸😹😻😼😽🙀😿😾🙈🙉🙊💋💌💘💝💖💗💓💞💕💟❣️💔❤️‍🔥❤️‍🩹❤️🩷🧡💛💚💙🩵💜🤎🖤🩶🤍💯💢💥💫💦💨🕳️💬👁️‍🗨️🗨️🗯️💭💤👋🤚🖐️✋🖖🫱🫲🫳🫴🫷🫸👌🤌🤏✌️🤞🫰🤟🤘🤙👈👉👆🖕👇☝️🫵👍👎✊👊🤛🤜👏🙌🫶👐🤲🤝🙏✍️💅🤳💪🦾🦿🦵🦶👂🦻👃🧠🫀🫁🦷🦴👀👁️👅👄🫦
    """.filter { !$0.isWhitespace }).map(String.init)

    private static func build() -> [Emoji] {
        // Apple's own list and names (includes joined emoji like 👨‍💻, keycaps and flags).
        let path = "/System/Library/PrivateFrameworks/CoreEmoji.framework/Versions/A/Resources/en.lproj/AppleName.strings"
        var names = (NSDictionary(contentsOfFile: path) as? [String: String]) ?? [:]
        if names.isEmpty { names = scalarNames() }
        let skinTones: ClosedRange<UInt32> = 0x1F3FB...0x1F3FF

        var entries: [(Emoji, Int, String)] = []
        let headRank = Dictionary(keyboardHead.enumerated().map { ($1, $0) }, uniquingKeysWith: { a, _ in a })
        for (char, name) in names {
            let scalars = char.unicodeScalars.map(\.value)
            guard let first = scalars.first, !scalars.contains(where: skinTones.contains) else { continue }
            let group: Int, rank: Int
            if let h = headRank[char] {
                group = 1; rank = h - 10_000
            } else if (0x1F1E6...0x1F1FF).contains(first) || (first == 0x1F3F4 && scalars.count > 1) || name.hasPrefix("flag") {
                group = 8; rank = 0
            } else if scalars.contains(0x20E3) {
                group = 7; rank = table.count
            } else {
                (group, rank) = place(of: first)
            }
            entries.append((Emoji(char: char, name: name.lowercased(), group: group), rank, char))
        }
        // By group, then keyboard rank / table row, then code points so related emoji sit together.
        entries.sort { a, b in
            if a.0.group != b.0.group { return a.0.group < b.0.group }
            if a.1 != b.1 { return a.1 < b.1 }
            if a.0.group == 8 { return a.0.name < b.0.name }
            return a.2.unicodeScalars.map(\.value).lexicographicallyPrecedes(b.2.unicodeScalars.map(\.value))
        }
        return entries.map(\.0)
    }

    /// Fallback when Apple's list is unavailable: single-scalar emoji from Unicode data.
    private static func scalarNames() -> [String: String] {
        var out: [String: String] = [:]
        for r in [0x00A9...0x00AE, 0x203C...0x3299, 0x1F000...0x1FAFF] as [ClosedRange<UInt32>] {
            for v in r {
                guard let s = Unicode.Scalar(v), s.properties.isEmoji, let n = s.properties.name else { continue }
                if (0x1F1E6...0x1F1FF).contains(v) || (0x1F9B0...0x1F9B3).contains(v) { continue }
                out[s.properties.isEmojiPresentation ? String(s) : String(s) + "\u{FE0F}"] = n
            }
        }
        return out
    }

    // MARK: Recent

    static var recent: [Emoji] {
        let chars = UserDefaults.standard.stringArray(forKey: "recentEmoji") ?? []
        return chars.compactMap { c in all.first { $0.char == c }.map { Emoji(char: $0.char, name: $0.name, group: 0) } }
    }

    static func used(_ e: Emoji) {
        var chars = UserDefaults.standard.stringArray(forKey: "recentEmoji") ?? []
        chars.removeAll { $0 == e.char }
        chars.insert(e.char, at: 0)
        UserDefaults.standard.set(Array(chars.prefix(27)), forKey: "recentEmoji")
    }

    /// What the grid shows: recent first, then every group; or name matches when searching.
    static func visible(query: String) -> [Emoji] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        if q.isEmpty { return recent + all }
        let words = q.split(separator: " ")
        return all.filter { e in words.allSatisfy { e.name.contains($0) } }
    }
}

// MARK: - Grid

struct EmojiGrid: View {
    @ObservedObject var state: PanelState
    static let columns = 9
    private let cell: CGFloat = 38

    var body: some View {
        let list = state.emojiList
        if list.isEmpty {
            Text("No emoji for \"\(state.search)\"").font(DS.Text.meta).foregroundStyle(DS.Palette.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(cell), spacing: 1), count: Self.columns), spacing: 1,
                              pinnedViews: [.sectionHeaders]) {
                        ForEach(sections(list), id: \.0) { group, items in
                            Section {
                                ForEach(items, id: \.offset) { pair in
                                    EmojiCell(emoji: pair.element, selected: state.emojiIndex == pair.offset) {
                                        state.pickEmoji(pair.element)
                                    } hover: { state.hoverEmoji(pair.offset) }
                                    .id(pair.offset)
                                }
                            } header: {
                                if state.search.isEmpty {
                                    Overline(EmojiCatalog.groups[group])
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 4).padding(.leading, 4)
                                        .background(.ultraThinMaterial.opacity(0.0001))
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.never)
                .onChange(of: state.keyboardMove) { _, _ in proxy.scrollTo(state.emojiIndex, anchor: nil) }
            }
        }
    }

    /// Splits the flat list into (group, [(offset in flat list, emoji)]) so keyboard indexes stay flat.
    private func sections(_ list: [Emoji]) -> [(Int, [EnumeratedSequence<[Emoji]>.Element])] {
        var out: [(Int, [EnumeratedSequence<[Emoji]>.Element])] = []
        for pair in list.enumerated() {
            let g = state.search.isEmpty ? pair.element.group : 99
            if out.last?.0 == g { out[out.count - 1].1.append(pair) } else { out.append((g, [pair])) }
        }
        return out.map { ($0.0 == 99 ? 7 : $0.0, $0.1) }
    }
}

struct EmojiCell: View {
    let emoji: Emoji
    let selected: Bool
    let action: () -> Void
    let hover: () -> Void
    @State private var hovering = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Text(emoji.char)
            .font(.system(size: 22))
            .frame(width: 38, height: 38)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 9, style: .continuous).fill(DS.wash(scheme))
                        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(DS.washEdge(scheme), lineWidth: 0.5))
                }
            }
            .scaleEffect(hovering ? 1.22 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.55), value: hovering)
            .contentShape(Rectangle())
            .onHover { h in hovering = h; if h { hover() } }
            .onTapGesture(perform: action)
            .help(emoji.name.capitalized)
    }
}
