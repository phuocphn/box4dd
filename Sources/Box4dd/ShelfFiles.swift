import Foundation
import ShelfCore

/// Saves the Shelves as JSON in Application Support, so open and Recent Shelves survive a relaunch.
@MainActor
final class ShelfFile: ShelfStore {
    private let url: URL

    init(url: URL = URL.applicationSupportDirectory.appending(path: "box4dd/shelves.json")) {
        self.url = url
    }

    func load() -> SavedShelves? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try JSONDecoder().decode(SavedShelves.self, from: data)
        } catch {
            NSLog("box4dd: couldn't read saved Shelves at \(url.path): \(error)")
            return nil
        }
    }

    func save(_ shelves: SavedShelves) {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(shelves).write(to: url, options: .atomic)
        } catch {
            NSLog("box4dd: couldn't save Shelves to \(url.path): \(error)")
        }
    }
}

/// Resolves Reference Item bookmarks to tell the core what became of each original.
@MainActor
final class BookmarkFileSystem: FileSystem {
    func original(of bookmark: Data) -> Original {
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: bookmark, options: Self.options, bookmarkDataIsStale: &isStale),
              FileManager.default.fileExists(atPath: url.path), !Self.isInTrash(url) else {
            return .deleted
        }
        if isStale, let refreshed = try? url.bookmarkData() {
            return .moved(refreshedBookmark: refreshed)
        }
        return .present
    }

    /// Where a bookmark's original is now, or nil if it can't be found.
    static func resolve(_ bookmark: Data) -> URL? {
        var isStale = false
        return try? URL(resolvingBookmarkData: bookmark, options: options, bookmarkDataIsStale: &isStale)
    }

    /// The original's name as it was when the bookmark was made, which still works once it's gone.
    static func savedName(in bookmark: Data) -> String? {
        URL.resourceValues(forKeys: [.nameKey], fromBookmarkData: bookmark)?.name
    }

    // Don't show UI or mount volumes just to check an Item: an unmounted drive reads as missing until it's back.
    private static let options: URL.BookmarkResolutionOptions = [.withoutUI, .withoutMounting]

    // A bookmark follows a file into the Trash, but to the user a trashed original is deleted.
    private static func isInTrash(_ url: URL) -> Bool {
        url.pathComponents.contains { $0 == ".Trash" || $0 == ".Trashes" }
    }
}
