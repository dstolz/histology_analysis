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
- one or more `*values.csv` profile files;
- optionally a `*_roi_surface.json` written by this browser, holding where the brain
  surface sits on the line — see **Marking the brain surface**.

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
| `detect_brain_surface.m` | Find where a line profile steps out of background into tissue. |
| `read_surface_mark.m` / `write_surface_mark.m` / `surface_mark_path.m` | The brain surface sidecar beside a `.roi`. |
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
| Dragging the brain surface mark | `images.roi.Point` | `@HistologyImageBrowser/attachSurfaceEditor.m` |
| Clicking the brain surface onto the line | `drawpoint` | `@HistologyImageBrowser/onMarkSurface.m` |
| Downsampling for display | `imresize` | `@HistologyImageBrowser/loadDisplayImage.m` |

All five are guarded by `exist` checks, so without the toolbox the browser still opens,
catalogs, displays, and plots — only ROI drawing/editing, placing a brain surface, and
display downsampling are lost. `detect_brain_surface` is base MATLAB and needs none of it:
its Otsu threshold is written out rather than taken from `graythresh`, so a surface can be
found from a profile on a machine with no toolbox at all.

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

It checks the filename parser, the ROI encode/decode round trip, profile measurement, the
values-CSV round trip, and the brain surface detector and its sidecar against synthetic
inputs, then builds a catalog and drives a live browser through filtering, selection, the
ROI edit / revert cycle, and marking a brain surface. The surface detector is checked
against a profile built with its edge at a known sample, drawn both ways round, and against
the traces it has to refuse — a line entirely inside tissue, one that only slopes, and a
flat one.

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
the `.roi` sidecar, remeasures the `*values.csv` beside it from the full resolution page,
and writes or removes the brain surface mark.
**Revert** goes back to the file. The stroke and the badge on the tile say where the line
stands against its file — read from disk, edited but unsaved, or just written — so an unsaved
edit is visible without the control panel in view, and leaving a section with unsaved changes
prompts rather than discarding them.

An edit belongs to one section, because a drag happens on one tile, but it no longer requires
that only one section be *selected*. With several on screen the first drawn tile takes the
line, and that tile says so before the button is pressed: it is framed more heavily than the
others and its label is filled in with the tile's own color and reads **(ROI target)**. The
ROI hint under the buttons names the same section in words, and the status bar names it again
once the line lands there. The geometry lives in the browser
rather than in the graphics object, so an edit survives its tile scrolling past the Max tiles
cap: the draggable handle goes away, the status bar says so, and **Save ROI** still writes.

## Marking the brain surface

A cortical profile is only comparable to another one if both are read from the same
depth, and the depth that means anything is depth below the pial surface — not distance
from wherever the line happened to be started. **Detect**, **Mark Surface** and **Clear**,
on the row under the ROI edit buttons, put that point on the line and take it off again.

### What is stored

One number: how far along the line, in pixels from its start point, the surface sits.
Distance from the start rather than a fraction of the length, because dragging the deep
end of a line should leave the surface where it was.

It goes in a small JSON file named after the `.roi` it belongs to —
`…_proj_roi.roi` gets `…_proj_roi_surface.json` — carrying the offset, the endpoints of
the line it was marked against, and whether it was detected or placed by hand. Beside the
ROI rather than inside it, because Fiji's format has no field for a point along a line and
inventing one would produce files the line-measure macro could no longer open. The catalog
scan looks for images, `.roi` and `*values.csv`, so the sidecar is invisible to it and
cannot turn up as a stray section.

Clearing a mark deletes that file rather than writing an empty one, so a section either
has a surface beside its ROI or does not, and nothing downstream has to tell an absent
sidecar from a blank one. Nothing reaches disk until **Save ROI**, which writes or removes
it alongside the `.roi` and the `*values.csv`.

### Finding it automatically

A line drawn across a section starts in background and steps up into tissue, and
`detect_brain_surface` looks for that step: the trace is smoothed, split into background
and tissue by Otsu's threshold, and walked in from whichever end is background until it
crosses and stays across for a couple of percent of its length — which is what keeps a
speck of debris in the background from taking the mark. The crossing is interpolated
between the two samples that straddle it.

Otsu rather than a fixed threshold because nothing here is calibrated in absolute
intensity: exposure, gain and stain vary between sections, and the only thing they share
is that a profile crossing the edge of a section has a two-moded histogram. Which end is
background is read off the trace rather than assumed, so a line drawn inward and one drawn
outward both come out right.

Otsu will cut anything in two, though, including a trace that only slopes. So a crossing
has to be shown to be an edge before it is believed: the run between a tenth and nine
tenths of the step has to be under a quarter of the profile. A section edge crosses that in
a few samples; a line lying entirely inside tissue that merely dims with depth takes most
of its length to, and is refused. A line with tissue at both ends is refused for the same
reason, and one whose two levels are within about three noise sigmas is marked but reported
as low confidence, because a weak step is still the best estimate the trace supports and
the marker is there to be dragged.

This runs on its own **when a line is created** — drawn with **Draw Line**, or placed
across the middle of a section that never had one — and on demand from **Detect**. It does
not run when an edit opens on an ROI that already has a file behind it: a guess made there
would turn a section nobody has touched into one with unsaved changes.

### Correcting it

The mark is a draggable handle on the line, so a detection that landed a little off is a
drag rather than a dialog; the handle slides along the line whatever the mouse does,
because a point off the line has no depth along the profile. **Mark Surface** takes one
from a click for a line that has no mark at all, and projects it onto the line the same
way. **Clear** takes it off, which is the right answer for a section whose edge cannot be
told from its background — an unmarked trace is visibly unaligned on the plot, where a
wrong mark would quietly move a section somewhere it never was.

The tile ticks the band across at the mark, on every tile rather than only the one being
edited, and labels it `surface (auto)` while it is still the detector's answer — so a grid
of sections says at a glance which of them have been checked over. **Brain surface**
(`Ctrl+4`) switches the ticks and the rules on the profile plot on and off together.

### Using it

**Distance → From brain surface** on the profile plot shifts each trace so its own mark
sits at zero, which is what lines two sections up by cortical depth. A trace with no mark
falls back to its own line start — the axis it already had — and the plot says how many
did, so an unmarked section reads as unaligned rather than as aligned at a surface nobody
found.

**Export to Workspace** carries the mark out beside the geometry, as `SurfaceOffset` along
the line, the `SurfaceX`/`SurfaceY` it lands on, and `SurfaceSource` saying whether it was
detected or placed by hand. That is what an alignment done at the command line works from.

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
own first sample, *Percent of line* runs every line from 0 to 100 whatever its length,
which is what lines two profiles up by relative depth rather than by microns, and *From
brain surface* puts each trace's own surface mark at zero — see **Marking the brain
surface**. All three are per trace whatever **over** says, because a line's own start, its
own length, and its own surface are the only things they can mean.

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
| `Ctrl+E` | Start or finish editing the line ROI |
| `Ctrl+D` | Draw a new line over the image |
| `Ctrl+S` | Save the ROI and remeasure its profile |
| `Ctrl+Z` | Discard unsaved ROI changes |
| `Ctrl+B` | Find the brain surface in the profile and mark it |
| `Ctrl+Shift+B` | Click on the image to mark the brain surface |
| `Esc` | Leave ROI editing |
| `Ctrl+1` / `Ctrl+2` / `Ctrl+3` / `Ctrl+4` | Line ROI / sampling band / intensity shading / brain surface marks on or off |
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

## Reading a tile

Each tile is framed, labelled and has its ROI stroked in one color, and the profile plot
reuses it for that section's trace, so a picture can be matched to its curve without counting
positions. Those colors come from `HistologyImageBrowser.tileColors`, which takes MATLAB's
`lines` and `turbo` maps and lifts the dark end of them: both open on a near-black color, and
sections are usually near-black fluorescence, so a navy frame or a navy ROI line on one is
not a line anyone can see. Only brightness and saturation move — hue is what identifies the
tile, so the set stays as separable as it was.

The label sits inside the axes box, along the top left, on an opaque plate. A MATLAB title
sits outside the box and takes a strip of the window with it, which on a grid of a dozen
sections is a strip taken a dozen times out of the pictures. The plate is what keeps the
label readable either way round: over a dark section it disappears and only the color reads,
and over a bright brightfield one it is what the color reads against. The ROI state badge
sits in the opposite corner so the two share the top edge without ever colliding.

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

Editing an ROI takes the same cheap path. Opening a session, drawing a line, dragging one,
marking a brain surface on it, saving, reverting and closing all change the same three
things — the draggable handles, the overlay on the one tile the line belongs to, and the
profile plot beside it — and not one of them changes a pixel of any image, so
`refreshRoiEdit` updates that tile in place and the rest of the grid keeps the pictures it
already has. Dragging the surface mark is cheaper still: it moves a point along a line the
profile was already measured under, so nothing is remeasured at all, on every mouse move as
well as at the end of the drag. It falls back to a full redraw only when
there is no tile to update: the layout may not have been built yet, or the section may have
failed to read and be showing a placeholder, which has no image coordinates to put a line in.

Changes that alter the pixels or the set of tiles — the rendition, the channel, the
colormap, the contrast percentiles, **Max tiles**, and the background — still rebuild the
whole layout, because they have to. Every display control shares one callback, so which of
the two happened is settled by comparing the settings in force against the ones the tiles on
screen were drawn from, rather than by trusting each control to route itself.
