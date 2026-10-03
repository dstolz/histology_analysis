# histology_analysis: repository review and improvement plan

Reviewed at commit `80f800e` (`main`, 2026-09-25). Review date 2026-10-03.

## How this review was done

- Every `.m`, `.R`, `.ijm`, `.md` and workflow file was read. MATLAB and R were not
  executed in the review environment, so the review is static. Where ImageJ behaviour
  mattered (`measure_line_profile`, `.roi` encoding, TIFF unit strings) it was checked
  against the ImageJ source (`ij/Line.java`, `PolygonRoi.java`, `Straightener.java`,
  `ImageProcessor.java`, `ProfilePlot.java`, `RoiDecoder.java`, `FileSaver.java`,
  `Calibration.java`), not against memory.
- Every finding cites `file:line` at the reviewed commit. **CONFIRMED** means it is
  demonstrable from the source alone. **SUSPECTED** means it depends on runtime or library
  behaviour that was not executed; those are labelled.
- There are no open issues or pull requests on the repository, so nothing here duplicates
  tracked work.

**Priority** is by consequence for the data, which the owner has named as the only thing
that matters:

| Priority | Meaning |
|---|---|
| P0 | Can silently alter, destroy, or misrepresent measured data, or produce wrong published numbers. |
| P1 | Confirmed functional defect without silent data loss. |
| P2 | Testing, CI, performance and structure that gate everything else. |
| P3 | Features and workflow gaps. |
| P4 | Documentation and repository hygiene. |

**Effort**: S under half a day, M one to three days, L more than three days.

## 1. State of the repository

About 40 k lines of MATLAB outside the vendored `colorcet.m`, plus a 1.4 k-line R script.
Three distinct generations of code live side by side:

- `histology_browser/` (the GUI, ingest, tracker, 5 k lines of tests): actively developed,
  documented in detail, with design notes that match the code in most places.
- `ECM_Analysis/` (the group-comparison GUI, preparation function, R statistics): actively
  developed, **no tests at all**.
- The 17 root files and `tools/`: a single import commit each, no caller in maintained code,
  hard-coded lab paths in the `T_*` scripts, several crash paths.

Nothing runs the tests. Both test runners print a failure count and return normally, so even
a MATLAB CI job would always pass. The repository has no `LICENSE`, `CITATION.cff`,
`CONTRIBUTING.md`, `CHANGELOG.md` or `CLAUDE.md`, and `.gitignore` covers only `fiji.log`.

The highest-consequence findings, each confirmed in source:

1. **Edit ROI can overwrite a Fiji-measured profile with an invented one, immediately and
   without a prompt** (row 1). Pressing Ctrl+E on a section whose ROI has no readable `.roi`
   file writes a horizontal line at 20 to 80 % of the image width and remeasures the existing
   `*values.csv` from it. Revert cannot undo it.
2. **A MATLAB remeasurement is indistinguishable on disk from Fiji's measurement** (row 3),
   and the two differ at image borders (row 5). Nothing records which tool produced a file.
3. **The tracker write-back can land on the wrong row and report success** (row 11), and
   two fresh MATLAB sessions mint identical `Row UID`s (row 13).
4. **The R statistics and the MATLAB preparation analyse different section sets with
   different smoothing**, and nothing checks that they agree (rows 15, 16). Every error band
   and bootstrap in the ECM browser treats sections as independent replicates (row 17).
5. **Units are not carried through**: axes say µm whatever the calibration, a 72-dpi TIFF
   yields a 352.78 "µm" pixel, and Fiji's own unit string is not recognised (row 8).

## 2. Prioritised improvements

Detail for each row, with the full evidence, is in section 3 under the same number.

| # | Pri | Area | Improvement | Key evidence | Effort |
|---|---|---|---|---|---|
| 1 | P0 | Browser | Never auto-save an invented line when a `.roi` or `*values.csv` already exists for that key; open the edit unsaved and require an explicit, named confirmation. | `initialRoiGeometry.m:31-75`, `onToggleEditRoi.m:138-144`, `onSaveRoiEdits.m:148-153` | S |
| 2 | P0 | Browser | Add an unchanged-guard to Save and back up the previous `.roi`, `*values.csv` and surface sidecar before any overwrite. | `updateRoiEditControls.m:20`, `onSaveRoiEdits.m:19-20`, `write_imagej_roi.m:92-104` | S |
| 3 | P0 | Ingest | Write a provenance sidecar for every profile MATLAB measures (tool, commit, image path and hash, geometry, width, pixel size and unit, time) and surface it in the catalog and export. | `write_values_csv.m:49-50`, `write_surface_mark.m:68-69` | M |
| 4 | P0 | Browser | Add **Delete ROI** (files and catalog entry) with confirmation and backup. | no implementation exists | S |
| 5 | P0 | Ingest | Make `measure_line_profile` match ImageJ at image borders and for non-integer widths, or flag affected profiles; add a golden test against a Fiji-written CSV. | `measure_line_profile.m:88, 206-207`; ImageJ `ImageProcessor.getInterpolatedValue`, `Straightener.java:130` | M |
| 6 | P0 | Browser | Remeasure from the projection only; refuse to save, or name and record the variant, when the projection is missing. | `measureImagePath.m:7-17`, `resolveImagePath.m:6-10`, `onSaveRoiEdits.m:135` | S |
| 7 | P0 | Browser | Keep a file's sub-pixel stroke width instead of substituting the 994 px default; never write width 0. | `initialRoiGeometry.m:34-36`, `HistologyImageBrowser.m:328`, `write_imagej_roi.m:47-51` | S |
| 8 | P0 | Ingest, Browser, ECM | Carry the distance unit end to end: a `Unit` column in `combined` and exports, axis labels from it, a sanity bound on pixel size, decoding of Fiji's `\u00B5m`, and a refusal to mix units in one plot or analysis. | `HistologyImageBrowser.m:397-399`, `buildViewPanel.m:37`, `loadMeasureImage.m:94-101`, `measure_line_profile.m:150-153`, `imagej_pixel_size.m:58-70, 112-125` | M |
| 9 | P0 | Browser | Validate the surface sidecar against the current `.roi` endpoints on read; clamp or refuse an offset longer than the line on write. | `write_surface_mark.m:61-68, 99-102`, `roiForRow.m:142-153`, `read_surface_mark.m:75-78` | S |
| 10 | P0 | Browser | Invalidate the full-resolution measurement cache on reload and key it on path, size and mtime. | `loadMeasureImage.m:29-36`, `onLoadData.m:108-109` | S |
| 11 | P0 | Tracker | Treat a value that reads back differently as a failed write; snapshot the target cells before writing and restore them when verification fails; name the row that received the value. | `applyUpdates.m:24-25, 146-191` | M |
| 12 | P0 | Tracker | Optimistic concurrency: compare `Last Updated` and `Measured` with the values the catalog loaded before writing; refuse or prompt on drift. | `writeReview.m:29-42`, `runShortcut.m:233` | S |
| 13 | P0 | Tracker | Generate `Row UID`s from a real UUID source; write them only to rows whose `Image Filename` still matches the read; re-verify uniqueness of the whole column after writing. | `SectionTracker.m:228-234`, `ensureSchema.m:121-134, 144-155` | S |
| 14 | P0 | Tracker | Write numeric values at full precision (or refuse them) and verify with `UNFORMATTED_VALUE`. | `applyUpdates.m:107`, `updateValues.m:47`, `getValues.m:32` | S |
| 15 | P0 | ECM / R | Filter on `IncludeInAnalysis` in R, assert that factor coercion drops nothing, and write an exclusion table with reasons to the report. | `ecm_analysis.R:278, 293-299, 351, 505`; `S_ECManalysis.m:122, 144, 169, 189` | S |
| 16 | P0 | ECM / R | One parameter file written by `ecm_export_for_r` and read by R (kernel, window, bins, depth window, surface mode, commit), plus a test that per-section surface and peak agree between MATLAB and R. | `ecm_analysis.R:359, 466-467, 483-489, 498`; `ecm_prepare_analysis_data.m:129, 188` | M |
| 17 | P0 | ECM | A **Unit** control (section, subject × hemisphere, subject) that aggregates before SEM, CI and bootstrap; t quantiles for small n; n shown per depth. | `bootBand.m:26-28`, `drawGroup.m:108-110`, `ECMBrowser.m:1565-1572`, `ecm_prepare_analysis_data.m:757-765` | M |
| 18 | P0 | ECM / R | Set and print the degrees-of-freedom method; add a random depth slope or an AR(1)/GAMM alternative for the depth-profile model; label the multi-model table as sensitivity, not inference. | `ecm_analysis.R:58-60, 1101-1105, 1364-1380` | M |
| 19 | P0 | ECM | Write a settings sidecar (`A.options`, view settings, N per group, input identity, versions) beside every CSV and figure export; include it in `viewData`. | `saveData.m`, `viewTable.m:12-18`, `copySummary.m`, `viewCommands.m:117-126` | S |
| 20 | P0 | ECM / R | Seed the bootstrap and R's Shapiro subsample; store the seed; dump `ver` and `sessionInfo()` in reports. | no `rng` outside `make_test_dataset.m:56`; `ECMBrowser.m:468`; `ecm_analysis.R:1325` | S |
| 21 | P0 | ECM / R | Peak detection with prominence and interior checks, and a per-section peak flag. | `ecm_prepare_analysis_data.m:703`, `ecm_analysis.R:475-480`, `section_metrics.m:55-56` | S |
| 22 | P0 | ECM / R | Default smoothing width in distance units, shared by MATLAB and R. | `ecm_prepare_analysis_data.m:129`, `ecm_analysis.R:466` | S |
| 23 | P0 | ECM | Minimum n per depth for group means and bands (dash or cut beyond it); integrate metrics over the common depth window only and report coverage. | `drawGroup.m:127`, `column_area.m`, `section_metrics.m:49-53` | S |
| 24 | P0 | Ingest | Protect `combine_values_csv`: normalise headers per file, skip and diagnose mismatches instead of aborting on `vertcat`, dedupe duplicate copies, add `filenamePattern`. | `combine_values_csv.m:33-41, 132, 534-542` | S |
| 25 | P0 | Ingest | Refuse to collapse `_proj_roi.roi` and `_proj_A_roi.roi` into one entry; never adopt an orphan `.roi` when more than one orphan profile exists; emit pairing diagnostics. | `histology_roi_key.m:31-40`, `build_histology_image_catalog.m:258, 275-304, 349` | S |
| 26 | P0 | Ingest | Write crops to a sibling folder, ignore `_roiCropped`/`_slanted`/`_end` in the scan, validate parsed fields, allow `[^_]` in ROI labels. | `crop_roi_image.m:98-105`, `parse_histology_filename.m:89-118, 200`, `combine_values_csv.m:363` | S |
| 27 | P1 | Browser | Refresh the `ROI` column in place after save or rename (the code writes `ROIs`). | `onSaveRoiEdits.m:322-323`, `onEditRoiNames.m:96`, `HistologyImageBrowser.m:446-451`, `catalogDisplayTable.m:78` | S |
| 28 | P1 | Browser | Honour Cancel in the unsaved-changes prompt, prompt on window close, show a dirty marker in the title. | `onSelectionChanged.m:41-48`, `HistologyImageBrowser.m:716-728` | S |
| 29 | P1 | Browser | Keep the drag handles in the browser when opening an external figure; attach the surface editor wherever the ROI editor is attached. | `onOpenInFigure.m:37-39`, `drawImageTile.m:82`, `attachRoiEditor.m:7-17`, `refreshRoiEdit.m:86` | S |
| 30 | P1 | Browser | Clear `RoiEditCreated` after a save so later Draw Line calls do not auto-save. | `onToggleEditRoi.m:101`, `onDrawRoi.m:158-161` | S |
| 31 | P1 | Tests | Fix the stale Add ROI test before it is run against real data; it now fails and writes `_proj_B_*` files beside a real section. | `tests/test_histology_browser.m:2050-2061`, `onToggleEditRoi.m:138-144` | S |
| 32 | P1 | Tracker | Backoff on 429 and 5xx, one refresh-and-retry on 401, a read-only scope for reads. | `request.m:55-68`, `accessToken.m:24, 38-47` | S |
| 33 | P1 | Tracker, Ingest | Read tracker columns as text in both CSV paths, warn on a second header candidate or duplicate headers, keep the join key verbatim. | `read.m:77-78, 101-103`, `combine_values_csv.m:430, 437-440` | S |
| 34 | P1 | Root tools | Repair or retire `straighten_cortex.m` (three crash paths, a column-index bug shared with `straighten_cortex2.m`, a double offset, and two unit mismatches). | `straighten_cortex.m:153-160, 200-241, 227-233, 298-304, 426`; `straighten_cortex2.m:148-155` | M |
| 35 | P1 | Root tools | Fix the smaller confirmed bugs in `runImageJMacro`, `InteractiveAffineOverlay`, `histologyLabeller`, `tools/ylabelf`, `T_HistologyBrainSurface`, `parseBfTiff`. | see section 3 | S |
| 36 | P2 | Tests | Convert both runners to `matlab.unittest` with tags, real skips, unique temp folders and a non-zero exit on failure. | `test_section_tracker.m:38-42`, `test_histology_browser.m:110-114, 126-128, 778-782` | M |
| 37 | P2 | CI | Run the headless tests on every push; parse the R script and restore an `renv.lock`; renormalise `claude.yml`. | `.github/workflows/` holds only `claude.yml`, `wiki.yml` | M |
| 38 | P2 | Tests | Cover the risky paths: Save, Draw, Mark Surface, close, rename, external figure; golden `.roi` and `*values.csv` fixtures from Fiji; `batch_detect_brain_surface`; all of `ECM_Analysis/`; the `+gsheet` transport; a race hook in the fake sheet. | see section 3 | L |
| 39 | P2 | Browser | Index `Data.combined` by stem and label at load; debounce preference writes. | `readProfile.m:146`, `onSurfaceEditChanged.m:54`, `HistologyImageBrowser.m:1092` | S |
| 40 | P2 | Structure | Split the two 3 k-line classes along existing seams; one TIFF page reader; one copy each of the duplicated helpers. | `HistologyImageBrowser.m` (2654 lines), `ECMBrowser.m` (3021 lines) | L |
| 41 | P2 | Structure | Move the legacy root tools to `legacy/` off the default path; turn the two useful `T_*` scripts into `examples/` with a config cell; delete the duplicate `histology_browser/addpath_nogit.m`. | 17 root files, one commit each, no maintained caller | S |
| 42 | P2 | Config | A project configuration file (paths, treatment levels, plate centre, windows, output names) consumed by `S_ECManalysis.m`, `ecm_export_for_r.m` and `ecm_analysis.R`. | `S_ECManalysis.m:5, 21, 80`, `ecm_export_for_r.m:57-58`, `ecm_analysis.R:72, 299, 306` | S |
| 43 | P2 | Packaging | `buildfile.m` with test and package tasks; an `.mltbx` release; a namespace or documented path layout to remove the `helper_fnc` shadowing risk. | `README.md:7-11` | M |
| 44 | P3 | Browser | Batch operations on the selection: detect and clear surface, remeasure, with a dry-run summary. | only `batch_detect_brain_surface.m` exists, command line only | M |
| 45 | P3 | Browser | Export geometry and surface marks to CSV without the workspace; configurable export dpi and region; a channel dropdown that refuses rather than clamps. | `onExportWorkspace.m`, `onExportView.m`, `loadDisplayImage.m:66` | S |
| 46 | P3 | Browser | Keyboard nudging of endpoints and the surface mark; plain arrow navigation in the table; progress and cancel for multi-tile renders. | `keyBindings.m`, `renderSelection.m:37-41` | M |
| 47 | P3 | Tracker | Write-back beyond `Measured`, a dry-run preview, the acting user recorded, and conflict display. | `writeReview.m:58` | M |
| 48 | P3 | ECM | Effect sizes with CIs for the headline contrasts; a one-action reproducibility bundle (figure, data, settings, versions). | `ecm_analysis.R:1364-1380` | M |
| 49 | P3 | Ingest | Calibration from OME-XML and CZI metadata as a fallback to the TIFF tag; a shared image cache and optional `parfor` for the batch detector. | `imagej_pixel_size.m`, `batch_detect_brain_surface.m:77, 96` | M |
| 50 | P4 | Docs | Correct the stale statements listed in section 4 (surface-mark FAQ, "missing helpers", minimum release, missing shortcut, Bio-Formats line, menu table, README function table, `measure_line_profile` docstring). | see section 4 | S |
| 51 | P4 | Hygiene | Add `LICENSE`, `CITATION.cff`, `THIRD_PARTY_NOTICES.md`, `CONTRIBUTING.md`, `CHANGELOG.md`, `CLAUDE.md`; expand `.gitignore`; decide on the 1.1 MB of wiki PNGs. | repository root | S |

## 3. Evidence and detail, by row

### P0: data integrity

**1. Auto-save of an invented line over existing files.** `initialRoiGeometry.m:31-75`
returns a horizontal line from 20 % to 80 % of the image width with `isNew = true` whenever
`roiForRow` does not return a valid line. That covers a values-only ROI (a profile whose
`.roi` is missing or was never paired), a corrupt `.roi`, and a non-line `.roi`.
`onToggleEditRoi.m:138-144` then calls `onSaveRoiEdits` at once. `onSaveRoiEdits.m:148-153`
reuses `entry.valuesPath` when it exists, so `write_values_csv` replaces the Fiji-measured
profile with the profile of the invented line; lines `144-146` use the existing `.roi` as
the template and overwrite it. `onSaveRoiEdits.m:22-24` states that no prompt is given.
`onRevertRoiEdits.m:20` re-reads the file that was just overwritten. Fix: auto-save only when
neither sidecar exists; otherwise open the edit dirty and unsaved, and have Save name the file
it is about to replace.

**2. Save with nothing changed.** `updateRoiEditControls.m:20` enables Save whenever an edit
is open. `onSaveRoiEdits` has no comparison against disk, so a user who opens an edit and
presses Ctrl+S replaces Fiji's `.roi` and `*values.csv` with MATLAB's versions.
`write_imagej_roi.m:92-104` keeps only C/Z/T from the template's header2, dropping ROI
properties, group and overlay fields, which contradicts its own docstring at `:16-18`.
`onSaveRoiEdits.m:19-20` says nothing is backed up. A `.bak` beside the file, or a
per-section `history/` folder with a timestamp, is enough.

**3. No provenance.** `write_values_csv.m:49-50` writes `distance_pixel_index,intensity` and
the samples. A file remeasured in MATLAB after a drag is byte-for-byte the same shape as the
macro's output. Only the surface JSON records `source` and `written`
(`write_surface_mark.m:68-69`). Proposed sidecar `<base>_values.json`: `measuredBy`
(`fiji-macro` | `matlab`), repository commit, `imagePath`, image size and a content hash,
`x1 y1 x2 y2`, `strokeWidth`, `pixelSize`, `unit`, `nSamples`, `written`. `combine_values_csv`
reads it into a `ProfileSource` column; the export already has a `ProfileSource` field.

**4. No Delete ROI.** There is no method, menu item or shortcut that removes an ROI's files
or its catalog entry. Given rows 1 and 2, a user who creates a wrong ROI has to leave MATLAB
to remove it.

**5. `measure_line_profile` versus ImageJ.** Checked against ImageJ source. Sample count and
spacing match (`PolygonRoi.getEquidistantPoints`: `npOut = round(L)+1`;
`measure_line_profile.m:96, 101`); band centring matches (`Straightener.java:181-189`;
`:106`); the pixel-index convention matches. Two divergences are confirmed:

- Out-of-image samples. `band_mean` clamps coordinates to the image
  (`measure_line_profile.m:206-207`), replicating edge pixels. ImageJ's
  `getInterpolatedValue` returns 0 outside the image and `ProfilePlot` counts those zeros in
  the column mean. With the macro's default 994 µm band (about 600 px at 1.66 µm/px) any
  band that crosses the border gives a different mean, and `detect_brain_surface` sees a
  different trace. The comment at `:191-192` claiming ImageJ holds edge pixels is wrong.
- Width. `:88` rounds `strokeWidth`; ImageJ truncates (`Straightener.java:130`) and uses
  the single-pixel path when width ≤ 1 (`Line.java:449`). Only non-integer widths differ.

The docstring at `:13-17` attributes the 0.03 % residual to a sample-grid difference that
does not exist in current ImageJ; the residual is float32 arithmetic. There is no golden test
against a Fiji-written CSV (`tests/test_histology_browser.m:971-1008` uses synthetic ramps
inside the image). Recommended convention: sample as ImageJ does so files are interchangeable,
or use NaN outside the image, exclude it from the mean, and record the count of outside
samples in the provenance sidecar. Either way, add a Fiji-authored fixture.

**6. What gets measured depends on a display setting.** `measureImagePath.m:7-17` falls back
to `resolveImagePath`, which starts from the Variant dropdown (`resolveImagePath.m:6-10`). A
section with no `_proj` is remeasured from mid, composite (RGB averaged,
`measure_line_profile.m:178-186`) or raw, page 1 only (`loadMeasureImage.m:72-77`), and the
file is still named `_proj_values.csv` (`onSaveRoiEdits.m:135`).

**7. Sub-pixel widths.** `initialRoiGeometry.m:34-36` substitutes the Width field (default
`DefaultRoiWidth = 994`, `HistologyImageBrowser.m:328`) when the file's stroke width is below
1. A line Fiji measured 1 px wide is saved and remeasured as a 994 px band. Separately,
`write_imagej_roi.m:47-51` writes width 0 when `strokeWidth` is NaN; ImageJ's `RoiDecoder`
leaves width unset for ≤ 0 and the `Line` constructor then applies the global line width,
which the macro sets to about 600 px (`MACRO_Batch_LineMeasure.ijm:99, 126`), so Fiji and
MATLAB measure that file at different widths.

**8. Units.** Axis labels are fixed to µm (`HistologyImageBrowser.m:397-399`,
`buildViewPanel.m:37`), so an uncalibrated dataset plots pixel indices under a µm label.
`loadMeasureImage.m:94-101` measures an uncalibrated image at the spacing of the existing
profile while `onExportWorkspace.m` labels `PixelUnit` from the image header, so exported
distances can be in µm and tagged `pixel`. `measure_line_profile.m:150-153` forces `um` for
any caller-supplied pixel size. `imagej_pixel_size.m:58-70` accepts any TIFF resolution, so
the 72 dpi default written by `imwrite` or Photoshop gives 352.78 "µm" per pixel. Fiji writes
the unit through `FileSaver.appendEscapedLine`, which emits the micron sign as the literal
text `\u00B5m`; `imagej_pixel_size.m:112-125` recognises `um`, `micron`, `microns` and the
real µ character but not that escape, so the unit propagates literally. `combine_values_csv`
has no unit column, so a dataset mixing calibrated and uncalibrated files merges silently;
`ecm_analysis.R:291` renames `Distance` to `distance_um` unconditionally and hard-codes
"(um)" axis labels, and `ECMBrowser` takes the unit from the first section only
(`indexFields.m:41-43`).

**9. Surface sidecar trust.** `write_surface_mark.m:61-68` stores the endpoints the mark was
placed against, but `roiForRow.m:142-153` and `read_surface_mark.m:75-78` never compare them
with the `.roi` now on disk; a `.roi` rewritten in Fiji keeps the old offset. After the far end
is shortened, `write_surface_mark.m:99-102` writes an offset longer than the line while
`readProfile.m:105` clamps it for display, so disk and screen disagree.

**10. Measurement cache.** `loadMeasureImage.m:29-36` returns the cached full-resolution
page whenever `MeasureKey` equals the path. `onLoadData.m:108-109` resets `ImageCache` but
not `MeasureImage`/`MeasureKey`, so after a projection is re-exported and the dataset
reloaded, Save remeasures from the old pixels.

**11. Tracker verification gaps.** `applyUpdates.m:146-191` (`verify_write`) re-reads and
checks only that each UID still sits at the sheet row written to. A value that reads back
differently is appended to `Warnings` (`:183-189`), not raised. Undetected cases: rows
reordered between read and write and back in place by the verify read; a re-mark of a cell
that already held `yes` (only the timestamp differs); two rows sharing a UID after the write
(`find(...,1)` at `:159` takes the first). Because `Last Updated` is always written
(`:24-25`), the row that wrongly received the value also carries an application timestamp,
which defeats the purpose stated in `SectionTracker.m:20-22`. The pre-write table is in
memory and nothing restores the victim row; the user is told to check version history
(`:177-180`). The GUI then reports success and patches the catalog (`writeReview.m:36-42`).

**12. No optimistic check.** `Last Updated` is written but never read back and compared with
the value the catalog loaded, so a hand edit between load and Ctrl+M is overwritten without
notice, and Ctrl+M decides whether to mark or clear from the in-memory `View.Measured`
(`runShortcut.m:233`).

**13. UID generation and schema writes.** `newUid` (`SectionTracker.m:228-234`) draws from
`randi` on the default global stream. MATLAB seeds that stream identically at every start, so
two fresh sessions on the same day mint the same `SEC-yyyymmdd-<12 hex>` sequence; the
collision check (`ensureSchema.m:115-119`) sees only the current tab, so two machines
preparing the sheet concurrently, the case the comment at `:221-222` claims to cover, produce
duplicate UIDs whenever their blank sets differ. `ensureSchema.m:121-134` writes new UIDs to
the sheet rows that were blank at read time; a sort or insert in between puts them on other
rows, possibly over an existing UID, and `verify_uids` (`:144-155`) checks only that the cell
at row N holds what was written there. `java.util.UUID.randomUUID` or
`matlab.lang.internal.uuid` removes the seed problem; writing only where `Image Filename`
still matches the read, then re-verifying the whole column, removes the clobber.

**14. Numeric precision.** `applyUpdates.m:75` admits numeric values; `:107` converts with
`string(value)`, about five significant digits (`string(pi)` is `"3.1416"`). `RAW` input
(`updateValues.m:47`) stores text in a numeric column. Verify reads `FORMATTED_VALUE`
(`getValues.m:32`), where text `30` and number 30 are indistinguishable, so neither the
rounding nor the type change is caught. `Measured` and `Notes` are unaffected; any numeric
write-back is.

**15. R section set.** `ecm_analysis.R:278` reads `IncludeInAnalysis` and `:505` selects it;
nothing filters on it. `:293-299` coerce `Hemisphere`, `Condition` and `Treatment` to fixed
level sets, so any other spelling becomes `NA` and `lmer`'s default `na.omit` drops the row
with no message. `:351` drops sections without a `SurfaceDistance`, where
`ecm_prepare_analysis_data` detects a surface for them. `S_ECManalysis.m:122, 144, 169, 189`
filter on `IncludeInAnalysis`, so the MATLAB figures and the R statistics are computed on
different section sets. `ecm_export_for_r.m` also drops every cell column (`:47`), so
`ROIKey` does not reach R and multi-ROI sections can only be caught by the hard stop at
`ecm_analysis.R:338-345`.

**16. Two smoothing pipelines, no agreement check.** MATLAB: gaussian, default 50 samples,
applied to the whole profile before alignment and trimming
(`ecm_prepare_analysis_data.m:129, 188, 208`), peak from the smoothed trace by default
(`:686-703`). R: 25-sample centred boxcar applied after the `depth_um >= 0` trim
(`:359, 466-467, 498`), which leaves `NA` for the first and last 12 samples, so the first
roughly 12 samples past the surface are excluded from the peak search. Windows and bins are
literals (`:483-489, 603`). The wiki says to keep them in sync by hand
(`docs/wiki/ECM-Analysis.md:207-215`). A JSON parameter file written by `ecm_export_for_r`
and read by R, plus a per-section comparison of `SurfaceDistance`, `PeakX` and `PeakY`
between `A.peaks` and the R output, closes this.

**17. Sections as independent units.** `bootBand.m:26-28` resamples section columns with
`bootci` (percentile, `BootReps = 2000` at `ECMBrowser.m:468`); `drawGroup.m:108-110` uses
`n = sum(isfinite(M), 2)`, the number of sections with data at each depth, and `bandOf`
applies a normal 1.96 (`ECMBrowser.m:1565-1572`); `ecm_prepare_analysis_data.m:757-765` uses
n = samples for `A.grouped`. An animal with five sections contributes five exchangeable units,
so every band is anti-conservative relative to animal-level inference, and with n of 2 to 5
the normal quantile under-covers further. Comparisons average per match and then across
matches with n = matches (`compareWithin.m:49-50, 101-105`), so matches that omit `SubjectID`
are pseudo-replicated, and "(each vs. the rest)" reuses sections across comparisons that are
then averaged as independent.

**18. R model details.** `(1 | SubjectID/Hemisphere)` is appropriate for hemispheres in
subjects with treatment between subjects. M3 (`:1101-1105`) adds `(1 | section_id)` but no
depth autocorrelation or random depth slope, so 25 µm bins within a section are treated as
conditionally independent, which inflates the Treatment × depth F and the depth-wise
contrasts (which are labelled unadjusted at `:1120, 1410`). `lmer.df` and `emm_options` are
never set, so the emmeans df method depends on whether `pbkrtest` is installed; it is not in
the required list (`:58-60`) and the method is never printed. Singular fits are refit without
the nested term but the reduced model is only printed (`:876-882`). The headline table
(`:1364-1380`) reports five specifications' p-values with no adjustment.

**19. Export provenance.** `saveData.m` writes `viewTable`'s normalised, compared and
depth-trimmed values with a `Depth_<unit>` header (`viewTable.m:12-18`) and no record of
signal, normalisation, scope, Ref window, depth window or comparison. `viewData.m:40` holds
`settings` but `saveData` does not write them. `copySummary.m` omits N per group.
`viewCommands.m` omits how `A` was built, axis limits (`matchLimits` has them,
`ECMBrowser.m:2672`), dpi and background, and emits `setFilter` calls without a leading clear
(`:117-126`), so the commands are correct only on a fresh browser. Saved configurations drop
fields or values the current dataset lacks silently (`ECMBrowser.m:1251-1286`,
`applySettings.m:24-44`).

**20. Randomness.** The only `rng` call is in `make_test_dataset.m:56`. The bootstrap band and
R's Shapiro subsample (`ecm_analysis.R:1325`) are unrepeatable run to run.

**21. Peaks.** `find_peak` is `max` within `peakRange` (`ecm_prepare_analysis_data.m:703`);
R's superficial peak is `band_at`, a plain max (`:475-480`), and only the deep band has an
interior test (`:556-557`); the browser's "peak height" metric is `max(y)` over the displayed
window (`section_metrics.m:55-56`). A misplaced surface mark or a bright slide edge becomes
the peak with no flag.

**22. Smoothing in samples.** `smoothingWindow` defaults to 50 with
`smoothingWindowUnit = "samples"` (`ecm_prepare_analysis_data.m:129`), and R's boxcar is 25
samples. Sections with different pixel sizes are smoothed over different physical widths.
`"distance"` already exists as an option; it should be the default, with the width in µm.

**23. Coverage.** `drawGroup.m:127` draws the mean out to depths held by a single section with
no visual cue; `column_area.m` and `section_metrics.m:49-53` integrate each section over its
own finite range, so "integral" and "area = 1" are not comparable across sections of
different depth coverage. Degenerate sections are drawn unnormalised beside normalised ones
with only a status-line note (`normalizationOf.m:57`).

**24. `combine_values_csv`.** `vertcat(validTables{:})` at `:132` is outside the per-file
try/catch: one file with a different header (an older macro's `X,Y`, a hand-edited file, an
extra column) aborts the whole combine after every file was read, and the diagnostics never
see it. Duplicate copies of a values file in a parent and a section folder, a layout
`build_histology_image_catalog.m:17-19` calls common and `make_test_dataset` writes
(`duplicateProj`), are both ingested and double-counted. There is no `filenamePattern` option
(`:33-41`), so custom-scheme datasets yield zero combined rows. With a tracker supplied, a
file whose row is missing is dropped from `combined` (`:534-537`), while the catalog keeps it,
so the two disagree.

**25. Keys and pairing.** `histology_roi_key.m:31-40` maps both `""` and `"A"` to `A`;
`collect_rois` deduplicates by key (`build_histology_image_catalog.m:258`), so
`_proj_roi.roi` and `_proj_A_roi.roi` collapse to one entry and `pick_preferred` (`:349`)
keeps whichever `dir` listed first. `adopt_unlabelled_roi` (`:275-304`) gives the unlabelled
`.roi` to the alphabetically first orphan profile; the macro overwrites `_roi.roi` on every
run (`MACRO_Batch_LineMeasure.ijm:151-152`), so after two runs with different suffixes the
`.roi` belongs to the last run and a later Save remeasures the wrong profile from it. Keys
are case-sensitive. `parse_histology_filename` takes the first `_proj_` as the base
(`:200`), so a stem containing `_proj_` is mis-split.

**26. Generated files and field validation.** `crop_roi_image.m:98-105` writes
`<stem>_proj_roiCropped.tif` beside the source. The catalog's recursive globs
(`build_histology_image_catalog.m:82-91`) pick it up, and `parse_histology_filename.m:89-118`
accepts any stem with seven or more `_` tokens and a `SUBJ-ID-` prefix, so it becomes a
validly parsed section with shifted fields (SectionID = the stain, Hemisphere = the Z plane,
and so on). Labels containing `-`, space or `.` fail the `\w*?` label match (`:200`;
`combine_values_csv.m:363`) and shift fields silently; the macro's suffix is free text
(`MACRO_Batch_LineMeasure.ijm:29`). Matching is case-sensitive, so `.TIF` or `_Values.csv`
are missed on Linux.

### P1: correctness

**27.** `onSaveRoiEdits.m:322-323` and `onEditRoiNames.m:96` assign `data.ROIs(...)` and
`data.Status(...)` on the display table, whose columns are named by heading
(`catalogDisplayTable.m:78`); the heading is `ROI` (`HistologyImageBrowser.m:446-451`). The
visible ROI column is not refreshed after Add ROI, Save or rename until the next filter or
load, a stray `ROIs` column is appended, and `ColumnWidth` is one short.

**28.** `onSelectionChanged.m:41-48`: when the selection leaves an edited section, a cancelled
`exitRoiEdit(true)` is followed by `exitRoiEdit(false)`, so Cancel discards. `onCloseRequest`
(`HistologyImageBrowser.m:716-728`) saves preferences and deletes the figure regardless of
`RoiEditDirty`. The README's "prompts rather than discarding" is not met on either path.

**29.** `onOpenInFigure.m:37-39` calls `drawImageTile`, which unconditionally calls
`attachRoiEditor` (`drawImageTile.m:82`); `attachRoiEditor.m:7-17, 39` deletes the browser's
`RoiEditor` and creates one in the external figure, so later drags act on the other window.
`drawImageTile` never calls `attachSurfaceEditor` (only `refreshRoiEdit.m:86` does), so any
full redraw during an edit (colormap, variant, background, a changed selection) leaves the
surface mark without a handle. SUSPECTED: bare Escape is bound to `cancelRoiEdit`
(`keyBindings.m:85`, `runShortcut.m:205-216`) and the figure's key handler is live while
`drawline` waits (`onDrawRoi.m:91-106`), so cancelling a draw probably also ends the edit.

**30.** `RoiEditCreated` is set at `onToggleEditRoi.m:101` and never cleared by a save, so once
a created ROI has been saved, every later Draw Line in that session auto-saves
(`onDrawRoi.m:158-161`).

**31.** `tests/test_histology_browser.m:2050-2061` calls `onAddRoi` under the comment "Nothing
is written" and asserts `RoiEditDirty`. Since commit `9f6f59e`, `onToggleEditRoi.m:138-144`
saves on placement, so the assertion fails, and run against a real root
(`test_histology_browser("D:/...")`) the suite writes `_proj_B_roi.roi`, `_proj_B_values.csv`
and possibly a surface sidecar beside the first editable section.

**32.** `request.m:55-68`: a non-2xx raises immediately; no retry or backoff. Nothing in the
repository calls `accessToken(..., forceRefresh = true)`, so a token Google has invalidated
is served from the cache for up to an hour (`accessToken.m:38-47`). Every GUI write costs
three calls, so a 429 during rapid Ctrl+M fails the write. Reads request the read/write scope
(`accessToken.m:24`).

**33.** `read.m:77-78` takes the first cell equal to `Image Filename`; a second header row
lower in the tab survives the blank-row filter, receives a UID and is writable, with no
warning. Duplicate headers: first wins with a warning that never blocks a write
(`:101-103`). `combine_values_csv.m:430` finds the header by `contains(line, "Image
Filename")` on raw lines; `detectImportOptions` defaults (`:437-440`) drop leading zeros from
all-digit IDs and re-render `Image Date`. Reads over the API use `FORMATTED_VALUE`
(`getValues.m:32`), so numbers arrive display-rounded.

**34. `straighten_cortex.m`.** `opts.imgFlipped` is read at `:153-160` but assigned only when
`imgRotation` is empty (`:136`); the file's own example (`:72`) supplies `imgRotation`.
`x_surface`/`y_surface` are defined only when `surfaceXY` is empty (`:200-241`) and used at
`:261`. `segmentHeight`/`segSpacing` are set only when the option is empty (`:298-304`) and
used at `:342-343`. `yi(i) = find(nind(:,i),1)` at `:227-229` indexes column `i` instead of
`xi(i)`; `straighten_cortex2.m:148-150` has the same loop. `:233` subtracts 1 from `xi` and
`:238` subtracts it again. `:426, 435` divide µm by the µm/px factor and label the axis µm.
`surfaceWindow` is applied in µm here (`:238, 261`) and in pixels in `straighten_cortex2.m:151-155`;
`T_HistologyBrainSurface.m:54` passes `[-2000 4000]`. `straighten_cortex2.m` declares
`numSegments` (`:32`) and never uses it, and documents `M.data` as (channel, profile, segment)
where `straightenLine` returns (depth, position, channel).

**35. Smaller root-tool defects.** `runImageJMacro.m:14-17` builds `input="%s",output="%s"`
inside a double-quoted argument, so any path with a space splits and the inner quotes are
consumed by the shell; the browser's own launcher escapes correctly (`onOpenInFiji.m:224-240`).
`InteractiveAffineOverlay.m:196-205`: `r` returns before `updateOverlay()`, so reset is not
drawn until the next key. `histologyLabeller.m:146-158` refreshes only the tiles of the last
page's crops and leaves the rest showing the previous page. `tools/ylabelf.m:3-10` accepts an
axes handle and ignores it. `T_HistologyBrainSurface.m:263` assigns `AP(k,p).x = M.x` before
the `load` at `:270`. `parseBfTiff.m:4, 17` document the outputs as `[img, info, nChannels,
xy_res]` against a signature of `[img, info, xy_res, nChannels]`, and `:41` counts every
plane as a channel. SUSPECTED: `parseBfTiff.m:48`, `straighten_cortex.m:119, 238-239` and
`straighten_cortex2.m:55, 188-189` treat `GlobalXResolution` as µm/px and multiply, where
`imagej_pixel_size.m:58-59` takes the reciprocal of the TIFF tag; `bfopen`'s `T{2}` is
series 2's plane list for multi-series files. `extract_czi_metadata.m:811-812` rescales any
`|Transmission| ≤ 1` by 100 and `:1305-1306` treats any distance below 1 as metres, both
without a provenance check.

### P2: tests, CI, structure

**36.** `test_section_tracker.m:38-42` and `test_histology_browser.m:110-114` print the
failure count and return; `run_case` prints `ME.message` only (`:126-128`), so a failing
assert inside a 150-line check gives no location. Several GUI checks `return` early when no
editable ROI exists (`:1526, 1994, 2522, 2946, 3113`) and count as passes.
`check_jwt_assertion` passes silently without a JVM (`test_section_tracker.m:198-200`).
Fixed temp folders are removed with `rmdir(..., "s")` (`test_histology_browser.m:778-782,
834-838`), so two concurrent runs delete each other's fixtures; fixed file names at `:899,
929, 946, 1668`. `check_gui` chains six sub-checks on one app (`:1796-1801`), so the first
failure hides the rest. The GUI checks write to the base workspace (`:2452-2459`) and use the
real `prefdir`. Suggested shape: `tests/+hb/*Test.m` classes with tags `Headless`, `GUI`,
`RealData`; `assumeTrue` for skips; `tempname` fixtures; `buildfile.m` with a `test` task
that runs `Headless` by default.

**37.** `.github/workflows/` holds `claude.yml` (issue-triggered agent) and `wiki.yml`
(mirror). For a public repository `matlab-actions/setup-matlab` and `matlab-actions/run-tests`
run without a licence secret; a private repository needs a MathWorks batch-licensing token or
a self-hosted runner. An R job can at least `Rscript -e 'parse("ECM_Analysis/ecm_analysis.R")'`
and restore an `renv.lock`. `claude.yml` is stored with CRLF in the index despite
`* text=auto` (`git ls-files --eol`); `git add --renormalize` fixes it.

**38.** Never invoked by any test: `onSaveRoiEdits` (reached only through the stale case in
row 31), `onDrawRoi`, `onMarkSurface`, `onCloseRequest`, `onRoiWidthChanged`,
`onEditRoiNames`, `onFigureKeyPress`, `onStepSelection`, `onExportView`, `onOpenInFigure`,
`onOpenInFiji`, the modal dialogs, `batch_detect_brain_surface`, `addpath_nogit`. Nothing
reads back a GUI-written `.roi`, `*values.csv` or sidecar. `write_imagej_roi`/`read_imagej_roi`
are round-tripped only (`:894-970`); the test writer emits no header2. `measure_line_profile`
has no border, non-integer width, RGB, multi-page or file-calibration case and no Fiji golden.
`imagej_pixel_size` has no `micron`, `µm`, inch, cm, 72 dpi or missing-tag case. The catalog
pairing tests cover one orphan and one labelled `.roi`, not two orphans, the `A` collision,
the duplicate-copy choice or an ambiguous tracker prefix. `combine_values_csv` has no
malformed, duplicate, `_mid` or unmatched-tracker case. Nothing in `ECM_Analysis/` is
referenced by any test. In `+gsheet`, `request.m`, `accessToken.m`, `getValues.m`,
`updateValues.m` (including `to_json_rows`), `appendColumns.m` and `sheetInfo.m` have no
coverage. `fake_section_tracker.m` ignores the requested range (`:68`), writes values
horizontally from the top-left cell regardless of range extent (`:103-117`), has no
`FORMATTED_VALUE` rendering and no hook between `getValues` and `updateValues`, so the race
`verify_write` exists for is untested; `check_row_moved` (`test_section_tracker.m:587-604`,
fake `:123-130`) reverses rows after the write and so exercises a false positive.

**39.** `readProfile.m:146` converts and scans the whole `Data.combined` table per ROI per
overlay refresh, which runs on every mouse move of a surface drag
(`onSurfaceEditChanged.m:54` → `drawRoiOverlay.m:106-110`). `savePreferences` (about thirty
`setpref` calls) runs on every overlay toggle (`HistologyImageBrowser.m:1092`). The catalog
build runs six recursive `dir("**")` passes (`build_histology_image_catalog.m:85-91`) and
re-parses names per file, per stem and per tracker row (`:113, 164, 590`);
`batch_detect_brain_surface` rebuilds it per run (`:77`).

**40.** `HistologyImageBrowser.m` (2654 lines) mixes UI state, the status bar
(`:2095-2175`), background and colour helpers, ROI-key helpers and about forty small methods.
`ECMBrowser.m` (3021 lines, 108 methods) buries the statistics that should be reviewable
(`bandOf`/`metricBand` `:1536-1580`, `peakHeights` `:1522`, `matchFields` `:1613`,
`peakWindow` `:1671`) among collapsible-panel plumbing, filter editing, configuration
persistence and clipboard code. Duplicates: three TIFF page readers
(`loadMeasureImage.m:67-79`, `loadDisplayImage.m:52-74`, `measure_line_profile.m:162-176`);
`center_on` four times; `on_off` three times beside `matlab.lang.OnOffSwitchState`;
two `surface_note`s; max-tiles arithmetic in three places; SEM formulas in
`ecm_prepare_analysis_data.m:757-765` and `ECMBrowser.m:1565-1572`; surface placement in
`ecm_surface_distance.m` and `readProfile.m:93-107`. Longest methods: `drawRoiOverlay.m`
521 lines, `buildDisplayPanel.m` 428, `loadPreferences.m` 421, `onExportWorkspace.m` 408,
`onSaveRoiEdits.m` 397.

**41.** All 17 root files date from one commit (`5964113`). No test, browser or ECM code calls
any of them; the only cross-folder call is `S_ECManalysis.m:5-6` to `addpath_nogit`.
`straighten_cortex.m`, `extract_equal_area_profiles.m`, `parabola_offset.m` and
`runImageJMacro.m` have no live caller. `T_HistologyBrainSurface.m` is an ECM analysis
notebook for two named projects with `C:/Users/dstolz/My Drive/...` paths at sixteen lines;
`T_Overlay.m` is a 13-line call with a `G:/Shared drives/...` path; `T_ShowSections.m`
renders hemisphere montages from a hard-coded project folder. None is a test.
`histology_browser/addpath_nogit.m` is byte-identical to the root copy; `addpath_nogit(root)`
puts the root copy first, so the duplicate is a divergence hazard with no benefit.

**42.** `S_ECManalysis.m:5` (`C:\src\histology_analysis`), `:21` and `:80`
(`D:/GM6001_HISTOLOGY/...`), `:75` (control cannula plate 30), `:31-66` (hemisphere and
treatment mapping); `ecm_export_for_r.m:31, 57-58` (output names fixed to "ECM Projects -
GM6001 - ..."; first table in the `.mat` taken silently at `:43`); `ecm_analysis.R:72`
(`DATA_DIR`), `:78-79` (file names), `:295-299` (levels), `:306` (plate centre), `:483-489`
(windows); `ECMBrowser.m:960-966` (default grouping fields). A single `project.json` read by
MATLAB (`jsondecode`) and R (`jsonlite`) removes all of them.

**43.** The README notes that `tools/` duplicates `helper_fnc` functions, so any user with
`helper_fnc` on the path gets silent shadowing of `colorcet`, `use_fig` and `titlef` by
whichever copy is earlier. A `+histology` package, or at minimum a `buildfile.m` that packages
an `.mltbx` with a defined path, removes that. Octave is not a realistic target (`arguments`
blocks, `classdef` validation, `uifigure`, `clim`).

### P3: features

**44.** Only `batch_detect_brain_surface` exists for bulk work, at the command line. In the
GUI, detect, clear and remeasure act on one ROI; Ctrl+M is the only selection-wide action.
A selection-wide Detect, Clear and Remeasure with a dry-run count and a result table would
cover the common review loop.

**45.** Geometry and surface marks leave the browser only through the workspace export
(`onExportWorkspace.m`); a CSV export of the same table, without the `Profile` cell column,
is a small addition. `onExportView` is fixed at 300 dpi of the whole layout. The channel
dropdown clamps to the pages a file has (`loadDisplayImage.m:66`), so "Channel 3" can show
channel 2 without saying so.

**46.** `keyBindings.m` has no nudge keys; endpoints and the surface mark move only by mouse.
Table navigation is Ctrl+arrow only. A twelve-tile render has a status message and no cancel
(`renderSelection.m:37-41`).

**47.** `writeReview.m:58` writes only `Measured`. Notes and plate corrections go through the
Sheets UI. Every user writes as the same service account, so nothing records who marked a
section. A dry run exists only for `ensureSchema` (`ensureSchema.m:30-31`).

**48.** `ecm_analysis.R:1364-1380` reports estimate, SE and p for the headline contrast;
no standardised effect size or CI. Depth-wise contrasts have a ribbon but no table of CIs.
A one-action export of figure, data, settings and versions would make a figure traceable.

**49.** `imagej_pixel_size.m` reads only the TIFF tag and the ImageJ `unit=` line.
`extract_czi_metadata.m` already parses CZI pixel sizes; OME-XML `PhysicalSizeX` is a
one-line read with Bio-Formats. `batch_detect_brain_surface.m` reads and converts each image
per section (`:96, 367-392`) with no cache across sections and no `parfor`.

### P4: documentation and hygiene

**50.** See section 4.

**51.** No `LICENSE` (the repository's own code has no stated terms), no `CITATION.cff`, no
`THIRD_PARTY_NOTICES.md` (`tools/colorcet.m` carries Kovesi's CC-BY-4.0 and an MIT-style
notice in its header; `tools/parfor_progress.m` credits its author at `:33` but omits the
File Exchange BSD text and was modified without saying so), no `CONTRIBUTING.md`, no
`CHANGELOG.md`, no `CLAUDE.md`. `.gitignore` is `fiji.log`; MATLAB autosaves (`*.asv`,
`*.autosave`), `*.mat` outputs, `R_figures/`, `.Rhistory`, `.DS_Store` and `Thumbs.db` are
uncovered. `docs/wiki/images/` holds about 1.1 MB of PNGs beside their SVG sources
(`ecm-browser-layout.png` 441 KB, `browser-layout.png` 332 KB, `pipeline.png` 233 KB,
`roi-states.png` 118 KB); each regeneration adds that much history.

## 4. Documentation corrections (row 50)

| Page | Says | Code |
|---|---|---|
| `docs/wiki/Troubleshooting-and-FAQ.md` ("The surface in the ECM app doesn't match…") | `ecm_prepare_analysis_data` detects the surface again and "doesn't read the browser's `SurfaceOffset`" | It reads it by default: `surfaceMarks = "prefer"` (`ecm_prepare_analysis_data.m:120, 530-575`). The ECM-Analysis page and the browser README say so correctly. |
| `docs/wiki/Troubleshooting-and-FAQ.md` ("Undefined function 'colorcet'…"), `docs/wiki/Image-Processing-Tools.md` ("Missing helpers" callout and Needs column) | The helpers "aren't in this repository" | Vendored in `tools/` since commit `d38c396`. The root README says so. |
| `docs/wiki/Getting-Started.md` requirements table | MATLAB R2021a or newer | `clim(` as a function (R2022a) in `InteractiveAffineOverlay.m`, `InteractiveRotator.m`, `ThresholdAdjuster.m`, `histologyLabeller.m`, `straighten_cortex.m`, `straighten_cortex2.m`, `T_HistologyBrainSurface.m` and `@HistologyImageBrowser/drawImageTile.m`; `affinetform2d` (R2022b) in `InteractiveAffineOverlay.m:251`. |
| `docs/wiki/Keyboard-Shortcuts.md` | Display table | Omits Ctrl+Shift+O (Open in Fiji), which `keyBindings.m` binds and `Histology-Browser.md` lists. The page's claim that it always agrees with the F1 list is true of F1, not of the page. |
| `README.md` Dependencies | Bio-Formats is needed by "`ECM_Analysis/` scripts that read OME-TIFF data" | Nothing under `ECM_Analysis/` calls `bfopen` or `bfGetReader`; the users are `straighten_cortex*.m`, `extract_czi_metadata.m`, `parseBfTiff.m` and `loadDisplayImage.m`. |
| `README.md` Functions table | Three rows read "Test or exploratory script…" | None is a test. `T_HistologyBrainSurface.m` is an ECM profile-analysis notebook (its first line is `%% ECM ANALYSIS`), `T_ShowSections.m` renders hemisphere montages, `T_Overlay.m` is one call to `InteractiveAffineOverlay`. `addpath_nogit.m` and `tools/` are not in the table. |
| `docs/wiki/Histology-Browser.md` Menus table | Dataset menu contents | Omits `Clear Tracker CSV` and `Clear Published Sheet` (`buildDatasetMenu.m:28-29, 50-51`); names the submenu item "Clear" where the code says `Clear Sheet Tracker` (`:72-73`). |
| `docs/wiki/Image-Processing-Tools.md` InteractiveAffineOverlay | "Other options:" lists seven | `InteractiveAffineOverlay.m:67-83` has seventeen `inputParser` parameters. |
| `docs/wiki/Troubleshooting-and-FAQ.md` known issues | One issue for `straighten_cortex` | Row 34 lists seven. |
| `histology_browser/measure_line_profile.m:13-17` | ImageJ "walks its resampled line in unit steps" | Current ImageJ uses `round(L)+1` equidistant samples, the same grid; the residual is float32 arithmetic. The border and width divergences (row 5) are not mentioned. |
| `histology_browser/write_imagej_roi.m:16-18, 66-67` | Template preserves header2; version 228 needed for float stroke width | Only C/Z/T are kept (`:92-104`); `FLOAT_STROKE_WIDTH` predates 228, and Fiji now writes 229. |
| `histology_browser/README.md:86-87` | "only one line could have produced both" | False with two or more orphan profiles (row 25). |

## 5. Checked and found sound

Listed so they are not re-reviewed:

- `write_imagej_roi.m` / `read_imagej_roi.m`: magic, version, type offset, float coordinates,
  stroke width, options flag, header2 offset, name block and UTF-16BE name all match
  `RoiDecoder`. No byte defect.
- `measure_line_profile.m`: sample count, spacing, band centring and pixel-index convention
  match ImageJ (row 5 lists the two divergences).
- `ecm_surface_distance.m`, `readProfile.m:93-107`, `ecm_export_for_r.m:114-123` and
  `onExportWorkspace.m:313-340` place the surface mark by the same fraction-of-line rule, so
  the browser, the MATLAB preparation and the R export align each section on the same number.
- `+gsheet`: `columnLetter`/`columnNumber` are correct bijective base-26 past `ZZ`;
  `rangeOrigin`, `encodeSegment`, base64url padding, PKCS#8 handling and the JWT claims are
  correct; the `Last Updated` format is correct UTC ISO 8601.
- Secret hygiene: no code path prints, stores in preferences, or puts in an error message the
  private key or an access token; preferences hold the key path only
  (`savePreferences.m:18`).
- `detect_brain_surface.m`: NaN filtering, sorting, short-trace and flat-trace refusals,
  reverse mapping and nearest-rank percentiles are numerically sound. Caveat: `S.index` and
  `S.fraction` are in the filtered, sorted index space, not the caller's.
- `crop_roi_image.m`: geometry, rotation, padding and `nOutside` are correct and well tested.
- `fetch_published_tracker.m`: URL handling and UTF-8 round trip are correct; quoted commas
  and µ/° characters are tested.
- `combine_values_csv.m`: Fiji writes with `Locale.US`, so decimal separators are not a risk.

## 6. Suggested sequencing

1. **Stop the bleeding (rows 1, 2, 4, 6, 7, 10, 27, 28, 30, 31).** All S effort, all in the
   browser, all independent. Row 31 first, because the current test suite writes into a real
   dataset if someone runs it against one.
2. **Make failures visible (rows 36, 37, 20).** Until the runners can fail, nothing in step 1
   stays fixed.
3. **Provenance and units (rows 3, 5, 8, 9, 19, 24, 25, 26).** These decide whether a file on
   disk can be trusted; they also give the tests of step 4 something to assert on.
4. **Tracker correctness (rows 11 to 14, 32, 33, 38 for the race hook).**
5. **Statistics (rows 15 to 18, 21 to 23, 42).** Do these before any figure from the ECM
   browser or the R report is used in a manuscript. Row 16's agreement test is the gate.
6. **Structure and features (rows 39 to 49)** as time allows, and the documentation and
   hygiene rows (50, 51) alongside whichever code they describe.

## 7. What this review did not do

- Nothing was executed. MATLAB behaviours asserted here (table dot-assignment creating a
  column, `string(double)` precision, the default random seed) are standard and documented,
  but were not run. Regex edge cases were checked by running the identical patterns in Python.
- No real dataset was available, so claims about Fiji-written files (unit escaping, `.roi`
  bytes, profile values) rest on the ImageJ source, not on a file from the lab's microscope.
  A Fiji-authored `.tif`, `.roi` and `*values.csv` committed under `tests/fixtures/` would
  turn several SUSPECTED items into tests.
- The Google Sheets API was not called. The TOCTOU analysis is from the code and the API's
  documented semantics.
- `tools/colorcet.m` was skimmed for licence and entry points only.
