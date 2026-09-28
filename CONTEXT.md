# box4dd

A personal macOS utility, modeled on Dropover, that gives drag-and-drop a temporary floating place to collect items and then drag them onward together.

## Language

**Shelf**:
A temporary floating window that holds items collected by drag-and-drop until they are dragged out together.
_Avoid_: Box, stash, tray, basket

**Shake**:
A quick back-and-forth pointer motion made while dragging, which opens a new Shelf under the cursor.
_Avoid_: Wiggle, jiggle, gesture

**Stack**:
The compact look of a Shelf, where its Items appear as one pile with a count; clicking it expands the Shelf so single Items can be selected.
_Avoid_: Pile, collapsed view

**Excluded App**:
An app chosen by the user where a Shake is ignored, so fast drags there never open a Shelf.
_Avoid_: Blacklist, ignored app

**Recent Shelf**:
A closed Shelf that can still be reopened with its Items; only the last 10 are kept, and a Shelf's Captured Items are discarded when it falls off the list.
_Avoid_: History, archive, trash

**Item**:
One thing held on a Shelf.
_Avoid_: Entry, file (an Item is not always a file)

**Reference Item**:
An Item that points to an existing file or folder the Shelf does not own; it follows the original through renames and moves.
_Avoid_: Link, alias, shortcut

**Captured Item**:
An Item whose content the Shelf created and owns, because what was dropped was not an existing file (text, link, rich text, image, or a file promised by another app).
_Avoid_: Snippet, clipping, temp file

**Placeholder**:
An Item standing in for a file another app has promised but not yet delivered; it shows at once but can't be dragged out, becomes a Captured Item when the file arrives, and leaves the Shelf if it never does.
_Avoid_: Pending item, stub

**Missing Item**:
A Reference Item whose original has been deleted; it stays on the Shelf, marked as missing.
_Avoid_: Broken item, dead link
