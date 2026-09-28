import AppKit
import ShelfCore
import SwiftUI

/// The floating window for one Shelf: above normal windows, on every Space and over full-screen apps,
/// and never activating the app, so the app the user is dragging from keeps focus.
final class ShelfPanel: NSPanel, NSWindowDelegate {
    private let shelfID: Shelf.ID
    private weak var windows: ShelfWindows?
    private let collapseButton = NSTitlebarAccessoryViewController()
    private var keyAllowed = false

    private static let stackSize = NSSize(width: 150, height: 160)
    private static let listSize = NSSize(width: 240, height: 300)

    init(shelfID: Shelf.ID, windows: ShelfWindows) {
        self.shelfID = shelfID
        self.windows = windows
        super.init(
            contentRect: NSRect(origin: .zero, size: Self.stackSize),
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isReleasedWhenClosed = false
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        delegate = self
        let itemsView = ShelfItemsView(shelfID: shelfID, windows: windows)
        contentView = itemsView

        let button = NSButton(image: NSImage(systemSymbolName: "square.stack", accessibilityDescription: "Collapse to Stack") ?? NSImage(),
                              target: itemsView, action: #selector(ShelfItemsView.collapse))
        button.isBordered = false
        button.frame = NSRect(x: 0, y: 0, width: 28, height: 28)
        collapseButton.view = button
        collapseButton.layoutAttribute = .trailing
        collapseButton.isHidden = true
        addTitlebarAccessoryViewController(collapseButton)
    }

    // Key only once the user clicks the Shelf to work with its Items, never when it opens or while a drag
    // hovers over it, so keystrokes normally stay with the app in front. The panel is non-activating, so even
    // when key the app doesn't come forward, and it gives the keys back as soon as the user clicks elsewhere.
    override var canBecomeKey: Bool { keyAllowed }

    func becomeKeyForUserClick() {
        keyAllowed = true
        makeKey()
    }

    override func resignKey() {
        super.resignKey()
        keyAllowed = false
    }

    /// Switches between the Stack and the expanded list, keeping the Shelf's top edge where it is.
    func showExpanded(_ expanded: Bool) {
        collapseButton.isHidden = !expanded
        let size = expanded ? Self.listSize : Self.stackSize
        var frame = frame
        frame.origin.y = frame.maxY - size.height
        frame.size = size
        setFrame(frame, display: true, animate: true)
    }

    func windowWillClose(_ notification: Notification) {
        windows?.panelClosed(shelfID)
    }

    func windowDidMove(_ notification: Notification) {
        windows?.panelMoved(shelfID, to: frame.origin)
    }
}

/// Watches whether a drag is hovering over a Shelf, so the view can highlight it.
@Observable
@MainActor
final class DropTarget {
    var isTargeted = false
}

/// The body of a Shelf's panel: takes Finder files dropped on it, and shows either the Stack, which starts
/// a drag of all its Items and expands when clicked, or the expanded list of Items.
final class ShelfItemsView: NSView, NSDraggingSource {
    private let shelfID: Shelf.ID
    private weak var windows: ShelfWindows?
    private let dropTarget = DropTarget()
    private let stack: NSView
    private let list = NSScrollView()
    private var itemList: ItemList?
    private var isExpanded = false
    private var mouseDownEvent: NSEvent?
    private var draggedItemIDs: [Item.ID] = []

    init(shelfID: Shelf.ID, windows: ShelfWindows) {
        self.shelfID = shelfID
        self.windows = windows
        stack = NSHostingView(rootView: ShelfContent(windows: windows, shelfID: shelfID, dropTarget: dropTarget))
        super.init(frame: .zero)
        registerForDraggedTypes([.fileURL])

        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        list.translatesAutoresizingMaskIntoConstraints = false
        list.drawsBackground = false
        list.hasVerticalScroller = true
        list.autohidesScrollers = true
        list.wantsLayer = true
        list.layer?.cornerRadius = 6
        list.layer?.borderColor = NSColor.controlAccentColor.cgColor
        list.isHidden = true
        addSubview(list)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            list.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            list.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            list.topAnchor.constraint(equalTo: topAnchor, constant: Self.titleStripHeight),
            list.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    // MARK: Stack and expanded list

    /// The user clicked the Stack: show single Items, and take the keys so they can act on a selection.
    private func expand() {
        guard !isExpanded, let windows, !items.isEmpty else { return }
        let itemList = ItemList(shelfID: shelfID, windows: windows) { [weak self] in self?.collapse() }
        self.itemList = itemList
        list.documentView = itemList
        isExpanded = true
        stack.isHidden = true
        list.isHidden = false
        let panel = window as? ShelfPanel
        panel?.showExpanded(true)
        panel?.becomeKeyForUserClick()
        panel?.makeFirstResponder(itemList)
    }

    @objc func collapse() {
        guard isExpanded else { return }
        if window?.firstResponder === itemList { window?.makeFirstResponder(nil) }
        list.documentView = nil
        itemList = nil
        isExpanded = false
        list.isHidden = true
        stack.isHidden = false
        (window as? ShelfPanel)?.showExpanded(false)
    }

    // On the Stack, clicks land here, not in the SwiftUI content, so a drag of the Items can start anywhere
    // on the Shelf; the expanded list handles its own clicks. The top strip is left to the window for moving
    // it and for the close and collapse buttons.
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard frame.contains(point) else { return nil }
        let local = convert(point, from: superview)
        if local.y > bounds.height - Self.titleStripHeight { return nil }
        return isExpanded ? super.hitTest(point) : self
    }

    private static let titleStripHeight: CGFloat = 28

    override var mouseDownCanMoveWindow: Bool { items.isEmpty }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private var items: [Item] {
        windows?.items(on: shelfID) ?? []
    }

    // MARK: Dropping onto the Shelf

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        // Dropping a Shelf's Items back onto the same Shelf is a no-op, so treat it as a cancelled drag.
        let source = sender.draggingSource as AnyObject?
        let fromThisShelf = source != nil && (source === self || source === itemList)
        guard !fromThisShelf, !fileURLs(in: sender).isEmpty else { return [] }
        setTargeted(true)
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        setTargeted(false)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        setTargeted(false)
        let urls = fileURLs(in: sender)
        return windows?.drop(urls, on: shelfID) ?? false
    }

    private func setTargeted(_ targeted: Bool) {
        dropTarget.isTargeted = targeted
        list.layer?.borderWidth = targeted ? 2 : 0
    }

    private func fileURLs(in info: NSDraggingInfo) -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        return info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] ?? []
    }

    // MARK: Dragging out of the Shelf

    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
    }

    override func mouseUp(with event: NSEvent) {
        // A click, not a drag: expand the Stack.
        guard mouseDownEvent != nil else { return }
        mouseDownEvent = nil
        expand()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let mouseDownEvent, let windows, draggedItemIDs.isEmpty else { return }
        // A little slack, so a slightly shaky click still expands the Stack instead of starting a drag.
        let start = mouseDownEvent.locationInWindow, now = event.locationInWindow
        guard hypot(now.x - start.x, now.y - start.y) > 3 else { return }
        let resolved = items.compactMap { item in windows.url(for: item).map { (item.id, $0) } }
        guard !resolved.isEmpty else { return }

        let draggingItems = resolved.map { _, url in
            let draggingItem = NSDraggingItem(pasteboardWriter: url as NSURL)
            draggingItem.setDraggingFrame(NSRect(x: bounds.midX - 32, y: bounds.midY - 32, width: 64, height: 64),
                                          contents: NSWorkspace.shared.icon(forFile: url.path))
            return draggingItem
        }
        draggedItemIDs = resolved.map(\.0)
        beginDraggingSession(with: draggingItems, event: mouseDownEvent, source: self)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        // Let the destination decide, as Finder does: move on the same volume, copy across volumes, ⌥ to copy.
        // No .delete or .link: a drop on the Trash or an alias gesture must not count as delivering the Items.
        [.copy, .move, .generic]
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        let ids = draggedItemIDs
        draggedItemIDs = []
        mouseDownEvent = nil
        windows?.dragOutEnded(ids, from: shelfID, accepted: operation != [])
    }

    // MARK: Context menu

    override func menu(for event: NSEvent) -> NSMenu? {
        guard !isExpanded, !items.isEmpty else { return nil }
        let menu = NSMenu()
        let showInFinder = NSMenuItem(title: "Show in Finder", action: #selector(showItemsInFinder), keyEquivalent: "")
        showInFinder.target = self
        menu.addItem(showInFinder)
        return menu
    }

    @objc private func showItemsInFinder() {
        let urls = items.compactMap { windows?.url(for: $0) }
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }
}

/// What a Shelf shows: a hint when empty, otherwise a small pile of its Items' icons and a count.
struct ShelfContent: View {
    let windows: ShelfWindows
    let shelfID: Shelf.ID
    let dropTarget: DropTarget

    var body: some View {
        let items = windows.items(on: shelfID)
        VStack(spacing: 8) {
            if items.isEmpty {
                Image(systemName: "tray.and.arrow.down")
                    .font(.system(size: 30))
                    .foregroundStyle(.secondary)
                Text("Drop files here")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ZStack {
                    ForEach(Array(items.prefix(3).enumerated().reversed()), id: \.element.id) { offset, item in
                        Image(nsImage: icon(for: item))
                            .resizable()
                            .frame(width: 64, height: 64)
                            .offset(x: CGFloat(offset) * 6, y: CGFloat(offset) * -6)
                    }
                }
                Text(label(for: items))
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.top, 16)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(dropTarget.isTargeted ? Color.accentColor : .clear, lineWidth: 2)
                .padding(4)
        }
    }

    private func icon(for item: Item) -> NSImage {
        guard let url = windows.url(for: item) else {
            return NSImage(systemSymbolName: "questionmark.square.dashed", accessibilityDescription: nil) ?? NSImage()
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    private func label(for items: [Item]) -> String {
        let missing = items.count { $0.isMissing }
        if items.count == 1 {
            return windows.name(for: items[0]) + (missing > 0 ? " (missing)" : "")
        }
        return "\(items.count) items" + (missing > 0 ? ", \(missing) missing" : "")
    }
}
