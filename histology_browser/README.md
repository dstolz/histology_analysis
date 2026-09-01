# histology_browser

MATLAB tools for browsing histology sections and the cortical line profiles measured from
them in Fiji. The centerpiece is `HistologyImageBrowser`, a GUI that catalogs every image
rendition under a histology root folder, filters them by subject / hemisphere / stain /
plate, and overlays the Fiji line ROI and its intensity profile on each image.

Extracted from [`helper_fnc`](https://github.com/dstolz/helper_fnc) so the browser and its ingest helpers can
be used without pulling in that repository's general-purpose utilities.

## Quick start

```matlab
addpath_nogit('c:\src\histology_browser')

% Open on the last folder used, then use Dataset > Load Dataset:
launch_histology_browser()

% Or load a dataset immediately:
launch_histology_browser("D:/GM6001_HISTOLOGY/", ...
    metadataCSV = "D:/GM6001_HISTOLOGY/Trackers - Sections.csv")
```

Every `.m` file lives at the repository root, so a plain `addpath` of the root also works.
The `@HistologyImageBrowser` class folder is resolved by its parent directory, which must be
the folder added to the path — not the class folder itself.

## What it expects on disk

The browser reads the output of the Fiji batch line-measure workflow. Under the root folder
it discovers, per acquisition:

- image renditions — raw `.czi` plus the `_proj`, `_mid`, and `_composite` exports;
- a `.roi` sidecar holding the measured line, in ImageJ's binary ROI format;
- one or more `*values.csv` profile files.

Filenames are expected to follow

```
SUBJ-ID-<n><SampleID>_<Section>_<Hemi>_<Stain>_<Z>_<Date>_<ImageNumber>
```

Names that do not match are still cataloged and browsable — `parse_histology_filename`
reports the mismatch through an `isValid` flag instead of raising, and the browser counts
unparsed names in its status bar.

`fiji/MACRO_Batch_LineMeasure.ijm` is the macro that produces the `.roi` and `*values.csv`
sidecars. It runs inside Fiji/ImageJ, not MATLAB, and is included here so the two halves of
the workflow stay together.

An optional section tracker CSV (`metadataCSV`) is joined onto the catalog by image filename
stem, supplying annotations the filenames do not carry.

## Contents

| File | Role |
|---|---|
| `launch_histology_browser.m` | Entry point; constructs the browser. |
| `@HistologyImageBrowser/` | The GUI class — catalog, filters, image tiles, profile plot, ROI editor. |
| `combine_values_csv.m` | Ingests every `*values.csv` under a root into one structured dataset, with per-file diagnostics. |
| `build_histology_image_catalog.m` | One row per section: all renditions, the ROI sidecar, the profiles, and joined tracker metadata. |
| `parse_histology_filename.m` | Non-raising filename parser used by the catalog. |
| `read_imagej_roi.m` / `write_imagej_roi.m` | Decode and encode ImageJ's binary `.roi` format. |
| `measure_line_profile.m` | Measure a banded line profile from an image, matching the Fiji macro. |
| `write_values_csv.m` | Write a measured profile back out in the macro's `*values.csv` format. |
| `imagej_pixel_size.m` | Recover spatial calibration from a TIFF's ImageJ header. |
| `addpath_nogit.m` | Add a folder tree to the MATLAB path, skipping `.git`. |
| `tests/test_histology_browser.m` | Smoke test; see below. |
| `tests/make_test_dataset.m` | Writes the synthetic dataset the smoke test runs against. |

## Requirements

**Base MATLAB** covers the entire UI and the ingest path — App Designer components,
`imread`/`imfinfo`, `readtable`/`writetable`, `getpref`/`setpref`.

**Image Processing Toolbox** is needed for the ROI workflow:

| Used for | Function | Site |
|---|---|---|
| Dragging the line ROI | `images.roi.Line` | `@HistologyImageBrowser/attachRoiEditor.m` |
| Drawing a new line ROI | `drawline` | `@HistologyImageBrowser/onDrawRoi.m` |
| Downsampling for display | `imresize` | `@HistologyImageBrowser/loadDisplayImage.m` |

All three are guarded by `exist` checks, so without the toolbox the browser still opens,
catalogs, displays, and plots — only ROI drawing/editing and display downsampling are lost.

**Bio-Formats** (`bfmatlab`) is optional and needed only to display raw `.czi`; every other
rendition reads through `imread`. It does not have to be on the MATLAB path — when it is not,
the browser looks for a `bfmatlab` folder beside this toolbox, inside it, in `userpath`, and
at `BFMATLAB_PATH`, and adds the first one it finds. Only when none of those exist does a
`.czi` tile refuse to draw, and it then says so on the tile. Reads go through `bfGetReader`
and pull the single requested channel rather than the whole file.

## Tests

```matlab
test_histology_browser()                       % generates a dataset and checks everything
test_histology_browser("D:/GM6001_HISTOLOGY/") % checks the same things against real data
```

It checks the filename parser, the ROI encode/decode round trip, profile measurement, and
the values-CSV round trip against synthetic inputs, then builds a catalog and drives a live
browser through filtering, selection, and the ROI edit / revert cycle.

With no argument the catalog and GUI checks run against a dataset `make_test_dataset` writes
to a temp folder and the test deletes afterwards, so the whole suite runs on a machine that
has no histology data on it. Given a real root folder it runs those same checks against that
instead of generating anything. Either way the browser's saved preferences are snapshotted
and put back, because driving the GUI writes them.

The generated dataset is a miniature of what the Fiji workflow leaves on disk — two subjects,
both hemispheres, two stains over a range of atlas plates, multi-page calibrated projections
with their `.roi` and `*values.csv` sidecars, a section tracker CSV, and a few deliberately
unfinished sections. It is deterministic and about 220 KB.

## Menus

`Dataset` picks the root folder and tracker CSV and loads them. `View` collapses the data
column and the display row, separately or together, to give the image tiles the window.

`Display` mirrors every control in the Display panel, so collapsing the display row costs
reach rather than capability. The panel keeps the state; each menu item writes to the control
it mirrors and then runs that control's own callback, so a menu choice and a click go down
the same path, and `syncDisplayMenu` pushes the panel's state back the other way. Dropdowns
become checked submenus, checkboxes become checked items, and the numeric settings (contrast
percentiles, max tiles, profile size, ROI band width) become items that prompt for a value
and show it in their own label. Anything that already has a keyboard shortcut routes through
`runShortcut`, so menu, key, and button converge on one implementation.

`Help` holds the keyboard shortcut list, a link that opens the
[Gerbil Atlas Explorer](https://dstolz.github.io/GerbilAtlasExplorer/gerbil_atlas_explorer.html)
in the default browser, and the two issue items. **Report a Bug** and **Request a Feature**
open a prefilled issue on this repository's tracker; nothing is submitted from MATLAB, the
browser lands on GitHub's new-issue form with the title and body already written and the
button still to press.

A bug report carries the things nobody types from memory: the checked-out commit (flagged
when the working tree has uncommitted changes), the MATLAB release, whether the Image
Processing Toolbox is installed, the monitor layout and window size, what is loaded, the
saved preferences, and the recent status bar messages. Because that describes the machine
and the folders being worked in, and the tracker is public, the body is shown for review and
left editable before the browser opens, preferences whose names read as secrets are withheld,
and a copy goes on the clipboard for the cases where the report is too long to travel in a
URL.

## Editing a line ROI

**Edit ROI** puts a draggable line on the tile; **Draw Line** replaces it by dragging a new
one at the width in the Width field. Nothing touches disk until **Save ROI**, which rewrites
the `.roi` sidecar and remeasures the `*values.csv` beside it from the full resolution page.
**Revert** goes back to the file. The stroke and the badge on the tile say where the line
stands against its file — read from disk, edited but unsaved, or just written — so an unsaved
edit is visible without the control panel in view, and leaving a section with unsaved changes
prompts rather than discarding them.

An edit belongs to one section, because a drag happens on one tile, but it no longer requires
that only one section be *selected*. With several on screen the first drawn tile takes the
line and the status bar names the section it went to. The geometry lives in the browser
rather than in the graphics object, so an edit survives its tile scrolling past the Max tiles
cap: the draggable handle goes away, the status bar says so, and **Save ROI** still writes.

## Keyboard shortcuts

uifigure menus ignore the `Accelerator` property, so every shortcut is bound on the figure
itself. `@HistologyImageBrowser/keyBindings.m` is the single table naming the keys; the menu
labels, the button tooltips, and the **Help > Keyboard Shortcuts** dialog (`F1`) are all
rendered from it, so a shortcut cannot be advertised in one place and bound in another.

| Keys | Action |
|---|---|
| `Ctrl+Down` / `Ctrl+Right` | Next section |
| `Ctrl+Up` / `Ctrl+Left` | Previous section |
| `Ctrl+Home` / `Ctrl+End` | First / last section |
| `Ctrl+A` | Select every section passing the filters |
| `Ctrl+F` | Jump to the search box |
| `Ctrl+Shift+R` | Clear every filter |
| `Ctrl+L` | Load the dataset |
| `Ctrl+E` | Start or finish editing the line ROI |
| `Ctrl+D` | Draw a new line over the image |
| `Ctrl+S` | Save the ROI and remeasure its profile |
| `Ctrl+Z` | Discard unsaved ROI changes |
| `Esc` | Leave ROI editing |
| `Ctrl+1` / `Ctrl+2` / `Ctrl+3` | Line ROI / sampling band / intensity shading on or off |
| `Ctrl+Shift+D` / `Ctrl+Shift+P` | Hide or show the data column / the display row |
| `Ctrl+H` | Hide or show both together |
| `Ctrl+O` | Redraw the view in a normal figure |
| `Ctrl+P` | Export the view to an image file |
| `Ctrl+Shift+F` | Open the folder holding the selected image |
| `F1` | Show the shortcut list |

Every shortcut carries a modifier. Bare letters are not bound: a uifigure hands key presses
to `WindowKeyPressFcn` whether or not an edit field has the caret, so typing into the search
box would have fired them. The few chords that also mean something inside a text field —
`Ctrl+A`, `Ctrl+Z`, `Ctrl+Home`, `Ctrl+End`, `Ctrl+Left`, `Ctrl+Right` — stand aside when a
field was the last thing clicked.

Shortcuts run the same callbacks the buttons and menus do, so the guards those already carry
(nothing selected, nothing loaded, no Image Processing Toolbox) report through the status bar
exactly as they do for a click, and `Ctrl+S` / `Ctrl+Z` stay behind the same `Enable` state
the Save and Revert buttons show.

## Preferences

Window and display settings persist under the MATLAB preference group
`HistologyImageBrowser`. That is a name rather than a path, so settings saved before this
code moved out of `helper_fnc` carry over unchanged.

The window reopens at the size and position it was closed at, and reopens maximized if it
was closed maximized. A saved position that no longer lands on an attached monitor is
dropped, so unplugging a second display cannot strand the window off screen.

## Naming conventions other than the built-in one

The convention under **What it expects on disk** is one lab's. **Dataset > Filename Pattern**
describes a different one,
and the table under the editor shows what the pattern pulls out of the filenames in the
loaded dataset, redrawn on every keystroke, so a pattern that matches nothing is obvious
while it is being written rather than after a load. With nothing loaded the preview falls
back to worked examples, two of them in other conventions.

A scheme can be written either way:

- **a regular expression** whose named tokens become the parsed fields —
  `^(?<SubjectID>[^_]+)_(?<SectionID>[^_]+)_(?:[^_]+)_(?<Stain>[^_]+)$` — where an unnamed
  `(?:...)` group is how a field is parsed past and ignored;
- **a token list**, a delimiter plus the field names in order, with `-` marking a field to
  ignore. It compiles into a pattern of exactly the form above, which is then what is
  stored, so nothing downstream has to know which of the two it was written in.

Tokens named `SubjectID`, `SampleID`, `SectionID`, `Hemisphere`, `Stain`, `ZPlane`,
`DateCode`, `ImageNumber`, `Protocol` or `Series` become catalog columns; any other token is
parsed and shown in the preview but is not cataloged, because the filters, the sort order,
and the results table all name the columns they work on.

The `_proj`, `_mid`, `_composite`, `_roi` and `_values` suffixes are stripped before the
pattern runs and are not customizable. They are written by `fiji/MACRO_Batch_LineMeasure.ijm`
rather than by whoever named the acquisition, and rendition discovery, the ROI sidecar
lookup, and the ROI labels read off values filenames all depend on exactly those strings.

The pattern persists with the other preferences and is re-validated on the way back in, so
one that no longer works is dropped for the built-in convention rather than left to fail on
the next load. **Restore Default** puts it back at any time. With no pattern set — the state
a fresh install is in — `parse_histology_filename` runs the built-in convention exactly as it
always did; `parse_histology_filename(name, pattern = ...)` and
`build_histology_image_catalog(root, filenamePattern = ...)` take one from a script.

## Right-click on a plot

Every image tile and the profile plot carry a context menu, and it comes up from whatever
the pointer is over — the picture, the line ROI and its start marker, the sampling band, the
intensity shading, the band grid, the state badge, the tile title, or a profile trace — not
only from bare axes.

A tile's menu names the section it came up on at the top, then offers the rendition, the
channel, the colormap, the panel background, the four overlay switches, **Edit ROI**,
**Draw Line**, **Open Containing Folder**, **Open in Figure** and **Export View**. The three
per-tile items act on the tile that was actually right-clicked rather than on the first
selected row: they select that section first, exactly as clicking its row in the results
table would, and then run the same action the button and the keyboard shortcut run. The
profile plot's menu carries where the plot sits, plus the same two output items.

Nothing in these menus is a second implementation of anything. Each item writes the control
in the Display panel that it mirrors and then runs that control's own callback, or goes
through the shortcut table, so a right-click, a click on the panel, a pick from the
**Display** menu, and a key press are one code path — and the check marks follow the panel
because the items register with the same mirror list the Display menu uses.

## Redrawing only what changed

Switching an overlay on or off — **Line ROI**, **Sampling band**, **Shade ROI by intensity**,
**Band grid** — replaces just the graphics drawn over each image. The tiled layout, the
images, their contrast stretch, and the axes around them are all left standing, and an ROI
being dragged keeps the very handle the mouse is holding. On a nine-tile view a sampling
band toggle went from about 0.82 s to about 0.17 s that way, a little under five times
faster.

Changes that alter the pixels or the set of tiles — the rendition, the channel, the
colormap, the contrast percentiles, **Max tiles**, and the background — still rebuild the
whole layout, because they have to. Every display control shares one callback, so which of
the two happened is settled by comparing the settings in force against the ones the tiles on
screen were drawn from, rather than by trusting each control to route itself.
