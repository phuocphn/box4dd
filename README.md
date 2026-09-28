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

### Opening a Shelf
- **Shake to open.** Start dragging anything, in any app, and shake the pointer left and right. A Shelf opens under the cursor, ready for your drop.
- **Keyboard shortcut.** Press **⌃⌥Space** (you can change it) to open an empty Shelf under the cursor.
- **Menu bar drop.** Drop anything on the menu bar icon to open a new Shelf holding it.
- **Several at once.** Each Shake, shortcut or drop opens a new Shelf, so you can collect things for different places in separate Shelves.

### What a Shelf holds
- **Finder files and folders.** These are kept as **references** to the originals, not copies, so no disk space is used. If you rename or move an original, the Shelf follows it. If you delete one, it stays on the Shelf marked as missing.
- **Text, links, rich text and images.** These are saved as files the app owns (`.txt`, `.webloc`, `.rtf`, `.png`). When you drag one out, a text field or address bar gets the text or link itself, and Finder gets a file.
- **Files from other apps**, such as Mail attachments and photos from Photos. A placeholder appears straight away and becomes the real file when it arrives.
- **Paste** with ⌘V to add what's on the clipboard.

### Working with Items
- **Stack view.** A Shelf shows a small pile of icons with a count. Click it to expand it into a list.
- **Select** one, several (⌘/⇧-click) or all (⌘A) Items, and drag out just those.
- **Quick Look** with Space, **remove** with ⌫ (originals are never touched), **copy** with ⌘C, and **Show in Finder**.
- **Behaves like Finder when dragging out.** Dragging to the same disk moves the files, dragging to another disk copies them, and holding ⌥ forces a copy. Items you drop somewhere leave the Shelf, and an empty Shelf closes itself.

### Stays out of your way
- **Menu bar only.** No Dock icon and no ⌘Tab entry.
- **Floats above other windows**, stays visible when you switch Spaces and over full-screen apps, and **never steals keyboard focus** until you click a Shelf.
- **Recent Shelves.** The last 10 closed Shelves can be reopened from the menu bar, so closing one by accident loses nothing.
- **Reopens after a restart.** Shelves that were open when you quit or restarted come back where they were.

### Settings
Shake sensitivity, the new-Shelf shortcut, launch at login, and **Excluded Apps**: apps where a Shake is ignored, such as design tools or games.

### Permissions
None expected. box4dd reads the pointer position and watches for drags without Accessibility or Input Monitoring access. The global shortcut uses Carbon hot keys, which also need no permission.

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

## How it's built

box4dd is a native Swift app. AppKit handles windows, drag-and-drop and the menu bar, and SwiftUI draws the contents of each Shelf. [ADR 0001](docs/adr/0001-native-appkit-over-web-stack.md) explains why.

```
Sources/
  ShelfCore/    Shelf rules. No AppKit. Covered by the automated tests.
                  Shelves        - Shelves, Items, Recent Shelves, restore after relaunch, Placeholders
                  ShakeDetector  - turns pointer samples into "was that a Shake?"
  Box4dd/       Thin AppKit/SwiftUI app: panels, drag in and out, file promises,
                menu bar, hot key, Shake monitor, Settings
Tests/ShelfCoreTests/   Swift Testing suites for the two seams above
docs/
  adr/                  Architecture decisions
  manual-checklist.md   Hand checks for the parts tests can't reach
CONTEXT.md              Glossary: Shelf, Item, Reference/Captured/Missing Item, Shake, Stack, ...
```

**Testing approach:** everything that can be tested without a screen lives in `ShelfCore` and is tested only through two public interfaces: `Shelves` and `ShakeDetector`. The AppKit layer is kept thin and checked by hand using [`docs/manual-checklist.md`](docs/manual-checklist.md), because dragging between apps can't be reliably tested automatically.

```sh
scripts/test.sh   # runs the test suite (finds Swift Testing even without Xcode)
swift build       # debug build
```

---

## Contributing

Contributions are welcome, from bug reports to whole features. Some good ways to help:

- **Run the manual checklist** ([`docs/manual-checklist.md`](docs/manual-checklist.md)) on your Mac and report what fails. This is the most useful thing right now.
- **Try it with your apps.** Browser, Mail, Photos, design tools: tell us what drags in or out badly.
- **Pick up a [known limitation](#known-limitations)** or an open [issue](https://github.com/phuocphn/box4dd/issues).
- **Add screenshots or a short demo GIF** to this README.

### Workflow

1. Open an issue first for anything bigger than a small fix, so we can agree on the approach.
2. Fork, then branch from `master`.
3. **Use the glossary.** Name things with the terms in [`CONTEXT.md`](CONTEXT.md): a *Shelf* holds *Items*; an Item is a *Reference Item* or a *Captured Item*. Avoid words it lists under *Avoid* (e.g. "tray", "box" for a Shelf).
4. **Write the test first** for any change to Shelf rules or Shake detection. Add a failing test in `Tests/ShelfCoreTests` that uses only the public interface, then make it pass. Keep AppKit out of `ShelfCore`.
5. For app-layer changes, add or update the matching section of `docs/manual-checklist.md`, and say in the PR which items you checked by hand.
6. Make sure `scripts/test.sh` passes and `swift build` shows no warnings (the code builds in Swift 6 strict concurrency mode).
7. Open a PR against `master` that references the issue.

Record decisions that are hard to reverse as a short ADR in `docs/adr/`.

---

## Known limitations

- **No prebuilt, notarized download**, only building from source.
- **Browser drags:** Chrome image drags may arrive as a link instead of an image, and rich text from Chrome loses its formatting.
- Finder may create a **text clipping** instead of a file when you drag a Captured Item out.
- A promised file that **never arrives** has no timeout; remove it with ⌫ or relaunch.
- The Settings window may not take keyboard focus in every case, and there's no ⌘W to close it.
- Only side-to-side motion counts as a Shake.
- Parts of the manual checklist haven't been run yet (Recent Shelves, Captured Items, file promises, Quick Look, Settings, launch at login).

## Not planned for v1

Cloud upload and sharing, Instant Actions and scripts, image resize, text extraction and ZIP, renaming Items, pinned or docked Shelves, watched folders, and Shortcuts, Alfred or Raycast integrations. If you'd like one of these, open an issue to discuss it.

---

## License

[MIT](LICENSE) © 2026 Phuoc Pham

Inspired by [Dropover](https://dropoverapp.com/). box4dd is an independent project and is not affiliated with or endorsed by its makers.
