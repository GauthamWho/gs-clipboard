import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var updates: UpdateChecker
    var onClose: () -> Void
    var onOpenSettings: () -> Void

    @State private var search = ""
    @FocusState private var searchFocused: Bool

    private var filtered: [ClipItem] {
        guard !search.isEmpty else { return model.store.items }
        let query = search.lowercased()
        return model.store.items.filter {
            $0.preview.lowercased().contains(query) || ($0.text?.lowercased().contains(query) ?? false)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            list
            Divider()
            footer
        }
        .frame(width: 400, height: 520)
        .onAppear { search = "" }
        .task {
            // The popover window becomes key just after the view appears,
            // so nudge focus once it does.
            try? await Task.sleep(for: .milliseconds(120))
            searchFocused = true
        }
        .onExitCommand(perform: onClose)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search history", text: $search)
                .textFieldStyle(.plain)
                .focused($searchFocused)
            if !search.isEmpty {
                Button {
                    search = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var list: some View {
        if filtered.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 32))
                    .foregroundStyle(.tertiary)
                Text(model.store.items.isEmpty ? "Copy something to get started" : "No matches")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filtered) { item in
                        ClipRow(item: item, model: model) {
                            model.copy(item)
                            onClose()
                        }
                        Divider().padding(.leading, 12)
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Text("\(model.store.items.count) items")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if let version = updates.available?.version {
                Button {
                    updates.installAvailable()
                } label: {
                    Label("Update \(version)", systemImage: "arrow.down.circle.fill")
                }
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.blue)
                .help("Install the latest version")
            }
            Button("Clear") {
                model.store.clearAll()
            }
            .buttonStyle(.plain)
            .font(.caption)
            Button {
                onClose()
                onOpenSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .help("Settings")
            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.plain)
            .help("Quit G's Clipboard")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

struct ClipRow: View {
    let item: ClipItem
    @ObservedObject var model: AppModel
    let onCopy: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Button(action: onCopy) {
                HStack(alignment: .top, spacing: 10) {
                    thumbnail
                    textContent
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Click to copy")

            actions
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if item.kind == .image,
           let name = item.blobName,
           let image = ThumbnailCache.shared.image(for: model.store.blobsDir.appendingPathComponent(name)) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            Image(systemName: iconName)
                .font(.system(size: 16))
                .frame(width: 44, height: 44)
                .foregroundStyle(.secondary)
        }
    }

    private var textContent: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(item.preview.isEmpty ? "(empty)" : item.preview)
                .lineLimit(2)
                .font(.system(size: 13))
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 6) {
                Text(relativeTime)
                if let source = item.sourceApp {
                    Text("· \(source)")
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private var actions: some View {
        VStack(spacing: 8) {
            Button {
                model.store.togglePin(item)
            } label: {
                Image(systemName: item.pinned ? "pin.fill" : "pin")
            }
            .buttonStyle(.plain)
            .foregroundStyle(item.pinned ? .orange : .secondary)
            .help(item.pinned ? "Unpin" : "Pin")

            Button {
                model.store.delete(item)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Delete")
        }
        .font(.caption)
    }

    private var iconName: String {
        switch item.kind {
        case .text: return "text.alignleft"
        case .image: return "photo"
        case .file: return "doc"
        }
    }

    private var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: item.createdAt, relativeTo: Date())
    }
}
