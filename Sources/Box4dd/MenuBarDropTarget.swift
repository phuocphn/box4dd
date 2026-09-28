import AppKit

/// Lies over the menu bar icon and takes drops on it. It handles no clicks itself: they go up the responder
/// chain to the icon's button, which shows the menu as usual.
@MainActor
final class MenuBarDropTarget: NSView {
    private let canDrop: (NSPasteboard) -> Bool
    private let drop: (NSPasteboard) -> Bool

    init(on button: NSStatusBarButton, types: [NSPasteboard.PasteboardType],
         canDrop: @escaping (NSPasteboard) -> Bool, drop: @escaping (NSPasteboard) -> Bool) {
        self.canDrop = canDrop
        self.drop = drop
        super.init(frame: button.bounds)
        autoresizingMask = [.width, .height]
        registerForDraggedTypes(types)
        button.addSubview(self)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private var button: NSStatusBarButton? { superview as? NSStatusBarButton }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard canDrop(sender.draggingPasteboard) else { return [] }
        button?.highlight(true)
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        button?.highlight(false)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        button?.highlight(false)
        return drop(sender.draggingPasteboard)
    }
}
