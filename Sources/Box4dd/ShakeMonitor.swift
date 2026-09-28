import AppKit
import ShelfCore

/// Watches the pointer during drags in any app and reports each Shake with where the cursor is.
///
/// It polls instead of listening to events: the mouse button state, the pointer position and the drag
/// pasteboard's change count are all readable without Accessibility or Input Monitoring permission.
/// A drag is in progress when the drag pasteboard changed since the mouse button went down.
@MainActor
final class ShakeMonitor {
    var detector = ShakeDetector()

    // Slow polling only to notice the mouse button going down; fast sampling while it's held.
    private static let idleInterval: TimeInterval = 1.0 / 10
    private static let sampleInterval: TimeInterval = 1.0 / 120

    private let onShake: (NSPoint) -> Void
    private let dragPasteboard = NSPasteboard(name: .drag)
    private var timer: Timer?
    private var mouseIsDown = false
    /// The drag pasteboard's change count last seen with the mouse button up.
    private var changeCountBeforeMouseDown: Int

    init(onShake: @escaping (NSPoint) -> Void) {
        self.onShake = onShake
        changeCountBeforeMouseDown = dragPasteboard.changeCount
        schedule(every: Self.idleInterval)
    }

    isolated deinit {
        timer?.invalidate()
    }

    private func schedule(every interval: TimeInterval) {
        timer?.invalidate()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = interval / 10
        // Common modes, so sampling goes on while this app runs its own drag out of a Shelf.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        let changeCount = dragPasteboard.changeCount
        let sample = PointerSample(position: NSEvent.mouseLocation, time: ProcessInfo.processInfo.systemUptime)
        let frontmostApp = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        guard NSEvent.pressedMouseButtons & 1 != 0 else {
            changeCountBeforeMouseDown = changeCount
            if mouseIsDown {
                // The drag ended: let the detector forget it.
                _ = detector.pointerMoved(sample, dragInProgress: false, frontmostApp: frontmostApp)
                mouseIsDown = false
                schedule(every: Self.idleInterval)
            }
            return
        }
        if !mouseIsDown {
            mouseIsDown = true
            schedule(every: Self.sampleInterval)
        }

        let dragInProgress = changeCount != changeCountBeforeMouseDown
        if detector.pointerMoved(sample, dragInProgress: dragInProgress, frontmostApp: frontmostApp) {
            onShake(sample.position)
        }
    }
}
