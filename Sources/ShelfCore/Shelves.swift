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

// Saved flat, as `bookmark` or `capturedFile`, so Shelves saved before Captured Items still load.
extension Item: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, bookmark, capturedFile, isMissing
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        if let file = try container.decodeIfPresent(String.self, forKey: .capturedFile) {
            content = .captured(file: file)
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

    /// Picks up the Shelves saved before the last quit, so open Shelves come back where they were.
    public init(store: (any ShelfStore)? = nil, fileSystem: (any FileSystem)? = nil, now: @escaping () -> Date = Date.init) {
        self.store = store
        self.fileSystem = fileSystem
        self.now = now
        if let saved = store?.load() {
            openShelves = saved.openShelves
            recentShelves = saved.recentShelves
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
    /// has saved to its storage as Captured Items, in the order given.
    public func drop(_ contents: [Item.Content], on id: Shelf.ID) {
        guard let index = openShelves.firstIndex(where: { $0.id == id }) else { return }
        openShelves[index].items += contents.map { Item(id: UUID(), content: $0) }
    }

    /// A drag of some Items out of a Shelf finished. Items that were dropped somewhere leave the Shelf.
    public func dragOutEnded(_ itemIDs: [Item.ID], from id: Shelf.ID, accepted: Bool) {
        guard accepted else { return }
        remove(itemIDs, from: id)
    }

    /// Some Items left a Shelf, by drag-out or by the user removing them. A Reference Item's original is
    /// never touched. A Shelf left empty closes itself and goes to Recent Shelves holding the Items that
    /// were last on it, so they can be reopened. A Captured Item's file is kept until its Shelf falls off
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

    /// Only the last 10 are kept. A Shelf with no Items has nothing to reopen, so it isn't kept.
    private func moveToRecent(_ shelf: Shelf) {
        guard !shelf.items.isEmpty else { return }
        var shelf = shelf
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
