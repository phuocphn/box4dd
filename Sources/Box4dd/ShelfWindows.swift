import AppKit
import ShelfCore

/// Keeps one floating panel per open Shelf, and passes what the user does in the panels to the Shelf rules.
@MainActor
final class ShelfWindows {
    let shelves = Shelves()
    private var panels: [Shelf.ID: ShelfPanel] = [:]

    /// Opens a new Shelf centred on a point in screen coordinates (usually the cursor).
    func openShelf(at point: NSPoint) {
        let id = shelves.openShelf()
        let panel = ShelfPanel(shelfID: id, windows: self)
        panels[id] = panel
        panel.setFrameOrigin(origin(centering: panel.frame.size, on: point))
        panel.orderFrontRegardless()
    }

    /// Returns false when none of the files could be kept, so the drag source sees the drop as refused.
    func drop(_ urls: [URL], on id: Shelf.ID) -> Bool {
        let bookmarks = urls.compactMap { try? $0.bookmarkData() }
        guard !bookmarks.isEmpty else { return false }
        shelves.drop(references: bookmarks, on: id)
        return true
    }

    func items(on id: Shelf.ID) -> [Item] {
        shelves.shelf(id)?.items ?? []
    }

    func dragOutEnded(_ itemIDs: [Item.ID], from id: Shelf.ID, accepted: Bool) {
        shelves.dragOutEnded(itemIDs, from: id, accepted: accepted)
        closePanelsOfClosedShelves()
    }

    /// The user closed a Shelf's panel.
    func panelClosed(_ id: Shelf.ID) {
        panels[id] = nil
        shelves.close(id)
    }

    /// The original file for a Reference Item, if it still exists.
    func url(for item: Item) -> URL? {
        var isStale = false
        return try? URL(resolvingBookmarkData: item.bookmark, options: .withoutUI, bookmarkDataIsStale: &isStale)
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
