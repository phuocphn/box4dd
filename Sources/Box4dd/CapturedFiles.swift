import AppKit
import UniformTypeIdentifiers

/// Where Captured Items' files live: Application Support/box4dd/Captured/<uuid>/<name>.<ext>. Each file gets
/// its own folder, so it can keep a readable name (it arrives in Finder under that name) without clashing.
/// The core names a file by its path in here.
enum CapturedFiles {
    static let directory = URL.applicationSupportDirectory.appending(path: "box4dd/Captured", directoryHint: .isDirectory)

    /// Saves content that isn't an existing file as a new file the Shelf owns, and returns its path in storage.
    static func save(_ content: PasteboardContent) -> String? {
        let saved: (name: String, ext: String, data: Data)?
        switch content {
        case .file, .promise:
            saved = nil
        case .text(let text):
            saved = (name(from: text, or: "Text"), "txt", Data(text.utf8))
        case .richText(let rtf):
            let plain = NSAttributedString(rtf: rtf, documentAttributes: nil)?.string ?? ""
            saved = (name(from: plain, or: "Rich Text"), "rtf", rtf)
        case .link(let url, let title):
            let webloc = try? PropertyListSerialization.data(fromPropertyList: ["URL": url.absoluteString], format: .xml, options: 0)
            saved = webloc.map { (name(from: title ?? url.host() ?? "", or: "Link"), "webloc", $0) }
        case .image(let data):
            let png = NSBitmapImageRep(data: data)?.representation(using: .png, properties: [:])
            saved = png.map { ("Image", "png", $0) }
        }
        guard let saved else { return nil }
        let file = "\(UUID().uuidString)/\(saved.name).\(saved.ext)"
        let url = directory.appending(path: file)
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try saved.data.write(to: url)
            return file
        } catch {
            NSLog("box4dd: couldn't save a Captured Item to \(url.path): \(error)")
            return nil
        }
    }

    /// Where promised files are written while they arrive, before they're moved into storage. Whatever is
    /// left there belonged to promises that never finished, so it's cleared at launch.
    static let incoming = URL.applicationSupportDirectory.appending(path: "box4dd/Incoming", directoryHint: .isDirectory)

    /// A new, empty folder in `incoming` for the files promised in one drop.
    static func newIncomingFolder() -> URL {
        let folder = incoming.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    static func clearIncoming() {
        try? FileManager.default.removeItem(at: incoming)
    }

    /// Moves a promised file that has arrived into storage under its own name, and returns its path there.
    static func take(_ url: URL) -> String? {
        let file = "\(UUID().uuidString)/\(url.lastPathComponent)"
        let destination = directory.appending(path: file)
        do {
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.moveItem(at: url, to: destination)
            return file
        } catch {
            NSLog("box4dd: couldn't keep the promised file \(url.path): \(error)")
            return nil
        }
    }

    /// The file on disk, or nil if it's gone.
    static func url(for file: String) -> URL? {
        let url = directory.appending(path: file)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// The storage path of a file URL that points into this storage, as when a copied Captured Item is pasted.
    static func file(at url: URL) -> String? {
        let base = directory.standardizedFileURL.path + "/"
        let path = url.standardizedFileURL.path
        return path.hasPrefix(base) ? String(path.dropFirst(base.count)) : nil
    }

    /// Deletes a Captured Item's file together with its folder. Never reaches outside the storage.
    static func delete(_ file: String) {
        let url = directory.appending(path: file).standardizedFileURL
        guard let stored = Self.file(at: url), !stored.isEmpty else { return }
        let folder = stored.contains("/") ? url.deletingLastPathComponent() : url
        try? FileManager.default.removeItem(at: folder)
    }

    /// The raw content of a Captured Item's file, for targets that want text, a URL, rich text or an image.
    static func contents(of url: URL) -> [NSPasteboard.PasteboardType: Any] {
        switch url.pathExtension {
        case "txt":
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [:] }
            return [.string: text]
        case "rtf":
            guard let rtf = try? Data(contentsOf: url) else { return [:] }
            let plain = NSAttributedString(rtf: rtf, documentAttributes: nil)?.string ?? ""
            return [.rtf: rtf, .string: plain]
        case "webloc":
            guard let data = try? Data(contentsOf: url),
                  let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                  let link = plist["URL"] as? String else { return [:] }
            return [.URL: link, .string: link]
        case "png":
            guard let png = try? Data(contentsOf: url) else { return [:] }
            return [.png: png]
        default:
            return [:]
        }
    }

    /// A name from the first few words of some text, safe as a file name.
    private static func name(from text: String, or fallback: String) -> String {
        let words = text.split { $0.isWhitespace || $0 == "/" || $0 == ":" }.prefix(6).joined(separator: " ")
        var name = String(words.prefix(40))
        while name.hasPrefix(".") { name.removeFirst() }
        name = name.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? fallback : name
    }
}

/// What a Captured Item puts on a drag: its raw content, so a text field or address bar gets the text or
/// URL, and a promise of its file, so Finder gets a copy. A promise rather than a file URL: a text view
/// given a file URL inserts the file or its path instead of the text, and Finder would move a file URL out
/// of the app's storage on the same volume. The copy keeps the Captured Item's file until eviction.
final class CapturedItemDrag: NSFilePromiseProvider, NSFilePromiseProviderDelegate {
    private let source: URL
    private let contents: [NSPasteboard.PasteboardType: Any]

    init(source: URL) {
        self.source = source
        contents = CapturedFiles.contents(of: source)
        super.init()
        fileType = (UTType(filenameExtension: source.pathExtension) ?? .data).identifier
        delegate = self
    }

    override func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        // Raw content first, so it's what a target that takes both picks.
        Array(contents.keys) + super.writableTypes(for: pasteboard)
    }

    override func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        contents[type] ?? super.pasteboardPropertyList(forType: type)
    }

    override func writingOptions(forType type: NSPasteboard.PasteboardType, pasteboard: NSPasteboard) -> NSPasteboard.WritingOptions {
        contents[type] != nil ? [] : super.writingOptions(forType: type, pasteboard: pasteboard)
    }

    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
        source.lastPathComponent
    }

    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, writePromiseTo url: URL,
                             completionHandler: @escaping ((any Error)?) -> Void) {
        do {
            try FileManager.default.copyItem(at: source, to: url)
            completionHandler(nil)
        } catch {
            completionHandler(error)
        }
    }

    /// For ⌘C, where a promise can't be kept: the raw content and the file itself, which Finder copies on paste.
    static func clipboardItem(for source: URL) -> NSPasteboardItem {
        let item = NSPasteboardItem()
        for (type, value) in CapturedFiles.contents(of: source) {
            if let data = value as? Data { item.setData(data, forType: type) }
            if let string = value as? String { item.setString(string, forType: type) }
        }
        item.setString(source.absoluteString, forType: .fileURL)
        return item
    }
}
