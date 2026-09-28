# box4dd

**A temporary place to put things while you drag and drop on macOS.**

On a Mac, drag-and-drop only works when the thing you're dragging and the place it's going are both visible at once. box4dd gives you somewhere to put things in between. Shake the pointer while dragging and a small floating **Shelf** appears under the cursor. Drop files, text, links or images on it, go wherever you need to, then drag everything out together.

box4dd is a free, open-source app inspired by [Dropover](https://dropoverapp.com/). It is not affiliated with Dropover.

![macOS 26+](https://img.shields.io/badge/macOS-26%2B-black?logo=apple)
![Swift 6](https://img.shields.io/badge/Swift-6-orange?logo=swift)
![License: MIT](https://img.shields.io/badge/license-MIT-blue)

> **Status:** v1 is feature-complete and has 54 automated tests. Some parts have only been checked by hand so far, not by automated tests; see [Known limitations](#known-limitations). Bug reports are very welcome.

---

## Features

- **Shake to open.** Shake the pointer while dragging in any app, and a Shelf opens under the cursor. You can also press **⌃⌥Space** or drop onto the menu bar icon.
- **Holds anything.** Finder files are kept as references that follow their originals. Text, links, rich text, images, and files from Mail or Photos are saved as files the Shelf owns.
- **Drag out together.** Drag out all the Items or a selection. Dragging out works the same way it does in Finder, and an empty Shelf closes itself.
- **Quick actions.** Quick Look (Space), remove (⌫), copy (⌘C), paste (⌘V), Show in Finder.
- **Stays out of the way.** Menu bar only. Shelves float above other windows and across Spaces, and don't take keyboard focus until you click one.
- **Nothing lost.** Reopen any of the last 10 closed Shelves, and open Shelves come back after a restart.
- **Configurable, no permissions needed.** Adjust shake sensitivity, the shortcut, launch at login, and Excluded Apps. No Accessibility or Input Monitoring access is required.

---

## Install

There's no prebuilt download yet. Build it from source. You only need the Command Line Tools; Xcode is optional.

**Requirements:** macOS 26 or later, and the Swift 6.2 toolchain (`xcode-select --install`).

```sh
git clone https://github.com/phuocphn/box4dd.git
cd box4dd
scripts/bundle.sh          # builds build/box4dd.app (ad-hoc signed)
open build/box4dd.app
```

To keep it, move `build/box4dd.app` into `/Applications`. Launch at login is on by default; you can turn it off in **Settings…** (⌘, from the menu bar icon).

## Usage

1. Start dragging something: files in Finder, selected text, an image in a browser.
2. **Keep holding the mouse button and shake** the pointer left and right. A Shelf appears. (Shaking without a drag in progress does nothing, on purpose.)
3. Drop onto the Shelf, then go wherever you need to.
4. Drag the Shelf's Items out to deliver them. When the Shelf is empty it closes and moves to **Recent Shelves** in the menu bar.

Move a Shelf by dragging its top strip; an empty Shelf can be moved from anywhere. Close a Shelf with the button at its top-left.

---

## Design decisions

The reasons behind box4dd's design are written down as **Architecture Decision Records** in [`docs/adr/`](docs/adr/). **Read them before proposing a big change.** They record the trade-offs already made and the alternatives that were turned down.

| ADR | Decision |
|---|---|
| [0001](docs/adr/0001-native-appkit-over-web-stack.md) | Native Swift with AppKit, not a web stack or SwiftUI alone. macOS 26 minimum. |

The shared vocabulary (Shelf, Item, Reference Item, Captured Item, Shake, Stack, …) is in [`CONTEXT.md`](CONTEXT.md).

---

## Contributing

Contributions are welcome. The most useful thing right now is running [`docs/manual-checklist.md`](docs/manual-checklist.md) on your Mac and [reporting](https://github.com/phuocphn/box4dd/issues) what fails.

1. Read the [ADRs](docs/adr/) and [`CONTEXT.md`](CONTEXT.md), and use the glossary's terms in code.
2. For anything bigger than a small fix, open an issue first.
3. Write the test first for changes to Shelf rules or Shake detection (`Tests/ShelfCoreTests`). For app-layer changes, update the manual checklist.
4. `scripts/test.sh` must pass and `swift build` must show no warnings.
5. Add an ADR for any decision that's hard to reverse, then open a PR against `master`.

---

## Known limitations

- **No prebuilt, notarized download**, only building from source.
- **Browser drags:** Chrome image drags may arrive as a link instead of an image, and rich text from Chrome loses its formatting.
- Finder may create a **text clipping** instead of a file when you drag a Captured Item out.
- A promised file that **never arrives** has no timeout; remove it with ⌫ or relaunch.
- The Settings window may not take keyboard focus in every case, and there's no ⌘W to close it.
- Only side-to-side motion counts as a Shake.
- Parts of the manual checklist haven't been run yet (Recent Shelves, Captured Items, file promises, Quick Look, Settings, launch at login).

---

## License

[MIT](LICENSE) © 2026 Phuoc Pham

Inspired by [Dropover](https://dropoverapp.com/). box4dd is an independent project and is not affiliated with or endorsed by its makers.
