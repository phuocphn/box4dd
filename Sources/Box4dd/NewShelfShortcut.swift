import AppKit
import Carbon.HIToolbox
import Observation

/// Keeps the new-Shelf shortcut from Settings registered, and records a new one when the user changes it.
@MainActor @Observable
final class NewShelfShortcut {
    /// Why the last registration or recording didn't work, to show in Settings.
    private(set) var problem: String?
    private(set) var isRecording = false

    @ObservationIgnored private let settings: Settings
    @ObservationIgnored private let action: () -> Void
    /// Called with the shortcut in use whenever it changes, so the menu can show it.
    @ObservationIgnored var changed: (Shortcut) -> Void = { _ in }
    @ObservationIgnored private var hotKey: HotKey?
    @ObservationIgnored private var keyMonitor: Any?

    var shortcut: Shortcut { settings.newShelfShortcut }

    init(settings: Settings, action: @escaping () -> Void) {
        self.settings = settings
        self.action = action
    }

    /// Registers the saved shortcut, for example at launch.
    func register() {
        _ = register(settings.newShelfShortcut)
    }

    /// Waits for the next shortcut typed in the Settings window. Esc cancels.
    func startRecording() {
        guard !isRecording else { return }
        // Let go of the current shortcut, so pressing it again can be recorded instead of opening a Shelf.
        hotKey = nil
        isRecording = true
        problem = nil
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            MainActor.assumeIsolated { self?.recorded(event) }
            return nil
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        finishRecording()
        _ = register(settings.newShelfShortcut)
    }

    private func recorded(_ event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape), event.modifierFlags.isDisjoint(with: [.control, .option, .command]) {
            stopRecording()
            return
        }
        guard let new = Shortcut(event) else {
            problem = "Use at least one of ⌃, ⌥ or ⌘."
            return
        }
        finishRecording()
        change(to: new)
    }

    /// Uses a new shortcut, or keeps the old one and says why if the new one can't be registered.
    func change(to new: Shortcut) {
        let old = settings.newShelfShortcut
        if register(new) {
            settings.newShelfShortcut = new
        } else {
            let message = problem
            _ = register(old)
            problem = message.map { $0 + " Still using \(old.displayName)." }
        }
    }

    private func finishRecording() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        isRecording = false
    }

    private func register(_ shortcut: Shortcut) -> Bool {
        hotKey = nil
        do {
            hotKey = try HotKey(shortcut, action: action)
            problem = nil
            changed(shortcut)
            return true
        } catch {
            problem = "Couldn't use \(shortcut.displayName) (error \(error.status)); another app may already use it."
            return false
        }
    }
}
