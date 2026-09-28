import Carbon.HIToolbox
import Foundation

/// A system-wide keyboard shortcut. Carbon's hot key API needs no Accessibility permission.
/// Registered for as long as the `HotKey` lives.
@MainActor
final class HotKey {
    struct RegistrationFailed: Error {
        let status: OSStatus
    }

    private let action: () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    init(_ shortcut: Shortcut, action: @escaping () -> Void) throws(RegistrationFailed) {
        self.action = action

        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return OSStatus(eventNotHandledErr) }
            let hotKey = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
            MainActor.assumeIsolated { hotKey.action() }
            return noErr
        }, 1, &pressed, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)

        let id = EventHotKeyID(signature: OSType(0x6234_6464), id: 1) // "b4dd"
        let status = RegisterEventHotKey(UInt32(shortcut.keyCode), shortcut.carbonModifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status != noErr {
            NSLog("box4dd: couldn't register the new-Shelf shortcut \(shortcut.displayName) (error \(status)); another app may already use it")
            throw RegistrationFailed(status: status)
        }
    }

    isolated deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
