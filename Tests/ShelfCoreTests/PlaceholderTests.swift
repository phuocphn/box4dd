import Foundation
import Testing
import ShelfCore

@MainActor
struct PlaceholderTests {
    @Test func aPromisedFileShowsAsAPlaceholderStraightAway() {
        let shelves = Shelves()
        let id = shelves.openShelf()

        let dropped = shelves.drop([.reference(bookmark: Data("a".utf8)), .placeholder(name: "Invoice.pdf")], on: id)

        let items = shelves.shelf(id)?.items ?? []
        #expect(items.map(\.id) == dropped)
        #expect(items.map(\.content) == [.reference(bookmark: Data("a".utf8)), .placeholder(name: "Invoice.pdf")])
        #expect(items.map(\.isPlaceholder) == [false, true])
        #expect(items.map(\.capturedFile) == [nil, nil])
    }

    @Test func aPlaceholderBecomesACapturedItemInItsPlaceWhenItsFileArrives() {
        let fileSystem = TestFileSystem()
        let shelves = Shelves(fileSystem: fileSystem)
        let id = shelves.openShelf()
        let dropped = shelves.drop([.placeholder(name: "Invoice.pdf"), .captured(file: "1/Note.txt")], on: id)

        shelves.promisedFileArrived(dropped[0], file: "2/Invoice.pdf")

        #expect(shelves.shelf(id)?.items.map(\.id) == dropped)
        #expect(shelves.shelf(id)?.items.map(\.content) == [.captured(file: "2/Invoice.pdf"), .captured(file: "1/Note.txt")])
        #expect(fileSystem.deletedFiles == [])
    }

    @Test func aFileArrivingForARemovedPlaceholderIsDeleted() {
        let fileSystem = TestFileSystem()
        let shelves = Shelves(fileSystem: fileSystem)
        let id = shelves.openShelf()
        let dropped = shelves.drop([.placeholder(name: "Invoice.pdf"), .captured(file: "1/Note.txt")], on: id)
        shelves.remove([dropped[0]], from: id)

        shelves.promisedFileArrived(dropped[0], file: "2/Invoice.pdf")

        #expect(shelves.shelf(id)?.items.map(\.content) == [.captured(file: "1/Note.txt")])
        #expect(fileSystem.deletedFiles == ["2/Invoice.pdf"])
    }

    @Test func aPlaceholderWhosePromiseFailsLeavesTheShelfAndTheOtherItemsStay() {
        let shelves = Shelves()
        let id = shelves.openShelf()
        let dropped = shelves.drop([.captured(file: "1/Note.txt"), .placeholder(name: "Invoice.pdf")], on: id)

        shelves.promisedFileFailed(dropped[1])

        #expect(shelves.shelf(id)?.items.map(\.content) == [.captured(file: "1/Note.txt")])
        #expect(shelves.recentShelves.isEmpty)
    }

    @Test func aShelfLeftEmptyByAFailedPromiseClosesAndIsNotKeptInRecentShelves() {
        let shelves = Shelves()
        let id = shelves.openShelf()
        let dropped = shelves.drop([.placeholder(name: "Invoice.pdf")], on: id)

        shelves.promisedFileFailed(dropped[0])

        #expect(shelves.shelf(id) == nil)
        #expect(shelves.openShelves.isEmpty)
        #expect(shelves.recentShelves.isEmpty)
    }

    @Test func aShelfLeftEmptyByAFailedPromiseHasTheFilesOfItemsThatLeftItDeleted() {
        let fileSystem = TestFileSystem()
        let shelves = Shelves(fileSystem: fileSystem)
        let id = shelves.openShelf()
        let dropped = shelves.drop([.captured(file: "1/Delivered.txt"), .placeholder(name: "Invoice.pdf")], on: id)
        shelves.dragOutEnded([dropped[0]], from: id, accepted: true)

        shelves.promisedFileFailed(dropped[1])

        #expect(shelves.recentShelves.isEmpty)
        #expect(fileSystem.deletedFiles == ["1/Delivered.txt"])
    }

    @Test func aPlaceholderIsLeftOutOfADragOut() {
        let shelves = Shelves()
        let id = shelves.openShelf()
        let dropped = shelves.drop([.captured(file: "1/Note.txt"), .placeholder(name: "Invoice.pdf")], on: id)

        shelves.dragOutEnded(dropped, from: id, accepted: true)

        #expect(shelves.shelf(id)?.items.map(\.content) == [.placeholder(name: "Invoice.pdf")])
    }

    @Test func closingAShelfBeforeItsPromisedFileArrivesKeepsOnlyItsReadyItemsInRecentShelves() {
        let fileSystem = TestFileSystem()
        let shelves = Shelves(fileSystem: fileSystem)
        let id = shelves.openShelf()
        let dropped = shelves.drop([.captured(file: "1/Note.txt"), .placeholder(name: "Invoice.pdf")], on: id)
        shelves.close(id)

        shelves.promisedFileArrived(dropped[1], file: "2/Invoice.pdf")

        #expect(shelves.recentShelves.map { $0.items.map(\.content) } == [[.captured(file: "1/Note.txt")]])
        #expect(fileSystem.deletedFiles == ["2/Invoice.pdf"])
        shelves.reopen(id)
        #expect(shelves.shelf(id)?.items.map(\.content) == [.captured(file: "1/Note.txt")])
    }

    @Test func aShelfClosedWhileHoldingOnlyPlaceholdersIsNotKeptAndItsLateFilesAreDeleted() {
        let fileSystem = TestFileSystem()
        let shelves = Shelves(fileSystem: fileSystem)
        let id = shelves.openShelf()
        let dropped = shelves.drop([.placeholder(name: "IMG_0001.heic"), .placeholder(name: nil)], on: id)
        shelves.close(id)

        shelves.promisedFileArrived(dropped[0], file: "1/IMG_0001.heic")
        shelves.promisedFileFailed(dropped[1])

        #expect(shelves.openShelves.isEmpty)
        #expect(shelves.recentShelves.isEmpty)
        #expect(fileSystem.deletedFiles == ["1/IMG_0001.heic"])
    }

    @Test func removingTheLastItemsOfAShelfKeepsOnlyTheReadyOnesInRecentShelves() {
        let shelves = Shelves()
        let withNote = shelves.openShelf()
        let dropped = shelves.drop([.captured(file: "1/Note.txt"), .placeholder(name: "Invoice.pdf")], on: withNote)
        let onlyPlaceholder = shelves.openShelf()
        let cancelled = shelves.drop([.placeholder(name: "IMG_0001.heic")], on: onlyPlaceholder)

        shelves.remove(dropped, from: withNote)
        shelves.remove(cancelled, from: onlyPlaceholder)

        #expect(shelves.openShelves.isEmpty)
        #expect(shelves.recentShelves.map(\.id) == [withNote])
        #expect(shelves.recentShelves.first?.items.map(\.content) == [.captured(file: "1/Note.txt")])
    }

    @Test func aFileArrivingAfterItsShelfFellOffRecentShelvesIsDeleted() {
        let fileSystem = TestFileSystem()
        let shelves = Shelves(fileSystem: fileSystem)
        let evicted = shelves.openShelf()
        let dropped = shelves.drop([.captured(file: "1/Note.txt"), .placeholder(name: "Invoice.pdf")], on: evicted)
        shelves.close(evicted)
        for _ in 0..<10 {
            let id = shelves.openShelf()
            shelves.drop([.reference(bookmark: Data("kept".utf8))], on: id)
            shelves.close(id)
        }

        shelves.promisedFileArrived(dropped[1], file: "2/Invoice.pdf")

        #expect(!shelves.recentShelves.map(\.id).contains(evicted))
        #expect(fileSystem.deletedFiles == ["1/Note.txt", "2/Invoice.pdf"])
    }

    @Test func placeholdersDoNotComeBackAfterARelaunch() {
        let store = MemoryStore()
        let before = Shelves(store: store)
        let mixed = before.openShelf()
        before.drop([.captured(file: "1/Note.txt"), .placeholder(name: "Invoice.pdf")], on: mixed)
        let onlyPlaceholders = before.openShelf()
        before.drop([.placeholder(name: "IMG_0001.heic"), .placeholder(name: nil)], on: onlyPlaceholders)
        let empty = before.openShelf()

        let after = Shelves(store: store)

        #expect(after.openShelves.map(\.id) == [mixed, empty])
        #expect(after.shelf(mixed)?.items.map(\.content) == [.captured(file: "1/Note.txt")])
        #expect(after.recentShelves.isEmpty)
    }

    @Test func shelvesSavedWhilePlaceholdersArePendingStillLoadAsJSON() {
        let store = JSONStore()
        let before = Shelves(store: store)
        let id = before.openShelf()
        before.drop([.reference(bookmark: Data("a".utf8)), .placeholder(name: "Invoice.pdf"), .placeholder(name: nil)], on: id)

        let after = Shelves(store: store)

        #expect(after.shelf(id)?.items.map(\.content) == [.reference(bookmark: Data("a".utf8))])
    }
}
