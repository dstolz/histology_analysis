# Data Layout and File Formats

The browser doesn't need a database or an index file. It scans a **root folder** recursively and
builds its catalog from what it finds there. This page describes what it looks for.

## What goes in the root folder

For each acquisition, the browser recognizes:

| File | Written by | Role |
|---|---|---|
| `<stem>.czi` | microscope | Raw rendition. Displaying it needs Bio-Formats. |
| `<stem>_proj.tif` | your export | Projection. This is the default rendition and the one profiles are measured from. |
| `<stem>_mid.tif` | your export | Mid-plane rendition (optional). |
| `<stem>_composite.png` | your export | Composite rendition (optional). |
| `<stem>_proj_roi.roi` | browser | The line ROI, in ImageJ's binary `.roi` format. |
| `<stem>_proj_values.csv` | browser | The intensity profile measured along that line. |
| `<stem>_proj_roi_surface.json` | browser | Where the brain surface sits on that line (optional). |

Any of the three exported renditions can be `.tif`, `.tiff` or `.png`; the scan looks for all
three extensions.

A folder per subject, and optionally a folder per section inside it, is typical. Only the file
names matter, though; the folder structure doesn't. The synthetic dataset from
`make_test_dataset` shows a realistic layout:

```
<root>/
├── Trackers - Sections.csv
├── SUBJ-ID-1174/
│   ├── SUBJ-ID-1174IHC_ECM26A260608S1_1A_L_WFA-PV_Z3_260616_1/
│   │   ├── SUBJ-ID-1174IHC_ECM26A260608S1_1A_L_WFA-PV_Z3_260616_1_proj.tif
│   │   ├── SUBJ-ID-1174IHC_ECM26A260608S1_1A_L_WFA-PV_Z3_260616_1_mid.tif
│   │   ├── SUBJ-ID-1174IHC_ECM26A260608S1_1A_L_WFA-PV_Z3_260616_1_composite.png
│   │   ├── SUBJ-ID-1174IHC_ECM26A260608S1_1A_L_WFA-PV_Z3_260616_1_proj_roi.roi
│   │   └── SUBJ-ID-1174IHC_ECM26A260608S1_1A_L_WFA-PV_Z3_260616_1_proj_ACxvalues.csv
│   └── ...
└── SUBJ-ID-2087/
    └── ...
```

## Filename convention

The built-in convention is:

```
SUBJ-ID-<n><SampleID>_<Section>_<Hemi>_<Stain>_<Z>_<Date>_<ImageNumber>
```

For example, `SUBJ-ID-1174IHC_ECM26A260608S1_1A_L_WFA-PV_Z3_260616_1` parses as:

| Field | Value |
|---|---|
| SubjectID | `SUBJ-ID-1174` |
| SampleID | `IHC_ECM26A260608S1` |
| SectionID | `1A` |
| Hemisphere | `L` |
| Stain | `WFA-PV` |
| ZPlane | `Z3` |
| DateCode | `260616` |
| ImageNumber | `1` |

The name is parsed from the right, so `SampleID` may itself contain underscores.

**Names that don't match are still cataloged and browsable.** They show `unparsed name` in the
Status column, and the status bar counts them.

### Using a different naming scheme

Use **Dataset > Filename Pattern** in the browser. You can describe your scheme as either:

- **a regular expression with named tokens**, for example
  `^(?<SubjectID>[^_]+)_(?<SectionID>[^_]+)_(?:[^_]+)_(?<Stain>[^_]+)$`. An unnamed `(?:...)`
  group skips a field.
- **a token list**: a delimiter plus field names in order, with `-` for a field to ignore.

A live preview shows what your pattern extracts from the files in the loaded dataset. These
tokens become catalog columns: `SubjectID`, `SampleID`, `SectionID`, `Hemisphere`, `Stain`,
`ZPlane`, `DateCode`, `ImageNumber`, `Protocol`, `Series`. Other token names are parsed and
previewed, but not cataloged.

The `_proj`, `_mid`, `_composite`, `_roi` and `_values` suffixes are stripped before your pattern
runs, and you can't change them. Rendition discovery depends on them.

From a script:

```matlab
info = parse_histology_filename(name, pattern = "^(?<SubjectID>[^_]+)_...");
C = build_histology_image_catalog(root, filenamePattern = "^(?<SubjectID>[^_]+)_...");
```

## Several ROIs on one section

A section can carry more than one line, one per region measured. The two sidecars of a line are
tied together by a label in their filenames:

```
<stem>_proj_roi.roi        <stem>_proj_values.csv        first ROI  (key A)
<stem>_proj_B_roi.roi      <stem>_proj_B_values.csv      second ROI (key B)
<stem>_proj_C_roi.roi      <stem>_proj_C_values.csv      third ROI  (key C)
```

- The first ROI has **no label**. That keeps datasets measured before multi-ROI support readable
  unchanged.
- **Keys are letters.** To give them meaningful names (A = `ACx`, B = `S1`), use **Name ROIs...**
  in the browser. Names are stored as a MATLAB preference, so no file is renamed.
- **Mismatched names are paired automatically.** An unlabelled `.roi` that has no profile of its
  own is paired with a profile that has no `.roi` of its own. So `_proj_roi.roi` beside
  `_proj_ACxvalues.csv` reads as one ROI keyed `ACx`.

## `*values.csv`: the profile

```
distance_pixel_index,intensity
0.0000,112.4
...
```

This is one row per sample along the line. The first column is in **calibrated units** (µm) when
the image is calibrated, despite its name. The browser's `write_values_csv` writes this header.

## `*_roi_surface.json`: the brain surface mark

This file is written by the browser when you **Save ROI** with a surface mark on the line:

```json
{
  "version": 1,
  "surfaceOffsetPx": 143.2,
  "x1": 512.0, "y1": 88.0, "x2": 640.5, "y2": 1320.0,
  "source": "auto",
  "written": "2026-09-01 14:03:22"
}
```

- `surfaceOffsetPx` is the distance **in pixels from the line's start point** to the surface.
- `source` is `auto` (from **Detect**) or `manual` (placed or dragged by hand).
- The endpoints are the line the mark was placed against. They are there so a person can check
  why a mark looks wrong.
- Clearing a mark **deletes** the file rather than writing an empty one.

*(The numeric values above are placeholders showing the shape of the file.)*

## The section tracker

This is a spreadsheet with one row per section image. It is joined onto the catalog through its
`Image Filename` column. The columns the browser reads are listed on the
[Section Tracker](Section-Tracker#columns-the-browser-uses) page.
