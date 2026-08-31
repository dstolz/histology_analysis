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

% Or read the tracker straight from the published Google Sheet:
launch_histology_browser("D:/GM6001_HISTOLOGY/", ...
    publishedUrl = "https://docs.google.com/spreadsheets/d/e/2PACX-.../pub?gid=1084786865&single=true&output=csv")
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

An optional section tracker is joined onto the catalog by image filename stem, supplying
annotations the filenames do not carry. It can come from a CSV export (`metadataCSV`) or
from the published copy of the Google Sheet it is maintained in (`publishedUrl`) — see
below.

## Reading the tracker from a published Google Sheet

The tracker is a tab in a Google Sheet. Pointing the browser at it directly means no
exporting a CSV by hand every time somebody edits it.

### Publishing the tab

In the sheet, **File → Share → Publish to web**. Choose the **Sections** tab (not "Entire
document") and the **Comma-separated values (.csv)** format, then Publish. Paste the link
it gives you into **Dataset → Published Sheet** in the browser.

That link is checked as soon as it is set — it is downloaded there and then rather than at
the next load, so a link that will not work says so while you are still looking at the
dialog that set it.

### What publishing does and does not do

Publishing exposes **that one tab** to anyone who has the link. The rest of the workbook
stays private, and the link is not indexed or guessable, but it is not access-controlled
either. Do not take the shortcut of setting the whole file to "anyone with the link can
view" to achieve the same thing — that would expose every other tab, including the
subject records.

Leave **"Automatically republish when changes are made"** checked, which is the default.
Edits then reach the published copy on their own. Google caches it, so an edit made in the
last few minutes may not be in what the browser downloads; for the usual rhythm of editing
the tracker and reloading later, that is invisible.

### Read-only

This route is one-way. A published sheet serves its contents and accepts nothing back, so
the browser reads the tracker and never writes to it. Writing would need the Google Sheets
API and a service account, which needs a Google Cloud project — see
`worktree-sheets-sync` in this repository for an implementation of that, parked because
creating a Cloud project under a `umd.edu` account is blocked by organization policy.

### Notes

- The published CSV keeps the blank and title rows above the header, exactly as the
  exported CSV did, so the header is searched for rather than assumed to be row 1.
- The download is written to a temporary file as UTF-8 and deleted after the load, so
  micrometre and degree signs in the Notes column survive the round trip.
- A link that serves the tab as a web page is accepted and asked for as CSV instead. An
  ordinary `/edit` link is refused, with a message saying what to paste instead — it is
  the most likely thing to be pasted and would never work.
- Naming a published sheet takes precedence over naming a tracker CSV.

## Contents

| File | Role |
|---|---|
| `launch_histology_browser.m` | Entry point; constructs the browser. |
| `@HistologyImageBrowser/` | The GUI class — catalog, filters, image tiles, profile plot, ROI editor. |
| `fetch_published_tracker.m` | Download the section tracker from a published Google Sheet as a CSV. |
| `combine_values_csv.m` | Ingests every `*values.csv` under a root into one structured dataset, with per-file diagnostics. |
| `build_histology_image_catalog.m` | One row per section: all renditions, the ROI sidecar, the profiles, and joined tracker metadata. |
| `parse_histology_filename.m` | Non-raising filename parser used by the catalog. |
| `read_imagej_roi.m` / `write_imagej_roi.m` | Decode and encode ImageJ's binary `.roi` format. |
| `measure_line_profile.m` | Measure a banded line profile from an image, matching the Fiji macro. |
| `write_values_csv.m` | Write a measured profile back out in the macro's `*values.csv` format. |
| `imagej_pixel_size.m` | Recover spatial calibration from a TIFF's ImageJ header. |
| `addpath_nogit.m` | Add a folder tree to the MATLAB path, skipping `.git`. |
| `tests/test_histology_browser.m` | Smoke test; see below. |

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
test_histology_browser()                       % synthetic checks only
test_histology_browser("D:/GM6001_HISTOLOGY/") % also exercises the catalog and live GUI
```

With no argument it checks the filename parser, the ROI encode/decode round trip, profile
measurement, and the values-CSV round trip against synthetic inputs, so it runs anywhere.
Given a real root folder it additionally builds a catalog and drives a live browser through
filtering, selection, and the ROI edit / save / revert cycle.

## Menus

`Dataset` picks the root folder and the tracker — a CSV export, or the published Google
Sheet — and loads them. `View` collapses the data column and the display row, separately
or together, to give the image tiles the window.

`Display` mirrors every control in the Display panel, so collapsing the display row costs
reach rather than capability. The panel keeps the state; each menu item writes to the control
it mirrors and then runs that control's own callback, so a menu choice and a click go down
the same path, and `syncDisplayMenu` pushes the panel's state back the other way. Dropdowns
become checked submenus, checkboxes become checked items, and the numeric settings (contrast
percentiles, max tiles, profile size, ROI band width) become items that prompt for a value
and show it in their own label. Anything that already has a keyboard shortcut routes through
`runShortcut`, so menu, key, and button converge on one implementation.

## Keyboard shortcuts

uifigure menus ignore the `Accelerator` property, so every shortcut is bound on the figure
itself. `@HistologyImageBrowser/keyBindings.m` is the single table naming the keys; the menu
labels, the button tooltips, and the **View > Keyboard Shortcuts** dialog (`F1`) are all
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
code moved out of `helper_fnc` carry over unchanged. The published sheet URL is saved
there too, and restored without being fetched — opening the browser should not wait on the
network to find out something the next load will report anyway.

The window reopens at the size and position it was closed at, and reopens maximized if it
was closed maximized. A saved position that no longer lands on an attached monitor is
dropped, so unplugging a second display cannot strand the window off screen.
