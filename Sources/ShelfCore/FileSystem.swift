import Foundation

/// Tells the core what happened to a Reference Item's original. Only the app resolves bookmarks.
@MainActor
public protocol FileSystem: AnyObject {
    func original(of bookmark: Data) -> Original
}

/// What became of a Reference Item's original since its bookmark was made.
public enum Original: Equatable, Sendable {
    case present
    /// Renamed or moved; the new bookmark points to where it is now.
    case moved(refreshedBookmark: Data)
    case deleted
}
