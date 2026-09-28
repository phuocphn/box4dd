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

## Slice 3: Recent Shelves and reopen-on-launch (#4)

Saved state lives in `~/Library/Application Support/box4dd/shelves.json`. Delete it to start clean.

- [ ] Menu bar icon → Recent Shelves shows "No Recent Shelves" on a clean start
- [ ] Drop 3 Finder files on a Shelf, close it with its close button: Recent Shelves lists it as "<first file> + 2 more — now"
- [ ] Choose that entry: the Shelf reopens where it was, with the same 3 Items, and it's gone from the Recent list
- [ ] Drag all Items out of a Shelf to the Desktop: the Shelf closes and is first in Recent Shelves; reopening it shows those Items, now pointing at the files on the Desktop
- [ ] Open a Shelf and close it without dropping anything: it does not appear in Recent Shelves
- [ ] Close 11 Shelves that each hold an Item: Recent Shelves lists 10, newest first, and the first one closed is gone
- [ ] Open two Shelves with Items, move one somewhere else, quit from the menu, relaunch: both reopen in the same positions with their Items
- [ ] Log out or restart the Mac with Shelves open, then launch the app: they reopen where they were
- [ ] Recent Shelves are still listed after a relaunch
- [ ] Drop a file on a Shelf, rename it in Finder: within a few seconds the Shelf shows the new name, and dragging it out delivers the renamed file
- [ ] Drop a file on a Shelf, move it to another folder in Finder: dragging it out still works and delivers that file
- [ ] Drop a file on a Shelf and delete it (move to Trash, and separately empty the Trash): within a few seconds the Item shows a "?" icon and "(missing)", and stays on the Shelf
- [ ] Put the trashed file back (Finder → Put Back): the Item is no longer missing
- [ ] Drag a Shelf holding a Missing Item and a normal Item out to a folder: only the normal Item is delivered
- [ ] A Recent Shelf whose original was deleted reopens with that Item marked missing
- [ ] Put a Shelf on a second display, quit, disconnect the display, relaunch: the Shelf reopens on the remaining screen
