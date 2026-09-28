import Foundation

/// Where the Shelves are kept between launches. The app saves to a file; tests keep it in memory.
@MainActor
public protocol ShelfStore: AnyObject {
    func load() -> SavedShelves?
    func save(_ shelves: SavedShelves)
}

/// Everything that must survive a relaunch: the open Shelves with their positions, and the Recent Shelves.
public struct SavedShelves: Equatable, Sendable, Codable {
    public var openShelves: [Shelf]
    public var recentShelves: [Shelf]

    public init(openShelves: [Shelf], recentShelves: [Shelf]) {
        self.openShelves = openShelves
        self.recentShelves = recentShelves
    }
}
