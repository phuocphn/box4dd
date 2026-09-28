import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The Settings window, opened from the menu bar. Unlike a Shelf it's a normal window: opening it brings
/// the app forward and takes the keys, so the shortcut recorder can hear what the user types.
@MainActor
final class SettingsWindow: NSObject, NSWindowDelegate {
    private let settings: Settings
    private let newShelfShortcut: NewShelfShortcut
    private let launchAtLogin: LaunchAtLogin
    private var window: NSWindow?

    init(settings: Settings, newShelfShortcut: NewShelfShortcut, launchAtLogin: LaunchAtLogin) {
        self.settings = settings
        self.newShelfShortcut = newShelfShortcut
        self.launchAtLogin = launchAtLogin
    }

    func show() {
        let window = self.window ?? makeWindow()
        self.window = window
        launchAtLogin.refresh()
        // A menu bar app isn't active after its menu is used, so ask to come forward before showing the window.
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    private func makeWindow() -> NSWindow {
        let view = SettingsView(settings: settings, newShelfShortcut: newShelfShortcut, launchAtLogin: launchAtLogin)
        let hosting = NSHostingController(rootView: view)
        hosting.sizingOptions = .preferredContentSize
        let window = NSWindow(contentViewController: hosting)
        window.title = "box4dd Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        return window
    }

    func windowWillClose(_ notification: Notification) {
        newShelfShortcut.stopRecording()
    }
}

private struct SettingsView: View {
    @Bindable var settings: Settings
    let newShelfShortcut: NewShelfShortcut
    @Bindable var launchAtLogin: LaunchAtLogin

    var body: some View {
        Form {
            Section("Shake") {
                LabeledContent("Sensitivity") {
                    Slider(value: $settings.shakeSensitivity, in: 0...1) {
                        EmptyView()
                    } minimumValueLabel: {
                        Text("Wide")
                    } maximumValueLabel: {
                        Text("Small")
                    }
                }
                Text("How small a back-and-forth motion while dragging opens a Shelf.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("New Shelf shortcut") {
                ShortcutRecorder(newShelfShortcut: newShelfShortcut)
            }
            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin.isOn)
                if launchAtLogin.needsApproval {
                    HStack {
                        Text("Allow box4dd in System Settings to open it at login.")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Open Login Items…") { launchAtLogin.openLoginItemsSettings() }
                    }
                }
                if let problem = launchAtLogin.problem {
                    Text(problem).foregroundStyle(.red)
                }
            }
            Section {
                ExcludedAppsList(bundleIDs: $settings.excludedApps)
            } header: {
                Text("Excluded Apps")
            } footer: {
                Text("A Shake is ignored while one of these apps is in front.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct ShortcutRecorder: View {
    let newShelfShortcut: NewShelfShortcut

    var body: some View {
        LabeledContent("Open a new Shelf") {
            HStack {
                Button(newShelfShortcut.isRecording ? "Type a shortcut…" : newShelfShortcut.shortcut.displayName) {
                    if newShelfShortcut.isRecording {
                        newShelfShortcut.stopRecording()
                    } else {
                        newShelfShortcut.startRecording()
                    }
                }
                .frame(minWidth: 120)
                if !newShelfShortcut.isRecording, newShelfShortcut.shortcut != .standard {
                    Button("Reset") { newShelfShortcut.change(to: .standard) }
                }
            }
        }
        if let problem = newShelfShortcut.problem {
            Text(problem).foregroundStyle(.red)
        } else if newShelfShortcut.isRecording {
            Text("Press the new shortcut, or Esc to cancel.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ExcludedAppsList: View {
    @Binding var bundleIDs: [String]
    @State private var selection: Set<String> = []

    var body: some View {
        if bundleIDs.isEmpty {
            Text("No Excluded Apps")
                .foregroundStyle(.secondary)
        } else {
            List(bundleIDs, id: \.self, selection: $selection) { bundleID in
                ExcludedAppRow(bundleID: bundleID)
            }
            .frame(minHeight: 100)
        }
        HStack {
            Button("Add App…", action: addApps)
            Button("Remove") {
                bundleIDs.removeAll { selection.contains($0) }
                selection = []
            }
            .disabled(selection.isEmpty)
        }
    }

    private func addApps() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(filePath: "/Applications")
        panel.prompt = "Exclude"
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            if let bundleID = Bundle(url: url)?.bundleIdentifier, !bundleIDs.contains(bundleID) {
                bundleIDs.append(bundleID)
            }
        }
    }
}

private struct ExcludedAppRow: View {
    let bundleID: String

    var body: some View {
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        HStack {
            Image(nsImage: url.map { NSWorkspace.shared.icon(forFile: $0.path) } ?? NSWorkspace.shared.icon(for: .applicationBundle))
                .resizable()
                .frame(width: 20, height: 20)
            // An app that's no longer installed shows its bundle ID.
            Text(url.map { FileManager.default.displayName(atPath: $0.path) } ?? bundleID)
        }
        .help(bundleID)
    }
}
