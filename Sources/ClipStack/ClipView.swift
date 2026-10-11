import SwiftUI

// Plain ObservableObjects instead of @State: the Command Line Tools toolchain lacks the SwiftUI macro plugin.
final class Flag: ObservableObject { @Published var on = false }
final class Query: ObservableObject { @Published var text = "" }

struct ClipView: View {
    @ObservedObject var store: ClipStore
    var onPaste: (ClipItem) -> Void
    @StateObject private var query = Query()

    private var filtered: [ClipItem] {
        let all = store.sorted
        return query.text.isEmpty ? all : all.filter { $0.text.localizedCaseInsensitiveContains(query.text) }
    }

    var body: some View {
        VStack(spacing: 0) {
            TextField("Search clipboard…", text: $query.text)
                .textFieldStyle(.roundedBorder)
                .padding(10)
            Divider()
            if filtered.isEmpty {
                Spacer()
                Text("Nothing copied yet").foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { index, item in
                            Row(item: item, index: index, store: store, onPaste: onPaste)
                        }
                    }
                    .padding(6)
                }
            }
            Divider()
            HStack {
                Text("⌘1–9 paste · pin to keep").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Clear unpinned") { store.clearUnpinned() }.font(.caption).buttonStyle(.link)
                Button("Quit") { NSApp.terminate(nil) }.font(.caption).buttonStyle(.link)
            }
            .padding(8)
            // Hidden buttons provide ⌘1…⌘9 shortcuts.
            ForEach(0..<9, id: \.self) { i in
                Button("") {
                    if i < filtered.count { onPaste(filtered[i]) }
                }
                .keyboardShortcut(KeyEquivalent(Character("\(i + 1)")), modifiers: .command)
                .frame(width: 0, height: 0).opacity(0)
            }
        }
        .frame(width: 380, height: 460)
        .background(.regularMaterial)
    }
}

private struct Row: View {
    let item: ClipItem
    let index: Int
    @ObservedObject var store: ClipStore
    var onPaste: (ClipItem) -> Void
    @StateObject private var h = Flag()
    private var hover: Bool { h.on }

    var body: some View {
        HStack(spacing: 8) {
            Text(index < 9 ? "⌘\(index + 1)" : "")
                .font(.caption.monospaced()).foregroundStyle(.secondary)
                .frame(width: 28)
            Text(item.text.trimmingCharacters(in: .whitespacesAndNewlines))
                .lineLimit(2).truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button { store.togglePin(item) } label: {
                Image(systemName: item.pinned ? "pin.fill" : "pin")
                    .foregroundStyle(item.pinned ? Color.orange : .secondary)
            }.buttonStyle(.plain)
            if hover {
                Button { store.delete(item) } label: { Image(systemName: "xmark.circle") }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8).fill(hover ? Color.accentColor.opacity(0.18) : .clear))
        .contentShape(Rectangle())
        .onHover { h.on = $0 }
        .onTapGesture { onPaste(item) }
        .animation(.easeInOut(duration: 0.12), value: hover)
    }
}
