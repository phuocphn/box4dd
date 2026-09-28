import Foundation
import ShelfCore

/// Answers for each bookmark what happened to its original; anything not listed is still in place.
/// Records the Captured Item files the core asks to delete.
@MainActor
final class TestFileSystem: FileSystem {
    var originals: [Data: Original] = [:]
    private(set) var deletedFiles: [String] = []

    func original(of bookmark: Data) -> Original { originals[bookmark] ?? .present }
    func deleteCapturedFile(_ file: String) { deletedFiles.append(file) }
}

/// Keeps what the Shelves save in memory, standing in for the file on disk across a relaunch.
@MainActor
final class MemoryStore: ShelfStore {
    private var saved: SavedShelves?

    func load() -> SavedShelves? { saved }
    func save(_ shelves: SavedShelves) { saved = shelves }
}

/// Keeps what the Shelves save as JSON, as the app's file does, so what can't be encoded or read back shows up.
@MainActor
final class JSONStore: ShelfStore {
    private var saved: Data?

    func load() -> SavedShelves? { saved.flatMap { try? JSONDecoder().decode(SavedShelves.self, from: $0) } }
    func save(_ shelves: SavedShelves) { saved = try? JSONEncoder().encode(shelves) }
}
