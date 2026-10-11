import AppKit
import Foundation

struct ClipItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var text: String
    var pinned = false
    var date = Date()
}

final class ClipStore: ObservableObject {
    @Published private(set) var items: [ClipItem] = []

    private let maxUnpinned = 50
    private var lastChangeCount = NSPasteboard.general.changeCount
    private var timer: Timer?
    private let fileURL: URL

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ClipStack", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("history.json")
        load()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    /// Pinned items first, then newest first.
    var sorted: [ClipItem] {
        items.filter { $0.pinned } + items.filter { !$0.pinned }
    }

    private func poll() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount
        // Skip password managers' concealed/transient items.
        let types = pb.types?.map(\.rawValue) ?? []
        if types.contains("org.nspasteboard.ConcealedType") || types.contains("org.nspasteboard.TransientType") { return }
        guard let text = pb.string(forType: .string), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        add(text)
    }

    private func add(_ text: String) {
        if let i = items.firstIndex(where: { $0.text == text }) {
            // Keep pinned items in place; move unpinned duplicates to the top.
            if items[i].pinned { return }
            items.remove(at: i)
        }
        items.insert(ClipItem(text: text), at: 0)
        trim()
        save()
    }

    private func trim() {
        var count = 0
        items = items.filter { item in
            if item.pinned { return true }
            count += 1
            return count <= maxUnpinned
        }
    }

    func togglePin(_ item: ClipItem) {
        guard let i = items.firstIndex(of: item) else { return }
        items[i].pinned.toggle()
        save()
    }

    func delete(_ item: ClipItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    func clearUnpinned() {
        items.removeAll { !$0.pinned }
        save()
    }

    /// Puts the item on the clipboard without re-adding it to history.
    func copyToPasteboard(_ item: ClipItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(item.text, forType: .string)
        lastChangeCount = pb.changeCount
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([ClipItem].self, from: data) else { return }
        items = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: fileURL, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }
}
