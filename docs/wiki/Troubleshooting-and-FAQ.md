# Troubleshooting and FAQ

## Histology Browser

**`Unable to resolve the name HistologyImageBrowser` / the class isn't found.**
Add the folder that *contains* `@HistologyImageBrowser` (that is, `histology_browser/`), not the
`@` folder itself. Or run `addpath_nogit('<repo root>')`.

**The window opens but nothing is listed.**
The browser doesn't load anything until you ask it to. Choose **Dataset > Root Folder**, then
**Dataset > Load Dataset** (Ctrl+L). Or pass the folder to `launch_histology_browser(root)`.

**A `.czi` tile says it can't be drawn.**
Showing raw `.czi` needs Bio-Formats (`bfmatlab`). Put it on the path, or place a `bfmatlab`
folder inside or next to the `histology_analysis` checkout, or set the `BFMATLAB_PATH` environment
variable. Every other rendition (`_proj`, `_mid`, `_composite`) is read with `imread` and doesn't
need it.

**Edit ROI, Draw Line, Detect and Mark Surface don't work.**
These need the Image Processing Toolbox (`images.roi.Line`, `drawline`, `images.roi.Point`,
`drawpoint`). Without it, the browser still catalogs, displays and plots. The status bar says
why an action was refused.

**Add ROI says to select exactly one section.**
Adding an ROI works on one section at a time. Narrow the selection to that section.

**Many sections show `unparsed name`.**
Their file names don't follow the built-in convention. They're still browsable, but they have no
subject, stain, and so on to filter by. Describe your convention under **Dataset > Filename
Pattern**; see [Use your own filename convention](Recipes#use-your-own-filename-convention).

**Tracker columns (plate, notes) are blank for some sections.**
The tracker's `Image Filename` value must match the image's file name stem, or be a prefix of
it. Check for typos, and for sections missing from the tracker. The export's `InTracker` column
shows which ones matched.

**Ctrl+M doesn't mark anything as measured.**
Writing back needs the **Sheets API** tracker. The CSV and published-sheet routes are read-only.
The status bar says which requirement is missing:

- a sheet;
- a key file;
- a selection;
- `Row UID`s. To add them, run **Prepare Sheet for Writing...**.

**The published-sheet link is refused.**
You probably pasted the sheet's normal `/edit` URL. Use the link from **File > Share > Publish to
web**, for the tracker tab, in CSV format. See
[Section Tracker](Section-Tracker#option-b-published-sheet-read-only-no-credentials).

**A tracker edit I just made isn't showing.**
Google caches the published copy for a few minutes. Reload the dataset a little later, or use the
Sheets API route, which is always current.

**`SectionTracker:RowMovedDuringWrite`.**
Someone sorted, inserted or deleted rows in the sheet while the browser was writing. Nothing was
written to the wrong row. Reload and try again.

**Detect won't place a surface.**
It refuses traces that don't show a clear background-to-tissue step. Examples are a line lying
entirely in tissue, tissue at both ends, or a trace that only slopes. Draw the line so it
**starts outside the section**, or place the mark by hand with **Mark Surface**
(Ctrl+Shift+B).

**A trace is flat at zero after normalizing.**
That trace has no range. With **Min-max** a flat trace maps to 0. That is deliberate, so the
trace stays visible instead of disappearing as NaN.

**The window opens off-screen or at a strange size.**
A saved position on a monitor that's no longer attached is discarded automatically. To reset
every saved setting, run `rmpref("HistologyImageBrowser")` and reopen the browser.

**Shortcuts don't fire while I type in the search box.**
That's by design for `Ctrl+A`, `Ctrl+Z`, `Ctrl+Home`, `Ctrl+End`, `Ctrl+Left` and `Ctrl+Right`:
they go to the text field when it was clicked last. Click a table row or a tile first.

## ECM Analysis

**`ECMBrowser:NothingToBrowse`.**
No profile survived preparation. Look at `A.diagnostics`. Its `Status` (`ok`, `skipped`, `error`)
and `Message` columns say why each profile was dropped. Common causes:

- `surfaceFallback = "skip"` combined with no surface found;
- empty profiles;
- a `depthRange` that excludes everything.

**Sections are missing from the ECM plot.**
Check, in order:

1. the **Filter** section;
2. the status line, which reports "skipped or failed, see A.diagnostics";
3. whether the field you tile or color by has more than 25 distinct values. Fields like that
   aren't offered for grouping.

**`bootstrap 95%` shows no band.**
It needs the Statistics and Machine Learning Toolbox and at least two sections per group.
Otherwise it is silently omitted.

**"Nothing to compare".**
Comparisons only pair sections that share every **Pair within** field, plus the tile and the
color. Loosen **Pair within**, or check that both levels exist within each match.

**The surface in the ECM app doesn't match the mark I placed in the browser.**
That's expected. `ecm_prepare_analysis_data` detects the surface again from each profile with its
own `surfaceMode` settings. It doesn't read the browser's `SurfaceOffset`.

**The R script can't find my data.**
`ecm_analysis.R` hard-codes `DATA_DIR <- "D:/GM6001_HISTOLOGY"` and the GM6001 CSV names that
`ecm_export_for_r` writes. Edit `DATA_DIR`.

## Image processing tools

**`Undefined function 'colorcet'`, `'use_fig'` or `'parfor_progress'`.**
These helpers aren't in this repository. Get `use_fig`, `use_fig_tiledlayout`, `titlef` and
`ylabelf` from [`helper_fnc`](https://github.com/dstolz/helper_fnc). Get `colorcet` and
`parfor_progress` from the MATLAB File Exchange. See
[Image Processing Tools](Image-Processing-Tools).

**`Undefined function 'bfopen'` / `'bfGetReader'`.**
Install Bio-Formats for MATLAB and add `bfmatlab` to the path.

### Known issues in the older tools

These are documented here so they don't surprise you. They are all confirmed in the current code.

- **`parseBfTiff`**: the outputs are `[img, info, xy_res, nChannels]`. The help text lists the
  last two the other way round.
- **`extract_equal_area_profiles`**: the help example passes `'metrics', {{'mean'}}`, which
  errors. Use `metrics = {'mean'}`.
- **`straighten_cortex`**:
  - the help example passes an options struct, but the function takes name-value arguments;
  - supplying `imgRotation` skips the step that sets the internal flip flags, which are then
    read unset.
- **`histologyLabeller`**: the `contrastLim` property and its Shift-key adjustments have no
  visible effect, because the line applying it is commented out.
- **`addpath_nogit`**: it skips any folder whose path contains `.git`, including `.github`.

## Reporting a problem

In the browser, choose **Help > Report a Bug...** or **Help > Request a Feature...**. This opens
a prefilled GitHub issue on
[dstolz/histology_analysis](https://github.com/dstolz/histology_analysis/issues). A bug report
includes:

- the checked-out commit;
- the MATLAB release;
- whether the Image Processing Toolbox is installed;
- the window layout;
- what is loaded;
- the saved preferences;
- recent status messages.

**Review the text before submitting, because the tracker is public.** Preferences whose names
look like secrets are withheld automatically. Nothing is sent from MATLAB; you submit the issue
yourself on GitHub.
