import Foundation

/// Tells the core what happened to a Reference Item's original, and deletes Captured Item files when the
/// core asks. Only the app resolves bookmarks and knows where Captured Item files are stored.
@MainActor
public protocol FileSystem: AnyObject {
    func original(of bookmark: Data) -> Original
    /// The core no longer needs this Captured Item file. Never called for a Reference Item's original.
    func deleteCapturedFile(_ file: String)
}

/// What became of a Reference Item's original since its bookmark was made.
public enum Original: Equatable, Sendable {
    case present
    /// Renamed or moved; the new bookmark points to where it is now.
    case moved(refreshedBookmark: Data)
    case deleted
}
