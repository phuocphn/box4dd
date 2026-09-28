import Foundation
import Observation

/// A temporary floating place that holds Items until they are dragged out together.
public struct Shelf: Identifiable, Equatable, Sendable {
    public let id: UUID
    public internal(set) var items: [Item]
}

/// One thing held on a Shelf. A Reference Item points to a file or folder the Shelf does not own.
public struct Item: Identifiable, Equatable, Sendable {
    public let id: UUID
    /// Opaque bookmark to the original; only the app layer resolves it.
    public let bookmark: Data
}

/// The open Shelves and the rules for what happens to them as the user drags things in and out.
@MainActor
@Observable
public final class Shelves {
    public private(set) var openShelves: [Shelf] = []

    public init() {}

    @discardableResult
    public func openShelf() -> Shelf.ID {
        let shelf = Shelf(id: UUID(), items: [])
        openShelves.append(shelf)
        return shelf.id
    }

    public func close(_ id: Shelf.ID) {
        openShelves.removeAll { $0.id == id }
    }

    public func shelf(_ id: Shelf.ID) -> Shelf? {
        openShelves.first { $0.id == id }
    }

    /// Finder files or folders were dropped on a Shelf; each becomes a Reference Item.
    public func drop(references bookmarks: [Data], on id: Shelf.ID) {
        guard let index = openShelves.firstIndex(where: { $0.id == id }) else { return }
        openShelves[index].items += bookmarks.map { Item(id: UUID(), bookmark: $0) }
    }

    /// A drag of some Items out of a Shelf finished. Items that were dropped somewhere leave the Shelf,
    /// and a Shelf left empty closes itself.
    public func dragOutEnded(_ itemIDs: [Item.ID], from id: Shelf.ID, accepted: Bool) {
        guard accepted, let index = openShelves.firstIndex(where: { $0.id == id }) else { return }
        openShelves[index].items.removeAll { itemIDs.contains($0.id) }
        if openShelves[index].items.isEmpty {
            openShelves.remove(at: index)
        }
    }
}
