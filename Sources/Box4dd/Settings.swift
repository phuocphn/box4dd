import Foundation
import Observation

/// The user's choices from the Settings window. Each change is saved at once in UserDefaults,
/// so it survives a relaunch.
@MainActor @Observable
final class Settings {
    private enum Key {
        static let shakeSensitivity = "shakeSensitivity"
        static let excludedApps = "excludedApps"
        static let newShelfShortcut = "newShelfShortcut"
        static let launchAtLogin = "launchAtLogin"
    }

    @ObservationIgnored private let defaults: UserDefaults
    /// Called after the sensitivity or the Excluded Apps change, so the Shake detector can use them straight away.
    @ObservationIgnored var shakeSettingsChanged: () -> Void = {}

    /// From 0 (needs wide strokes) to 1 (small strokes are enough).
    var shakeSensitivity: Double {
        didSet {
            defaults.set(shakeSensitivity, forKey: Key.shakeSensitivity)
            shakeSettingsChanged()
        }
    }

    /// Bundle identifiers of the Excluded Apps, in the order they were added.
    var excludedApps: [String] {
        didSet {
            defaults.set(excludedApps, forKey: Key.excludedApps)
            shakeSettingsChanged()
        }
    }

    var newShelfShortcut: Shortcut {
        didSet { defaults.set(try? JSONEncoder().encode(newShelfShortcut), forKey: Key.newShelfShortcut) }
    }

    /// What the user wants; `LaunchAtLogin` makes the system match it.
    var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Key.launchAtLogin) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        shakeSensitivity = defaults.object(forKey: Key.shakeSensitivity) as? Double ?? 0.5
        excludedApps = defaults.stringArray(forKey: Key.excludedApps) ?? []
        newShelfShortcut = defaults.data(forKey: Key.newShelfShortcut)
            .flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) } ?? .standard
        launchAtLogin = defaults.object(forKey: Key.launchAtLogin) as? Bool ?? true
    }
}
