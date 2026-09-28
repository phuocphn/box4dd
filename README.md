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

Contributions are welcome, from bug reports to whole features. Some good ways to help:

- **Run the manual checklist** ([`docs/manual-checklist.md`](docs/manual-checklist.md)) on your Mac and report what fails. This is the most useful thing right now.
- **Try it with your apps.** Browser, Mail, Photos, design tools: tell us what drags in or out badly.
- **Pick up a [known limitation](#known-limitations)** or an open [issue](https://github.com/phuocphn/box4dd/issues).
- **Add screenshots or a short demo GIF** to this README.

### Workflow

1. Read the [ADRs](docs/adr/) and [`CONTEXT.md`](CONTEXT.md), then open an issue for anything bigger than a small fix, so we can agree on the approach.
2. Fork, then branch from `master`.
3. **Use the glossary.** Name things with the terms in [`CONTEXT.md`](CONTEXT.md): a *Shelf* holds *Items*; an Item is a *Reference Item* or a *Captured Item*. Avoid words it lists under *Avoid* (e.g. "tray", "box" for a Shelf).
4. **Write the test first** for any change to Shelf rules or Shake detection. Add a failing test in `Tests/ShelfCoreTests` that uses only the public interface, then make it pass. Keep AppKit out of `ShelfCore`.
5. For app-layer changes, add or update the matching section of `docs/manual-checklist.md`, and say in the PR which items you checked by hand.
6. Make sure `scripts/test.sh` passes (it runs the tests and finds Swift Testing even without Xcode) and that `swift build` shows no warnings. The code builds in Swift 6 strict concurrency mode.
7. Open a PR against `master` that references the issue.

**Architecture decisions:** if your change is hard to reverse or goes against an existing ADR, add a new ADR in [`docs/adr/`](docs/adr/) as part of the PR. Name it `NNNN-short-title.md` and write a paragraph on the context, the decision and why. Say whether it supersedes an earlier one.

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
