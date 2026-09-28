// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "box4dd",
    platforms: [.macOS(.v26)],
    targets: [
        // Shelf rules. No AppKit here: everything in this target is tested through its public interface.
        .target(name: "ShelfCore"),
        // The menu bar app: panels, drag-and-drop, hotkey. Kept thin and checked by hand (docs/manual-checklist.md).
        .executableTarget(name: "Box4dd", dependencies: ["ShelfCore"]),
        .testTarget(name: "ShelfCoreTests", dependencies: ["ShelfCore"]),
    ]
)
