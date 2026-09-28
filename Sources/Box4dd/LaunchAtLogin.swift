import AppKit
import Observation
import ServiceManagement

/// Makes the system's login item for box4dd match the launch-at-login setting.
///
/// The setting is on by default, so the first launch registers the app. After that, the app changes the
/// login item only when the setting changes, so turning it off in System Settings isn't undone at relaunch.
@MainActor @Observable
final class LaunchAtLogin {
    private static let appliedKey = "launchAtLoginApplied"

    /// Why the login item couldn't be changed, to show in Settings.
    private(set) var problem: String?
    /// The login item is registered but the user must allow it in System Settings → General → Login Items.
    private(set) var needsApproval = false
    /// Whether the system will open box4dd at login, as far as it says.
    private(set) var isEnabled = false

    @ObservationIgnored private let settings: Settings
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let service = SMAppService.mainApp

    init(settings: Settings, defaults: UserDefaults = .standard) {
        self.settings = settings
        self.defaults = defaults
    }

    /// The switch in Settings: shows the system's state, and changing it changes the login item.
    var isOn: Bool {
        get { isInAppBundle ? isEnabled : settings.launchAtLogin }
        set {
            settings.launchAtLogin = newValue
            apply()
        }
    }

    /// At launch: registers on first launch, or applies a setting that didn't take effect last time.
    func applyIfChanged() {
        if defaults.object(forKey: Self.appliedKey) as? Bool != settings.launchAtLogin {
            apply()
        } else {
            refresh()
        }
    }

    func refresh() {
        let status = service.status
        NSLog("box4dd: launch at login status \(status.rawValue) (0 not registered, 1 enabled, 2 requires approval, 3 not found)")
        isEnabled = status == .enabled || status == .requiresApproval
        needsApproval = status == .requiresApproval
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    // A login item needs an app bundle; `swift run` starts a bare executable.
    private var isInAppBundle: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    private func apply() {
        guard isInAppBundle else {
            problem = "Launch at login works only from the app bundle (scripts/bundle.sh), not from swift run."
            return
        }
        let wanted = settings.launchAtLogin
        do {
            let status = service.status
            if wanted, status != .enabled, status != .requiresApproval {
                try service.register()
            } else if !wanted, status == .enabled || status == .requiresApproval {
                try service.unregister()
            }
            defaults.set(wanted, forKey: Self.appliedKey)
            problem = nil
        } catch {
            NSLog("box4dd: couldn't \(wanted ? "register" : "unregister") the login item: \(error)")
            problem = "Couldn't \(wanted ? "turn on" : "turn off") launch at login: \(error.localizedDescription)"
        }
        refresh()
    }
}
