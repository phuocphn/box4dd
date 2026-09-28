import AppKit
import Carbon.HIToolbox
import QuickLookUI
import ShelfCore
import SwiftUI

/// The expanded Shelf: a list of its Items where single Items can be selected (click, ⌘-click, ⇧-click, ⌘A),
/// dragged out, previewed with space, copied with ⌘C and removed with ⌫. The selection is view state only.
final class ItemList: NSTableView, NSTableViewDataSource, NSTableViewDelegate, @preconcurrency QLPreviewPanelDataSource {
    private let shelfID: Shelf.ID
    private weak var windows: ShelfWindows?
    private let collapse: () -> Void
    private var rows: [Item] = []
    private var draggedItemIDs: [Item.ID] = []
    private var isControllingPreview = false

    init(shelfID: Shelf.ID, windows: ShelfWindows, collapse: @escaping () -> Void) {
        self.shelfID = shelfID
        self.windows = windows
        self.collapse = collapse
        super.init(frame: .zero)
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("item"))
        column.resizingMask = .autoresizingMask
        addTableColumn(column)
        columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
        headerView = nil
        style = .plain
        rowHeight = 26
        backgroundColor = .clear
        allowsMultipleSelection = true
        dataSource = self
        delegate = self
        // Same rule as dragging the Stack: move, copy or let the destination decide, but never delete or link.
        setDraggingSourceOperationMask([.copy, .move, .generic], forLocal: false)
        setDraggingSourceOperationMask([.copy, .move, .generic], forLocal: true)
        observeItems()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Keeps the rows in step with the Shelf, holding on to the selected Items that are still there.
    private func observeItems() {
        let items = withObservationTracking {
            windows?.items(on: shelfID) ?? []
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in self?.observeItems() }
        }
        let selected = Set(selectedItems.map(\.id))
        rows = items
        reloadData()
        selectRowIndexes(IndexSet(rows.indices.filter { selected.contains(rows[$0].id) }), byExtendingSelection: false)
    }

    private var selectedItems: [Item] {
        selectedRowIndexes.filter { $0 < rows.count }.map { rows[$0] }
    }

    /// The originals of the selected Items that can still be found.
    private var selectedURLs: [URL] {
        selectedItems.compactMap { windows?.url(for: $0) }
    }

    // MARK: Rows

    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let url = windows?.url(for: rows[row])
        return PassthroughHostingView(rootView: ItemRow(url: url))
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        ItemRowView()
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        if isControllingPreview { QLPreviewPanel.shared()?.reloadData() }
    }

    // MARK: Clicks and keys

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        (window as? ShelfPanel)?.becomeKeyForUserClick()
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }

    override func keyDown(with event: NSEvent) {
        switch Int(event.keyCode) {
        case kVK_Space: togglePreview()
        case kVK_Delete, kVK_ForwardDelete: removeSelection()
        case kVK_Escape: collapse()
        default: super.keyDown(with: event)
        }
    }

    // There's no main menu in a menu-bar-only app, so ⌘A and ⌘C are handled here.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard window?.firstResponder === self,
              event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command else {
            return super.performKeyEquivalent(with: event)
        }
        switch event.charactersIgnoringModifiers {
        case "a": selectAll(nil)
        case "c": copySelection()
        default: return super.performKeyEquivalent(with: event)
        }
        return true
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let row = row(at: convert(event.locationInWindow, from: nil))
        guard row >= 0 else { return nil }
        if !selectedRowIndexes.contains(row) {
            selectRowIndexes([row], byExtendingSelection: false)
        }
        let menu = NSMenu()
        let showInFinder = NSMenuItem(title: "Show in Finder", action: #selector(showSelectionInFinder), keyEquivalent: "")
        showInFinder.target = self
        showInFinder.isEnabled = !selectedURLs.isEmpty
        menu.autoenablesItems = false
        menu.addItem(showInFinder)
        return menu
    }

    // MARK: Item actions

    /// Takes the selected Items off the Shelf. Only the Shelf changes; the original files are never touched.
    private func removeSelection() {
        let ids = selectedItems.map(\.id)
        guard !ids.isEmpty else { return }
        windows?.remove(ids, from: shelfID)
    }

    /// Puts the selected Items' files on the clipboard, the way Finder's Copy does, so they paste in Finder.
    private func copySelection() {
        let urls = selectedURLs
        guard !urls.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects(urls as [NSURL])
    }

    @objc private func showSelectionInFinder() {
        let urls = selectedURLs
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    // MARK: Quick Look

    private func togglePreview() {
        guard let panel = QLPreviewPanel.shared() else { return }
        if isControllingPreview, panel.isVisible {
            panel.orderOut(nil)
        } else if !selectedURLs.isEmpty {
            // Ordered front, not made key, so the Shelf keeps the keys: space again closes it, arrows move the selection.
            panel.updateController()
            panel.orderFront(nil)
        }
    }

    // Collapsing the Shelf back to a Stack also closes a preview of its Items.
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil, isControllingPreview { QLPreviewPanel.shared()?.orderOut(nil) }
    }

    // Quick Look isn't annotated for concurrency, but it calls these on the main thread.
    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool { true }

    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        MainActor.assumeIsolated {
            isControllingPreview = true
            panel.dataSource = self
        }
    }

    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        MainActor.assumeIsolated {
            isControllingPreview = false
            panel.dataSource = nil
        }
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        selectedURLs.count
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        selectedURLs[index] as NSURL
    }

    // MARK: Dragging out a selection

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> (any NSPasteboardWriting)? {
        windows?.url(for: rows[row]).map { $0 as NSURL }
    }

    func tableView(_ tableView: NSTableView, draggingSession session: NSDraggingSession,
                   willBeginAt screenPoint: NSPoint, forRowIndexes rowIndexes: IndexSet) {
        draggedItemIDs = rowIndexes.filter { windows?.url(for: rows[$0]) != nil }.map { rows[$0].id }
    }

    func tableView(_ tableView: NSTableView, draggingSession session: NSDraggingSession,
                   endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        let ids = draggedItemIDs
        draggedItemIDs = []
        windows?.dragOutEnded(ids, from: shelfID, accepted: operation != [])
    }
}

/// One Item in the expanded Shelf.
struct ItemRow: View {
    let url: URL?

    var body: some View {
        HStack(spacing: 6) {
            Image(nsImage: url.map { NSWorkspace.shared.icon(forFile: $0.path) }
                  ?? NSImage(systemSymbolName: "questionmark.square.dashed", accessibilityDescription: nil) ?? NSImage())
                .resizable()
                .frame(width: 20, height: 20)
            Text(url?.lastPathComponent ?? "Unknown item")
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }
}

/// Lets clicks through to the list, which does all the selecting and dragging; SwiftUI only draws the row.
final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

/// A selected row stays a light highlight, since the SwiftUI row's text doesn't switch to white.
final class ItemRowView: NSTableRowView {
    override var isEmphasized: Bool {
        get { false }
        set {}
    }
}
