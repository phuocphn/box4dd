import AppKit
import UniformTypeIdentifiers

/// One thing a Shelf can take from a drag or the clipboard: a Finder file, which becomes a Reference Item,
/// or content that isn't an existing file, which becomes a Captured Item.
enum PasteboardContent {
    case file(URL)
    case text(String)
    /// RTF data, so the formatting is kept.
    case richText(Data)
    case link(URL, title: String?)
    /// Image data as it came (PNG, TIFF, JPEG…); it's saved as PNG.
    case image(Data)

    /// Every type a Shelf accepts, for registering as a drop destination.
    static let readableTypes: [NSPasteboard.PasteboardType] = [.fileURL] + imageTypes + [.URL, .rtf, .string]

    /// Whether a drag or the clipboard holds anything a Shelf can take, without reading it all.
    static func canRead(from pasteboard: NSPasteboard) -> Bool {
        pasteboard.pasteboardItems?.contains { item in
            readFile(item) != nil || item.availableType(from: [.URL, .rtf, .string] + imageTypes) != nil
        } ?? false
    }

    /// Reads what a drag or the clipboard holds, one entry per pasteboard item. Each item is read as the
    /// first of: a Finder file, an image, a web link, rich text, plain text. A browser image drag often
    /// carries the image's address too; that's the same image, not a separate link.
    static func read(from pasteboard: NSPasteboard) -> [PasteboardContent] {
        let contents = (pasteboard.pasteboardItems ?? []).compactMap(read)
        guard contents.contains(where: \.isImage) else { return contents }
        return contents.filter { if case .link = $0 { false } else { true } }
    }

    private static func read(_ item: NSPasteboardItem) -> PasteboardContent? {
        if let url = readFile(item) {
            return .file(url)
        }
        if let type = item.availableType(from: imageTypes), let data = item.data(forType: type) {
            return .image(data)
        }
        if let string = item.string(forType: .URL), let url = URL(string: string), !url.isFileURL, url.scheme != nil {
            return .link(url, title: item.string(forType: urlName).flatMap { $0.isEmpty ? nil : $0 })
        }
        if let rtf = item.data(forType: .rtf) {
            return .richText(rtf)
        }
        if let string = item.string(forType: .string), !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .text(string)
        }
        return nil
    }

    private static func readFile(_ item: NSPasteboardItem) -> URL? {
        // Finder writes file reference URLs (file:///.file/id=…); the path form is what the rest of the app needs.
        guard let string = item.string(forType: .fileURL), let url = NSURL(string: string), url.isFileURL else { return nil }
        return url.filePathURL
    }

    private var isImage: Bool {
        if case .image = self { true } else { false }
    }

    private static let imageTypes: [NSPasteboard.PasteboardType] = [
        .png, .tiff,
        NSPasteboard.PasteboardType(UTType.jpeg.identifier),
        NSPasteboard.PasteboardType(UTType.heic.identifier),
        NSPasteboard.PasteboardType(UTType.gif.identifier),
        NSPasteboard.PasteboardType(UTType.webP.identifier),
    ]

    /// The page title browsers put next to a dragged link.
    private static let urlName = NSPasteboard.PasteboardType("public.url-name")
}
