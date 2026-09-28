import Foundation
import Testing
import ShelfCore

@MainActor
struct CapturedItemsTests {
    @Test func droppingContentAddsACapturedItemTheShelfOwns() {
        let shelves = Shelves()
        let id = shelves.openShelf()

        shelves.drop([.captured(file: "1/Hello there.txt")], on: id)

        #expect(shelves.shelf(id)?.items.map(\.content) == [.captured(file: "1/Hello there.txt")])
        #expect(shelves.shelf(id)?.items.map(\.capturedFile) == ["1/Hello there.txt"])
        #expect(shelves.shelf(id)?.items.map(\.bookmark) == [nil])
    }

    @Test func capturedAndReferenceItemsSitOnOneShelfInTheOrderTheyCame() {
        let shelves = Shelves()
        let id = shelves.openShelf()

        shelves.drop(references: [Data("a".utf8)], on: id)
        shelves.drop([.captured(file: "1/Image.png"), .reference(bookmark: Data("b".utf8))], on: id)

        #expect(shelves.shelf(id)?.items.map(\.content) == [
            .reference(bookmark: Data("a".utf8)),
            .captured(file: "1/Image.png"),
            .reference(bookmark: Data("b".utf8)),
        ])
    }

    @Test func capturedItemsSurviveCloseReopenAndRelaunch() {
        let store = MemoryStore()
        let before = Shelves(store: store)
        let reopened = before.openShelf()
        before.drop([.captured(file: "1/Hello.txt"), .reference(bookmark: Data("a".utf8))], on: reopened)
        let recent = before.openShelf()
        before.drop([.captured(file: "2/example.com.webloc")], on: recent)
        before.close(reopened)
        before.close(recent)
        before.reopen(reopened)

        let after = Shelves(store: store)

        #expect(after.shelf(reopened)?.items.map(\.content) == [.captured(file: "1/Hello.txt"), .reference(bookmark: Data("a".utf8))])
        #expect(after.recentShelves.map { $0.items.map(\.content) } == [[.captured(file: "2/example.com.webloc")]])
    }

    @Test func checkingOriginalsLeavesCapturedItemsAlone() {
        let fileSystem = TestFileSystem()
        let shelves = Shelves(fileSystem: fileSystem)
        let id = shelves.openShelf()
        shelves.drop([.captured(file: "1/Hello.txt"), .reference(bookmark: Data("a".utf8))], on: id)
        fileSystem.originals[Data("a".utf8)] = .deleted

        shelves.checkOriginals()

        #expect(shelves.shelf(id)?.items.map(\.isMissing) == [false, true])
    }

    @Test func aShelfFallingOffRecentShelvesHasOnlyItsCapturedItemFilesDeleted() {
        let fileSystem = TestFileSystem()
        let shelves = Shelves(fileSystem: fileSystem)
        let evicted = shelves.openShelf()
        shelves.drop([.captured(file: "1/Hello.txt"), .reference(bookmark: Data("a".utf8)), .captured(file: "2/Image.png")], on: evicted)
        shelves.close(evicted)
        let newer = (0..<9).map { _ in shelfWithCapturedItem("kept", on: shelves) }
        for id in newer { shelves.close(id) }
        #expect(fileSystem.deletedFiles == [])

        shelves.close(shelfWithCapturedItem("newest", on: shelves))

        #expect(!shelves.recentShelves.map(\.id).contains(evicted))
        #expect(fileSystem.deletedFiles == ["1/Hello.txt", "2/Image.png"])
    }

    @Test func capturedItemFilesAreKeptAfterDraggingOutOrRemovingWhileTheShelfIsOpenOrRecent() throws {
        let fileSystem = TestFileSystem()
        let shelves = Shelves(fileSystem: fileSystem)
        let id = shelves.openShelf()
        shelves.drop([.captured(file: "1/Delivered.txt"), .captured(file: "2/Removed.txt"), .captured(file: "3/Last.png")], on: id)
        let items = try #require(shelves.shelf(id)?.items)

        shelves.dragOutEnded([items[0].id], from: id, accepted: true)
        shelves.remove([items[1].id], from: id)
        #expect(shelves.shelf(id)?.items.map(\.capturedFile) == ["3/Last.png"])
        shelves.dragOutEnded([items[2].id], from: id, accepted: true)

        #expect(shelves.recentShelves.map(\.id) == [id])
        #expect(fileSystem.deletedFiles == [])
    }

    @Test func capturedItemsThatLeftAShelfHaveTheirFilesDeletedWhenThatShelfFallsOffRecentShelves() throws {
        let fileSystem = TestFileSystem()
        let shelves = Shelves(fileSystem: fileSystem)
        let evicted = shelves.openShelf()
        shelves.drop([.captured(file: "1/Delivered.txt"), .captured(file: "2/Removed.txt"), .captured(file: "3/Last.png")], on: evicted)
        let items = try #require(shelves.shelf(evicted)?.items)
        shelves.dragOutEnded([items[0].id], from: evicted, accepted: true)
        shelves.remove([items[1].id], from: evicted)
        shelves.close(evicted)

        for _ in 0..<10 { shelves.close(shelfWithCapturedItem("kept", on: shelves)) }

        #expect(Set(fileSystem.deletedFiles) == ["1/Delivered.txt", "2/Removed.txt", "3/Last.png"])
    }

    @Test func aCapturedItemDraggedToAnotherShelfKeepsItsFileWhenTheFirstShelfFallsOffRecentShelves() throws {
        let fileSystem = TestFileSystem()
        let shelves = Shelves(fileSystem: fileSystem)
        let first = shelves.openShelf()
        shelves.drop([.captured(file: "1/Moved.txt"), .captured(file: "2/Stayed.txt")], on: first)
        let second = shelves.openShelf()
        let items = try #require(shelves.shelf(first)?.items)
        shelves.drop([.captured(file: "1/Moved.txt")], on: second)
        shelves.dragOutEnded([items[0].id], from: first, accepted: true)
        shelves.close(first)

        for _ in 0..<10 { shelves.close(shelfWithCapturedItem("kept", on: shelves)) }

        #expect(fileSystem.deletedFiles == ["2/Stayed.txt"])
        #expect(shelves.shelf(second)?.items.map(\.capturedFile) == ["1/Moved.txt"])
    }

    @Test func shelvesSavedBeforeCapturedItemsStillLoad() throws {
        let saved = """
        {"openShelves": [{"id": "8C0D6A57-6E43-4D2A-9C43-6C1B7B8A0001", "position": {"x": 1, "y": 2},
                          "items": [{"id": "8C0D6A57-6E43-4D2A-9C43-6C1B7B8A0002", "bookmark": "YQ==", "isMissing": false}]}],
         "recentShelves": []}
        """

        let shelves = try JSONDecoder().decode(SavedShelves.self, from: Data(saved.utf8))

        #expect(shelves.openShelves.first?.items.map(\.content) == [.reference(bookmark: Data("a".utf8))])
    }
}

/// Opens a Shelf holding one Captured Item.
@MainActor
private func shelfWithCapturedItem(_ file: String, on shelves: Shelves) -> Shelf.ID {
    let id = shelves.openShelf()
    shelves.drop([.captured(file: file)], on: id)
    return id
}
