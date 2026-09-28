import AppKit
import ShelfCore

/// Keeps one floating panel per open Shelf, and passes what the user does in the panels to the Shelf rules.
@MainActor
final class ShelfWindows {
    let shelves = Shelves(store: ShelfFile(), fileSystem: BookmarkFileSystem())
    private var panels: [Shelf.ID: ShelfPanel] = [:]
    private var originalsCheck: Timer?

    /// Brings back the Shelves that were open at quit, where they were, and starts watching their originals.
    func restoreOpenShelves() {
        shelves.checkOriginals()
        for shelf in shelves.openShelves {
            showPanel(for: shelf)
        }
        // Renames, moves and deletions in Finder happen outside the app, so look for them every few seconds.
        originalsCheck = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.shelves.checkOriginals() }
        }
    }

    /// Opens a new Shelf centred on a point in screen coordinates (usually the cursor).
    func openShelf(at point: NSPoint) {
        let id = shelves.openShelf()
        let panel = showPanel(for: id) { self.origin(centering: $0, on: point) }
        panelMoved(id, to: panel.frame.origin)
    }

    /// Reopens a Recent Shelf where it was when it closed.
    func reopen(_ id: Shelf.ID) {
        shelves.reopen(id)
        shelves.checkOriginals()
        if let shelf = shelves.shelf(id) { showPanel(for: shelf) }
    }

    /// Shows a Shelf at its saved position, moved onto a screen if that spot is no longer on one.
    private func showPanel(for shelf: Shelf) {
        showPanel(for: shelf.id) { size in
            let center = NSPoint(x: shelf.position.x + size.width / 2, y: shelf.position.y + size.height / 2)
            return self.origin(centering: size, on: center)
        }
    }

    @discardableResult
    private func showPanel(for id: Shelf.ID, placedAt place: (NSSize) -> NSPoint) -> ShelfPanel {
        let panel = ShelfPanel(shelfID: id, windows: self)
        panels[id] = panel
        panel.setFrameOrigin(place(panel.frame.size))
        panel.orderFrontRegardless()
        return panel
    }

    /// Puts what was dropped or pasted on a Shelf: Finder files as Reference Items, and anything else saved
    /// to the app's storage as Captured Items. Returns false when nothing could be kept, so a drag source
    /// sees the drop as refused.
    @discardableResult
    func add(_ contents: [PasteboardContent], to id: Shelf.ID) -> Bool {
        let items: [Item.Content] = contents.compactMap { content in
            if case .file(let url) = content {
                // A copied Captured Item pasted on a Shelf is still the app's own file, not a Finder file.
                if let file = CapturedFiles.file(at: url) { return .captured(file: file) }
                return (try? url.bookmarkData()).map { .reference(bookmark: $0) }
            }
            return CapturedFiles.save(content).map { .captured(file: $0) }
        }
        guard !items.isEmpty else { return false }
        shelves.drop(items, on: id)
        return true
    }

    /// ⌘V on a Shelf.
    func paste(on id: Shelf.ID) -> Bool {
        add(PasteboardContent.read(from: .general), to: id)
    }

    func items(on id: Shelf.ID) -> [Item] {
        shelves.shelf(id)?.items ?? []
    }

    func dragOutEnded(_ itemIDs: [Item.ID], from id: Shelf.ID, accepted: Bool) {
        shelves.dragOutEnded(itemIDs, from: id, accepted: accepted)
        closePanelsOfClosedShelves()
    }

    func remove(_ itemIDs: [Item.ID], from id: Shelf.ID) {
        shelves.remove(itemIDs, from: id)
        closePanelsOfClosedShelves()
    }

    /// The user closed a Shelf's panel.
    func panelClosed(_ id: Shelf.ID) {
        panels[id] = nil
        shelves.close(id)
    }

    /// The user moved a Shelf's panel; the position is its frame origin in screen coordinates.
    func panelMoved(_ id: Shelf.ID, to origin: NSPoint) {
        shelves.shelfMoved(id, to: ShelfPosition(x: origin.x, y: origin.y))
    }

    /// The original file for a Reference Item, or a Captured Item's own file. Nil for a Missing Item, which
    /// is also left out of drags.
    func url(for item: Item) -> URL? {
        switch item.content {
        case .reference(let bookmark): item.isMissing ? nil : BookmarkFileSystem.resolve(bookmark)
        case .captured(let file): CapturedFiles.url(for: file)
        }
    }

    /// The Item's name, which a Missing Item keeps from when it was dropped.
    func name(for item: Item) -> String {
        if let file = item.capturedFile { return URL(filePath: file).lastPathComponent }
        return url(for: item)?.lastPathComponent ?? item.bookmark.flatMap(BookmarkFileSystem.savedName(in:)) ?? "Unknown item"
    }

    /// A captured image shows itself; everything else shows its file's icon.
    func icon(for item: Item) -> NSImage {
        guard let url = url(for: item) else {
            return NSImage(systemSymbolName: "questionmark.square.dashed", accessibilityDescription: nil) ?? NSImage()
        }
        if let file = item.capturedFile, url.pathExtension == "png" {
            if let cached = thumbnails[file] { return cached }
            if let image = NSImage(contentsOf: url) {
                thumbnails[file] = image
                return image
            }
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    private var thumbnails: [String: NSImage] = [:]

    /// What an Item puts on a drag out of a Shelf: a Reference Item its original, a Captured Item its content
    /// and a promise of a copy of its file. Nil when there's nothing to deliver.
    func dragWriter(for item: Item) -> (any NSPasteboardWriting)? {
        guard let url = url(for: item) else { return nil }
        return item.capturedFile == nil ? url as NSURL : CapturedItemDrag(source: url)
    }

    /// What ⌘C puts on the clipboard for an Item: its file, and a Captured Item's content too.
    func clipboardWriter(for item: Item) -> (any NSPasteboardWriting)? {
        guard let url = url(for: item) else { return nil }
        return item.capturedFile == nil ? url as NSURL : CapturedItemDrag.clipboardItem(for: url)
    }

    private func closePanelsOfClosedShelves() {
        for (id, panel) in panels where shelves.shelf(id) == nil {
            panels[id] = nil
            panel.close()
        }
    }

    private func origin(centering size: NSSize, on point: NSPoint) -> NSPoint {
        var origin = NSPoint(x: point.x - size.width / 2, y: point.y - size.height / 2)
        let screen = NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) } ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            origin.x = min(max(origin.x, visible.minX), visible.maxX - size.width)
            origin.y = min(max(origin.y, visible.minY), visible.maxY - size.height)
        }
        return origin
    }
}
