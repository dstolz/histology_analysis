# histology_analysis

MATLAB tools for histology image processing: interactive alignment and thresholding tools,
cortex straightening and profile extraction, crop labeling, the histology section browser,
and the ECM staining analysis app.

Extracted from [`helper_fnc`](https://github.com/dstolz/helper_fnc) so these functions can
be used without pulling in that repository's general-purpose utilities. A handful of
`helper_fnc` functions that several of the root-level tools still call directly
(`colorcet`, `use_fig`, `use_fig_tiledlayout`, `titlef`, `ylabelf`, `parfor_progress`) are
vendored in [tools/](tools/) so the repository works standalone.

**Documentation:** the [wiki](https://github.com/dstolz/histology_analysis/wiki) has a getting
started guide, a tour of the browser, recipes for common tasks, and troubleshooting. Its source
is in [docs/wiki/](docs/wiki/) and is published to the wiki by `.github/workflows/wiki.yml`.

## Quick start

```matlab
addpath_nogit('c:/src/histology_analysis')
```

That adds the whole repository, including `histology_browser/` and `ECM_Analysis/`. The
functions in the table below live at the repository root, so a plain `addpath` of the root
is enough for them alone.

## Histology browser

[histology_browser/](histology_browser/) is `HistologyImageBrowser`, a GUI that catalogs
histology section images, overlays the Fiji line ROI and its intensity profile on each one,
and edits the ROI, plus the ingest helpers behind it (`combine_values_csv`,
`build_histology_image_catalog`, the ImageJ `.roi` reader and writer) and the Fiji macro that
produces the measurements. See its [README](histology_browser/README.md).

It was a standalone repository, `dstolz/histology_browser`, until September 2026. Its history
came with it, so `git log -- histology_browser/` reaches back to its first commit.

## ECM Analysis app

[ECM_Analysis/](ECM_Analysis/) is a GUI (`@ECMBrowser`) plus scripts for comparing ECM
staining measurements across groups, tiling, and normalization schemes, with an R export
path (`ecm_export_for_r.m`, `ecm_analysis.R`).

**It depends on [histology_browser/](histology_browser/)** for `combine_values_csv`, which
`addpath_nogit` of the repository root already puts on the path.

## Functions

| File | Summary |
| --- | --- |
| [extract_czi_metadata.m](extract_czi_metadata.m) | Recursively extracts checklist-aligned metadata from `.czi` files into a table, with optional parallel processing and Excel export. |
| [extract_equal_area_profiles.m](extract_equal_area_profiles.m) | Samples image intensity across trapezoidal regions laid out along a curve and returns profile metrics. |
| [histologyLabeller.m](histologyLabeller.m) | Interactive montage browser for labeling image crops or paired image sets. |
| [InteractiveAffineOverlay.m](InteractiveAffineOverlay.m) | Keyboard-driven affine overlay tool for aligning a foreground image onto a background image. |
| [InteractiveRotator.m](InteractiveRotator.m) | Interactive image rotation helper used by other histology workflows. |
| [organize_images_by_section_gui.m](organize_images_by_section_gui.m) | GUI for reorganizing images by tissue section. |
| [parabola_offset.m](parabola_offset.m) | Computes offset curves and arc lengths for parabolic profile construction. |
| [parseBfTiff.m](parseBfTiff.m) | Reads OME-TIFF data through Bio-Formats and returns image channels plus metadata. |
| [runImageJMacro.m](runImageJMacro.m) | Runs a Fiji/ImageJ macro from MATLAB. |
| [straightenLine.m](straightenLine.m) | Straightens image content sampled along a user-defined line. |
| [straighten_cortex.m](straighten_cortex.m) | End-to-end cortex straightening and profile extraction pipeline for histology OME-TIFF images. |
| [straighten_cortex2.m](straighten_cortex2.m) | Alternative cortex-straightening implementation. |
| [ThresholdAdjuster.m](ThresholdAdjuster.m) | Interactive threshold tuning tool with boundary overlays. |
| [T_HistologyBrainSurface.m](T_HistologyBrainSurface.m) | Test or exploratory script related to histology brain-surface workflows. |
| [T_Overlay.m](T_Overlay.m) | Test or exploratory script for image overlay workflows. |
| [T_ShowSections.m](T_ShowSections.m) | Test or exploratory script for viewing section data. |

## Dependencies

- MATLAB with Image Processing Toolbox-style functionality.
- Bio-Formats (`parseBfTiff.m`, `ECM_Analysis/` scripts that read OME-TIFF data).
- [histology_browser/](histology_browser/) on the MATLAB path for `ECM_Analysis/`.
- R, for `ECM_Analysis/ecm_analysis.R`.
