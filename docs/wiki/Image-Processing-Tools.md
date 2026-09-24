# Image Processing Tools

These are standalone functions and interactive helpers at the repository root. They predate the
browser and are independent of it.

> **Missing helpers.** Several of these call functions that are **not in this repository**:
> `use_fig`, `use_fig_tiledlayout`, `titlef`, `ylabelf`, `colorcet`, and `parfor_progress`. The
> first four come from [`helper_fnc`](https://github.com/dstolz/helper_fnc). `colorcet` and
> `parfor_progress` are MATLAB File Exchange functions. If you get
> `Undefined function 'colorcet'` or similar, add those to your path. The table marks which tools
> need them.

| Tool | Kind | Needs | Summary |
|---|---|---|---|
| [`extract_czi_metadata`](#extract_czi_metadata) | function | Bio-Formats | CZI acquisition metadata into a table / Excel |
| [`InteractiveAffineOverlay`](#interactiveaffineoverlay) | interactive class | IPT, R2022b+ | Align an image (e.g. an atlas plate) over a section with the keyboard |
| [`InteractiveRotator`](#interactiverotator) | interactive class | IPT, `colorcet` | Rotate and flip an image until it's upright |
| [`ThresholdAdjuster`](#thresholdadjuster) | interactive class | IPT, `colorcet` | Tune a threshold while watching the boundaries it produces |
| [`histologyLabeller`](#histologylabeller) | interactive class | IPT, `use_fig`, `colorcet`, `parfor_progress` | Label image crops page by page in a montage |
| [`organize_images_by_section_gui`](#organize_images_by_section_gui) | GUI | — | Move each `X.czi` into its own `X/` folder |
| [`straightenLine`](#straightenline) | function | Parallel Computing Toolbox, `parfor_progress` | Resample an image along a polyline into a straight strip |
| [`extract_equal_area_profiles`](#extract_equal_area_profiles) | function | IPT | Metrics inside equal-width trapezoids along a curve |
| [`parabola_offset`](#parabola_offset) | function | Curve Fitting Toolbox | Offset curves parallel to a fitted polynomial |
| [`straighten_cortex`, `straighten_cortex2`](#straighten_cortex-and-straighten_cortex2) | pipelines | many; see below | Older interactive cortex straightening pipelines |
| [`parseBfTiff`](#parsebftiff) | function | Bio-Formats | Read an OME-TIFF's planes and metadata |
| `addpath_nogit` | function | — | Add a folder tree to the path, skipping `.git` |

IPT = Image Processing Toolbox.

---

## extract_czi_metadata

This reads acquisition settings from every `.czi` under a folder, or from one file, into a table
with one row per file. The fields include:

- pixel size;
- objective and NA;
- laser wavelength and power;
- detector gain, offset and voltage;
- pinhole, averaging, and Z range;
- an `Error` column.

```matlab
T = extract_czi_metadata("D:/Scans");                                  % whole tree
T = extract_czi_metadata("D:/Scans", FileNameRegex = "WFA", ...
        UseParallel = true, OutputXlsx = "D:/Scans/wfa_metadata.xlsx");
```

| Option | Default |
|---|---|
| `Verbose` | `true` |
| `FileNameRegex` | `""` (case-insensitive; ignored for a single file) |
| `UseParallel` | `false` (falls back to serial if no pool starts) |
| `OutputXlsx` | `""` (must end in `.xlsx`; the folder must exist) |

Values that have one entry per channel are **de-duplicated**. Two channels with the same gain
show one value, so don't read those columns as channel-aligned.

## InteractiveAffineOverlay

This overlays a foreground image, typically an atlas outline, on a background section. You then
translate, rotate, scale and flip it with the keyboard. Pure-black foreground pixels, or the
foreground's alpha channel, are transparent.

```matlab
ia = InteractiveAffineOverlay("GerbilAtlas_Plate_30.tif", "section.png", scale = 1, thetaDeg = 90);
```

| Key | Action | Ctrl (fine) | Shift (coarse) |
|---|---|---|---|
| Arrow keys | Move 50 px | 10 px | ×5 |
| `,` / `.` | Rotate −/+ 5° | 1° | ×2 |
| `=` or numpad `+` / `-` | Scale ×/÷ 1.2 | 1.025 | step^1.5 |
| `h` / `v` | Flip horizontal / vertical | | |
| `[` / `]` | Lower/raise the upper color limit by 10 | 2 | ×2 |
| `i` | Toggle the position readout | | |
| `m` | Pick a colormap | | |
| `r` | Reset (the view updates on the next key press) | | |
| `t` | Save the transform (`tx, ty, scale, thetaDeg, flipH, flipV`) to a `.mat` | | |
| `w` | Save a screenshot | | |
| `o` | Save the object to a `.mat` | | |
| `?` | Print this list | | |

Other options: `transBaseStep`, `rotBaseStep`, `scaleBaseStep`, `clim` (default `[0 100]`),
`bgColormap` (default `'bone'`), `ax` (draw into existing axes), `showInfo`.

## InteractiveRotator

```matlab
rot = InteractiveRotator(img);
rot.start();                 % blocks until Enter
out = rot.accept();          % rotated/flipped image; also rot.Angle, rot.Flipped
```

| Key | Action |
|---|---|
| ← / → | Rotate −/+ 1° (Shift 5°, Ctrl 0.1°) |
| ↑ / ↓ | Rotate ±90° |
| `h` / `v` | Flip |
| `r` | Reset |
| Enter | Accept |

Press Enter to finish. Closing the window instead makes `accept()` fail.

## ThresholdAdjuster

This shows an image with the boundaries of `image > threshold` drawn on it. You adjust the
threshold with the arrow keys. The constructor **blocks until you press Enter**.

```matlab
adj = ThresholdAdjuster(img);          % starts at Otsu's threshold
t   = adj.ThresholdOriginal;           % in the image's own units
tn  = adj.Threshold;                   % normalized 0–1
```

| Key | Action |
|---|---|
| ↑ or → | +0.01 |
| ↓ or ← | −0.01 |
| Shift + arrow | step 0.1 |
| Ctrl + arrow | step 0.001 |
| Enter | Finish |

## histologyLabeller

This cuts crops around a list of points, or takes a stack of crops, and pages through them in a
montage so you can assign each one an integer label.

```matlab
L = histologyLabeller(img, XY, ImgB = img2, nUp = 36, halfWidth = 15, halfHeight = 15);
L.showMontage();
% ... label ...
labels = L.subimageLabel;              % one per crop; 0 = unlabelled
```

| Input | Action |
|---|---|
| `0`–`9` | Choose the active label |
| Left-click a tile | Assign the active label |
| Right-click a tile | Assign 0 |
| Enter / Shift+Enter | Next / previous page |
| `q` / `w` | Show image A / image B |
| `=` / `-` | More / less contrast saturation |
| Ctrl + `=` / `-` | Gamma ± 0.05 |
| `g` `m` `n` `z` `d` | Toggle filters: Gaussian, median, non-local means, Wiener, difference-of-Gaussians |
| `c` | Toggle the center marker |
| `t` | Print a count per label |
| `r` | Reset contrast, gamma and filters |
| `?` | Print this list |

**Caution.** With the default `ignoreOutOfBounds = true` in `computesubImages`, crops that fall
off the image edge are **dropped**. After that, `subimageLabel(i)` no longer corresponds to
`XY(i,:)`. Keep points away from the edge, or check the crop count against `size(XY,1)`.

## organize_images_by_section_gui

```matlab
organize_images_by_section_gui("D:/Scans")
```

This lists the subfolders with their `.czi` counts. Select rows and click **Process**: each
`X.czi` is **moved** into a new subfolder `X/`. A file whose destination already exists is
skipped.

## straightenLine

```matlab
S = straightenLine(I, x, y, width = 30, align = "top");   % S is width × numel(x) × channels
```

At each point of the polyline `(x, y)` (row vectors), this samples `width` pixels along the
perpendicular. `align` sets where the polyline sits in the output strip: `"center"` (the
default), `"top"` (the polyline is the top edge), or `"bottom"` (the polyline is the bottom
edge). It starts a parallel pool.

## extract_equal_area_profiles

```matlab
[M, d] = extract_equal_area_profiles(I, x, y, height = 5, segmentSpacing = 20, ...
                                     metrics = {'mean'}, visualize = true);
```

This resamples the curve `(x, y)` every `segmentSpacing` pixels. Between each pair of consecutive
points it builds a trapezoid of the given `height` and applies each metric to the pixels inside.
`approach` places the trapezoid centered on the curve (`"middle"`) or to one side.

Pass `metrics` as `{'mean'}`, not `{{'mean'}}` as the function's own help example shows.

## parabola_offset

```matlab
f = fit(x(:), y(:), "poly2");
[xo, yo, L] = parabola_offset(f, [min(x) max(x)], 0:-100:-500);
```

This returns curves offset from the fit by each distance in the third argument, each resampled to
`n` points (default 200) evenly spaced in arc length, plus their arc lengths.

## straighten_cortex and straighten_cortex2

These are older end-to-end pipelines for one OME-TIFF:

1. rotate interactively (`InteractiveRotator`);
2. threshold interactively (`ThresholdAdjuster`);
3. click a reference point on the surface;
4. fit the cortical surface with a polynomial;
5. extract profiles at fixed depths (`straighten_cortex`) or straighten the whole band
   (`straighten_cortex2`, output `M.data` is depth × position × channel).

```matlab
M = straighten_cortex2("section.ome.tiff", surfaceWindow = [-2000 4000], ...
                       profileWidth = 1000, polyOrder = 4);
```

Options are **name-value arguments**. The help text shows a struct being passed, which doesn't
work. These pipelines need:

- Bio-Formats;
- the Image Processing, Curve Fitting and Parallel Computing toolboxes;
- `use_fig`, `colorcet` and `parfor_progress`.

For new work, the [Histology Browser](Histology-Browser) plus [ECM Analysis](ECM-Analysis) path
is the maintained one. See [Troubleshooting and FAQ](Troubleshooting-and-FAQ#known-issues-in-the-older-tools)
for known issues.

## parseBfTiff

```matlab
[img, info, xy_res, nChannels] = parseBfTiff("sample.ome.tiff");
```

Note the output order: `xy_res` is **third** and `nChannels` fourth. The function's help text
lists them the other way round. Every plane (Z × C × T) is counted as a channel.
