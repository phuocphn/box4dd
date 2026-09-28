import Foundation
import Observation

/// A temporary floating place that holds Items until they are dragged out together.
public struct Shelf: Identifiable, Equatable, Sendable, Codable {
    public let id: UUID
    public internal(set) var items: [Item]
    public internal(set) var position: ShelfPosition = .init(x: 0, y: 0)
    /// When a Recent Shelf was closed; nil while the Shelf is open.
    public internal(set) var closedAt: Date?
    /// Files of Captured Items that left this Shelf while it stayed open. A drop target may read a delivered
    /// file late, so they are kept until the Shelf falls off Recent Shelves, and deleted with the rest.
    var releasedFiles: [String] = []

    /// Every Captured Item file this Shelf still answers for.
    var capturedFiles: [String] {
        items.compactMap(\.capturedFile) + releasedFiles
    }
}

// Shelves saved before Captured Items have no released files.
extension Shelf {
    private enum CodingKeys: String, CodingKey {
        case id, items, position, closedAt, releasedFiles
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        items = try container.decode([Item].self, forKey: .items)
        position = try container.decode(ShelfPosition.self, forKey: .position)
        closedAt = try container.decodeIfPresent(Date.self, forKey: .closedAt)
        releasedFiles = try container.decodeIfPresent([String].self, forKey: .releasedFiles) ?? []
    }
}

/// Where a Shelf sits on screen, in the app's screen coordinates (the core only stores it).
public struct ShelfPosition: Equatable, Sendable, Codable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// One thing held on a Shelf: a Reference Item or a Captured Item.
public struct Item: Identifiable, Equatable, Sendable {
    public let id: UUID
    public internal(set) var content: Content
    /// A Missing Item: its original was deleted. It stays on the Shelf, marked as missing.
    public internal(set) var isMissing = false

    public enum Content: Equatable, Sendable {
        /// A Reference Item points to a file or folder the Shelf does not own. The bookmark is opaque;
        /// only the app layer resolves it.
        case reference(bookmark: Data)
        /// A Captured Item is a file the Shelf created and owns, named by its path in the app's storage.
        case captured(file: String)
        /// A Placeholder stands in for a file another app promised but hasn't delivered yet, named as the
        /// promise names it, if it does. It can't be dragged out; it becomes a Captured Item when the file
        /// arrives, and leaves the Shelf if it never does.
        case placeholder(name: String?)
    }

    /// Whether this Item is still waiting for its promised file.
    public var isPlaceholder: Bool {
        if case .placeholder = content { true } else { false }
    }

    /// A Reference Item's bookmark; nil for a Captured Item.
    public var bookmark: Data? {
        if case .reference(let bookmark) = content { bookmark } else { nil }
    }

    /// A Captured Item's file; nil for a Reference Item.
    public var capturedFile: String? {
        if case .captured(let file) = content { file } else { nil }
    }
}

// Saved flat, as `bookmark`, `capturedFile` or `placeholder`, so Shelves saved before Captured Items still load.
// A Placeholder is saved only so the Shelves file stays readable; it's dropped on load.
extension Item: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, bookmark, capturedFile, placeholder, isMissing
    }

    /// What's saved for a Placeholder.
    private struct SavedPlaceholder: Codable {
        var name: String?
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        if let file = try container.decodeIfPresent(String.self, forKey: .capturedFile) {
            content = .captured(file: file)
        } else if let placeholder = try container.decodeIfPresent(SavedPlaceholder.self, forKey: .placeholder) {
            content = .placeholder(name: placeholder.name)
        } else {
            content = .reference(bookmark: try container.decode(Data.self, forKey: .bookmark))
        }
        isMissing = try container.decodeIfPresent(Bool.self, forKey: .isMissing) ?? false
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(bookmark, forKey: .bookmark)
        try container.encodeIfPresent(capturedFile, forKey: .capturedFile)
        if case .placeholder(let name) = content {
            try container.encode(SavedPlaceholder(name: name), forKey: .placeholder)
        }
        try container.encode(isMissing, forKey: .isMissing)
    }
}

/// The open Shelves and the rules for what happens to them as the user drags things in and out.
@MainActor
@Observable
public final class Shelves {
    public private(set) var openShelves: [Shelf] = [] {
        didSet { save() }
    }
    /// Closed Shelves that can still be reopened, newest first.
    public private(set) var recentShelves: [Shelf] = [] {
        didSet { save() }
    }

    private let store: (any ShelfStore)?
    private let fileSystem: (any FileSystem)?
    private let now: () -> Date

    /// Picks up the Shelves saved before the last quit, so open Shelves come back where they were. Promises
    /// die with the app that received them, so Placeholders don't come back, and a Shelf that held only
    /// Placeholders is gone.
    public init(store: (any ShelfStore)? = nil, fileSystem: (any FileSystem)? = nil, now: @escaping () -> Date = Date.init) {
        self.store = store
        self.fileSystem = fileSystem
        self.now = now
        if let saved = store?.load() {
            openShelves = saved.openShelves
            recentShelves = saved.recentShelves
        }
        let placeholders = openShelves.flatMap(\.items).filter(\.isPlaceholder).map(\.id)
        for id in placeholders {
            promisedFileFailed(id)
        }
    }

    private func save() {
        store?.save(SavedShelves(openShelves: openShelves, recentShelves: recentShelves))
    }

    @discardableResult
    public func openShelf(at position: ShelfPosition = .init(x: 0, y: 0)) -> Shelf.ID {
        let shelf = Shelf(id: UUID(), items: [], position: position)
        openShelves.append(shelf)
        return shelf.id
    }

    public func close(_ id: Shelf.ID) {
        guard let index = openShelves.firstIndex(where: { $0.id == id }) else { return }
        moveToRecent(openShelves.remove(at: index))
    }

    /// The user moved a Shelf's window.
    public func shelfMoved(_ id: Shelf.ID, to position: ShelfPosition) {
        guard let index = openShelves.firstIndex(where: { $0.id == id }) else { return }
        openShelves[index].position = position
    }

    /// Opens a Recent Shelf again with its Items; it leaves the Recent list.
    public func reopen(_ id: Shelf.ID) {
        guard let index = recentShelves.firstIndex(where: { $0.id == id }) else { return }
        var shelf = recentShelves.remove(at: index)
        shelf.closedAt = nil
        openShelves.append(shelf)
    }

    public func shelf(_ id: Shelf.ID) -> Shelf? {
        openShelves.first { $0.id == id }
    }

    /// Finder files or folders were dropped on a Shelf; each becomes a Reference Item.
    public func drop(references bookmarks: [Data], on id: Shelf.ID) {
        drop(bookmarks.map { .reference(bookmark: $0) }, on: id)
    }

    /// Things were dropped or pasted on a Shelf: Finder files as Reference Items, and content the app
    /// has saved to its storage as Captured Items, and promised files as Placeholders, in the order given.
    /// Returns the new Items' IDs in that order, so the app can tell the core when a promised file arrives.
    @discardableResult
    public func drop(_ contents: [Item.Content], on id: Shelf.ID) -> [Item.ID] {
        guard let index = openShelves.firstIndex(where: { $0.id == id }) else { return [] }
        let items = contents.map { Item(id: UUID(), content: $0) }
        openShelves[index].items += items
        return items.map(\.id)
    }

    /// The file another app promised for a Placeholder arrived in the app's storage: the Placeholder
    /// becomes a Captured Item holding it, in the same place on its Shelf. A file that arrives for a
    /// Placeholder no longer on an open Shelf has nowhere to go, so it's deleted.
    public func promisedFileArrived(_ itemID: Item.ID, file: String) {
        guard let (shelf, item) = placeholder(itemID) else {
            fileSystem?.deleteCapturedFile(file)
            return
        }
        openShelves[shelf].items[item].content = .captured(file: file)
    }

    /// The file another app promised for a Placeholder never came: the Placeholder leaves its Shelf. A Shelf
    /// left empty closes itself, but there's nothing to reopen, so it doesn't go to Recent Shelves.
    public func promisedFileFailed(_ itemID: Item.ID) {
        guard let (shelf, item) = placeholder(itemID) else { return }
        openShelves[shelf].items.remove(at: item)
        if openShelves[shelf].items.isEmpty {
            moveToRecent(openShelves.remove(at: shelf))
        }
    }

    private func placeholder(_ itemID: Item.ID) -> (shelf: Int, item: Int)? {
        for (shelf, open) in openShelves.enumerated() {
            if let item = open.items.firstIndex(where: { $0.id == itemID && $0.isPlaceholder }) {
                return (shelf, item)
            }
        }
        return nil
    }

    /// A drag of some Items out of a Shelf finished. Items that were dropped somewhere leave the Shelf.
    /// A Placeholder has nothing to deliver yet, so it's never part of a drag-out.
    public func dragOutEnded(_ itemIDs: [Item.ID], from id: Shelf.ID, accepted: Bool) {
        guard accepted, let shelf = shelf(id) else { return }
        let placeholders = Set(shelf.items.filter(\.isPlaceholder).map(\.id))
        remove(itemIDs.filter { !placeholders.contains($0) }, from: id)
    }

    /// Some Items left a Shelf, by drag-out or by the user removing them. A Reference Item's original is
    /// never touched, and removing a Placeholder gives up on its promised file. A Shelf left empty closes
    /// itself and goes to Recent Shelves holding the Items that were last on it, so they can be reopened. A Captured Item's file is kept until its Shelf falls off
    /// Recent Shelves.
    public func remove(_ itemIDs: [Item.ID], from id: Shelf.ID) {
        guard let index = openShelves.firstIndex(where: { $0.id == id }) else { return }
        let lastItems = openShelves[index].items
        openShelves[index].items.removeAll { itemIDs.contains($0.id) }
        if openShelves[index].items.isEmpty {
            var emptied = openShelves.remove(at: index)
            emptied.items = lastItems
            moveToRecent(emptied)
        } else {
            openShelves[index].releasedFiles += lastItems.filter { itemIDs.contains($0.id) }.compactMap(\.capturedFile)
        }
    }

    /// Asks the file system about every Reference Item's original, open or Recent: moved originals get
    /// a refreshed bookmark, deleted ones make Missing Items, and ones that came back are no longer missing.
    public func checkOriginals() {
        guard let fileSystem else { return }
        func check(_ shelves: [Shelf]) -> [Shelf] {
            shelves.map { shelf in
                var shelf = shelf
                for index in shelf.items.indices {
                    guard let bookmark = shelf.items[index].bookmark else { continue }
                    switch fileSystem.original(of: bookmark) {
                    case .present:
                        shelf.items[index].isMissing = false
                    case .moved(let refreshed):
                        shelf.items[index].content = .reference(bookmark: refreshed)
                        shelf.items[index].isMissing = false
                    case .deleted:
                        shelf.items[index].isMissing = true
                    }
                }
                return shelf
            }
        }
        let checkedOpen = check(openShelves)
        let checkedRecent = check(recentShelves)
        // Assign only on change, so a routine check doesn't redraw every Shelf or rewrite the saved file.
        if checkedOpen != openShelves { openShelves = checkedOpen }
        if checkedRecent != recentShelves { recentShelves = checkedRecent }
    }

    /// Only the last 10 are kept. Placeholders are dropped: a file promised for a closed Shelf is deleted
    /// when it arrives. A Shelf with no other Items has nothing to reopen, so it isn't kept, and it's gone
    /// for good at once.
    private func moveToRecent(_ shelf: Shelf) {
        var shelf = shelf
        shelf.items.removeAll(where: \.isPlaceholder)
        guard !shelf.items.isEmpty else {
            discardCapturedFiles(of: shelf)
            return
        }
        shelf.closedAt = now()
        let all = [shelf] + recentShelves
        recentShelves = Array(all.prefix(Self.recentLimit))
        for evicted in all.dropFirst(Self.recentLimit) {
            discardCapturedFiles(of: evicted)
        }
    }

    /// A Shelf is gone for good, so the files of its Captured Items are no longer needed, unless a Captured
    /// Item was dragged onto another Shelf that still holds its file. Reference Items are never deleted.
    private func discardCapturedFiles(of shelf: Shelf) {
        let stillHeld = Set((openShelves + recentShelves).flatMap(\.capturedFiles))
        for file in shelf.capturedFiles where !stillHeld.contains(file) {
            fileSystem?.deleteCapturedFile(file)
        }
    }

    private static let recentLimit = 10
}
