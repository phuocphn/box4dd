import AppKit
import ShelfCore
import SwiftUI

/// The floating window for one Shelf: above normal windows, on every Space and over full-screen apps,
/// and never activating the app, so the app the user is dragging from keeps focus.
final class ShelfPanel: NSPanel, NSWindowDelegate {
    private let shelfID: Shelf.ID
    private weak var windows: ShelfWindows?

    init(shelfID: Shelf.ID, windows: ShelfWindows) {
        self.shelfID = shelfID
        self.windows = windows
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 150, height: 160),
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
        contentView = ShelfItemsView(shelfID: shelfID, windows: windows)
    }

    // Never key: keystrokes keep going to the app the user is working in.
    override var canBecomeKey: Bool { false }

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

/// The body of a Shelf's panel: takes Finder files dropped on it, and starts a drag of all its Items.
final class ShelfItemsView: NSView, NSDraggingSource {
    private let shelfID: Shelf.ID
    private weak var windows: ShelfWindows?
    private let dropTarget = DropTarget()
    private var mouseDownEvent: NSEvent?
    private var draggedItemIDs: [Item.ID] = []

    init(shelfID: Shelf.ID, windows: ShelfWindows) {
        self.shelfID = shelfID
        self.windows = windows
        super.init(frame: .zero)
        registerForDraggedTypes([.fileURL])

        let content = NSHostingView(rootView: ShelfContent(windows: windows, shelfID: shelfID, dropTarget: dropTarget))
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: leadingAnchor),
            content.trailingAnchor.constraint(equalTo: trailingAnchor),
            content.topAnchor.constraint(equalTo: topAnchor),
            content.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    // Clicks land here, not in the SwiftUI content, so a drag of the Items can start anywhere on the Shelf,
    // except the top strip, which is left to the window for moving it and for the close button.
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard frame.contains(point) else { return nil }
        let local = convert(point, from: superview)
        return local.y > bounds.height - Self.titleStripHeight ? nil : self
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
        guard sender.draggingSource as? ShelfItemsView !== self, !fileURLs(in: sender).isEmpty else { return [] }
        dropTarget.isTargeted = true
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        dropTarget.isTargeted = false
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        dropTarget.isTargeted = false
        let urls = fileURLs(in: sender)
        return windows?.drop(urls, on: shelfID) ?? false
    }

    private func fileURLs(in info: NSDraggingInfo) -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        return info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] ?? []
    }

    // MARK: Dragging out of the Shelf

    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
    }

    override func mouseDragged(with event: NSEvent) {
        guard let mouseDownEvent, let windows, draggedItemIDs.isEmpty else { return }
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
