import AppKit
import ShelfCore

/// The menu bar's Recent Shelves submenu, rebuilt each time it opens. Choosing one reopens it.
@MainActor
final class RecentShelvesMenu: NSObject, NSMenuDelegate {
    private let windows: ShelfWindows
    let menu = NSMenu(title: "Recent Shelves")

    init(windows: ShelfWindows) {
        self.windows = windows
        super.init()
        menu.delegate = self
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        windows.shelves.checkOriginals()
        menu.removeAllItems()
        let recent = windows.shelves.recentShelves
        guard !recent.isEmpty else {
            let none = NSMenuItem(title: "No Recent Shelves", action: nil, keyEquivalent: "")
            none.isEnabled = false
            menu.addItem(none)
            return
        }
        for shelf in recent {
            let item = NSMenuItem(title: label(for: shelf), action: #selector(reopen(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = shelf.id
            menu.addItem(item)
        }
    }

    @objc private func reopen(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? Shelf.ID else { return }
        windows.reopen(id)
    }

    /// For example "report.pdf + 2 more — 5 minutes ago".
    private func label(for shelf: Shelf) -> String {
        guard let first = shelf.items.first else { return "Empty Shelf" }
        var label = windows.name(for: first)
        if shelf.items.count > 1 { label += " + \(shelf.items.count - 1) more" }
        if let closedAt = shelf.closedAt { label += " — " + closedAt.formatted(.relative(presentation: .named)) }
        return label
    }
}
