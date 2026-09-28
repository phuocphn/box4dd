# Manual checklist

The app layer (panels, drag-and-drop, hotkey, menu bar) is checked by hand. Build and launch with:

```sh
scripts/bundle.sh && open build/box4dd.app
```

Each slice adds its own section. Run all sections before closing a slice.

## Slice 1: Basic Shelf (#2)

- [ ] The app shows only a menu bar icon: no Dock icon, and it's not in ⌘Tab
- [ ] Menu bar icon → Quit box4dd quits the app
- [ ] ⌃⌥Space opens an empty Shelf under the cursor ("Drop or paste here")
- [ ] ⌃⌥Space again opens a second Shelf; both stay open
- [ ] Menu bar icon → New Shelf opens a Shelf too
- [ ] With TextEdit in front and typing, ⌃⌥Space opens a Shelf and TextEdit keeps focus (you can keep typing)
- [ ] The Shelf stays above TextEdit when you click TextEdit
- [ ] Switch Space (⌃→): the Shelf is still visible
- [ ] Put Safari in full screen: ⌃⌥Space opens a Shelf over it
- [ ] Dragging the Shelf's top strip moves it (an empty Shelf also moves by dragging anywhere); with Items, dragging below the strip drags the Items, never the Shelf
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

## Slice 2: Shake (#3)

Start from a fresh install with no permissions granted to box4dd (System Settings → Privacy & Security → Accessibility and Input Monitoring both list nothing for it). The Shake is expected to need neither.

- [ ] On first launch no permission prompt appears, and box4dd is not added to Accessibility or Input Monitoring
- [ ] Drag 3 Finder files and Shake left-right quickly: a new Shelf opens under the cursor while the drag is still going
- [ ] Without letting go, drop the files on that Shelf: it shows "3 items"
- [ ] Shake while dragging selected text in Safari or TextEdit: a Shelf opens, and dropping the text on it adds a Captured Item
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

## Slice 4: Captured Items (#5)

Captured Item files live in `~/Library/Application Support/box4dd/Captured/<id>/<name>`. Open that folder in Finder to watch it.

Dropping content
- [ ] Select a sentence in TextEdit (plain text document) and drag it onto a Shelf: a Captured Item named after its first words appears, with a text file icon; a `.txt` file appears in `Captured`
- [ ] Drag a link from a Safari page onto a Shelf: a `.webloc` Captured Item named after the page title (or the host)
- [ ] Drag Safari's address bar URL onto a Shelf: a `.webloc` Captured Item
- [ ] Select formatted text (bold, colors) in a TextEdit rich text document or a Safari page and drop it: a `.rtf` Captured Item; Quick Look (space in the list) shows the formatting
- [ ] Drag an image from a Safari page onto a Shelf: one Captured Item showing a thumbnail of the image, not a link as well (since #6, if Safari promises the file it arrives under its own name and format, e.g. `photo.jpg`, instead of "Image.png")
- [ ] Same in Chrome (known risk: Chrome may only offer the image's address, giving a `.webloc`; note what happens)
- [ ] Take a screenshot with ⌘⇧4, then drag its floating thumbnail onto a Shelf: it's added (as a Reference Item to the screenshot file, or a Captured image)
- [ ] Drag 2 Finder files onto a Shelf: they are Reference Items as before (no files in `Captured`), and a Missing Item still shows "(missing)" when its original is trashed
- [ ] One Shelf holding Finder files, text, a link and an image shows them all in the Stack and the list, in the order they were dropped

Pasting with ⌘V
- [ ] ⌃⌥Space opens an empty Shelf; typing still goes to TextEdit. Click the empty Shelf, then ⌘V with text on the clipboard: a Captured text Item appears
- [ ] Copy a URL in Safari's address bar, click a Shelf, ⌘V: a `.webloc` Captured Item
- [ ] Copy formatted text in TextEdit, ⌘V on a Shelf: a `.rtf` Captured Item that keeps the formatting
- [ ] Copy a screenshot to the clipboard (⌘⌃⇧4), ⌘V on a Shelf: an "Image.png" Captured Item
- [ ] Copy 2 files in Finder (⌘C), ⌘V on a Shelf: 2 Reference Items, and no new files in `Captured`
- [ ] ⌘V on a Shelf with the list expanded adds to it; with the Stack collapsed (after Esc) too
- [ ] ⌘V with an empty clipboard beeps and adds nothing
- [ ] ⌘V while TextEdit has the keys pastes into TextEdit, not onto the Shelf

Dragging out
- [ ] Drag a text Captured Item into a TextEdit document and into Safari's search field: the text is inserted (not a file or a path)
- [ ] Drag a link Captured Item into Safari's address bar: the URL is filled in
- [ ] Drag a rich text Captured Item into a TextEdit rich text document: the formatting is kept
- [ ] Drag an image Captured Item into a TextEdit rich text document or Mail message: the image is inserted
- [ ] Drag each kind to a Finder folder: a `.txt`, `.webloc`, `.rtf` or `.png` file with the Item's name appears there, and the file in `Captured` is still there (copied, not moved)
- [ ] Double-click the delivered `.webloc`: the page opens in the browser
- [ ] Each accepted drag-out takes the Item off the Shelf, as for Finder files
- [ ] Drag a Stack holding a Finder file and a text Captured Item to a folder on the same volume: the Finder file is moved and the text arrives as a new `.txt` file
- [ ] Drag a Captured Item from one Shelf onto another: it lands on the second Shelf and leaves the first
- [ ] Select a Captured Item, ⌘C, then ⌘V in TextEdit: the text goes in; ⌘V in a Finder window: a copy of the file appears
- [ ] Right-click a Captured Item → Show in Finder is disabled (it lives in app storage); a Stack of only Captured Items has no Show in Finder menu

File lifecycle
- [ ] Remove a Captured Item with ⌫ while other Items stay: its file stays in `Captured`
- [ ] Drag out the last Captured Item to a text field: the Shelf goes to Recent Shelves; reopening it shows the Item, and dragging it out again still works
- [ ] Quit and relaunch: open and Recent Shelves still show their Captured Items with their names and thumbnails
- [ ] Put two text Captured Items, an image Captured Item and a Finder file on a Shelf, remove one text Item with ⌫, close the Shelf, then close 10 more Shelves that each hold an Item: the first Shelf leaves Recent Shelves, all three of its `Captured/<id>` folders are deleted (the ⌫ one too), and the Finder file's original is untouched
- [ ] Items dragged to another Shelf before the first Shelf fell off Recent Shelves still work on the second Shelf

## Slice 5: File promises (#6)

Promised files are written to `~/Library/Application Support/box4dd/Incoming/<drop id>/` while they arrive, then moved to `Captured/<id>/<name>`. Watch both folders in Finder. `log stream --predicate 'process == "Box4dd"'` shows "a promised file didn't arrive" errors.

Mail
- [ ] Drag a PDF attachment from a Mail message onto a Shelf: a Placeholder with a spinner and the attachment's name shows at once, then turns into a Captured Item with the PDF's icon and the same name; the file is in `Captured/<id>/`, not in Mail's folders
- [ ] Drag an image attachment from Mail: it becomes a Captured Item with a thumbnail, not a link or a preview-sized image
- [ ] Select 2 attachments in one message and drag them together: 2 Placeholders, then 2 Captured Items, in order
- [ ] Drag a whole message from Mail's message list onto a Shelf: note what arrives (expected: a `.eml` Captured Item, or a link)

Photos
- [ ] Drag one photo from Photos onto a Shelf: a Placeholder, then a Captured Item holding the image file (`.heic` or `.jpeg`) with a thumbnail
- [ ] Drag 3 photos at once: 3 Placeholders, then 3 Captured Items; "3 items" in the Stack
- [ ] Drag a photo that's only in iCloud (Optimize Mac Storage on): the Placeholder spins while it downloads, then becomes the image
- [ ] Drag a video from Photos (a slow, large promise): the Placeholder stays with its spinner for the whole export, and meanwhile other Items can be dropped on the Shelf and dragged out
- [ ] Drop a photo on the menu bar icon: a new Shelf opens with the Placeholder, which becomes the image

Browsers
- [ ] Drag an image from Safari and from Chrome onto a Shelf: a Captured image file (promised or saved as PNG), never only a `.webloc`
- [ ] Drag a "download linked file" style item (e.g. a file link or a download from Safari's Downloads popover) onto a Shelf: it arrives as a Captured Item holding the file, or is refused; note which

Nothing else changed
- [ ] Drag 2 Finder files onto a Shelf: 2 Reference Items at once (no Placeholder, nothing in `Incoming` or `Captured`)
- [ ] Drag selected text from TextEdit and a link from Safari: still a `.txt` and a `.webloc` Captured Item, no Placeholder
- [ ] ⌘V with a copied Mail attachment or photo on the clipboard: whatever is added arrives straight away (the clipboard never makes Placeholders)
- [ ] Drag a text Captured Item from one Shelf onto another: it arrives on the second Shelf (possibly after a brief Placeholder) as a `.txt` with the same name, and leaves the first

While a Placeholder is pending
- [ ] Drag the Stack out to a folder while a Placeholder is pending: only the ready Items go, and the Placeholder stays on the Shelf
- [ ] In the list, a Placeholder row can't be dragged, ⌘C with only it selected copies nothing, and space shows no preview
- [ ] Select a pending Placeholder and press ⌫: it leaves the Shelf; when the file arrives it doesn't come back, and its folder is gone from `Captured`
- [ ] Close the Shelf while a Placeholder is pending: Recent Shelves lists it without the Placeholder (or doesn't list it if the Placeholder was all it held); when the file arrives it's deleted, not left in `Captured`

Failure and cancellation
- [ ] Start dragging a large video from Photos to a Shelf, then cancel the export in Photos (if it offers one): the Placeholder goes away, with a short "Couldn't get …" message at the bottom of the Shelf that fades after a few seconds; no dialog
- [ ] A failed Placeholder on a Shelf that held nothing else: the Shelf closes (with a beep) and doesn't appear in Recent Shelves
- [ ] Press Esc during a Mail or Photos drag before dropping: nothing is added, no Placeholder, nothing in `Incoming`

Quitting while a promise is pending
- [ ] Start a slow Photos drop (a video), quit box4dd from the menu before it finishes, relaunch: the Shelf comes back with its other Items and no Placeholder (a Shelf that held only the Placeholder doesn't come back), and `Incoming` is empty

Dragging out
- [ ] Drag a Captured Item that came from Mail to a Finder folder: a copy of the file appears under its name, and the Item leaves the Shelf, like any Captured Item
- [ ] Drag a Captured photo into a Mail compose window or a TextEdit rich text document: the image is inserted
- [ ] Captured Items from promises survive a relaunch with their names and thumbnails, and their `Captured/<id>` folders are deleted when their Shelf falls off Recent Shelves

## Slice 6: Stack and Item actions (#7)

Setup: TextEdit in front with the cursor in a document; a Shelf holding 4 Finder files (make copies in a scratch folder first).

Stack and expanding
- [ ] A Shelf with Items shows a Stack: a pile of up to 3 icons and "4 items"
- [ ] Click the Stack: the Shelf grows downwards into a list of the 4 Items, top edge unchanged, with a collapse button at the top right
- [ ] A slightly shaky click still expands (doesn't start a drag)
- [ ] The collapse button returns to the Stack; so does Esc while the list has the keys
- [ ] Clicking an empty Shelf shows no empty list (since #5 it takes the keys, for ⌘V)

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

## Slice 7: Settings and dropping on the menu bar icon (#8)

Settings live in UserDefaults (`defaults read com.phuocphn.box4dd`; `defaults delete com.phuocphn.box4dd` starts clean). Login items can be inspected with `sfltool dumpbtm | grep -A8 "Name: box4dd"`.

Opening Settings
- [ ] Menu bar icon → Settings… (shown with ⌘,) opens "box4dd Settings", in front and with the keys (its traffic lights are coloured), even while another app was in front
- [ ] Settings… again while the window is open brings the same window forward (no second window)
- [ ] Close the window, open it again: it shows the same values

Shake sensitivity
- [ ] Slide sensitivity to Small: a gentle Shake (short strokes) while dragging a Finder file opens a Shelf
- [ ] Slide it to Wide, without relaunching: the same gentle Shake no longer opens a Shelf, a wide one does

New-Shelf shortcut
- [ ] The shortcut shows ⌃⌥Space, and the menu's New Shelf item shows ⌃⌥Space too
- [ ] Click it, press ⌃⌥Space: it records ⌃⌥Space again, no Shelf opens while recording
- [ ] Click it, press ⌘⇧8: the button and the New Shelf menu item show ⌘⇧8; ⌘⇧8 anywhere opens a Shelf, ⌃⌥Space no longer does
- [ ] Click it, press a plain letter (no ⌃⌥⌘): a red "Use at least one of ⌃, ⌥ or ⌘." shows and it keeps recording; Esc cancels and the old shortcut still works
- [ ] Click it, then close the window while recording: the old shortcut still works
- [ ] Record a shortcut another app has already registered as a hot key: a red error says it couldn't be used and the old one is kept (and works)
- [ ] Reset returns to ⌃⌥Space

Launch at login
- [ ] On a clean start (`defaults delete com.phuocphn.box4dd`) of the bundled app, Launch at login is on, and box4dd shows in System Settings → General → Login Items → Open at Login
- [ ] Switch it off: box4dd is gone from (or disabled in) Login Items; log out and in: box4dd doesn't start
- [ ] Switch it on, log out and in: box4dd starts by itself
- [ ] Turn it off in System Settings, relaunch box4dd: it stays off (the app doesn't turn it back on)
- [ ] If Settings shows "Allow box4dd in System Settings…", Open Login Items… opens that pane
- [ ] Run with `swift run`, open Settings, switch it: a red message says it works only from the app bundle, nothing crashes

Excluded Apps
- [ ] The list says "No Excluded Apps" on a clean start
- [ ] Add App… opens at /Applications; choose Preview: it's listed with its icon and name
- [ ] With Preview in front, drag an image out of it and Shake: nothing opens; do the same in Finder: a Shelf opens
- [ ] Select Preview, Remove: a Shake while dragging in Preview opens a Shelf again, without relaunching
- [ ] Adding the same app twice lists it once

Survives a relaunch
- [ ] Change sensitivity, the shortcut, launch at login and Excluded Apps, quit, relaunch: all four are as you left them, and the shortcut and Excluded Apps work straight away

Dropping on the menu bar icon
- [ ] Drag 3 Finder files onto the menu bar icon: it highlights while hovering; drop: a new Shelf opens just below the icon holding "3 items", and the originals are untouched
- [ ] Drop on the icon again: another new Shelf opens (each drop opens its own Shelf)
- [ ] Drag Items out of a Shelf onto the icon: they move to a new Shelf, and the first Shelf closes if emptied
- [ ] Drag selected text, a browser link, and a browser image onto the icon, one at a time: each opens a new Shelf holding a Captured Item
- [ ] After all this, clicking the icon still opens the menu
