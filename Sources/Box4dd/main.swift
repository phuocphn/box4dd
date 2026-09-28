import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Menu bar only: no Dock icon, no ⌘Tab entry (Info.plist's LSUIElement says the same for the bundled app).
app.setActivationPolicy(.accessory)
app.run()
