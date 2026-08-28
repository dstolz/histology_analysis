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

% Or read the tracker from the Google Sheet it is maintained in:
launch_histology_browser("D:/GM6001_HISTOLOGY/", ...
    sheetUrl = "https://docs.google.com/spreadsheets/d/1yz6.../edit", ...
    sheetCredentials = "C:/keys/histology-sheets.json")
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
straight from the Google Sheet it is maintained in (`sheetUrl`) — see below.

## Reading the tracker from Google Sheets

The tracker is a tab in a spreadsheet several people edit. Reading it directly means the
browser shows what the sheet says now rather than what it said when somebody last exported
it, and it makes writing back possible. Both directions go through `SectionTracker`.

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
the browser looks for a `bfmatlab` folder beside this toolbox, inside it, in `userpath`, and
at `BFMATLAB_PATH`, and adds the first one it finds. Only when none of those exist does a
`.czi` tile refuse to draw, and it then says so on the tile. Reads go through `bfGetReader`
and pull the single requested channel rather than the whole file.

## Tests

```matlab
test_histology_browser()                       % synthetic checks only
test_histology_browser("D:/GM6001_HISTOLOGY/") % also exercises the catalog and live GUI
test_section_tracker()                         % the Google Sheets tracker
```

With no argument `test_histology_browser` checks the filename parser, the ROI encode/decode
round trip, profile measurement, and the values-CSV round trip against synthetic inputs, so
it runs anywhere. Given a real root folder it additionally builds a catalog and drives a live
browser through filtering, selection, and the ROI edit / save / revert cycle.

`test_section_tracker` needs no credentials, no key file, and no network: the tracker is
driven against an in-memory sheet, which is what makes the checks that matter testable at
all. What happens to a write when somebody reorders the tab underneath it is not something to
go and try against the real tracker. The two pieces that cannot be reached that way — the
RSA-SHA256 assertion and the shapes a values reply decodes to — are checked against a
throwaway key generated for the purpose and against real `jsondecode` output.

## Menus

`Dataset` picks the root folder and the tracker — a CSV export, or the Google Sheet under
**Google Sheet Tracker** — and loads them. Naming a sheet takes precedence over naming a CSV.
`View` collapses the data column and the display row, separately or together, to give the
image tiles the window.

Under the catalog table, the **Review** panel writes the atlas plate number and the
measured flag for the selected sections back to the tracker's sheet — see
[Reviewing sections](#reviewing-sections).

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
code moved out of `helper_fnc` carry over unchanged.

The sheet settings persist there too: the spreadsheet, the tab, and the *path* to the key
file. The key file is named rather than read, so nothing secret is written to the preference
store.

The window reopens at the size and position it was closed at, and reopens maximized if it
was closed maximized. A saved position that no longer lands on an attached monitor is
dropped, so unplugging a second display cannot strand the window off screen.
