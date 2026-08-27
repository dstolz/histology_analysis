function test_histology_browser(rootPath, options)
% test_histology_browser
%   test_histology_browser()
%   test_histology_browser(rootPath, metadataCSV = trackerPath)
%
% Smoke test for the histology browser and its helper functions. The filename
% parser and ROI decoder are checked against synthetic inputs, so they run
% anywhere. The catalog and GUI checks only run when a dataset folder is
% supplied and exists.
%
% Parameters
%   rootPath: Optional histology root folder to exercise the GUI against.
%   options.metadataCSV: Optional section tracker CSV.

arguments
    rootPath (1,1) string = ""
    options.metadataCSV (1,1) string = ""
end

% Add the repo root (this file lives in tests/, one level down) so the
% browser and its helpers resolve regardless of where it is checked out.
addpath(fileparts(fileparts(mfilename("fullpath"))));

nFailed = 0;

nFailed = nFailed + run_case("filename parser", @check_filename_parser);
nFailed = nFailed + run_case("ImageJ ROI decoder", @check_roi_decoder);
nFailed = nFailed + run_case("ImageJ ROI encoder", @check_roi_encoder);
nFailed = nFailed + run_case("line profile measurement", @check_profile_measurement);
nFailed = nFailed + run_case("missing metadata labels", @check_missing_metadata);

if rootPath == "" || ~isfolder(rootPath)
    fprintf("- Skipping catalog and GUI checks (no dataset folder supplied).\n");
else
    nFailed = nFailed + run_case("image catalog", @() check_catalog(rootPath, options.metadataCSV));
    nFailed = nFailed + run_case("browser GUI", @() check_gui(rootPath, options.metadataCSV));
end

if nFailed == 0
    fprintf("All checks passed.\n");
else
    fprintf(2, "%d check(s) failed.\n", nFailed);
end

end

function nFailed = run_case(name, fcn)
%RUN_CASE Run one check and report the outcome.

nFailed = 0;

try
    fcn();
    fprintf("PASS  %s\n", name);
catch ME
    nFailed = 1;
    fprintf(2, "FAIL  %s: %s\n", name, ME.message);
end

end

function check_filename_parser()
%CHECK_FILENAME_PARSER Verify every naming variant reduces to one stem.

base = "SUBJ-ID-1174IHC_ECM26A260608S1_1A_L_WFA-PV_Z3_260616_1";

cases = [ ...
    base + ".czi",                   "raw",       ""; ...
    base + "_proj.tif",              "proj",      ""; ...
    base + "_mid.tif",               "mid",       ""; ...
    base + "_composite.png",         "composite", ""; ...
    base + "_proj_roi.roi",          "proj",      ""; ...
    base + "_proj_values.csv",       "proj",      ""; ...
    base + "_proj_ACxvalues.csv",    "proj",      "ACx"; ...
    base + "_proj_ACx_values.csv",   "proj",      "ACx"];

for iCase = 1:size(cases, 1)
    info = parse_histology_filename(cases(iCase, 1));

    assert(info.isValid, "Failed to parse %s", cases(iCase, 1));
    assert(info.stem == base, "Wrong stem for %s: %s", cases(iCase, 1), info.stem);
    assert(info.variant == cases(iCase, 2), "Wrong variant for %s", cases(iCase, 1));
    assert(info.roi == cases(iCase, 3), "Wrong ROI label for %s", cases(iCase, 1));
end

assert(info.SubjectID == "SUBJ-ID-1174", "Wrong SubjectID");
assert(info.SectionID == "1A", "Wrong SectionID");
assert(info.Hemisphere == "L", "Wrong Hemisphere");
assert(info.Stain == "WFA-PV", "Wrong Stain");

% A name that does not follow the convention must report failure, not raise.
bad = parse_histology_filename("not_a_histology_name.tif");
assert(~bad.isValid, "Malformed name was accepted");

end

function check_missing_metadata()
%CHECK_MISSING_METADATA Verify absent plate or profile data is named, not hidden.

full = table("SUBJ-ID-1174", 12, 3, VariableNames = ["SubjectID", "AtlasPlate", "NProfiles"]);
assert(HistologyImageBrowser.missingMetadata(full) == "", ...
    "A fully annotated section was reported as missing metadata");

noPlate = full;
noPlate.AtlasPlate = NaN;
assert(HistologyImageBrowser.missingMetadata(noPlate) == "no atlas plate", ...
    "A missing atlas plate was not reported");

noProfile = full;
noProfile.NProfiles = 0;
assert(HistologyImageBrowser.missingMetadata(noProfile) == "no profile", ...
    "A missing profile was not reported");

neither = noPlate;
neither.NProfiles = 0;
assert(HistologyImageBrowser.missingMetadata(neither) == "no atlas plate, no profile", ...
    "Both missing annotations were not reported together");

end

function check_roi_decoder()
%CHECK_ROI_DECODER Decode a synthetic straight line ROI written to disk.

expected = struct("x1", 189, "y1", 1563, "x2", 1302, "y2", 2022, "width", 600);

roiPath = fullfile(tempdir, "test_line_roi.roi");
write_line_roi(roiPath, expected);
cleanup = onCleanup(@() delete(roiPath));

R = read_imagej_roi(string(roiPath));

assert(R.isValid, "ROI did not decode: %s", R.message);
assert(R.isLine, "ROI was not reported as a line");

% Coordinates come back 1-based, so each is one greater than what was written.
assert(R.x1 == expected.x1 + 1, "Wrong x1: %g", R.x1);
assert(R.y1 == expected.y1 + 1, "Wrong y1: %g", R.y1);
assert(R.x2 == expected.x2 + 1, "Wrong x2: %g", R.x2);
assert(R.y2 == expected.y2 + 1, "Wrong y2: %g", R.y2);
assert(R.strokeWidth == expected.width, "Wrong stroke width: %g", R.strokeWidth);

expectedLength = hypot(expected.x2 - expected.x1, expected.y2 - expected.y1);
assert(abs(R.length - expectedLength) < 1e-6, "Wrong line length: %g", R.length);

missing = read_imagej_roi(fullfile(tempdir, "does_not_exist.roi"));
assert(~missing.isValid, "A missing ROI file was reported as valid");

end

function check_roi_encoder()
%CHECK_ROI_ENCODER Write a line ROI and read the same numbers back out.
% The encoder is what lets a moved line go back to Fiji, so what matters is
% that the round trip is exact and that re-saving an existing ROI keeps the
% fields this toolbox does not manage.

roiPath = fullfile(tempdir, "test_written_roi.roi");
cleanup = onCleanup(@() delete(roiPath));

geometry = struct("x1", 190, "y1", 1564, "x2", 1303, "y2", 2023, "strokeWidth", 994);
write_imagej_roi(string(roiPath), geometry, name = "written_roi");

R = read_imagej_roi(string(roiPath));

assert(R.isValid, "Written ROI did not decode: %s", R.message);
assert(R.isLine, "Written ROI was not a line");
assert(R.x1 == geometry.x1 && R.y1 == geometry.y1, "Start point did not round trip");
assert(R.x2 == geometry.x2 && R.y2 == geometry.y2, "End point did not round trip");
assert(R.strokeWidth == geometry.strokeWidth, "Stroke width did not round trip");
assert(R.name == "written_roi", "ROI name did not round trip: %s", R.name);

% Re-saving with the first file as the template must keep its name while the
% geometry moves, which is what an edit in the browser does.
movedPath = fullfile(tempdir, "test_written_roi_moved.roi");
cleanupMoved = onCleanup(@() delete(movedPath));

moved = geometry;
moved.x2 = geometry.x2 - 100;
moved.strokeWidth = 600;
write_imagej_roi(string(movedPath), moved, template = string(roiPath));

M = read_imagej_roi(string(movedPath));

assert(M.x2 == moved.x2, "Template save did not move the end point");
assert(M.strokeWidth == 600, "Template save did not update the stroke width");
assert(M.name == "written_roi", "Template save did not keep the ROI name");

% Sub-pixel endpoints have to survive as written, since a dragged line is only
% snapped to whole pixels by the browser, not by the format.
fine = struct("x1", 10.5, "y1", 20.25, "x2", 300, "y2", 44, "strokeWidth", 17);
write_imagej_roi(string(movedPath), fine, name = "fine_roi");
F = read_imagej_roi(string(movedPath));

assert(abs(F.x1 - fine.x1) < 1e-4 && abs(F.y1 - fine.y1) < 1e-4, ...
    "Sub-pixel endpoints were not preserved");

end

function check_profile_measurement()
%CHECK_PROFILE_MEASUREMENT Measure a synthetic image with a known answer.
% A horizontal line over a vertical ramp averages to the value at its center
% whatever width it is given, so the band average can be checked exactly.

nRows = 201;
nCols = 301;
img = repmat((1:nRows)', 1, nCols);

roi = struct("x1", 51, "y1", 101, "x2", 251, "y2", 101, "strokeWidth", 41);
P = measure_line_profile(img, roi);

assert(P.hasData, "Nothing was measured: %s", P.message);
assert(P.nSamples == 201, "Expected one sample per pixel, got %d", P.nSamples);
assert(max(abs(P.intensity - 101)) < 1e-9, ...
    "A band centered on a ramp did not average to its middle: %g", max(abs(P.intensity - 101)));

% Uncalibrated pixel data has to report distance in pixels, one per sample.
assert(abs(P.distance(2) - 1) < 1e-9, "Distance was not one pixel per sample");

% A supplied pixel size scales the distance axis and nothing else.
scaled = measure_line_profile(img, roi, pixelSize = 1.6572864);
assert(abs(scaled.distance(2) - 1.6572864) < 1e-9, "Pixel size did not scale the distance axis");
assert(isequal(scaled.intensity, P.intensity), "Pixel size changed the intensities");

% A diagonal line over the same ramp rises linearly, which catches a band
% built off the wrong normal direction.
diagonal = struct("x1", 51, "y1", 51, "x2", 151, "y2", 151, "strokeWidth", 21);
D = measure_line_profile(img, diagonal);
expected = linspace(51, 151, D.nSamples)';

assert(max(abs(D.intensity - expected)) < 1e-6, ...
    "A diagonal band did not follow the ramp: %g", max(abs(D.intensity - expected)));

check_values_csv_round_trip(P);

end

function check_values_csv_round_trip(P)
%CHECK_VALUES_CSV_ROUND_TRIP The written CSV must read back as a values file.

csvPath = fullfile(tempdir, "test_values.csv");
cleanup = onCleanup(@() delete(csvPath));

write_values_csv(string(csvPath), P.distance, P.intensity);

T = readtable(csvPath);

assert(height(T) == P.nSamples, "Wrote %d rows for %d samples", height(T), P.nSamples);
assert(all(ismember(["distance_pixel_index", "intensity"], string(T.Properties.VariableNames))), ...
    "The CSV does not carry the column names the pipeline reads");
assert(max(abs(T.intensity - P.intensity)) < 1e-3, "Intensities lost too much precision");
assert(max(abs(T.distance_pixel_index - P.distance)) < 1e-3, "Distances lost too much precision");

end

function write_line_roi(roiPath, geometry)
%WRITE_LINE_ROI Write a minimal ImageJ straight line ROI file.

bytes = zeros(1, 128, "uint8");
bytes(1:4) = uint8('Iout');
bytes(5:6) = be_bytes_int16(228);       % version
bytes(7) = 3;                           % type: line

bytes(9:10) = be_bytes_int16(min(geometry.y1, geometry.y2));    % top
bytes(11:12) = be_bytes_int16(min(geometry.x1, geometry.x2));   % left
bytes(13:14) = be_bytes_int16(max(geometry.y1, geometry.y2));   % bottom
bytes(15:16) = be_bytes_int16(max(geometry.x1, geometry.x2));   % right

bytes(19:22) = be_bytes_single(geometry.x1);
bytes(23:26) = be_bytes_single(geometry.y1);
bytes(27:30) = be_bytes_single(geometry.x2);
bytes(31:34) = be_bytes_single(geometry.y2);
bytes(35:36) = be_bytes_int16(geometry.width);

fid = fopen(roiPath, "w");
assert(fid > 0, "Could not write the test ROI file");
closeFile = onCleanup(@() fclose(fid));
fwrite(fid, bytes, "uint8");

end

function b = be_bytes_int16(value)
%BE_BYTES_INT16 Big-endian bytes for a 16-bit integer.

b = fliplr(typecast(int16(value), "uint8"));

end

function b = be_bytes_single(value)
%BE_BYTES_SINGLE Big-endian bytes for a 32-bit float.

b = fliplr(typecast(single(value), "uint8"));

end

function check_catalog(rootPath, metadataCSV)
%CHECK_CATALOG Build the catalog and verify its basic invariants.

C = build_histology_image_catalog(rootPath);

assert(height(C) > 0, "Catalog is empty");
assert(all(C.Stem ~= ""), "Catalog contains a blank stem");
assert(numel(unique(C.Stem)) == height(C), "Catalog contains duplicate stems");

hasProfile = C.NProfiles > 0;

for iRow = find(hasProfile)'
    paths = C.ValuesPaths{iRow};
    assert(numel(paths) == C.NProfiles(iRow), ...
        "Profile count disagrees with the stored values paths");
    assert(all(isfile(paths)), "A recorded values path does not exist");
end

if metadataCSV ~= "" && isfile(metadataCSV)
    S = combine_values_csv(rootPath, metadataCSV = metadataCSV, continueOnError = true);
    Cm = build_histology_image_catalog(rootPath, metadataTable = S.metadata.table);

    assert(height(Cm) >= height(C), "Joining the tracker lost catalog rows");
    assert(any(Cm.InTracker), "No catalog row matched the tracker");
end

end

function check_gui(rootPath, metadataCSV)
%CHECK_GUI Launch the browser, exercise filtering, and render a selection.

app = HistologyImageBrowser(rootPath, metadataCSV = metadataCSV);
closeApp = onCleanup(@() close(app.Fig));

assert(height(app.Catalog) > 0, "Browser loaded an empty catalog");
assert(height(app.View) == height(app.Catalog), "Filters were active on load");
assert(~isempty(app.Selection), "Nothing was selected after loading");

check_dataset_menu(app, rootPath, metadataCSV);

% Filtering to a single subject must narrow the view.
subject = app.Catalog.SubjectID(find(app.Catalog.SubjectID ~= "", 1));
app.SubjectList.Value = cellstr(subject);
app.applyFilters();

assert(height(app.View) > 0, "Filtering by subject removed every row");
assert(all(app.View.SubjectID == subject), "Subject filter let other subjects through");

app.onResetFilters();
assert(height(app.View) == height(app.Catalog), "Reset did not restore every row");

% Selecting several rows must draw one tile per row, up to the tile cap.
app.ProfileOnlyCheck.Value = true;
app.applyFilters();

nWanted = min(4, height(app.View));
app.MaxTilesField.Value = nWanted;
app.CatalogTable.Selection = 1:nWanted;
app.onSelectionChanged();

assert(isvalid(app.ImageLayout), "No tiled layout was created");
assert(numel(app.ImageLayout.Children) == nWanted, ...
    "Expected %d tiles, found %d", nWanted, numel(app.ImageLayout.Children));

% The overlay must reach the image as a shaded patch.
assert(~isempty(findobj(app.ImageLayout, "Type", "patch")), ...
    "No intensity overlay was drawn");

% Profiles must come from the combiner output rather than a re-read.
rows = app.selectedRows();
P = app.readProfile(rows(1, :));
assert(P.hasData, "No profile data for a section that reports one");

check_unannotated_section_renders(app);
check_profile_layouts(app);
check_stain_colormap(app);
check_roi_editing(app);

end

function check_dataset_menu(app, rootPath, metadataCSV)
%CHECK_DATASET_MENU The Dataset menu carries the paths the load ran with.
% They are no longer shown in edit fields, so the menu labels and the window
% title are the only place the user can read them back.

assert(isvalid(app.DatasetMenu), "No Dataset menu was built");
assert(app.RootPath == rootPath, "The Dataset menu lost the root folder");
assert(contains(app.Fig.Name, rootPath), "The window title does not name the root folder");
assert(startsWith(app.RootFolderMenu.Text, "Root Folder:"), ...
    "The root folder item was not labelled: %s", app.RootFolderMenu.Text);

if metadataCSV == ""
    assert(app.ClearMetadataMenu.Enable == "off", ...
        "Clearing the tracker was offered with no tracker loaded");
    return
end

assert(app.MetadataPath == metadataCSV, "The Dataset menu lost the tracker CSV");
assert(app.ClearMetadataMenu.Enable == "on", "Clearing the loaded tracker was not offered");

end

function check_stain_colormap(app)
%CHECK_STAIN_COLORMAP The colormap chosen for a stain comes back with it.
% Which colormaps the dropdown offers does not matter here, only that a choice
% made while one stain is on screen is restored when that stain returns.

app.onResetFilters();

stains = unique(app.View.Stain(app.View.Stain ~= ""));

if isempty(stains)
    return
end

choices = string(app.ColormapDropDown.Items);
rows = find(app.View.Stain == stains(1));

% Pick a colormap for the stain, then move the dropdown without telling the
% browser, so only the remembered choice can put it back.
select_row(app, rows(1));
app.ColormapDropDown.Value = choices(1);
app.onColormapChanged();

app.ColormapDropDown.Value = choices(end);
select_row(app, rows(min(2, numel(rows))));

assert(string(app.ColormapDropDown.Value) == choices(1), ...
    "Stain %s came back in %s rather than %s", stains(1), ...
    string(app.ColormapDropDown.Value), choices(1));

if numel(stains) < 2
    return
end

% A second stain keeps its own choice rather than inheriting the first.
other = find(app.View.Stain == stains(2), 1);

select_row(app, other);
app.ColormapDropDown.Value = choices(end);
app.onColormapChanged();

select_row(app, rows(1));
assert(string(app.ColormapDropDown.Value) == choices(1), ...
    "Stain %s lost its colormap to stain %s", stains(1), stains(2));

% A selection spanning both stains belongs to neither, so a colormap chosen
% there must leave both remembered choices alone.
app.CatalogTable.Selection = sort([rows(1) other]);
app.onSelectionChanged();
app.ColormapDropDown.Value = choices(2);
app.onColormapChanged();

select_row(app, rows(1));
assert(string(app.ColormapDropDown.Value) == choices(1), ...
    "A mixed selection overwrote the colormap remembered for %s", stains(1));

end

function select_row(app, viewRow)
%SELECT_ROW Select one row of the current view and let the browser react.

app.CatalogTable.Selection = viewRow;
app.onSelectionChanged();

end

function check_roi_editing(app)
%CHECK_ROI_EDITING Move a line ROI and confirm the preview follows it.
% Nothing is saved: this runs against the real dataset, so it stops short of
% the write and reverts to the ROI on disk before leaving.

app.onResetFilters();

editable = find(app.View.RoiPath ~= "" & isfile(app.View.RoiPath), 1);

if isempty(editable)
    return
end

app.MaxTilesField.Value = 1;
app.CatalogTable.Selection = editable;
app.onSelectionChanged();

app.EditRoiButton.Value = true;
app.onToggleEditRoi();
leaveEdit = onCleanup(@() app.exitRoiEdit(false));

assert(app.RoiEditStem == app.View.Stem(editable), "Editing did not start on the selected section");
assert(~isempty(app.RoiEditor) && isvalid(app.RoiEditor), "No draggable line was attached");
assert(~app.RoiEditDirty, "An untouched ROI was reported as changed");

% The band width has to be legible on the image, not only in the panel.
assert(~isempty(findobj(app.ImagePanel, Type = "text", Tag = "roiOverlay")), ...
    "The sampling band width was not labelled on the tile");

before = app.RoiEditGeom;
app.onRoiEditChanged([before.x1, before.y1 + 25; before.x2 - 50, before.y2], true);

assert(app.RoiEditDirty, "Moving the line did not mark the edit unsaved");
assert(app.RoiEditGeom.y1 == before.y1 + 25, "The moved position was not taken");
assert(app.RoiPreview.hasData, "The moved line was not remeasured");

% What the profile panel plots must be the remeasurement, not the stale file.
P = app.readProfile(app.editedRow());
assert(P.hasData && numel(P.intensity) == app.RoiPreview.nSamples, ...
    "The plotted profile did not follow the moved line");
assert(contains(P.source, "unsaved"), "The plotted profile was not marked unsaved: %s", P.source);

app.onRevertRoiEdits();

assert(app.RoiEditGeom.y1 == before.y1, "Revert did not restore the ROI on disk");
assert(~app.RoiEditDirty, "Revert left the edit marked unsaved");

end

function check_profile_layouts(app)
%CHECK_PROFILE_LAYOUTS Every profile placement must rearrange the view grid.

app.onResetFilters();
app.ProfileOnlyCheck.Value = true;
app.applyFilters();

if height(app.View) == 0
    return
end

app.MaxTilesField.Value = 1;
app.CatalogTable.Selection = 1;
app.onSelectionChanged();

originalLayout = app.ProfileLayoutDropDown.Value;
restore = onCleanup(@() set_layout(app, originalLayout));

% Side placements split the view by column, stacked ones by row.
set_layout(app, "right");
assert(numel(app.ViewGrid.ColumnWidth) == 2, "Right layout did not split by column");
assert(app.ProfilePanel.Layout.Column == 2, "Profiles did not move to the right");
assert(app.ImagePanel.Layout.Column == 1, "Images did not stay on the left");

set_layout(app, "left");
assert(app.ProfilePanel.Layout.Column == 1, "Profiles did not move to the left");
assert(app.ImagePanel.Layout.Column == 2, "Images did not move to the right");

set_layout(app, "top");
assert(numel(app.ViewGrid.RowHeight) == 2, "Top layout did not split by row");
assert(app.ProfilePanel.Layout.Row == 1, "Profiles did not move above the images");
assert(app.ImagePanel.Layout.Row == 2, "Images did not move below the profiles");

% The size control only splits a view that shows both panels.
set_layout(app, "hidden");
assert(app.ProfilePanel.Visible == "off", "Profiles stayed visible when hidden");
assert(app.ImagePanel.Visible == "on", "Images were hidden along with the profiles");
assert(app.ProfileSizeField.Enable == "off", "Size stayed enabled with one panel");

set_layout(app, "only");
assert(app.ImagePanel.Visible == "off", "Images stayed visible in profiles-only");
assert(app.ProfilePanel.Visible == "on", "Profiles were hidden in profiles-only");
assert(isempty(app.ImageLayout) || ~isvalid(app.ImageLayout), ...
    "Tiles were drawn even though the image panel is hidden");

% Coming back must redraw the tiles that profiles-only skipped.
set_layout(app, "bottom");
assert(isvalid(app.ImageLayout), "Tiles were not redrawn when the images came back");
assert(app.ProfileSizeField.Enable == "on", "Size stayed disabled with a split view");

% Size changes the split without disturbing which cell each panel is in.
app.ProfileSizeField.Value = 60;
app.onLayoutOptionChanged();
assert(app.ProfilePanel.Layout.Row == 2, "Resizing moved the profile panel");
assert(numel(app.ViewGrid.RowHeight) == 2, "Resizing collapsed the split");

end

function set_layout(app, code)
%SET_LAYOUT Choose a profile layout the way the dropdown callback would.

app.ProfileLayoutDropDown.Value = code;
app.onLayoutOptionChanged();

end

function check_unannotated_section_renders(app)
%CHECK_UNANNOTATED_SECTION_RENDERS A section without a plate or profile must
% still be drawn, with the gap stated rather than the tile left out.

app.onResetFilters();

bare = find(isnan(app.View.AtlasPlate) | app.View.NProfiles == 0, 1);

if isempty(bare)
    return
end

app.MaxTilesField.Value = 1;
app.CatalogTable.Selection = bare;
app.onSelectionChanged();

assert(isvalid(app.ImageLayout), "No tile was drawn for an unannotated section");
assert(numel(app.ImageLayout.Children) == 1, ...
    "An unannotated section was not drawn as a tile");

notes = findobj(app.ImageLayout, "Type", "text");
noteText = "";

for iNote = 1:numel(notes)
    noteText = noteText + " " + join(string(notes(iNote).String), " ");
end

assert(contains(noteText, "no atlas plate") || contains(noteText, "no profile"), ...
    "The missing metadata was not labelled on the tile");
assert(contains(string(app.StatusLabel.Text), "issing"), ...
    "The status line did not mention the missing metadata: %s", app.StatusLabel.Text);

end
