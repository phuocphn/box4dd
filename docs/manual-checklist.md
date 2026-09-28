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
- [ ] Drag Items out of a Shelf's Stack while typing in TextEdit: keystrokes still go to TextEdit (since #7, *clicking* a Shelf takes the keys; see Slice 6)

## Slice 6: Stack and Item actions (#7)

Setup: TextEdit in front with the cursor in a document; a Shelf holding 4 Finder files (make copies in a scratch folder first).

Stack and expanding
- [ ] A Shelf with Items shows a Stack: a pile of up to 3 icons and "4 items"
- [ ] Click the Stack: the Shelf grows downwards into a list of the 4 Items, top edge unchanged, with a collapse button at the top right
- [ ] A slightly shaky click still expands (doesn't start a drag)
- [ ] The collapse button returns to the Stack; so does Esc while the list has the keys
- [ ] Clicking an empty Shelf does nothing (no empty list)

Focus
- [ ] ⌃⌥Space while typing in TextEdit: TextEdit keeps the keys (opening never takes them)
- [ ] Drag a Finder file over a Shelf and hover without dropping, while TextEdit had the keys: TextEdit keeps them
- [ ] Drag all Items out of the Stack to a folder: TextEdit still has the keys afterwards
- [ ] Click the Stack or a row in the list: the Shelf takes the keys, and TextEdit stays the frontmost app (its menu bar stays)
- [ ] Then click back in TextEdit: typing goes to TextEdit again, and space/⌫ no longer act on the Shelf
- [ ] Known limit: after Esc collapses the Stack, the Shelf keeps the keys until you click elsewhere

Selecting
- [ ] In the list, click selects one Item; ⌘-click adds and removes Items; ⇧-click selects a range; ⌘A selects all
- [ ] The first click on a Shelf that doesn't have the keys already selects (no wasted click)

Dragging out a selection
- [ ] Select 2 of 4 Items, drag them to a Finder folder: only those 2 files move there, and the Shelf shows the other 2
- [ ] Drag one unselected Item: only that Item goes
- [ ] Select 2, start dragging, press Esc: all Items stay
- [ ] Select 2, drag them onto another Shelf: they move to that Shelf, and 2 stay on the first
- [ ] Drag the last Items out of the list: the Shelf closes
- [ ] Drag the Stack (collapsed): all Items go, as in Slice 1
- [ ] Drop more Finder files onto the expanded list: it highlights, and the new Items appear in the list

Keys
- [ ] Select 2 Items, press space: Quick Look shows them (arrows in Quick Look page between them); space again closes it
- [ ] With Quick Look open, change the selection with ↑/↓: the preview follows
- [ ] Select 1 Item, press ⌫: it leaves the Shelf and the original file is still in its folder, unchanged
- [ ] Select all, press ⌫: the Shelf closes, and every original is still in its folder
- [ ] Select 2 Items, ⌘C, then click a Finder folder window and ⌘V: copies of both files appear there, the originals stay, and the Items stay on the Shelf

Show in Finder
- [ ] Right-click an Item in the list → Show in Finder: Finder opens with the original selected
- [ ] Right-click one of several selected Items → Show in Finder: all selected originals are revealed
- [ ] Right-click the Stack → Show in Finder: all the Shelf's originals are revealed
- [ ] Move one original to another folder in Finder, then Show in Finder: it reveals the new location
