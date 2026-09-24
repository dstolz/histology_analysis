# Recipes

Step-by-step instructions for common tasks. Each recipe assumes the repository is on the path
([Getting Started](Getting-Started)).

**Browsing and reviewing**
- [Try everything without real data](#try-everything-without-real-data)
- [Measure a new batch and review it](#measure-a-new-batch-and-review-it)
- [Compare profiles for one stain across a subject's sections](#compare-profiles-for-one-stain-across-a-subjects-sections)
- [Fix a badly drawn line](#fix-a-badly-drawn-line)
- [Measure a second region on the same section](#measure-a-second-region-on-the-same-section)
- [Align profiles to the brain surface](#align-profiles-to-the-brain-surface)
- [Find sections that still need work](#find-sections-that-still-need-work)

**Section tracker**
- [Connect the Google Sheet without credentials](#connect-the-google-sheet-without-credentials)
- [Set atlas plates and mark sections measured](#set-atlas-plates-and-mark-sections-measured)
- [Use your own filename convention](#use-your-own-filename-convention)

**Getting results out**
- [Make a figure of several sections](#make-a-figure-of-several-sections)
- [Get profiles into MATLAB and plot them yourself](#get-profiles-into-matlab-and-plot-them-yourself)
- [Compare treatment groups in the ECM Browser](#compare-treatment-groups-in-the-ecm-browser)
- [Save an ECM view so you can rebuild it later](#save-an-ecm-view-so-you-can-rebuild-it-later)
- [Run the R statistics](#run-the-r-statistics)

**Other tools**
- [Pull acquisition settings from CZI files into Excel](#pull-acquisition-settings-from-czi-files-into-excel)
- [Overlay an atlas plate on a section](#overlay-an-atlas-plate-on-a-section)

---

## Try everything without real data

```matlab
[root, trackerCsv] = make_test_dataset();
app = launch_histology_browser(root, metadataCSV = trackerCsv);
```

This is a small synthetic dataset: two subjects, both hemispheres, two stains, and three
deliberately unfinished sections. Anything you save goes into the temp folder `root`, so
experiment freely.

---

## Measure a new batch and review it

1. **Export projections.** Make sure each section has a `<stem>_proj.tif` in the data folder.
2. **Open the browser on the folder:**
   ```matlab
   launch_histology_browser("D:/MyHistology/", metadataCSV = "D:/MyHistology/Trackers - Sections.csv")
   ```
3. **Draw a line on each section.** Set **Sort by** to `Status` and step through with
   **Ctrl+Down**. On a section with no line yet, press **Ctrl+E** (Edit ROI); a new line is
   placed across the image. Drag it into place, or draw it with **Ctrl+D**, then press
   **Ctrl+S** (Save ROI).
4. **Review each line.** For each section:
   - check that the line crosses the region you meant;
   - check the **surface (auto)** tick, if you've run **Detect**.

Draw lines starting **outside** the tissue. That gives the surface detector a background-to-tissue
step to find, and gives every profile the same orientation.

---

## Compare profiles for one stain across a subject's sections

1. In **Look Up**, click the subject under **Subject** and the stain under **Stain**. Ctrl-click
   to pick several.
2. Press **Ctrl+A** to select every section that passes the filters.
3. Each section gets a tile and a colored trace. The colors match, so you can tell which trace
   belongs to which picture.
4. To compare shapes rather than brightness, set **Normalize** to `Min-max (0-1)` over
   `Each trace`. To keep brightness differences, use `All traces`.
5. If there are more sections than **Max tiles** (12), raise it or narrow the filter.

---

## Fix a badly drawn line

1. Select the section. If several are on screen, **click its tile** so it becomes the
   **(ROI target)**.
2. Press **Ctrl+E** (Edit ROI). The line turns gold and shows `ROI FROM FILE`.
3. Fix the line, in one of two ways:
   - **Drag** an end point or the line itself. It turns dashed orange-red and shows
     `UNSAVED EDITS`.
   - **Redraw it from scratch:** set **Width px** if needed, press **Ctrl+D** (Draw Line), and
     drag the new line out.
4. Press **Ctrl+S** (Save ROI). This rewrites the `.roi` and **remeasures** the profile from the
   full-resolution projection. The line turns green and shows `SAVED TO DISK`.
5. Changed your mind before saving? Press **Ctrl+Z** (Revert).

---

## Measure a second region on the same section

1. Select **exactly one** section and press **Ctrl+N** (Add ROI). A new key (`B`, then `C`, …)
   is created and editing starts on a new line for it.
2. Drag it into place, or draw it with **Ctrl+D**, then press **Ctrl+S**. The new sidecars are
   `<stem>_proj_B_roi.roi` and `<stem>_proj_B_values.csv`.
3. Click **Name ROIs...** and give the keys meaningful names, for example `A` = `ACx` and
   `B` = `S1`. The names apply to every section and are remembered. No files are renamed.
4. **Ctrl+Shift+N** moves between a section's ROIs.

---

## Align profiles to the brain surface

1. Select a section and press **Ctrl+E** to edit its ROI.
2. Press **Ctrl+B** (Detect). A tick labelled `surface (auto)` appears where the trace steps
   from background into tissue.
   - If it's slightly off, **drag** the tick along the line.
   - If Detect refuses (for example, the line lies entirely inside tissue), press
     **Ctrl+Shift+B** and click the surface on the image.
   - If the edge genuinely can't be seen, **Clear** it. An unmarked trace is visibly unaligned,
     but a wrong mark would silently shift it.
3. Press **Ctrl+S** to save. This writes `<roi>_surface.json` beside the `.roi`.
4. Repeat for the other sections. **Ctrl+Down** moves to the next one.
5. Select them all and set **Distance** to `From brain surface`. Every trace now has its own
   surface at 0. The plot says how many traces had no mark.

Detect also runs by itself whenever you **draw a new line**.

---

## Find sections that still need work

- **No profile yet:** set **Sort by** to `Status`. Rows showing `image only` have an image but no
  profile.
- **Not measured yet:** with a Sheets tracker, open **Columns...** and add **Meas**. It shows a
  tick for measured sections.
- **No atlas plate:** tiles show `plate n/a` when the tracker has no plate for a section.
- **Name doesn't parse:** `unparsed name` in Status. See
  [Use your own filename convention](#use-your-own-filename-convention).
- **Hide everything unmeasured:** tick **Only with profiles**.

---

## Connect the Google Sheet without credentials

1. In the Google Sheet, choose **File > Share > Publish to web**.
2. Choose **the tracker tab only** and **Comma-separated values (.csv)**, then click **Publish**.
3. Copy the link. In the browser, choose **Dataset > Published Sheet** and paste it. It is tested
   immediately.
4. Choose **Dataset > Load Dataset** (Ctrl+L).

Or from code:

```matlab
launch_histology_browser("D:/MyHistology/", publishedUrl = "https://docs.google.com/spreadsheets/d/e/2PACX-.../pub?gid=...&single=true&output=csv")
```

This route is **read-only**. To write back, see the next recipe. Read the privacy note on
[Section Tracker](Section-Tracker#option-b-published-sheet-read-only-no-credentials) before
publishing.

---

## Set atlas plates and mark sections measured

This needs the **Sheets API** tracker with a key that has **Editor** access. Setup is on
[Section Tracker](Section-Tracker#option-c-reading-and-writing-over-the-sheets-api).

1. Once per spreadsheet, choose **Dataset > Google Sheet Tracker > Prepare Sheet for Writing...**
   and confirm. This adds the `Row UID`, `Last Updated` and `Measured` columns.
2. Select the sections. A run from one slide can be selected together.
3. Type the plate number in **Atlas plate** and press **Enter** or **Set**.
4. Click **Mark Measured**, or press **Ctrl+M**. Pressing Ctrl+M again once everything selected is
   marked clears them.

The catalog updates in place, and the selection stays where it was.

---

## Use your own filename convention

1. Load your folder. Sections will show `unparsed name`.
2. Open **Dataset > Filename Pattern**.
3. Write a pattern. The preview table updates as you type, using your actual files. Either:
   - a **token list**: a delimiter plus field names, with `-` for fields to skip; or
   - a **regular expression** with named tokens, for example:
     ```
     ^(?<SubjectID>[^_]+)_(?<SectionID>[^_]+)_(?:[^_]+)_(?<Stain>[^_]+)$
     ```
4. Use the names `SubjectID`, `SampleID`, `SectionID`, `Hemisphere`, `Stain`, `ZPlane`,
   `DateCode`, `ImageNumber`, `Protocol`, `Series` for fields you want as catalog columns and
   filters.
5. Save and reload. The pattern is remembered. **Restore Default** returns to the built-in
   convention.

Don't include `_proj`, `_mid`, `_composite`, `_roi` or `_values` in the pattern. They are
stripped first.

---

## Make a figure of several sections

1. Select the sections and set the rendition, channel, colormap and contrast in **Display**.
2. Choose the overlays: **Ctrl+1** for the line, **Ctrl+2** for the band, **Ctrl+3** for
   shading, **Ctrl+4** for surface marks.
3. Decide where the profile plot goes (**Profiles**: `Below images`, `Right of images`, `Hidden`,
   …) and its **Size %**.
4. Get the figure out in one of two ways:
   - **Export View** (Ctrl+P) saves straight to an image file.
   - **Open in Figure** (Ctrl+O) redraws the view in a normal MATLAB figure. There you can
     adjust fonts and labels and use `exportgraphics`.

Press **Ctrl+H** to hide the side panels, which gives the tiles the whole window while you set up
the view.

---

## Get profiles into MATLAB and plot them yourself

1. Select the sections and choose **Dataset > Export Selection to Workspace...**
   (Ctrl+Shift+E). Keep the name `histology`.
2. You now have a table with **one row per ROI**. Each row's `Profile` holds a two-column table
   (`Distance`, `Intensity`), which is empty if the ROI was never measured.

```matlab
T = histology;
figure; hold on
for i = 1:height(T)
    P = T.Profile{i};
    if height(P) == 0, continue, end
    x = P.Distance;
    if isfinite(T.SurfaceOffset(i)) && T.RoiLength(i) > 0   % align to the surface mark, if any
        f = min(max(T.SurfaceOffset(i) / T.RoiLength(i), 0), 1);
        x = x - (x(1) + f * (x(end) - x(1)));
    end
    plot(x, P.Intensity, DisplayName = T.SubjectID(i) + " " + T.SectionID(i) + " " + T.ROIName(i))
end
xlabel("distance (" + T.PixelUnit(1) + ")"); ylabel("intensity"); legend(Interpreter = "none")
```

`SurfaceOffset` and `RoiLength` are both **in pixels**, measured along the line. `Distance` is
in `PixelUnit` (µm when the image is calibrated). The code above converts the mark to a fraction
of the line and places it on the profile's own distance axis. That is the same mapping the
browser uses for **Distance > From brain surface** (`readProfile.m`), so the two agree.

To keep the export for later: `save("histology_profiles.mat", "histology")`.

---

## Compare treatment groups in the ECM Browser

1. **Export** the sections (previous recipe) and join your group labels, for example a
   `Treatment` column matched on `SubjectID` and `Hemisphere` with `outerjoin`.
2. **Prepare and launch:**
   ```matlab
   A = ecm_prepare_analysis_data(histology, fileVar = "ImagePath", ...
           groupVars = ["SubjectID", "AtlasPlate", "Treatment"], smoothingWindow = 25);
   B = launch_ecm_browser(A);
   ```
3. **Plot the groups.** In **Plot**, set **Show** to `group mean` and **Color by** to
   `Treatment`. Choose an **Error band**.
4. **Split by plate.** In **Split**, select `AtlasPlate` under **Tile by**.
5. **Look at the difference directly.** Open **Compare** and set:
   - **Compare** to `difference`;
   - **Compare by** to `Treatment`;
   - **Reference** to `Vehicle`;
   - **Pair within** to `SubjectID` and `AtlasPlate`, so only matched sections are compared.
6. **Restrict the data** with **Filter**, for example keep `IncludeInAnalysis = TRUE`.
7. Read the **status line** for how many sections and comparisons went in. If sections are
   missing, check `A.diagnostics`.

---

## Save an ECM view so you can rebuild it later

- **Same session or later:** in **Configurations**, click **Save**. The view is stored under a
  descriptive name and survives restarts. Per-group colors aren't included.
- **In a script:** click **Copy code** in the toolbar and paste into your analysis script. It
  contains the `B.setFilter`, `B.setTiling` and `B.setComparison` calls, plus `B.refresh()`, that
  rebuild exactly this view. `S_ECManalysis.m` has examples.
- **In a methods section:** click **Copy summary** for a plain-language account of every setting.

---

## Run the R statistics

1. **Save** the joined table: `save("D:/Data/histology_full.mat", "histology")`.
2. **Export** the CSVs: `ecm_export_for_r("D:/Data/histology_full.mat", "D:/Data")`.
3. **Edit** `ECM_Analysis/ecm_analysis.R`:
   - set `DATA_DIR` to your folder;
   - check that the file names, treatment levels and the alignment/smoothing constants match
     your MATLAB settings.
4. **Install** the packages if needed:
   ```r
   install.packages(c("readr", "dplyr", "tidyr", "ggplot2", "scales", "lme4", "lmerTest", "emmeans"))
   ```
5. **Run it:** `source("ECM_Analysis/ecm_analysis.R")`. The report is written to
   `<DATA_DIR>/R_figures/ECM_GM6001_report.html`.

The script was written for the GM6001 project; see the caveats on
[ECM Analysis](ECM-Analysis#statistics-in-r).

---

## Pull acquisition settings from CZI files into Excel

```matlab
T = extract_czi_metadata("D:/Scans", UseParallel = true, OutputXlsx = "D:/Scans/czi_metadata.xlsx");
```

You get one row per file: pixel size, objective, laser power, detector gain, pinhole, Z range,
and so on. Use `FileNameRegex = "WFA"` to limit it to matching files. This needs Bio-Formats on
the path.

---

## Overlay an atlas plate on a section

```matlab
ia = InteractiveAffineOverlay("GerbilAtlas_Plate_30.tif", "section_composite.png", scale = 1);
```

1. **Rotate** with `,` and `.`, **scale** with `=` and `-`, and **move** with the arrow keys.
   Hold **Ctrl** for fine steps and **Shift** for coarse ones.
2. **Flip** with `h` or `v` if the section is mirrored.
3. When the outline fits, press `t` to save the transform, or `w` to save a screenshot.

**Help > Gerbil Atlas Explorer** in the browser opens the online atlas, for choosing which plate
to try.
