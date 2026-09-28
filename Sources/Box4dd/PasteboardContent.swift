import AppKit
import UniformTypeIdentifiers

/// One thing a Shelf can take from a drag or the clipboard: a Finder file, which becomes a Reference Item,
/// or content that isn't an existing file, which becomes a Captured Item.
enum PasteboardContent {
    case file(URL)
    /// A file another app writes only once the drop is accepted (Mail attachments, Photos, some browser
    /// drags). It shows as a Placeholder until it arrives.
    case promise(NSFilePromiseReceiver)
    case text(String)
    /// RTF data, so the formatting is kept.
    case richText(Data)
    case link(URL, title: String?)
    /// Image data as it came (PNG, TIFF, JPEG…); it's saved as PNG.
    case image(Data)

    /// Every type a Shelf accepts, for registering as a drop destination.
    static let readableTypes: [NSPasteboard.PasteboardType] = [.fileURL] + promiseTypes + imageTypes + [.URL, .rtf, .string]

    /// Whether a drag or the clipboard holds anything a Shelf can take, without reading it all.
    static func canRead(from pasteboard: NSPasteboard) -> Bool {
        pasteboard.pasteboardItems?.contains { item in
            readFile(item) != nil || item.availableType(from: promiseTypes + [.URL, .rtf, .string] + imageTypes) != nil
        } ?? false
    }

    /// Reads what a drag or the clipboard holds, one entry per pasteboard item. Each item is read as the
    /// first of: a Finder file, a promised file, an image, a web link, rich text, plain text. Mail and Photos
    /// drags also carry a preview image or a link, but the promised file is the real thing. A browser image
    /// drag often carries the image's address too; that's the same image, not a separate link. A promise
    /// can only be called in during a drag, so the clipboard is read without promises.
    static func read(from pasteboard: NSPasteboard, takingPromises: Bool = true) -> [PasteboardContent] {
        let items = pasteboard.pasteboardItems ?? []
        let receivers = takingPromises ? promiseReceivers(for: items, on: pasteboard) : [:]
        let contents = items.compactMap { read($0, promise: receivers[ObjectIdentifier($0)]) }
        guard contents.contains(where: \.isImage) else { return contents }
        return contents.filter { if case .link = $0 { false } else { true } }
    }

    /// AppKit makes promise receivers for a whole pasteboard: one per item that promises files, in order.
    /// If they can't be matched to the items, the promises are ignored and the items read as other content.
    private static func promiseReceivers(for items: [NSPasteboardItem], on pasteboard: NSPasteboard) -> [ObjectIdentifier: NSFilePromiseReceiver] {
        let promising = items.filter { $0.availableType(from: promiseTypes) != nil }
        guard !promising.isEmpty,
              let receivers = pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self]) as? [NSFilePromiseReceiver],
              receivers.count == promising.count else { return [:] }
        return Dictionary(uniqueKeysWithValues: zip(promising.map(ObjectIdentifier.init), receivers))
    }

    private static func read(_ item: NSPasteboardItem, promise: NSFilePromiseReceiver?) -> PasteboardContent? {
        // An app that also promises the file may point at its own private copy, such as Mail's attachment
        // cache or the Photos library; that copy isn't the user's file to reference.
        if let url = readFile(item), promise == nil || !isAppPrivate(url) {
            return .file(url)
        }
        if let promise {
            return .promise(promise)
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

    /// Inside ~/Library or a Photos library: data an app keeps for itself.
    private static func isAppPrivate(_ url: URL) -> Bool {
        url.standardizedFileURL.path.hasPrefix(URL.libraryDirectory.standardizedFileURL.path + "/")
            || url.pathComponents.contains { $0.hasSuffix(".photoslibrary") }
    }

    private var isImage: Bool {
        if case .image = self { true } else { false }
    }

    private static let promiseTypes = NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) }

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
