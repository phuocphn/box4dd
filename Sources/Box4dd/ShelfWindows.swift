import AppKit
import ImageIO
import ShelfCore
import UniformTypeIdentifiers

/// Keeps one floating panel per open Shelf, and passes what the user does in the panels to the Shelf rules.
@MainActor
final class ShelfWindows {
    let shelves = Shelves(store: ShelfFile(), fileSystem: BookmarkFileSystem())
    private var panels: [Shelf.ID: ShelfPanel] = [:]
    private var originalsCheck: Timer?
    /// Promised files are received here, off the main thread, and moved into storage as they arrive.
    private let promiseQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.qualityOfService = .userInitiated
        return queue
    }()
    /// For each file promise being received: its Shelf, and its Placeholders still waiting, in the order
    /// the files are expected.
    private var waitingPromises: [UUID: (shelf: Shelf.ID, placeholders: [Item.ID])] = [:]

    /// Brings back the Shelves that were open at quit, where they were, and starts watching their originals.
    func restoreOpenShelves() {
        // Promises pending at quit died with it; the core already dropped their Placeholders.
        CapturedFiles.clearIncoming()
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
    @discardableResult
    func openShelf(at point: NSPoint) -> Shelf.ID {
        let id = shelves.openShelf()
        let panel = showPanel(for: id) { self.origin(centering: $0, on: point) }
        panelMoved(id, to: panel.frame.origin)
        return id
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

    /// Puts what was dropped or pasted on a Shelf: Finder files as Reference Items, anything else saved
    /// to the app's storage as Captured Items, and promised files as Placeholders that become Captured Items
    /// when the files arrive. Returns false when nothing could be kept, so a drag source sees the drop as refused.
    @discardableResult
    func add(_ contents: [PasteboardContent], to id: Shelf.ID) -> Bool {
        var items: [Item.Content] = []
        var promises: [(promise: UUID, placeholders: Range<Int>)] = []
        // Every promise in one drag must be received into the same folder.
        lazy var incoming = CapturedFiles.newIncomingFolder()
        for content in contents {
            switch content {
            case .file(let url):
                // A copied Captured Item pasted on a Shelf is still the app's own file, not a Finder file.
                if let file = CapturedFiles.file(at: url) {
                    items.append(.captured(file: file))
                } else if let bookmark = try? url.bookmarkData() {
                    items.append(.reference(bookmark: bookmark))
                }
            case .promise(let receiver):
                let promise = UUID()
                receive(receiver, into: incoming, as: promise)
                // The names are known only once the promise is called in; a promise may hold several files.
                let names: [String?] = receiver.fileNames.isEmpty ? [nil] : receiver.fileNames
                promises.append((promise, items.count..<items.count + names.count))
                items += names.map { .placeholder(name: $0) }
            default:
                if let file = CapturedFiles.save(content) { items.append(.captured(file: file)) }
            }
        }
        guard !items.isEmpty else { return false }
        let dropped = shelves.drop(items, on: id)
        for (promise, placeholders) in promises where dropped.count == items.count {
            waitingPromises[promise] = (id, Array(dropped[placeholders]))
        }
        return true
    }

    /// Calls in a promised file. The reader runs on `promiseQueue`, where the file is only sure to be
    /// complete inside the block, so it's moved into storage there before the core hears of it.
    private func receive(_ receiver: NSFilePromiseReceiver, into folder: URL, as promise: UUID) {
        receiver.receivePromisedFiles(atDestination: folder, options: [:], operationQueue: promiseQueue) { @Sendable [weak self] url, error in
            if let error { NSLog("box4dd: a promised file didn't arrive: \(error)") }
            let file = error == nil ? CapturedFiles.take(url) : nil
            Task { @MainActor in
                guard let self else {
                    if let file { CapturedFiles.delete(file) }
                    return
                }
                self.promisedFile(file, arrivedFor: promise)
            }
        }
    }

    /// A promised file arrived in storage, or failed (nil). It fills the promise's next Placeholder; a file
    /// beyond the Placeholders, from a promise that didn't name its files, is added next to them.
    private func promisedFile(_ file: String?, arrivedFor promise: UUID) {
        guard let waiting = waitingPromises[promise] else {
            if let file { CapturedFiles.delete(file) }
            return
        }
        guard let placeholder = waiting.placeholders.first else {
            if let file, shelves.drop([.captured(file: file)], on: waiting.shelf).isEmpty {
                CapturedFiles.delete(file)
            }
            return
        }
        waitingPromises[promise]?.placeholders.removeFirst()
        if let file {
            shelves.promisedFileArrived(placeholder, file: file)
            return
        }
        guard case .placeholder(let name) = shelves.shelf(waiting.shelf)?.items.first(where: { $0.id == placeholder })?.content else { return }
        shelves.promisedFileFailed(placeholder)
        if let panel = panels[waiting.shelf], shelves.shelf(waiting.shelf) != nil {
            panel.showNotice(name.map { "Couldn't get \($0)" } ?? "A promised file didn't arrive")
        } else {
            NSSound.beep()
        }
        closePanelsOfClosedShelves()
    }

    /// ⌘V on a Shelf.
    func paste(on id: Shelf.ID) -> Bool {
        add(PasteboardContent.read(from: .general, takingPromises: false), to: id)
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
        case .placeholder: nil
        }
    }

    /// The Item's name, which a Missing Item keeps from when it was dropped, and a Placeholder has only if
    /// its promise named its file.
    func name(for item: Item) -> String {
        if let file = item.capturedFile { return URL(filePath: file).lastPathComponent }
        if case .placeholder(let name) = item.content { return name ?? "Arriving file" }
        return url(for: item)?.lastPathComponent ?? item.bookmark.flatMap(BookmarkFileSystem.savedName(in:)) ?? "Unknown item"
    }

    /// A captured image shows itself; everything else shows its file's icon.
    func icon(for item: Item) -> NSImage {
        guard let url = url(for: item) else {
            return NSImage(systemSymbolName: "questionmark.square.dashed", accessibilityDescription: nil) ?? NSImage()
        }
        if let file = item.capturedFile, UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true {
            if let cached = thumbnails[file] { return cached }
            if let image = Self.thumbnail(of: url) {
                thumbnails[file] = image
                return image
            }
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    /// A small copy of an image, so a large photo isn't decoded in full just to show its icon.
    private static func thumbnail(of url: URL) -> NSImage? {
        let options = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true,
                       kCGImageSourceThumbnailMaxPixelSize: 256] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
        return NSImage(cgImage: image, size: .zero)
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
