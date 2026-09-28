import AppKit
import Carbon.HIToolbox

/// A key with modifiers, as the new-Shelf shortcut. Saved in Settings, registered as a `HotKey`,
/// and shown as the New Shelf menu item's key equivalent.
struct Shortcut: Codable, Equatable, Sendable {
    /// The virtual key code (kVK_…), which is what Carbon registers.
    var keyCode: UInt16
    /// Raw `NSEvent.ModifierFlags`, only ⌃⌥⇧⌘.
    var modifiers: UInt
    /// The character the key types with no modifiers, as the menu item's key equivalent.
    var key: String

    static let standard = Shortcut(keyCode: UInt16(kVK_Space), modifiers: NSEvent.ModifierFlags([.control, .option]).rawValue, key: " ")

    init(keyCode: UInt16, modifiers: UInt, key: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.key = key
    }

    /// The shortcut the user pressed, or nil without ⌃, ⌥ or ⌘: a plain or ⇧ key would take over typing everywhere.
    init?(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection([.control, .option, .shift, .command])
        guard !flags.isDisjoint(with: [.control, .option, .command]),
              let key = event.characters(byApplyingModifiers: [])?.lowercased(), !key.isEmpty
        else { return nil }
        self.init(keyCode: event.keyCode, modifiers: flags.rawValue, key: key)
    }

    var modifierFlags: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: modifiers) }

    var carbonModifiers: UInt32 {
        var carbon = 0
        if modifierFlags.contains(.control) { carbon |= controlKey }
        if modifierFlags.contains(.option) { carbon |= optionKey }
        if modifierFlags.contains(.shift) { carbon |= shiftKey }
        if modifierFlags.contains(.command) { carbon |= cmdKey }
        return UInt32(carbon)
    }

    /// For example "⌃⌥Space".
    var displayName: String {
        var name = ""
        if modifierFlags.contains(.control) { name += "⌃" }
        if modifierFlags.contains(.option) { name += "⌥" }
        if modifierFlags.contains(.shift) { name += "⇧" }
        if modifierFlags.contains(.command) { name += "⌘" }
        return name + keyName
    }

    private var keyName: String {
        switch key {
        case " ": return "Space"
        case "\r": return "↩"
        case "\t": return "⇥"
        case "\u{7f}": return "⌫"
        case "\u{1b}": return "⎋"
        default: break
        }
        guard let scalar = key.unicodeScalars.first, key.unicodeScalars.count == 1 else { return key.uppercased() }
        switch Int(scalar.value) {
        case NSF1FunctionKey...NSF35FunctionKey: return "F\(Int(scalar.value) - NSF1FunctionKey + 1)"
        case NSUpArrowFunctionKey: return "↑"
        case NSDownArrowFunctionKey: return "↓"
        case NSLeftArrowFunctionKey: return "←"
        case NSRightArrowFunctionKey: return "→"
        case NSDeleteFunctionKey: return "⌦"
        case NSHomeFunctionKey: return "↖"
        case NSEndFunctionKey: return "↘"
        case NSPageUpFunctionKey: return "⇞"
        case NSPageDownFunctionKey: return "⇟"
        default: return key.uppercased()
        }
    }
}
