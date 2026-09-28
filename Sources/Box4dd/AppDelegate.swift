import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let windows = ShelfWindows()
    private let settings = Settings()
    private lazy var recentShelvesMenu = RecentShelvesMenu(windows: windows)
    private lazy var newShelfShortcut = NewShelfShortcut(settings: settings) { [windows] in
        windows.openShelf(at: NSEvent.mouseLocation)
    }
    private lazy var launchAtLogin = LaunchAtLogin(settings: settings)
    private lazy var settingsWindow = SettingsWindow(settings: settings, newShelfShortcut: newShelfShortcut, launchAtLogin: launchAtLogin)
    private var statusItem: NSStatusItem?
    private let newShelfMenuItem = NSMenuItem(title: "New Shelf", action: #selector(newShelf), keyEquivalent: "")
    private var shakeMonitor: ShakeMonitor?

    // The menu bar icon accepts whatever a Shelf accepts: Finder files, promised files, text, links, rich text and images.
    private static let menuBarDropTypes = PasteboardContent.readableTypes

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = makeStatusItem()
        windows.restoreOpenShelves()

        showNewShelfShortcut(settings.newShelfShortcut)
        newShelfShortcut.changed = { [weak self] in self?.showNewShelfShortcut($0) }
        newShelfShortcut.register()

        shakeMonitor = ShakeMonitor { [windows] point in
            windows.openShelf(at: point)
        }
        settings.shakeSettingsChanged = { [weak self] in self?.applyShakeSettings() }
        applyShakeSettings()

        launchAtLogin.applyIfChanged()
    }

    private func makeStatusItem() -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "tray.2", accessibilityDescription: "box4dd")
            _ = MenuBarDropTarget(on: button, types: Self.menuBarDropTypes,
                                  canDrop: { !PasteboardContent.read(from: $0).isEmpty },
                                  drop: { [weak self] in self?.openShelf(holding: $0) ?? false })
        }

        let menu = NSMenu()
        newShelfMenuItem.target = self
        menu.addItem(newShelfMenuItem)
        let recent = NSMenuItem(title: "Recent Shelves", action: nil, keyEquivalent: "")
        recent.submenu = recentShelvesMenu.menu
        menu.addItem(recent)
        menu.addItem(.separator())
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit box4dd", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        return item
    }

    @objc private func newShelf() {
        windows.openShelf(at: NSEvent.mouseLocation)
    }

    @objc private func openSettings() {
        settingsWindow.show()
    }

    private func showNewShelfShortcut(_ shortcut: Shortcut) {
        newShelfMenuItem.keyEquivalent = shortcut.key
        newShelfMenuItem.keyEquivalentModifierMask = shortcut.modifierFlags
    }

    private func applyShakeSettings() {
        shakeMonitor?.detector.sensitivity = settings.shakeSensitivity
        shakeMonitor?.detector.excludedApps = Set(settings.excludedApps)
    }

    /// Something was dropped on the menu bar icon: open a new Shelf just below it, holding what was dropped.
    private func openShelf(holding pasteboard: NSPasteboard) -> Bool {
        let contents = PasteboardContent.read(from: pasteboard)
        guard !contents.isEmpty else { return false }
        let id = windows.openShelf(at: pointBelowIcon)
        return windows.add(contents, to: id)
    }

    // A Shelf centred here is pushed down onto the screen, so it opens right under the icon.
    private var pointBelowIcon: NSPoint {
        guard let frame = statusItem?.button?.window?.frame else { return NSEvent.mouseLocation }
        return NSPoint(x: frame.midX, y: frame.minY)
    }
}
