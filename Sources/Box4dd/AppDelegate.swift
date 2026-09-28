import AppKit
import Carbon.HIToolbox

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let windows = ShelfWindows()
    private lazy var recentShelvesMenu = RecentShelvesMenu(windows: windows)
    private var statusItem: NSStatusItem?
    private var newShelfHotKey: HotKey?
    private var shakeMonitor: ShakeMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = makeStatusItem()
        windows.restoreOpenShelves()
        newShelfHotKey = HotKey(keyCode: UInt32(kVK_Space), modifiers: UInt32(controlKey | optionKey)) { [windows] in
            windows.openShelf(at: NSEvent.mouseLocation)
        }
        shakeMonitor = ShakeMonitor { [windows] point in
            windows.openShelf(at: point)
        }
    }

    private func makeStatusItem() -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "tray.2", accessibilityDescription: "box4dd")

        let menu = NSMenu()
        let newShelf = NSMenuItem(title: "New Shelf", action: #selector(newShelf), keyEquivalent: " ")
        newShelf.keyEquivalentModifierMask = [.control, .option]
        newShelf.target = self
        menu.addItem(newShelf)
        let recent = NSMenuItem(title: "Recent Shelves", action: nil, keyEquivalent: "")
        recent.submenu = recentShelvesMenu.menu
        menu.addItem(recent)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit box4dd", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        return item
    }

    @objc private func newShelf() {
        windows.openShelf(at: NSEvent.mouseLocation)
    }
}
