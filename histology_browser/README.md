# histology_browser

MATLAB tools for browsing histology sections and the cortical line profiles measured from
them in Fiji. The centerpiece is `HistologyImageBrowser`, a GUI that catalogs every image
rendition under a histology root folder, filters them by subject / hemisphere / stain /
plate, and overlays the Fiji line ROI and its intensity profile on each image.

Extracted from [`helper_fnc`](https://github.com/dstolz/helper_fnc) so the browser and its ingest helpers can
be used without pulling in that repository's general-purpose utilities.

This folder is part of [`histology_analysis`](../README.md). It was a standalone repository,
`dstolz/histology_browser`, until September 2026; its history came with it, so
`git log -- histology_browser/` reaches back to its first commit.

## Quick start

```matlab
addpath_nogit('c:\src\histology_analysis')   % this folder and the rest of histology_analysis

% Open on the last folder used, then use Dataset > Load Dataset:
launch_histology_browser()

% Or load a dataset immediately:
launch_histology_browser("D:/GM6001_HISTOLOGY/", ...
    metadataCSV = "D:/GM6001_HISTOLOGY/Trackers - Sections.csv")

% Or read the tracker straight from the published Google Sheet:
launch_histology_browser("D:/GM6001_HISTOLOGY/", ...
    publishedUrl = "https://docs.google.com/spreadsheets/d/e/2PACX-.../pub?gid=1084786865&single=true&output=csv")

% Or read it over the Sheets API, which can also write back:
launch_histology_browser("D:/GM6001_HISTOLOGY/", ...
    sheetUrl = "https://docs.google.com/spreadsheets/d/1yz6.../edit", ...
    sheetCredentials = "C:/keys/histology-sheets.json")
```

Every `.m` file lives at the top of this folder, so a plain
`addpath('c:\src\histology_analysis\histology_browser')` also works when only the browser is wanted.
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
from the published copy of the Google Sheet it is maintained in (`publishedUrl`), or over the
Sheets API from the sheet itself (`sheetUrl`) — see below.

The three are read in that reverse order of preference: `sheetUrl` first, then
`publishedUrl`, then `metadataCSV`, and only the first one set is used. Setting a better
source therefore does not mean clearing the others, which stay configured as fallbacks.
Which one a load actually used is named on the status bar, and the tracker link above the
search field opens it.

Pick by what the sitting needs. The published copy is the least trouble to set up and needs
no credentials; the Sheets API is the only one that can write a review back, and needs a
Google Cloud project to issue the key — see [Reading the tracker over the Sheets
API](#reading-the-tracker-over-the-sheets-api) for the caveat on that.

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
the browser reads the tracker and never writes to it. Writing goes through the Sheets API
instead, which is the next section.

### Notes

- The published CSV keeps the blank and title rows above the header, exactly as the
  exported CSV did, so the header is searched for rather than assumed to be row 1.
- The download is written to a temporary file as UTF-8 and deleted after the load, so
  micrometre and degree signs in the Notes column survive the round trip.
- A link that serves the tab as a web page is accepted and asked for as CSV instead. An
  ordinary `/edit` link is refused, with a message saying what to paste instead — it is
  the most likely thing to be pasted and would never work.
- Naming a published sheet takes precedence over naming a tracker CSV.

## Reading the tracker over the Sheets API

The tracker is a tab in a spreadsheet several people edit. Reading it directly means the
browser shows what the sheet says now rather than what it said when somebody last exported
it, and it makes writing back possible. Both directions go through `SectionTracker`.

> **Before starting:** this route needs a service account key, and issuing one needs a
> Google Cloud project. Creating a Cloud project under a `umd.edu` account is blocked by
> organization policy, so unless that policy has changed or the key comes from a project
> outside it, the published-sheet route above is the one that will work. The code is here
> and tested either way; only the credential is gated.

### One-time setup

The sheet is private, so this needs a service account: a Google identity that belongs to a
program rather than a person, authenticating with a key file instead of a browser prompt.
Nothing about the spreadsheet's sharing changes except that one more address can see it.

1. In the [Google Cloud console](https://console.cloud.google.com), create a project (or
   pick an existing one) and enable the **Google Sheets API** for it.
2. Under **IAM & Admin → Service Accounts**, create a service account. It needs no project
   roles — its access comes entirely from what the spreadsheet is shared with.
3. On that account, **Keys → Add key → Create new key → JSON**. Save the file somewhere
   outside this repository; the private key inside it grants whatever access the account
   has, to anyone holding the file.
4. Copy the account's `client_email` (it looks like
   `something@project.iam.gserviceaccount.com`) and share the spreadsheet with it:
   **Viewer** to read, **Editor** to write back.
5. In the browser, **Dataset → Google Sheet Tracker → Configure**, and give it the
   spreadsheet URL, the tab name, and the key file. **Test Connection** reads the tab and
   reports what it found.

### Writing back

Writing needs two columns the browser maintains, added by **Dataset → Google Sheet Tracker →
Prepare Sheet for Writing**. It says what it will change and waits to be told to go ahead.
Both are additive; no existing cell is touched, and Google Sheets version history can undo
it.

| Column | Why it exists |
|---|---|
| `Row UID` | Names a row in a way that survives sorting, filtering, and edits to every other column. |
| `Last Updated` | UTC ISO 8601 timestamp of the last write this code made to the row, so a value that changed on its own is distinguishable from one the browser wrote. |
| `Measured` | Whether the section has been measured. `yes` or blank. |

`Row UID` and `Last Updated` are bookkeeping and are never writable by hand — `updateRows` refuses them. `Measured` is an ordinary column that happens to be created here; it holds a judgement someone makes while reviewing, so it is written like any other.

### Reviewing sections

The **Review** panel under the catalog table writes two things to the tracker for
whatever is selected: the atlas plate number, and the measured flag. Both act on the
whole selection, so a stack of sections from one slide can be marked in one go.

- **Atlas plate** shows the selection's own number, and writes it on Enter or **Set**.
  A selection whose plates disagree shows a blank field rather than one of them.
  Clearing the field empties the cell, after a confirmation.
- **Mark Measured** / **Clear** set and unset the flag. Two buttons rather than one
  checkbox, because a selection can be part measured and a checkbox has no honest way
  to show that.
- **Ctrl+M** toggles: it marks until everything selected is marked, and only then starts
  clearing, so it is safe to press repeatedly down a stack.

The `Meas` column in the catalog table shows a tick for measured sections, so what is
still outstanding is visible while working. A successful write updates the table in
place without moving the selection.

Sections the tracker has no row for are skipped rather than refusing the whole write,
and the panel says how many before the button is pressed. The panel stays disabled,
naming the reason, when there is no sheet, no key file, no selection, or when the rows
have no `Row UID` yet.

Rows are found by `Row UID`, which the catalog carries across during the join. That
matters because the read-side join tolerates a tracker entry being a *prefix* of an
image name — fine for reading, too loose to write through.

From MATLAB:

```matlab
tracker = SectionTracker(url, "C:/keys/histology-sheets.json");
tracker.ensureSchema();                       % idempotent; safe to run any time

idx = tracker.findRows({"Hemisphere", "L", "Content", "DAPI"});
disp(tracker.Table(idx, :))

tracker.updateRows( ...
    {"Image Filename", "SUBJ-ID-896_2A_L_DAPI_Z1_250408_1"}, ...
    {"Notes", "Profile remeasured"}, expected = 1);
```

**Rows are addressed by what is in them, never by where they are.** A sheet row number is
true only until somebody sorts the tab, deletes a filtered row, or inserts above it, and
none of those leave a trace this code could notice. So `updateRows` re-reads the tab,
resolves the criteria against what is there now, writes, and then reads back to confirm the
values landed in the rows they were aimed at.

That last step is there because the Sheets API has no conditional write: between resolving a
row and writing to it there is a window nothing can close. It cannot be prevented, but it can
be *noticed*, which is the difference between a problem someone can go and fix and one nobody
knows about. A row that moves inside that window raises
`SectionTracker:RowMovedDuringWrite`.

Several other things stop a write rather than guessing:

- criteria that match nothing, or a different number of rows than `expected`;
- a `Row UID` whose row has since been deleted, or that two rows now share (which is what
  copying a row does);
- a matched row that has no `Row UID` yet;
- writing to `Row UID` or `Last Updated` by hand, or to a column the tab does not have.

### Notes

- Reading needs Viewer on the sheet; writing needs Editor. The scope requested is
  `auth/spreadsheets`, and the account can only reach spreadsheets explicitly shared with it.
- Tokens last an hour and are cached in memory, so a sitting costs one token request rather
  than one per read.
- Every cell arrives as text, which is what the CSV path gave most columns anyway; the
  columns read as numbers are converted where they are used.
- The header row is searched for rather than assumed to be row 1, so the blank and title rows
  above it are fine, exactly as they were in the exported CSV.
- Signing the service account assertion uses `java.security`, so MATLAB must have its JVM
  (it does unless started with `-nojvm`, which the GUI needs anyway).

## Contents

| File | Role |
|---|---|
| `launch_histology_browser.m` | Entry point; constructs the browser. |
| `@HistologyImageBrowser/` | The GUI class — catalog, filters, image tiles, profile plot, ROI editor. |
| `fetch_published_tracker.m` | Download the section tracker from a published Google Sheet as a CSV. |
| `@SectionTracker/` | The section tracker as held in a Google Sheet: read it, address rows by content, write back. |
| `+gsheet/` | Sheets API v4 transport — service account auth, values read/write, A1 notation. |
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
| `tests/test_section_tracker.m` | Checks for the sheet tracker, against an in-memory sheet. |
| `tests/fake_section_tracker.m` | The in-memory sheet both test files drive the tracker against. |

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
the browser looks for a `bfmatlab` folder inside this toolbox, beside it, beside the
`histology_analysis` checkout that holds it, in `userpath`, and at `BFMATLAB_PATH`, and adds
the first one it finds. Only when none of those exist does a
`.czi` tile refuse to draw, and it then says so on the tile. Reads go through `bfGetReader`
and pull the single requested channel rather than the whole file.

## Tests

```matlab
test_histology_browser()                       % generates a dataset and checks everything
test_histology_browser("D:/GM6001_HISTOLOGY/") % checks the same things against real data
test_section_tracker()                         % the Google Sheets tracker
```

`test_histology_browser` checks the filename parser, the ROI encode/decode round trip,
profile measurement, and the values-CSV round trip against synthetic inputs, then builds a
catalog and drives a live browser through filtering, selection, and the ROI edit / revert
cycle.

With no argument the catalog and GUI checks run against a dataset `make_test_dataset` writes
to a temp folder and the test deletes afterwards, so the whole suite runs on a machine that
has no histology data on it. Given a real root folder it runs those same checks against that
instead of generating anything. Either way the browser's saved preferences are snapshotted
and put back, because driving the GUI writes them.

The generated dataset is a miniature of what the Fiji workflow leaves on disk — two subjects,
both hemispheres, two stains over a range of atlas plates, multi-page calibrated projections
with their `.roi` and `*values.csv` sidecars, a section tracker CSV, and a few deliberately
unfinished sections. It is deterministic and about 220 KB.

`test_section_tracker` needs no credentials, no key file, and no network: the tracker is
driven against an in-memory sheet, which is what makes the checks that matter testable at
all. What happens to a write when somebody reorders the tab underneath it is not something to
go and try against the real tracker. The two pieces that cannot be reached that way — the
RSA-SHA256 assertion and the shapes a values reply decodes to — are checked against a
throwaway key generated for the purpose and against real `jsondecode` output.

## Menus

`Dataset` picks the root folder and the tracker — a CSV export, the published Google Sheet,
or the sheet itself under **Google Sheet Tracker** — and loads them. When more than one is
set, the sheet is preferred over the published copy, and the published copy over the CSV.
`View` collapses the data column and the display row, separately or together, to give the
image tiles the window.

Under the catalog table, the **Review** panel writes the atlas plate number and the
measured flag for the selected sections back to the tracker's sheet — see
[Reviewing sections](#reviewing-sections). It needs the Sheets API route; the CSV and the
published sheet are both read-only.

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
open a prefilled issue on the `histology_analysis` tracker; nothing is submitted from MATLAB, the
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

## Normalizing the profile plot

The bottom row of the Display panel rescales the profile plot without touching the data
behind it. **Normalize** puts the intensity axis through one of

| Choice | What each sample becomes |
|---|---|
| Raw intensity | the measured value, unchanged |
| Baseline subtracted | `y - min`, which moves the trace without stretching it |
| Min-max (0-1) | `(y - min) / (max - min)` |
| Percent of max | `100 * y / max` |
| Fold of mean | `y / mean` |
| Z-score | `(y - mean) / sd` |

and **over** decides where the `min`, `max`, `mean` and `sd` in that column come from. *Each
trace* takes them from the trace being scaled, which puts sections of very different
brightness on one scale and, in doing so, throws away how they differed. *All traces* takes
one set from every sample on the plot, which keeps that difference — the honest choice when
the sections are meant to be compared to each other rather than each read for its own shape.
The control greys out with the intensity axis left raw, because there is then nothing for it
to be measured over.

**Distance** rescales the other axis, independently: *From line start* subtracts each line's
own first sample, and *Percent of line* runs every line from 0 to 100 whatever its length,
which is what lines two profiles up by relative depth rather than by microns. Both are per
trace whatever **over** says, because a line's own start and its own length are the only
things they can mean.

Every one of these changes the picture and none of them changes the data. The rescaling
happens in `normalizeProfiles` on the copy `renderProfilePlot` is about to draw, so the
`*values.csv` files, a remeasured ROI, and the table **Export to Workspace** hands out all
stay in the units they were measured in. The axis labels follow the choice, so a plot that is
no longer in intensity units says so. Degenerate traces are left alone rather than divided by
zero: a flat trace under **Min-max** lands on zero — true, and visible — instead of becoming
a column of `NaN` that would draw as nothing and read as a missing file.

The normalizations also redraw only the profile plot. They rescale numbers on the way to one
axes and have nothing to say about a pixel in a tile, so `onProfileOptionChanged` goes
straight to `renderProfilePlot` rather than through the render-key comparison described under
**Redrawing only what changed**.

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
| `Ctrl+M` | Mark the selected sections measured, or clear them if all are |
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

The sheet settings persist there too: the spreadsheet, the tab, and the *path* to the key
file. The key file is named rather than read, so nothing secret is written to the preference
store.

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
profile plot's menu carries where the plot sits and the three normalizations that rescale its
axes — the settings whose subject is that plot and nothing else — plus the same two output
items.

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
