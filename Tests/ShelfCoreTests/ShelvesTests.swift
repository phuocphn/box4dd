import Foundation
import Testing
import ShelfCore

@MainActor
struct ShelvesTests {
    @Test func openingAShelfShowsAnEmptyShelf() {
        let shelves = Shelves()

        let id = shelves.openShelf()

        #expect(shelves.openShelves.map(\.id) == [id])
        #expect(shelves.openShelves.first?.items == [])
    }

    @Test func droppingFilesAddsReferenceItemsToThatShelfOnly() {
        let shelves = Shelves()
        let target = shelves.openShelf()
        let other = shelves.openShelf()

        shelves.drop(references: [bookmark("a"), bookmark("b")], on: target)

        #expect(shelves.shelf(target)?.items.map(\.bookmark) == [bookmark("a"), bookmark("b")])
        #expect(shelves.shelf(other)?.items == [])
    }

    @Test func itemsDroppedSomewhereLeaveTheShelf() throws {
        let shelves = Shelves()
        let id = shelves.openShelf()
        shelves.drop(references: [bookmark("a"), bookmark("b"), bookmark("c")], on: id)
        let items = try #require(shelves.shelf(id)?.items)

        shelves.dragOutEnded([items[0].id, items[2].id], from: id, accepted: true)

        #expect(shelves.shelf(id)?.items.map(\.bookmark) == [bookmark("b")])
    }

    @Test func itemsFromACancelledDragStayOnTheShelf() throws {
        let shelves = Shelves()
        let id = shelves.openShelf()
        shelves.drop(references: [bookmark("a"), bookmark("b")], on: id)
        let items = try #require(shelves.shelf(id)?.items)

        shelves.dragOutEnded(items.map(\.id), from: id, accepted: false)

        #expect(shelves.shelf(id)?.items.map(\.bookmark) == [bookmark("a"), bookmark("b")])
    }

    @Test func aShelfEmptiedByDraggingOutClosesItself() throws {
        let shelves = Shelves()
        let emptied = shelves.openShelf()
        let other = shelves.openShelf()
        shelves.drop(references: [bookmark("a"), bookmark("b")], on: emptied)
        let items = try #require(shelves.shelf(emptied)?.items)

        shelves.dragOutEnded(items.map(\.id), from: emptied, accepted: true)

        #expect(shelves.openShelves.map(\.id) == [other])
    }

    @Test func removingSelectedItemsTakesOnlyThoseOffTheShelf() throws {
        let shelves = Shelves()
        let id = shelves.openShelf()
        shelves.drop(references: [bookmark("a"), bookmark("b"), bookmark("c")], on: id)
        let items = try #require(shelves.shelf(id)?.items)

        shelves.remove([items[0].id, items[2].id], from: id)

        #expect(shelves.shelf(id)?.items.map(\.bookmark) == [bookmark("b")])
    }

    @Test func aShelfEmptiedByRemovingItemsClosesItself() throws {
        let shelves = Shelves()
        let emptied = shelves.openShelf()
        let other = shelves.openShelf()
        shelves.drop(references: [bookmark("a"), bookmark("b")], on: emptied)
        let items = try #require(shelves.shelf(emptied)?.items)

        shelves.remove(items.map(\.id), from: emptied)

        #expect(shelves.openShelves.map(\.id) == [other])
    }

    @Test func closingAShelfRemovesItEvenWithItemsOnIt() {
        let shelves = Shelves()
        let closed = shelves.openShelf()
        let other = shelves.openShelf()
        shelves.drop(references: [bookmark("a")], on: closed)

        shelves.close(closed)

        #expect(shelves.openShelves.map(\.id) == [other])
    }
}

/// Stand-in bookmark bytes; the core treats bookmarks as opaque.
private func bookmark(_ name: String) -> Data { Data(name.utf8) }
