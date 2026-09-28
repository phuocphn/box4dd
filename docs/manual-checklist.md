# Manual checklist

The app layer (panels, drag-and-drop, hotkey, menu bar) is checked by hand. Build and launch with:

```sh
scripts/bundle.sh && open build/box4dd.app
```

Each slice adds its own section. Run all sections before closing a slice.

## Slice 1: Basic Shelf (#2)

- [ ] The app shows only a menu bar icon: no Dock icon, and it's not in ⌘Tab
- [ ] Menu bar icon → Quit box4dd quits the app
- [ ] ⌃⌥Space opens an empty Shelf under the cursor ("Drop files here")
- [ ] ⌃⌥Space again opens a second Shelf; both stay open
- [ ] Menu bar icon → New Shelf opens a Shelf too
- [ ] With TextEdit in front and typing, ⌃⌥Space opens a Shelf and TextEdit keeps focus (you can keep typing)
- [ ] The Shelf stays above TextEdit when you click TextEdit
- [ ] Switch Space (⌃→): the Shelf is still visible
- [ ] Put Safari in full screen: ⌃⌥Space opens a Shelf over it
- [ ] Dragging the Shelf's top strip moves it (empty Shelves also move by dragging anywhere)
- [ ] Drag 3 Finder files onto a Shelf: it highlights while hovering, then shows a pile of icons and "3 items"
- [ ] No files are copied: the originals are still where they were, and there are no new files anywhere
- [ ] Drag the Items from the Shelf to the Desktop (same volume): the files **move** there, and the Shelf closes because it's empty
- [ ] Drop files on a Shelf, then drag them out to a USB drive or other volume: the files are **copied**, and the Shelf closes
- [ ] Drop files on a Shelf, drag them out holding ⌥ onto a folder on the same volume: the files are **copied**
- [ ] Drop files on a Shelf, start dragging them out, then press Esc or drop back on the same Shelf: the Items stay
- [ ] Drag Items from one Shelf onto another: they move to the second Shelf, and the first closes
- [ ] The close button on a Shelf with Items closes it, and the original files are untouched
- [ ] Drag Items from a Shelf onto the Trash: the drop is refused, and the Items and originals stay
- [ ] Click a Shelf while typing in TextEdit: keystrokes still go to TextEdit

## Slice 2: Shake (#3)

Start from a fresh install with no permissions granted to box4dd (System Settings → Privacy & Security → Accessibility and Input Monitoring both list nothing for it). The Shake is expected to need neither.

- [ ] On first launch no permission prompt appears, and box4dd is not added to Accessibility or Input Monitoring
- [ ] Drag 3 Finder files and Shake left-right quickly: a new Shelf opens under the cursor while the drag is still going
- [ ] Without letting go, drop the files on that Shelf: it shows "3 items"
- [ ] Shake while dragging selected text in Safari or TextEdit: a Shelf opens (it may refuse the text until Captured Items land)
- [ ] Shake while dragging an Item out of a Shelf: another Shelf opens, and the Items can be dropped on it
- [ ] Keep shaking for 2 seconds without stopping: only one Shelf opens
- [ ] Shake, pause for a second, Shake again in the same drag: a second Shelf opens
- [ ] Shake with a drag hovering over an existing Shelf: a new Shelf opens on top of it
- [ ] Shake the pointer with no button held: nothing opens
- [ ] Hold the button on the desktop (rubber-band selection) and Shake: nothing opens
- [ ] Drag a window by its title bar and Shake: nothing opens
- [ ] Drag a file slowly across the whole screen and drop it: nothing opens
- [ ] Drag a file and wiggle slowly left-right (about a third of a second per stroke): nothing opens
- [ ] Drag and Shake inside a full-screen app: the Shelf opens over it
- [ ] Activity Monitor shows box4dd near 0% CPU while idle
