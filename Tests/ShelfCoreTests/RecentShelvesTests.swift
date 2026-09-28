import Foundation
import Testing
import ShelfCore

@MainActor
struct RecentShelvesTests {
    @Test func closingAShelfByHandMovesItToRecentShelves() {
        let shelves = Shelves()
        let id = shelves.openShelf()
        shelves.drop(references: [bookmark("a"), bookmark("b")], on: id)

        shelves.close(id)

        #expect(shelves.recentShelves.map(\.id) == [id])
        #expect(shelves.recentShelves.first?.items.map(\.bookmark) == [bookmark("a"), bookmark("b")])
    }

    @Test func aShelfEmptiedByDraggingOutMovesToRecentShelvesWithTheItemsOfItsLastDrag() throws {
        let shelves = Shelves()
        let id = shelves.openShelf()
        shelves.drop(references: [bookmark("a"), bookmark("b"), bookmark("c")], on: id)
        let items = try #require(shelves.shelf(id)?.items)
        shelves.dragOutEnded([items[0].id], from: id, accepted: true)

        shelves.dragOutEnded([items[1].id, items[2].id], from: id, accepted: true)

        #expect(shelves.openShelves.isEmpty)
        #expect(shelves.recentShelves.map(\.id) == [id])
        #expect(shelves.recentShelves.first?.items.map(\.bookmark) == [bookmark("b"), bookmark("c")])
    }

    @Test func aShelfEmptiedByRemovingItemsMovesToRecentShelvesWithTheItemsLastOnIt() throws {
        let shelves = Shelves()
        let id = shelves.openShelf()
        shelves.drop(references: [bookmark("a"), bookmark("b")], on: id)
        let items = try #require(shelves.shelf(id)?.items)
        shelves.remove([items[0].id], from: id)

        shelves.remove([items[1].id], from: id)

        #expect(shelves.openShelves.isEmpty)
        #expect(shelves.recentShelves.map(\.id) == [id])
        #expect(shelves.recentShelves.first?.items.map(\.bookmark) == [bookmark("b")])
    }

    @Test func recentShelvesAreNewestFirst() {
        let shelves = Shelves()
        let first = shelfWithItem(on: shelves)
        let second = shelfWithItem(on: shelves)
        let third = shelfWithItem(on: shelves)

        shelves.close(second)
        shelves.close(first)
        shelves.close(third)

        #expect(shelves.recentShelves.map(\.id) == [third, first, second])
    }

    @Test func aRecentShelfRemembersWhenItWasClosedUntilItIsReopened() {
        var now = Date(timeIntervalSinceReferenceDate: 1_000)
        let shelves = Shelves(now: { now })
        let id = shelfWithItem(on: shelves)
        now = Date(timeIntervalSinceReferenceDate: 2_000)

        shelves.close(id)
        #expect(shelves.recentShelves.first?.closedAt == Date(timeIntervalSinceReferenceDate: 2_000))

        shelves.reopen(id)
        #expect(shelves.shelf(id)?.closedAt == nil)
    }

    @Test func aShelfClosedWithNoItemsIsNotKept() {
        let shelves = Shelves()
        let id = shelves.openShelf()

        shelves.close(id)

        #expect(shelves.openShelves.isEmpty)
        #expect(shelves.recentShelves.isEmpty)
    }

    @Test func onlyTheLastTenRecentShelvesAreKeptAndTheOldestIsDroppedFirst() {
        let shelves = Shelves()
        let ids = (0..<11).map { _ in shelfWithItem(on: shelves) }

        for id in ids { shelves.close(id) }

        #expect(shelves.recentShelves.count == 10)
        #expect(shelves.recentShelves.map(\.id) == Array(ids[1...].reversed()))
    }

    @Test func reopeningARecentShelfRestoresItsItemsAndTakesItOffTheRecentList() {
        let shelves = Shelves()
        let reopened = shelves.openShelf()
        shelves.drop(references: [bookmark("a"), bookmark("b")], on: reopened)
        let other = shelfWithItem(on: shelves)
        shelves.close(reopened)
        shelves.close(other)

        shelves.reopen(reopened)

        #expect(shelves.openShelves.map(\.id) == [reopened])
        #expect(shelves.shelf(reopened)?.items.map(\.bookmark) == [bookmark("a"), bookmark("b")])
        #expect(shelves.recentShelves.map(\.id) == [other])
    }

    @Test func aShelfIsWhereItWasOpenedUntilItIsMoved() {
        let shelves = Shelves()
        let moved = shelves.openShelf(at: ShelfPosition(x: 100, y: 200))
        let other = shelves.openShelf(at: ShelfPosition(x: 5, y: 6))

        shelves.shelfMoved(moved, to: ShelfPosition(x: 300, y: 400))

        #expect(shelves.shelf(moved)?.position == ShelfPosition(x: 300, y: 400))
        #expect(shelves.shelf(other)?.position == ShelfPosition(x: 5, y: 6))
    }

    @Test func openShelvesReopenAfterARelaunchWhereTheyWereWithTheirItems() {
        let store = MemoryStore()
        let before = Shelves(store: store)
        let first = before.openShelf(at: ShelfPosition(x: 10, y: 20))
        before.drop(references: [bookmark("a"), bookmark("b")], on: first)
        let second = before.openShelf(at: ShelfPosition(x: 30, y: 40))
        before.shelfMoved(second, to: ShelfPosition(x: 50, y: 60))

        let after = Shelves(store: store)

        #expect(after.openShelves.map(\.id) == [first, second])
        #expect(after.shelf(first)?.items.map(\.bookmark) == [bookmark("a"), bookmark("b")])
        #expect(after.shelf(first)?.position == ShelfPosition(x: 10, y: 20))
        #expect(after.shelf(second)?.items == [])
        #expect(after.shelf(second)?.position == ShelfPosition(x: 50, y: 60))
    }

    @Test func recentShelvesSurviveARelaunch() {
        let store = MemoryStore()
        let before = Shelves(store: store)
        let older = before.openShelf()
        before.drop(references: [bookmark("a")], on: older)
        let newer = before.openShelf()
        before.drop(references: [bookmark("b")], on: newer)
        before.close(older)
        before.close(newer)

        let after = Shelves(store: store)

        #expect(after.openShelves.isEmpty)
        #expect(after.recentShelves.map(\.id) == [newer, older])
        #expect(after.recentShelves.map { $0.items.map(\.bookmark) } == [[bookmark("b")], [bookmark("a")]])
    }

    @Test func anItemWhoseOriginalWasDeletedStaysOnTheShelfAsAMissingItem() {
        let fileSystem = TestFileSystem()
        let shelves = Shelves(fileSystem: fileSystem)
        let id = shelves.openShelf()
        shelves.drop(references: [bookmark("a"), bookmark("b")], on: id)
        fileSystem.originals[bookmark("a")] = .deleted

        shelves.checkOriginals()

        #expect(shelves.shelf(id)?.items.map(\.bookmark) == [bookmark("a"), bookmark("b")])
        #expect(shelves.shelf(id)?.items.map(\.isMissing) == [true, false])
    }

    @Test func aMissingItemWhoseOriginalComesBackIsNoLongerMissing() {
        let fileSystem = TestFileSystem()
        let shelves = Shelves(fileSystem: fileSystem)
        let id = shelves.openShelf()
        shelves.drop(references: [bookmark("a")], on: id)
        fileSystem.originals[bookmark("a")] = .deleted
        shelves.checkOriginals()

        fileSystem.originals[bookmark("a")] = .present
        shelves.checkOriginals()

        #expect(shelves.shelf(id)?.items.map(\.isMissing) == [false])
    }

    @Test func anItemWhoseOriginalMovedKeepsFollowingItWithARefreshedBookmark() {
        let fileSystem = TestFileSystem()
        let shelves = Shelves(fileSystem: fileSystem)
        let id = shelves.openShelf()
        shelves.drop(references: [bookmark("a"), bookmark("b")], on: id)
        fileSystem.originals[bookmark("a")] = .moved(refreshedBookmark: bookmark("a-moved"))

        shelves.checkOriginals()

        #expect(shelves.shelf(id)?.items.map(\.bookmark) == [bookmark("a-moved"), bookmark("b")])
        #expect(shelves.shelf(id)?.items.map(\.isMissing) == [false, false])
    }

    @Test func aRecentShelfReopensWithMissingItemsMarked() {
        let fileSystem = TestFileSystem()
        let shelves = Shelves(fileSystem: fileSystem)
        let id = shelves.openShelf()
        shelves.drop(references: [bookmark("a"), bookmark("b")], on: id)
        shelves.close(id)
        fileSystem.originals[bookmark("b")] = .deleted

        shelves.checkOriginals()
        shelves.reopen(id)

        #expect(shelves.shelf(id)?.items.map(\.isMissing) == [false, true])
    }
}

/// Answers for each bookmark what happened to its original; anything not listed is still in place.
@MainActor
private final class TestFileSystem: FileSystem {
    var originals: [Data: Original] = [:]

    func original(of bookmark: Data) -> Original { originals[bookmark] ?? .present }
}

/// Keeps what the Shelves save in memory, standing in for the file on disk across a relaunch.
@MainActor
private final class MemoryStore: ShelfStore {
    private var saved: SavedShelves?

    func load() -> SavedShelves? { saved }
    func save(_ shelves: SavedShelves) { saved = shelves }
}

/// Opens a Shelf holding one Reference Item, so closing it keeps it in Recent Shelves.
@MainActor
private func shelfWithItem(on shelves: Shelves) -> Shelf.ID {
    let id = shelves.openShelf()
    shelves.drop(references: [bookmark("x")], on: id)
    return id
}

/// Stand-in bookmark bytes; the core treats bookmarks as opaque.
private func bookmark(_ name: String) -> Data { Data(name.utf8) }
