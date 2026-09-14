function test_histology_browser(rootPath, options)
% test_histology_browser
%   test_histology_browser()
%   test_histology_browser(rootPath, metadataCSV = trackerPath)
%
% Smoke test for the histology browser and its helper functions. The filename
% parser and ROI decoder are checked against synthetic inputs, so they run
% anywhere. The catalog and GUI checks run against the dataset folder supplied
% or, when none is, against one MAKE_TEST_DATASET writes to a temp folder and
% this deletes on the way out, so they run anywhere too.
%
% Driving the browser reads and writes its saved preferences, so the run
% snapshots the whole preference group and puts it back on the way out. That
% cannot protect a run from another MATLAB writing the same preference file at
% the same time, and PREFDIR is fixed at startup: give concurrent runs a
% preference directory of their own by launching them with MATLAB_PREFDIR set.
%
% Parameters
%   rootPath: Optional histology root folder to exercise the GUI against.
%       A synthetic dataset is generated for the run when it is omitted.
%   options.metadataCSV: Optional section tracker CSV.

arguments
    rootPath (1,1) string = ""
    options.metadataCSV (1,1) string = ""
end

% Add the repo root (this file lives in tests/, one level down) so the
% browser and its helpers resolve regardless of where it is checked out, and
% this folder so the dataset generator beside this file resolves with them.
addpath(fileparts(fileparts(mfilename("fullpath"))));
addpath(fileparts(mfilename("fullpath")));

nFailed = 0;

nFailed = nFailed + run_case("filename parser", @check_filename_parser);
nFailed = nFailed + run_case("ImageJ ROI decoder", @check_roi_decoder);
nFailed = nFailed + run_case("ImageJ ROI encoder", @check_roi_encoder);
nFailed = nFailed + run_case("line profile measurement", @check_profile_measurement);
nFailed = nFailed + run_case("profile normalization", @check_profile_normalization);
nFailed = nFailed + run_case("missing metadata labels", @check_missing_metadata);
nFailed = nFailed + run_case("published sheet URLs", @check_published_url);
nFailed = nFailed + run_case("published sheet settings", @check_published_settings);

% With nothing to point at, the catalog and GUI checks run against a dataset
% generated for this run rather than being skipped, so the browser is covered
% on any machine instead of only on the one holding the real data.
if rootPath == ""
    [rootPath, options.metadataCSV] = make_test_dataset(string(tempname));
    dropDataset = onCleanup(@() rmdir(rootPath, "s"));

    fprintf("- Generated a synthetic dataset in %s\n", rootPath);
end

if ~isfolder(rootPath)
    fprintf("- Skipping catalog and GUI checks (%s is not a folder).\n", rootPath);
else
    % The browser saves its preferences whenever it loads, redraws, or closes,
    % so without this a test run would leave the user's own root folder,
    % colormaps, and ROI band width set to whatever these checks needed.
    restorePreferences = preserve_preferences(); %#ok<NASGU>  Restores on the way out.

    nFailed = nFailed + run_case("image catalog", @() check_catalog(rootPath, options.metadataCSV));
    nFailed = nFailed + run_case("browser GUI", @() check_gui(rootPath, options.metadataCSV));
    nFailed = nFailed + run_case("export to workspace", ...
        @() check_workspace_export(rootPath, options.metadataCSV));
    nFailed = nFailed + run_case("ROI edit grid", ...
        @() check_roi_edit_grid(rootPath, options.metadataCSV));
    nFailed = nFailed + run_case("custom filename pattern", ...
        @() check_filename_pattern(rootPath));
    nFailed = nFailed + run_case("incremental overlay redraw", ...
        @() check_incremental_redraw(rootPath, options.metadataCSV));
    nFailed = nFailed + run_case("plot context menus", ...
        @() check_plot_context_menus(rootPath, options.metadataCSV));
    nFailed = nFailed + run_case("sections table sorting and columns", ...
        @() check_catalog_table(rootPath, options.metadataCSV));
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

function restorer = preserve_preferences()
%PRESERVE_PREFERENCES Put the browser's saved preferences back after the run.
% Returns the cleanup object that does it, so the group is restored however the
% checks end, including when one of them throws.

group = char(HistologyImageBrowser.PrefGroup);
saved = struct();

if ispref(group)
    saved = getpref(group);
end

restorer = onCleanup(@() restore_preferences(group, saved));

end

function restore_preferences(group, saved)
%RESTORE_PREFERENCES Put the snapshot back and drop anything the run invented.
% The saved values are written before anything is removed, so a failure partway
% through leaves the group holding too much rather than holding nothing: the
% user's settings are worth more than a tidy group.

names = fieldnames(saved);

if isempty(names)
    % Nothing was there to begin with, so there is nothing to lose by
    % removing the group the run created.
    if ispref(group)
        rmpref(group);
    end

    return
end

setpref(group, names, struct2cell(saved));

invented = setdiff(fieldnames(getpref(group)), names);

if ~isempty(invented)
    rmpref(group, invented);
end

end

function check_published_url()
%CHECK_PUBLISHED_URL A published link is recognized, and an edit link is not.
% The download itself needs a network and a published sheet, so what is checked
% here is everything around it: which URLs are accepted, how they are rewritten,
% and that a reply which is not CSV is caught rather than handed to READTABLE
% to fail somewhere baffling. A file:// URL stands in for the server, which
% WEBREAD reads exactly as it reads an http one.

published = "https://docs.google.com/spreadsheets/d/e/2PACX-abc/pub" + ...
    "?gid=1084786865&single=true&output=csv";

% The single most likely thing to be pasted is the ordinary edit URL. It names
% the right document and will never work, so it has to be named for what it is.
assert_fails(@() fetch_published_tracker( ...
    "https://docs.google.com/spreadsheets/d/1yz6v2yP/edit?gid=108#gid=108"), ...
    "fetch_published_tracker:NotPublished", "An edit URL was accepted");

assert_fails(@() fetch_published_tracker(""), ...
    "fetch_published_tracker:NoUrl", "An empty URL was accepted");

% Whatever format the Publish to web dialog was left on, the tab is asked for
% as CSV: someone who took the default gets a link serving a web page, and it
% names the right document and tab, so it is rewritten rather than refused.
asked = strings(0, 1);
record = @(url, ~) collect(url);

for candidate = [ ...
        "https://docs.google.com/spreadsheets/d/e/2PACX-abc/pubhtml?gid=108&single=true"; ...
        "https://docs.google.com/spreadsheets/d/e/2PACX-abc/pub?gid=108&single=true&output=html"; ...
        "https://docs.google.com/spreadsheets/d/e/2PACX-abc/pub?gid=108&single=true&output=csv"]'

    downloaded = fetch_published_tracker(candidate, fetch = @(u, t) fake_reply(u, t, record));
    delete(downloaded);
end

assert(all(contains(asked, "output=csv")), ...
    "A link was fetched in a format other than CSV: %s", strjoin(asked, " "));
assert(~any(contains(asked, "pubhtml")), "A web page link was fetched as-is");
assert(~any(contains(asked, "output=html")), "A link kept its non-CSV format");
assert(all(contains(asked, "gid=108")), "Rewriting the link lost which tab it names");

% An anchor is for the browser and means nothing to the server, and the publish
% dialog's link can carry one.
downloaded = fetch_published_tracker(published + "#gid=1084786865", ...
    fetch = @(u, t) fake_reply(u, t, record));
delete(downloaded);
assert(~any(contains(asked, "#")), "An anchor was sent to the server");

% A tab that is no longer published still answers, with a web page saying so.
% Handing that to READTABLE would fail a long way from the cause.
assert_fails(@() fetch_published_tracker(published, ...
    fetch = @(~,~) "<!DOCTYPE html><html><body>Sorry, unable to open the file.</body></html>"), ...
    "fetch_published_tracker:NotCsv", "A web page was accepted as the tracker");

assert_fails(@() fetch_published_tracker(published, fetch = @(~,~) "   "), ...
    "fetch_published_tracker:EmptySheet", "An empty reply was accepted");

% A refused download is reported as one rather than escaping as whatever
% WEBREAD happened to raise.
assert_fails(@() fetch_published_tracker(published, ...
    fetch = @(~,~) error("MATLAB:webservices:HTTP404StatusCodeError", "Not Found")), ...
    "fetch_published_tracker:DownloadFailed", "A failed download was not reported");

% The real thing. A published tab keeps the rows above its header, exactly as
% the exported CSV did, so the header search COMBINE_VALUES_CSV already does
% finds it in the same way.
downloaded = fetch_published_tracker(published, fetch = @(~,~) sample_sheet());
removeDownload = onCleanup(@() delete(downloaded));

assert(isfile(downloaded), "Nothing was written to disk");

lines = readlines(downloaded);
headerLine = find(contains(lines, "Image Filename"), 1, "first");
assert(headerLine == 3, "The header landed on line %d rather than 3", headerLine);

T = readtable(downloaded, detectImportOptions(downloaded, ...
    NumHeaderLines = headerLine - 1, VariableNamingRule = "preserve"));

assert(height(T) == 2, "The downloaded CSV has %d rows rather than 2", height(T));
assert(string(T.("Atlas Plate #")(1)) == "42", "A column did not survive the download");

% The Notes column is full of commas, and a quoted field holding one has to
% stay a single field.
assert(string(T.Notes(1)) == "994 um band, left ACx", ...
    "A quoted field was split on its comma: '%s'", string(T.Notes(1)));

% Notes also carry micrometre and degree signs, which would be mangled if the
% download were written out in the machine's own locale rather than as UTF-8.
assert(isequal(double(char(string(T.Notes(2)))), [181 109 32 97 116 32 51 48 176]), ...
    "Non-ASCII characters did not survive being written to disk");

    function collect(url)
        %COLLECT Remember which URL the download was asked for.

        asked(end+1) = string(url);
    end

end

function text = fake_reply(url, timeout, record)
%FAKE_REPLY Stand in for the server, noting what was asked for.

assert(timeout > 0, "The download was given no time to complete");

record(url);
text = sample_sheet();

end

function text = sample_sheet()
%SAMPLE_SHEET A published Sections tab, shaped like the real one.
% Two rows above the header, a quoted field holding commas, and the non-ASCII
% characters that turn up in tracker notes.

text = join([ ...
    "Section tracker,,"; ...
    ",,"; ...
    "Image Filename,Notes,Atlas Plate #"; ...
    "SUBJ-ID-1174IHC_ECM26A260608S1_1A_L_WFA-PV_Z3_260616_1," + ...
        """994 um band, left ACx"",42"; ...
    "SUBJ-ID-1174IHC_ECM26A260608S1_1B_R_WFA-PV_Z3_260616_1," + ...
        string(char(181)) + "m at 30" + string(char(176)) + ",43"], newline);

end

function assert_fails(fcn, identifier, message)
%ASSERT_FAILS Check that a call fails, and fails for the stated reason.

try
    fcn();
catch ME
    assert(ME.identifier == string(identifier), ...
        "%s (failed with %s rather than %s)", message, ME.identifier, identifier);
    return
end

error("%s (the call succeeded)", message);

end

function check_published_settings()
%CHECK_PUBLISHED_SETTINGS The menu says whether a published sheet is set.

saved = snapshot_published_pref();
restorePref = onCleanup(@() restore_published_pref(saved));

app = HistologyImageBrowser();
cleanup = onCleanup(@() delete(app.Fig));

app.PublishedUrl = "";
app.refreshDatasetMenu();

assert(contains(app.PublishedSheetMenu.Text, "(none)"), ...
    "The menu did not start out empty: %s", app.PublishedSheetMenu.Text);
assert(app.ClearPublishedSheetMenu.Enable == "off", ...
    "Clearing was offered with no sheet set");

app.PublishedUrl = "https://docs.google.com/spreadsheets/d/e/2PACX-abc/pub" + ...
    "?gid=1084786865&single=true&output=csv";
app.refreshDatasetMenu();

% A published URL is a hundred unreadable characters, so the menu names the one
% part that tells two published tabs apart rather than all of it.
assert(contains(app.PublishedSheetMenu.Text, "1084786865"), ...
    "The menu does not name the tab: %s", app.PublishedSheetMenu.Text);
assert(strlength(app.PublishedSheetMenu.Text) < 60, ...
    "The menu label is too wide to sit on a menu: %s", app.PublishedSheetMenu.Text);
assert(app.ClearPublishedSheetMenu.Enable == "on", ...
    "Clearing a set sheet was not offered");

app.onClearPublishedSheet();
assert(app.PublishedUrl == "", "Clearing left the sheet set");
assert(contains(app.PublishedSheetMenu.Text, "(none)"), "The menu still names a sheet");

end

function saved = snapshot_published_pref()
%SNAPSHOT_PUBLISHED_PREF Record the published sheet preference as it stands.
% Closing the browser saves preferences, so a check that sets one would
% otherwise leave its scratch value behind as the real configuration.

group = char(HistologyImageBrowser.PrefGroup);

saved = struct(group = group, existed = ispref(group, "PublishedUrl"), value = "");

if saved.existed
    saved.value = getpref(group, "PublishedUrl");
end

end

function restore_published_pref(saved)
%RESTORE_PUBLISHED_PREF Put the published sheet preference back as it was.

if saved.existed
    setpref(saved.group, "PublishedUrl", saved.value);
elseif ispref(saved.group, "PublishedUrl")
    rmpref(saved.group, "PublishedUrl");
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

function check_profile_normalization()
%CHECK_PROFILE_NORMALIZATION The rescalings NORMALIZEPROFILES offers.
% Static, so the arithmetic is checked on any machine whether or not the GUI
% checks run, and against numbers whose right answer can be written down.

profiles = struct( ...
    distance = {(10:10:50)'; (100:100:300)'}, ...
    intensity = {(1:5)'; [4; 6; 8]});

% Nothing chosen must return the samples unchanged, and label the axes the way
% the plot has always labelled them.
N = HistologyImageBrowser.normalizeProfiles(profiles);
assert(isequal(N.profiles(1).intensity, (1:5)'), "Raw intensities were rescaled");
assert(isequal(N.profiles(1).distance, (10:10:50)'), "Raw distances were rescaled");
assert(contains(N.yLabel, "intensity"), "The intensity axis lost its label: %s", N.yLabel);

% Per trace, each is scaled by its own range; pooled, both are scaled by the
% range of the two together, which is the difference the scope exists for.
N = HistologyImageBrowser.normalizeProfiles(profiles, Normalization = "range");
assert(isequal(N.profiles(1).intensity, [0; 0.25; 0.5; 0.75; 1]), ...
    "Per-trace min-max did not map the first trace onto 0-1");
assert(isequal(N.profiles(2).intensity, [0; 0.5; 1]), ...
    "Per-trace min-max did not map the second trace onto 0-1");

N = HistologyImageBrowser.normalizeProfiles(profiles, ...
    Normalization = "range", Scope = "all");
assert(isequal(N.profiles(1).intensity, (0:4)' / 7), ...
    "Pooled min-max did not scale the first trace by the pooled range");
assert(abs(max(N.profiles(2).intensity) - 1) < 1e-12, ...
    "Pooled min-max did not put the brightest sample of the plot at one");
assert(min(N.profiles(1).intensity) < min(N.profiles(2).intensity), ...
    "Pooled min-max lost the offset between the two traces");

% The rest of the intensity mappings, each against its own definition.
N = HistologyImageBrowser.normalizeProfiles(profiles, Normalization = "baseline");
assert(isequal(N.profiles(2).intensity, [0; 2; 4]), "Baseline was not subtracted");

N = HistologyImageBrowser.normalizeProfiles(profiles, Normalization = "max");
assert(isequal(N.profiles(2).intensity, 100 * [4; 6; 8] / 8), ...
    "Percent of max did not put the peak at 100");

N = HistologyImageBrowser.normalizeProfiles(profiles, Normalization = "mean");
assert(abs(mean(N.profiles(1).intensity) - 1) < 1e-12, ...
    "Fold of mean did not put the mean at one");

N = HistologyImageBrowser.normalizeProfiles(profiles, Normalization = "zscore");
assert(abs(mean(N.profiles(1).intensity)) < 1e-12, "Z-score did not center the trace");
assert(abs(std(N.profiles(1).intensity) - 1) < 1e-12, "Z-score did not scale to unit SD");

% Distance is normalized per trace whatever the scope says, so two lines of
% very different length both run 0 to 100.
N = HistologyImageBrowser.normalizeProfiles(profiles, Distance = "percent", Scope = "all");
assert(isequal(N.profiles(1).distance, (0:25:100)'), ...
    "Percent of line did not map the first line onto 0-100");
assert(isequal(N.profiles(2).distance, [0; 50; 100]), ...
    "Percent of line did not map the second line onto 0-100");
assert(contains(N.xLabel, "%"), "The distance axis was not relabelled: %s", N.xLabel);

N = HistologyImageBrowser.normalizeProfiles(profiles, Distance = "start");
assert(isequal(N.profiles(1).distance, (0:10:40)'), "Distances did not start at zero");

% The two axes are independent.
N = HistologyImageBrowser.normalizeProfiles(profiles, ...
    Normalization = "zscore", Distance = "percent");
assert(abs(mean(N.profiles(2).intensity)) < 1e-12, ...
    "Normalizing the distance axis disturbed the intensity axis");
assert(isequal(N.profiles(2).distance, [0; 50; 100]), ...
    "Normalizing the intensity axis disturbed the distance axis");

check_degenerate_normalization();
check_stale_normalization_code();

end

function check_degenerate_normalization()
%CHECK_DEGENERATE_NORMALIZATION A trace with no range must survive being scaled.
% Dividing by its zero range would return a column of NaN, which draws as
% nothing and reads on screen exactly like a section whose values file is
% missing -- the one outcome a normalization must not produce.

flat = struct(distance = (1:4)', intensity = [7; 7; 7; 7]);

N = HistologyImageBrowser.normalizeProfiles(flat, Normalization = "range");
assert(all(isfinite(N.profiles(1).intensity)), "A flat trace was scaled into non-finite values");
assert(all(N.profiles(1).intensity == 0), "A flat trace did not land on its own baseline");

N = HistologyImageBrowser.normalizeProfiles(flat, Normalization = "zscore");
assert(all(isfinite(N.profiles(1).intensity)), "A flat trace z-scored into non-finite values");

point = struct(distance = 5, intensity = 3);

N = HistologyImageBrowser.normalizeProfiles(point, Distance = "percent");
assert(all(isfinite(N.profiles(1).distance)), ...
    "A single-sample trace has no length, and dividing by it was not guarded");

end

function check_stale_normalization_code()
%CHECK_STALE_NORMALIZATION_CODE A code this release does not offer is dropped.
% Preferences carry these, and a preference file can be hand-edited or written
% by a release that offered a normalization since withdrawn.

profiles = struct(distance = (1:3)', intensity = [2; 4; 6]);

N = HistologyImageBrowser.normalizeProfiles(profiles, ...
    Normalization = "logarithmic", Distance = "furlongs", Scope = "sometimes");

assert(N.normalization == "none", "An unknown normalization was not dropped");
assert(N.distance == "none", "An unknown distance mapping was not dropped");
assert(N.scope == "each", "An unknown scope was not dropped");
assert(isequal(N.profiles(1).intensity, [2; 4; 6]), ...
    "An unknown normalization rescaled the trace anyway");

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
check_profile_normalization_plot(app);
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

function check_profile_normalization_plot(app)
%CHECK_PROFILE_NORMALIZATION_PLOT The normalization dropdowns rescale the plot.
% The arithmetic is checked against written-down answers in
% CHECK_PROFILE_NORMALIZATION; what is checked here is that the panel reaches
% it, that the axes are relabelled with it, and that it stops there -- the
% tiles must come through a normalization untouched, because it rescales
% numbers on the way to the profile axes and has nothing to say about a pixel.

app.onResetFilters();
app.ProfileOnlyCheck.Value = true;
app.applyFilters();

if height(app.View) == 0
    return
end

% The saved layout this app opened with may not show the profile plot at all,
% so the check puts it back on screen rather than depending on a preference.
originalLayout = app.ProfileLayoutDropDown.Value;
restoreLayout = onCleanup(@() set_layout(app, originalLayout));
set_layout(app, "bottom");

restoreNormalization = onCleanup(@() set_normalization(app, "none", "none", "each"));
set_normalization(app, "none", "none", "each");

app.MaxTilesField.Value = min(2, height(app.View));
app.CatalogTable.Selection = 1:app.MaxTilesField.Value;
app.onSelectionChanged();

if isempty(profile_traces(app))
    return
end

layoutBefore = app.ImageLayout;

set_normalization(app, "range", "none", "each");

assert(isequal(app.ImageLayout, layoutBefore) && isvalid(app.ImageLayout), ...
    "Normalizing the profile plot redrew the image tiles");

traces = profile_traces(app);
assert(~isempty(traces), "Normalizing emptied the profile plot");

for iTrace = 1:numel(traces)
    y = traces(iTrace).YData;

    assert(min(y) >= -1e-9 && max(y) <= 1 + 1e-9, ...
        "A min-max normalized trace left the 0-1 range");
    assert(abs(max(y) - 1) < 1e-9, ...
        "A trace scaled by its own range did not reach one");
end

assert(contains(string(app.ProfileAxes.YLabel.String), "normalized"), ...
    "The intensity axis was not relabelled: %s", string(app.ProfileAxes.YLabel.String));

% Scope qualifies the normalization beside it, so it is offered only while one
% is in force -- and the menu has to say the same thing the panel does.
assert(app.ProfileScopeDropDown.Enable == "on", ...
    "The scope was greyed out while a normalization was in force");

set_normalization(app, "none", "none", "each");

assert(app.ProfileScopeDropDown.Enable == "off", ...
    "The scope stayed available with the intensity axis left raw");
assert(display_menu_item(app, "Normalize Over").Enable == "off", ...
    "The Display menu still offered a scope the panel had greyed out");

% The distance axis is independent of the intensity one, and every line runs
% the whole 0 to 100 whatever its own length was.
set_normalization(app, "none", "percent", "each");

traces = profile_traces(app);

for iTrace = 1:numel(traces)
    x = traces(iTrace).XData;

    assert(abs(min(x)) < 1e-9 && abs(max(x) - 100) < 1e-9, ...
        "A trace was not mapped onto 0-100 percent of its own line");
end

assert(contains(string(app.ProfileAxes.XLabel.String), "%"), ...
    "The distance axis was not relabelled: %s", string(app.ProfileAxes.XLabel.String));

% Pooled scaling has to keep the traces apart, which per-trace scaling is what
% throws away. With one section on screen there is nothing to compare, so the
% claim is only made when the selection actually holds two.
if numel(traces) > 1
    set_normalization(app, "none", "none", "each");
    rawPeaks = arrayfun(@(h) max(h.YData), profile_traces(app));

    set_normalization(app, "range", "none", "all");
    peaks = arrayfun(@(h) max(h.YData), profile_traces(app));

    assert(abs(max(peaks) - 1) < 1e-9, ...
        "Pooled min-max did not put the brightest sample of the plot at one");

    % Pooled scaling is one affine map applied to every trace, so two sections
    % measured to different peaks must still land on different peaks. Two that
    % happened to reach the same one are scaled alike by either scope and have
    % nothing to say about the difference between them.
    if max(rawPeaks) - min(rawPeaks) > 1e-9
        assert(any(peaks < 1 - 1e-9), ...
            "Pooled min-max scaled every trace to its own peak, as per-trace would");
    end
end

end

function set_normalization(app, norm, distance, scope)
%SET_NORMALIZATION Choose the three profile options the way the dropdowns do.

app.ProfileNormDropDown.Value = norm;
app.ProfileDistanceDropDown.Value = distance;
app.ProfileScopeDropDown.Value = scope;
app.onProfileOptionChanged();

end

function traces = profile_traces(app)
%PROFILE_TRACES The lines now drawn on the profile axes.

traces = findobj(app.ProfileAxes, "Type", "line");

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

function check_workspace_export(rootPath, metadataCSV)
%CHECK_WORKSPACE_EXPORT The selected sections must land in the base workspace.
% The variable name is handed in rather than typed, because the prompt the menu
% raises would wait forever in a batch run. Everything after the name is the
% same code path the menu item and the shortcut take.

app = HistologyImageBrowser(rootPath, metadataCSV = metadataCSV);
closeApp = onCleanup(@() close(app.Fig));

% The export has to be reachable, not merely callable, so the menu item and the
% key it advertises are checked alongside the table it produces.
assert(isvalid(app.ExportWorkspaceMenu), "The Dataset menu offers no workspace export");

hint = HistologyImageBrowser.shortcutHint("exportWorkspace");
assert(hint ~= "", "The workspace export has no keyboard shortcut");
assert(contains(string(app.ExportWorkspaceMenu.Text), hint), ...
    "The menu item does not name its shortcut: %s", app.ExportWorkspaceMenu.Text);

app.onResetFilters();

% A measured section and an unmeasured one together, because the empty profile
% is the case that has to come back as an empty table rather than as an error.
measured = find(app.View.NProfiles > 0, 1);
bare = find(app.View.NProfiles == 0, 1);

assert(~isempty(measured), "The dataset holds no measured section to export");

app.CatalogTable.Selection = unique([measured, bare]);
app.onSelectionChanged();

varName = "test_histology_export";
dropVariable = onCleanup(@() evalin("base", "clear " + varName));

app.onExportWorkspace(varName);

assert(ismember(varName, string(evalin("base", "who"))), ...
    "Nothing was assigned into the base workspace");

T = evalin("base", varName);
rows = app.selectedRows();

assert(istable(T), "The export was not a table");
assert(height(T) == height(rows), ...
    "Exported %d rows for %d selected sections", height(T), height(rows));
assert(isequal(string(T.Stem), string(rows.Stem)), ...
    "The exported rows are not the sections that were selected");

wanted = ["SubjectID", "SampleID", "SectionID", "Hemisphere", "Stain", "ZPlane", ...
    "DateCode", "ImageNumber", "Protocol", "Series", "NameParsed", ...
    "Folder", "ImagePath", "RoiPath", "ValuesPaths", "AtlasPlate", "Status", "Notes", ...
    "RoiState", "RoiX1", "RoiY1", "RoiX2", "RoiY2", "RoiWidth", "RoiLength", ...
    "PixelSize", "PixelUnit", "ROILabel", "Profile"];

absent = wanted(~ismember(wanted, string(T.Properties.VariableNames)));
assert(isempty(absent), "The export is missing columns: %s", strjoin(absent, ", "));

for iRow = 1:height(T)
    check_exported_row(app, T, rows, iRow);
end

% Calibration is what makes a pixel coordinate mean something, so at least the
% measured section has to carry the pixel size its image was written with.
calibrated = isfinite(T.PixelSize);
assert(any(calibrated), "No section reported the pixel size its image carries");
assert(all(T.PixelUnit(calibrated) ~= "pixel"), ...
    "A calibrated section reported its pixel size in pixels");

% A second export over the same name has to say it replaced something rather
% than fail or quietly double up.
app.onExportWorkspace(varName);

assert(app.StatusLevel == "warning", ...
    "Overwriting an existing variable was not flagged: %s", app.StatusLevel);
assert(contains(string(app.StatusLabel.Text), "replacing"), ...
    "The status bar did not report the replacement: %s", app.StatusLabel.Text);

check_export_without_selection(app);

end

function check_exported_row(app, T, rows, iRow)
%CHECK_EXPORTED_ROW One exported row must agree with what the browser shows.
% ROIFORROW and READPROFILE are asked again rather than the files being read,
% because they are what the tiles and the profile plot are drawn from and the
% export is supposed to hand over exactly that.

R = app.roiForRow(rows(iRow, :));
P = app.readProfile(rows(iRow, :));
S = T.Profile{iRow};

assert(istable(S), "Row %d packed its profile as something other than a table", iRow);
assert(isequal(string(S.Properties.VariableNames), ["Distance", "Intensity"]), ...
    "Row %d packed its profile under the wrong column names", iRow);

units = string(S.Properties.VariableUnits);
assert(units(1) == T.PixelUnit(iRow), ...
    "Row %d measured its distance in %s but reported %s", iRow, units(1), T.PixelUnit(iRow));

assert(T.RoiState(iRow) == R.state, ...
    "Row %d exported ROI state %s rather than %s", iRow, T.RoiState(iRow), R.state);

if R.isValid && R.isLine
    assert(T.RoiX1(iRow) == R.x1 && T.RoiY1(iRow) == R.y1 ...
        && T.RoiX2(iRow) == R.x2 && T.RoiY2(iRow) == R.y2, ...
        "Row %d did not export the pixel coordinates the browser draws", iRow);
    assert(T.RoiWidth(iRow) == R.strokeWidth, "Row %d exported the wrong band width", iRow);
    assert(abs(T.RoiLength(iRow) - hypot(R.x2 - R.x1, R.y2 - R.y1)) < 1e-9, ...
        "Row %d exported the wrong line length", iRow);
else
    assert(isnan(T.RoiX1(iRow)) && isnan(T.RoiLength(iRow)), ...
        "Row %d invented geometry for a section with no line", iRow);
end

if P.hasData
    assert(height(S) == numel(P.intensity), ...
        "Row %d packed %d samples for a profile of %d", iRow, height(S), numel(P.intensity));
    assert(isequal(S.Intensity, P.intensity(:)), "Row %d exported the wrong intensities", iRow);
    assert(isequal(S.Distance, P.distance(:)), "Row %d exported the wrong distances", iRow);
    assert(T.NSamples(iRow) == height(S), "Row %d miscounted its samples", iRow);
    return
end

assert(height(S) == 0, "Row %d invented samples for a section that has no profile", iRow);

end

function check_export_without_selection(app)
%CHECK_EXPORT_WITHOUT_SELECTION An empty selection must be refused, not exported.
% Through the status bar rather than through an error, so the refusal reads the
% same way as every other thing this window declines to do.

app.CatalogTable.Selection = [];
app.onSelectionChanged();

varName = "test_histology_export_nothing";
app.onExportWorkspace(varName);

assert(app.StatusLevel == "warning", ...
    "Exporting nothing was not reported as a warning: %s", app.StatusLevel);
assert(~ismember(varName, string(evalin("base", "who"))), ...
    "An empty selection still assigned a variable");

end

function check_roi_edit_grid(rootPath, metadataCSV)
%CHECK_ROI_EDIT_GRID The optional grid rules the band, and turns with the line.
% The option exists to judge alignment, so the check that matters is the one on
% direction: on a line that points at neither axis, every rule has to run along
% the line or square across it, and none of them along x or y. A grid that had
% been drawn in the axes' frame would look right on a level line and would fail
% here, which is the whole point of measuring the diagonal case.

app = HistologyImageBrowser(rootPath, metadataCSV = metadataCSV);
closeApp = onCleanup(@() close(app.Fig));

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

% Swing the line onto a diagonal about its own midpoint, so it stays over the
% section it was drawn on whatever dataset this runs against.
G = app.RoiEditGeom;
midpoint = [(G.x1 + G.x2) / 2, (G.y1 + G.y2) / 2];
arm = 0.35 * hypot(G.x2 - G.x1, G.y2 - G.y1) * [cosd(30), sind(30)];

app.onRoiEditChanged([midpoint - arm; midpoint + arm], true);

app.ShowBandGridCheck.Value = false;
app.onDisplayOptionChanged();

assert(isempty(band_grid_rules(app)), "The grid was drawn with its option switched off");

app.ShowBandGridCheck.Value = true;
app.onDisplayOptionChanged();

rules = band_grid_rules(app);
assert(~isempty(rules), "The grid was not drawn with its option switched on");

% Read the frame back off the geometry the overlay was drawn from, because
% ONROIEDITCHANGED snaps the endpoints to whole pixels.
G = app.RoiEditGeom;
unit = [G.x2 - G.x1, G.y2 - G.y1] / hypot(G.x2 - G.x1, G.y2 - G.y1);
normal = [-unit(2), unit(1)];

assert(min(abs(unit)) > 0.05, "The line under test came out axis aligned: %s", mat2str(unit, 3));

nAlong = 0;
nAcross = 0;

for iRule = 1:size(rules, 1)
    direction = rules(iRule, 3:4) - rules(iRule, 1:2);
    direction = direction / hypot(direction(1), direction(2));

    assert(min(abs(direction)) > 0.05, ...
        "A grid rule was drawn axis aligned: %s", mat2str(direction, 3));

    if abs(dot(direction, unit)) > 0.999
        nAlong = nAlong + 1;
    elseif abs(dot(direction, normal)) > 0.999
        nAcross = nAcross + 1;
    else
        error("A grid rule ran neither along the line nor across it: %s", mat2str(direction, 3));
    end
end

assert(nAlong > 0 && nAcross > 0, ...
    "Expected rules both along the line and across it, found %d and %d", nAlong, nAcross);

% Bounded by the band it rules, so it cannot wash over the rest of the tile.
lineLength = hypot(G.x2 - G.x1, G.y2 - G.y1);
ends = [rules(:, 1:2); rules(:, 3:4)] - [G.x1, G.y1];

assert(all(ends * unit' >= -1e-6 & ends * unit' <= lineLength + 1e-6), ...
    "The grid ran past the ends of the band");
assert(all(abs(ends * normal') <= G.strokeWidth / 2 + 1e-6), ...
    "The grid ran outside the width of the band");

% The menu mirrors the checkbox, and this is the one mirrored toggle with no
% shortcut behind it, so it has to reach the checkbox on its own.
item = display_menu_item(app, "Band Grid");
assert(item.Checked == "on", "The Display menu did not follow the checkbox");

item.MenuSelectedFcn(item, struct());

assert(~app.ShowBandGridCheck.Value, "The Display menu item did not turn the grid off");
assert(item.Checked == "off", "The Display menu item did not clear its own check mark");
assert(isempty(band_grid_rules(app)), "The grid stayed on the tile after the menu turned it off");

item.MenuSelectedFcn(item, struct());

assert(app.ShowBandGridCheck.Value, "The Display menu item did not turn the grid back on");

end

function item = display_menu_item(app, label)
%DISPLAY_MENU_ITEM Find the Display menu item that mirrors one panel control.

labels = string({app.DisplayMirrors.Label});
index = find(labels == label, 1);

assert(~isempty(index), "The Display menu has no ""%s"" item", label);

item = app.DisplayMirrors(index).Menu;

end

function rules = band_grid_rules(app)
%BAND_GRID_RULES Collect every drawn grid segment as an [x1 y1 x2 y2] row.
% The grid shares the overlay tag with the line and the band, because that tag
% is what a drag deletes and redraws, so it is picked out by its UserData.

rules = zeros(0, 4);

grids = findobj(app.ImagePanel, Tag = "roiOverlay");

for iGrid = 1:numel(grids)
    if ~isequal(grids(iGrid).UserData, "roiBandGrid")
        continue
    end

    faces = grids(iGrid).Faces;
    vertices = grids(iGrid).Vertices;

    rules = [rules; vertices(faces(:, 1), :), vertices(faces(:, 2), :)]; %#ok<AGROW>
end

end

function check_filename_pattern(rootPath)
%CHECK_FILENAME_PATTERN A custom naming scheme reaches the catalog and persists.
% Covers the whole path a lab with different filenames takes: the parser
% option, the two ways a scheme can be written, the table the dialog previews,
% the catalog build, and the preference round trip. The dialog itself is left
% out on purpose. It waits on a modal window, which in a batch run is a hang
% rather than a failure, and that is why the pattern is adopted through a
% method that takes it as an argument.

builtin = "SUBJ-ID-1174IHC_ECM26A260608S1_1A_L_WFA-PV_Z3_260616_1_proj.tif";

% An unset pattern must leave the parser doing literally what it did before.
assert(isequal(parse_histology_filename(builtin), ...
    parse_histology_filename(builtin, pattern = "")), ...
    "An empty pattern changed the built-in parse");

% A name in another convention: unparsable by default, parsable with a pattern,
% and still stripped of the marker the Fiji macro wrote.
foreign = "M12_slide3_CTX_DAPI_proj.tif";

assert(~parse_histology_filename(foreign).isValid, ...
    "A foreign name matched the built-in convention");

pattern = "^(?<SubjectID>[^_]+)_(?<SectionID>[^_]+)_(?:[^_]+)_(?<Stain>[^_]+)$";
info = parse_histology_filename(foreign, pattern = pattern);

assert(info.isValid, "The custom pattern did not match");
assert(info.SubjectID == "M12", "Wrong SubjectID: %s", info.SubjectID);
assert(info.SectionID == "slide3", "Wrong SectionID: %s", info.SectionID);
assert(info.Stain == "DAPI", "Wrong Stain: %s", info.Stain);
assert(info.variant == "proj", "The variant marker was not stripped before the pattern");
assert(info.SampleID == "", "A component the pattern does not name was filled anyway");

% The token list is a second way to write the same thing, so it has to parse
% the same name the same way.
tokens = HistologyImageBrowser.tokenListPattern("_", ["SubjectID", "SectionID", "-", "Stain"]);
fromTokens = parse_histology_filename(foreign, pattern = tokens);

assert(fromTokens.isValid, "The token list pattern did not match: %s", tokens);
assert(fromTokens.SubjectID == info.SubjectID && fromTokens.Stain == info.Stain, ...
    "The token list and the regular expression disagreed");

% A token outside the known components is extracted rather than dropped.
extra = parse_histology_filename("M12_slide3_CTX_DAPI", ...
    pattern = "^(?<SubjectID>[^_]+)_[^_]+_(?<Region>[^_]+)_[^_]+$");

assert(extra.isValid, "A pattern naming an unknown token did not match");
assert(extra.Region == "CTX", "A token outside the known components was lost");

check_filename_pattern_validation();
check_filename_pattern_preview(pattern);
check_filename_pattern_catalog(rootPath);
check_filename_pattern_settings(rootPath);

end

function check_filename_pattern_validation()
%CHECK_FILENAME_PATTERN_VALIDATION Only a usable pattern gets past the gate.

assert(HistologyImageBrowser.checkFilenamePattern(""), ...
    "The built-in convention was rejected");
assert(HistologyImageBrowser.checkFilenamePattern("^(?<SubjectID>.+)$"), ...
    "A valid pattern was rejected");

% REGEXP does not raise on an unclosed group, it silently stops reading the
% pattern there, so a malformed one has to be caught by asking which tokens
% MATLAB actually took out of it.
[usable, why] = HistologyImageBrowser.checkFilenamePattern("^(?<SubjectID>.+$");
assert(~usable, "A malformed pattern was accepted");
assert(why ~= "", "A rejected pattern came back without a reason");

assert(~HistologyImageBrowser.checkFilenamePattern("^.+$"), ...
    "A pattern that names no tokens was accepted");

% A lookbehind assertion opens with the same three characters a named token
% does, and naming nothing is exactly what it does.
assert(~HistologyImageBrowser.checkFilenamePattern("^(?<=x).+$"), ...
    "A lookbehind was mistaken for a named token");

end

function check_filename_pattern_preview(pattern)
%CHECK_FILENAME_PATTERN_PREVIEW The dialog table says which names matched.

names = ["M12_slide3_CTX_DAPI_proj.tif"; "nothing_like_it.tif"];
T = HistologyImageBrowser.filenamePatternPreview(names, pattern);

assert(height(T) == numel(names), "The preview lost a name");
assert(all(ismember(["Name", "Match", "Stem"], string(T.Properties.VariableNames))), ...
    "The preview is missing one of its fixed columns");
assert(T.Match(1) == "yes" && T.Match(2) == "no", ...
    "The preview did not report which names matched");
assert(ismember("Stain", string(T.Properties.VariableNames)), ...
    "The preview has no column for a token the pattern names");
assert(T.Stem(1) == "M12_slide3_CTX_DAPI", ...
    "The preview did not show the stem the pattern is matched against");

% Clearing the table between keystrokes must keep its shape rather than leave
% something a uitable cannot render.
empty = HistologyImageBrowser.filenamePatternPreview(strings(0, 1));
assert(height(empty) == 0 && width(empty) == 3, ...
    "An empty preview lost its fixed columns");

end

function check_filename_pattern_catalog(rootPath)
%CHECK_FILENAME_PATTERN_CATALOG The pattern reaches the catalog build itself.
% The convention written out as a pattern has to catalog the dataset the way
% the convention does. That is the check that the pattern is carried all the
% way down rather than accepted at the top and quietly dropped.

C = build_histology_image_catalog(rootPath);
P = build_histology_image_catalog(rootPath, ...
    filenamePattern = HistologyImageBrowser.DefaultFilenamePattern);

assert(height(P) == height(C), "The pattern changed how many sections were found");
assert(all(P.NameParsed), "The pattern failed on a name the convention parses");
assert(isequal(P.SubjectID, C.SubjectID), "The pattern lost the subject");
assert(isequal(P.SectionID, C.SectionID), "The pattern lost the section");
assert(isequal(P.Hemisphere, C.Hemisphere), "The pattern lost the hemisphere");
assert(isequal(P.Stain, C.Stain), "The pattern lost the stain");

% A pattern that matches nothing has to leave a browsable catalog of stems,
% which is what an unparsed name has always degraded to.
none = build_histology_image_catalog(rootPath, filenamePattern = "^(?<Nope>zzz)$");

assert(height(none) == height(C), "A pattern that matches nothing lost the images");
assert(~any(none.NameParsed), "A pattern that matches nothing reported a parse");
assert(all(none.Stem ~= ""), "A pattern that matches nothing blanked the stems");

end

function check_filename_pattern_settings(rootPath)
%CHECK_FILENAME_PATTERN_SETTINGS The browser adopts, refuses, and remembers one.
% Built without a root folder so the dataset is not loaded a second time; the
% catalog is handed over afterwards to check the preview reads real filenames
% when there are some.

app = HistologyImageBrowser();
closeApp = onCleanup(@() close(app.Fig));

assert(isvalid(app.FilenamePatternMenu), "The Dataset menu has no filename pattern item");

% A pattern is a saved preference, so a browser built here inherits whatever
% the preference file holds. The check starts by putting it back to the
% built-in convention rather than by assuming it is already there.
assert(app.applyFilenamePattern(""), "The built-in convention was refused");
assert(app.FilenamePattern == "", "Clearing the pattern left one in place");
assert(contains(app.FilenamePatternMenu.Text, "built-in"), ...
    "The Dataset menu does not name the built-in convention: %s", app.FilenamePatternMenu.Text);

% Nothing is loaded, so the preview has to fall back to examples rather than to
% an empty table that would read as a pattern matching nothing.
[names, source] = app.filenamePatternSamples();
assert(source == "examples", "An unloaded browser claimed to preview a dataset");
assert(~isempty(names), "The fallback preview had nothing in it");

pattern = "^(?<SubjectID>[^_]+)_(?<SectionID>[^_]+)_(?:[^_]+)_(?<Stain>[^_]+)$";

assert(app.applyFilenamePattern(pattern), "A valid pattern was refused");
assert(app.FilenamePattern == pattern, "The pattern was not kept");
assert(contains(app.FilenamePatternMenu.Text, "custom"), ...
    "The Dataset menu still claims the built-in convention: %s", app.FilenamePatternMenu.Text);

% A pattern that cannot be used must be refused without disturbing the one in
% force: losing a working pattern to a typo is worse than the typo.
assert(~app.applyFilenamePattern("^(?<Broken>.+$"), "An unusable pattern was accepted");
assert(app.FilenamePattern == pattern, "A refused pattern replaced the working one");

saved = getpref(char(HistologyImageBrowser.PrefGroup), "FilenamePattern");
assert(string(saved) == pattern, "The pattern was not written to preferences");

app.FilenamePattern = "";
app.loadPreferences();
assert(app.FilenamePattern == pattern, "The saved pattern did not come back");

% Restoring the default is a choice like any other and has to be persisted as
% one, rather than leaving the last custom pattern in the preference file.
assert(app.applyFilenamePattern(""), "Restoring the built-in convention was refused");
assert(app.FilenamePattern == "", "Restoring the default left the custom pattern in place");
assert(contains(app.FilenamePatternMenu.Text, "built-in"), ...
    "The Dataset menu did not go back to the built-in convention");

% With a catalog in hand the preview must run on the names that are in it, and
% on filenames rather than on the stems they were reduced to.
app.Catalog = build_histology_image_catalog(rootPath);
[names, source] = app.filenamePatternSamples();

assert(source == "dataset", "A loaded catalog was not previewed");
assert(numel(names) == min(height(app.Catalog), HistologyImageBrowser.MaxPatternPreviewNames), ...
    "The preview did not offer one name per section");
assert(all(contains(names, ".")), "The preview offered stems rather than filenames");
assert(any(endsWith(names, "_proj.tif")), ...
    "The preview offered no name carrying the marker it has to explain");

end

function check_incremental_redraw(rootPath, metadataCSV)
%CHECK_INCREMENTAL_REDRAW An overlay toggle reuses the tiles; a pixel change
%rebuilds them.
% The whole point of the split is that switching the sampling band on does not
% reread and restretch every image, so the check is on identity rather than on
% appearance: the tiled layout and the drawn image objects have to be the same
% handles afterwards. A colormap change is measured the same way in the other
% direction, because a test that only proved the cheap path was taken would
% pass just as well if every change had quietly become cheap and wrong.

app = HistologyImageBrowser(rootPath, metadataCSV = metadataCSV);
closeApp = onCleanup(@() close(app.Fig));

nWanted = min(3, height(app.View));
app.MaxTilesField.Value = nWanted;
app.CatalogTable.Selection = 1:nWanted;
app.onSelectionChanged();

assert(isvalid(app.ImageLayout), "No tiled layout was drawn to reuse");

layout = app.ImageLayout;
images = findall(app.ImageLayout, Type = "image");

assert(~isempty(images), "No image was drawn to reuse");

app.ShowBandCheck.Value = true;
app.ColorByIntensityCheck.Value = true;
app.onDisplayOptionChanged();

nBefore = numel(overlay_objects(app));

assert(nBefore > 0, "Nothing was drawn on the tiles for a toggle to remove");

app.ShowBandCheck.Value = false;
app.onDisplayOptionChanged();

assert(isvalid(layout) && isequal(app.ImageLayout, layout), ...
    "Toggling the sampling band rebuilt the tiled layout");
assert(all(isvalid(images)), "Toggling the sampling band redrew the images");
assert(numel(overlay_objects(app)) < nBefore, ...
    "Turning the sampling band off changed nothing on the tiles");

app.ShowBandCheck.Value = true;
app.onDisplayOptionChanged();

assert(all(isvalid(images)), "Restoring the sampling band redrew the images");
assert(numel(overlay_objects(app)) == nBefore, ...
    "The sampling band did not come back the way it went");

% A colormap change alters the pixels, so it has to take the expensive path.
choices = string(app.ColormapDropDown.Items);
wanted = choices(find(choices ~= string(app.ColormapDropDown.Value), 1));

app.ColormapDropDown.Value = wanted;
app.onColormapChanged();

assert(~any(isvalid(images)), "Changing the colormap reused the images already drawn");
assert(isvalid(app.ImageLayout), "Changing the colormap left the view with no tiles");

check_editor_survives_toggle(app);

end

function check_editor_survives_toggle(app)
%CHECK_EDITOR_SURVIVES_TOGGLE An open ROI edit outlives an overlay toggle.
% The draggable line is the one thing on a tile the mouse may be holding, so
% the cheap path must not delete and rebuild it, and it has to come back on top
% of the shading rather than underneath it.

if exist("images.roi.Line", "class") ~= 8
    return
end

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

assert(~isempty(app.RoiEditor) && isvalid(app.RoiEditor), "No draggable line was attached");

editor = app.RoiEditor;
ax = editor.Parent;

app.ShowBandCheck.Value = ~app.ShowBandCheck.Value;
app.onDisplayOptionChanged();

assert(isvalid(editor), "An overlay toggle deleted the line being dragged");
assert(isequal(app.RoiEditor, editor), "An overlay toggle rebuilt the line being dragged");
assert(isequal(editor.Parent, ax), "An overlay toggle moved the line off its tile");

% Restacking is best effort, so the order is only checked where the release
% actually parks the ROI among the axes children.
siblings = ax.Children;
position = find(arrayfun(@(h) isequal(h, editor), siblings), 1);

if ~isempty(position)
    assert(position == 1, ...
        "The line being dragged was left underneath the overlay drawn after it");
end

end

function check_plot_context_menus(rootPath, metadataCSV)
%CHECK_PLOT_CONTEXT_MENUS Every object of a plot raises the menu, and the
%per-tile items act on the tile that was clicked.
% Reaching the menu from the bare axes proves nothing on its own: the pointer
% lands on whichever object is topmost, so the image, the title, and every
% overlay graphic are checked as well. The overlay is then switched off and on,
% because those objects are deleted and recreated by the incremental redraw and
% the menu has to be handed to the new ones.

app = HistologyImageBrowser(rootPath, metadataCSV = metadataCSV);
closeApp = onCleanup(@() close(app.Fig));

editable = find(app.View.RoiPath ~= "" & isfile(app.View.RoiPath));

if numel(editable) < 2
    editable = (1:min(2, height(app.View)))';
end

app.MaxTilesField.Value = 2;
app.CatalogTable.Selection = editable(1:2)';
app.onSelectionChanged();

menu = app.TileContextMenu;

assert(~isempty(menu) && isvalid(menu), "No tile context menu was built");
assert(isequal(menu.Parent, app.Fig), ...
    "The context menu is not parented to the figure that uses it");

check_tiles_carry_menu(app, menu);
check_profile_carries_menu(app);

% The overlay objects that come back from a toggle are new ones.
app.ShowBandCheck.Value = ~app.ShowBandCheck.Value;
app.onDisplayOptionChanged();
app.ShowBandCheck.Value = ~app.ShowBandCheck.Value;
app.onDisplayOptionChanged();

check_tiles_carry_menu(app, menu);

check_context_targets_clicked_tile(app, menu);
check_context_item_writes_panel(app, menu);

end

function check_tiles_carry_menu(app, menu)
%CHECK_TILES_CARRY_MENU Every graphic on every tile has to raise the menu.

tiles = findall(app.ImageLayout, Type = "axes");

assert(~isempty(tiles), "No tiles were drawn to right-click");

for iTile = 1:numel(tiles)
    ax = tiles(iTile);

    assert(isequal(ax.ContextMenu, menu), "A tile axes raised no context menu");
    assert(isequal(ax.Title.ContextMenu, menu), "A tile title raised no context menu");

    % The image never receives the click itself, because DRAWIMAGETILE switches
    % its PickableParts off and the axes behind it answers instead; it still
    % has to carry the same menu, so the two cannot come apart.
    targets = [findobj(ax, Type = "image"); findobj(ax, Tag = "roiOverlay")];

    assert(~isempty(targets), "A tile drew neither an image nor an overlay");

    for iTarget = 1:numel(targets)
        assert(isequal(targets(iTarget).ContextMenu, menu), ...
            "A %s on a tile raised no context menu", targets(iTarget).Type);
    end
end

end

function check_profile_carries_menu(app)
%CHECK_PROFILE_CARRIES_MENU The profile axes and its traces raise their own menu.

menu = app.ProfileContextMenu;

assert(~isempty(menu) && isvalid(menu), "No profile context menu was built");
assert(isequal(app.ProfileAxes.ContextMenu, menu), "The profile axes raised no context menu");

traces = findobj(app.ProfileAxes, Type = "line");

for iTrace = 1:numel(traces)
    assert(isequal(traces(iTrace).ContextMenu, menu), ...
        "A profile trace raised no context menu");
end

end

function check_context_targets_clicked_tile(app, menu)
%CHECK_CONTEXT_TARGETS_CLICKED_TILE Edit ROI edits the tile under the pointer.
% With several sections on screen the panel's own Edit ROI takes the first
% selected row, so the check that matters is on the second tile: right-clicking
% it has to reach its section rather than the one the panel would have chosen.

if exist("images.roi.Line", "class") ~= 8
    return
end

rows = app.selectedRows();

if height(rows) < 2
    return
end

wanted = string(rows.Stem(2));
ax = tile_for_stem(app, wanted);

% Clicked on an overlay graphic rather than on the axes, so the walk from the
% object the pointer landed on up to its tile is exercised too.
clicked = findobj(ax, Tag = "roiOverlay");

if isempty(clicked)
    clicked = findobj(ax, Type = "image");
end

menu.ContextMenuOpeningFcn(menu, struct(ContextObject = clicked(1)));

assert(isequal(app.ContextAxes, ax), ...
    "The right-click did not resolve to the tile the pointer was over");

heading = findobj(menu, Tag = "contextTileLabel");

assert(contains(string(heading.Text), wanted), ...
    "The menu did not name the section it came up on: %s", heading.Text);

item = context_menu_item(menu, "Edit ROI");
item.MenuSelectedFcn(item, struct());
leaveEdit = onCleanup(@() app.exitRoiEdit(false));

assert(app.RoiEditStem == wanted, ...
    "Edit ROI from the context menu started on %s rather than on the clicked %s", ...
    app.RoiEditStem, wanted);

end

function check_context_item_writes_panel(app, menu)
%CHECK_CONTEXT_ITEM_WRITES_PANEL A context item goes through the panel control.
% Nothing about what an option means may be written twice, so the proof is that
% the panel moves: a right-click and a click on the checkbox are one path.

before = app.ShowBandCheck.Value;

item = context_menu_item(menu, "Sampling Band");
item.MenuSelectedFcn(item, struct());

assert(app.ShowBandCheck.Value ~= before, ...
    "The context menu did not move the checkbox it mirrors");

item.MenuSelectedFcn(item, struct());

assert(app.ShowBandCheck.Value == before, "The context menu could not put the band back");

% A dropdown is mirrored as a submenu SYNCDISPLAYMENU fills in, so the items
% have to exist and picking one has to reach the dropdown.
colormapMenu = context_menu_item(menu, "Colormap");
choices = string(app.ColormapDropDown.Items);

assert(numel(colormapMenu.Children) == numel(choices), ...
    "The Colormap submenu offered %d of %d colormaps", ...
    numel(colormapMenu.Children), numel(choices));

wanted = choices(find(choices ~= string(app.ColormapDropDown.Value), 1));
child = findobj(colormapMenu.Children, Text = wanted);
child.MenuSelectedFcn(child, struct());

assert(string(app.ColormapDropDown.Value) == wanted, ...
    "The context menu did not move the colormap dropdown");
assert(child.Checked == "on", "The context menu did not follow the choice it made");

end

function ax = tile_for_stem(app, stem)
%TILE_FOR_STEM Find the drawn tile belonging to one section.

tiles = findall(app.ImageLayout, Type = "axes");

for iTile = 1:numel(tiles)
    if HistologyImageBrowser.tileStem(tiles(iTile)) == stem
        ax = tiles(iTile);
        return
    end
end

error("No tile on screen was stamped with the section %s", stem);

end

function item = context_menu_item(menu, label)
%CONTEXT_MENU_ITEM Find one item of a context menu by the text it starts with.
% Matched on the start rather than the whole label, because SHORTCUTHINT adds
% the key an item advertises to the end of its text.

items = menu.Children;

for iItem = 1:numel(items)
    if startsWith(string(items(iItem).Text), label)
        item = items(iItem);
        return
    end
end

error("The context menu has no ""%s"" item", label);

end

function objects = overlay_objects(app)
%OVERLAY_OBJECTS Every graphic the ROI overlay drew on the tiles now on screen.

objects = findobj(app.ImagePanel, Tag = "roiOverlay");

end

function check_catalog_table(rootPath, metadataCSV)
%CHECK_CATALOG_TABLE A header sort still leaves the selection on its section.
% The one thing column sorting could break, and the reason it was switched off
% for so long: obj.Selection holds indices into obj.View, so a table showing
% the rows in an order of its own would make every one of those indices name
% the wrong section. Sorting cannot be driven through the widget without a
% mouse, so it is simulated by putting the widget in the state a sort leaves it
% in -- DisplayRowOrder set, DisplayDataChangedFcn fired -- which is enough to
% exercise everything downstream of the click.

app = HistologyImageBrowser(rootPath, metadataCSV = metadataCSV);
closeApp = onCleanup(@() close(app.Fig)); %#ok<NASGU>

app.onResetFilters();

assert(height(app.View) > 2, "The dataset is too small to sort");
assert(all(app.CatalogTable.ColumnSortable), "Column sorting was left switched off");
assert(~isempty(app.CatalogTable.DisplayDataChangedFcn), "Nothing follows a header sort");

check_catalog_key_column(app);
check_catalog_sort(app);
check_catalog_columns(app);
check_catalog_table_prefs(app);
check_stale_catalog_prefs(app);

end

function check_catalog_key_column(app)
%CHECK_CATALOG_KEY_COLUMN Every drawn row carries its stem, out of sight.

key = HistologyImageBrowser.CatalogKeyColumn;
names = string(app.CatalogTable.Data.Properties.VariableNames);

assert(names(end) == key, "The table carries no key column");
assert(isequal(string(app.CatalogTable.Data.(key)), string(app.View.Stem)), ...
    "The key column does not hold the stems of the view");

widths = app.CatalogTable.ColumnWidth;

assert(numel(widths) == numel(names), "The widths do not describe the columns");
assert(isequal(widths{end}, 0), "The key column is drawn wide enough to see");

end

function check_catalog_sort(app)
%CHECK_CATALOG_SORT Sorting reorders the view, not just the picture of it.

key = HistologyImageBrowser.CatalogKeyColumn;

% Row 3 rather than row 1, so a selection that silently stayed where it was
% would show up here as a failure.
app.CatalogTable.Selection = 3;
app.onSelectionChanged();

selected = string(app.selectedRows().Stem);

before = app.CatalogTable.Data;

% Section is never blank in this fixture, and its heading is not its catalog
% name, so recovering it proves the heading was mapped back to a column name
% the preferences can be written in.
assert(~any(ismissing(before.Section) | before.Section == ""), ...
    "The Section column has blanks, which this check cannot sort around");

[~, order] = sortrows(before, "Section", "descend");

app.CatalogTable.DisplayRowOrder = order(:).';
feval(app.CatalogTable.DisplayDataChangedFcn, app.CatalogTable, struct());

expected = string(before.(key));
expected = expected(order);

assert(isequal(string(app.View.Stem), expected), ...
    "The view was not put in the order the table showed");
assert(isequal(string(app.CatalogTable.Data.(key)), string(app.View.Stem)), ...
    "The table data and the view came apart after a sort");
assert(isequal(string(app.CatalogTable.DisplayData.(key)), string(app.View.Stem)), ...
    "What the table displays is not the order the view holds");

% The point of all of it: an index into the table still names its section.
rows = app.selectedRows();

assert(height(rows) == 1 && string(rows.Stem) == selected, ...
    "The selection moved off %s onto another section", selected);
assert(string(app.CatalogTable.Data.(key)(app.CatalogTable.Selection)) == selected, ...
    "The highlighted row is not the section the browser thinks is selected");

assert(app.CatalogSortColumn == "SectionID", ...
    "The sort was recorded as one on %s rather than on SectionID", app.CatalogSortColumn);
assert(app.CatalogSortDirection == "descend", ...
    "The sort was recorded as %s", app.CatalogSortDirection);

% A sort the user made outlives the next filter change, which is the whole
% reason for reproducing it rather than only noting that it happened.
app.ProfileOnlyCheck.Value = true;
app.applyFilters();

assert(height(app.View) > 1, "Filtering to profiles left too little to sort");
assert(issorted(string(app.CatalogTable.Data.Section), "descend"), ...
    "The column sort did not survive a refilter");

% Reaching for the Sort by preset is asking for a different order, so the
% column sort gives way to it rather than quietly outranking it.
app.SortDropDown.Value = "plate";
app.applyFilters();

assert(app.CatalogSortColumn == "", "Choosing a Sort by preset left the column sort in force");

app.onResetFilters();

end

function check_catalog_columns(app)
%CHECK_CATALOG_COLUMNS An arrangement decides the columns and their order.

key = HistologyImageBrowser.CatalogKeyColumn;

app.CatalogTable.Selection = 2;
app.onSelectionChanged();

selected = string(app.selectedRows().Stem);

wanted = ["SectionID", "Notes", "Stain"];
app.applyCatalogColumns(wanted);

assert(isequal(app.CatalogColumns, wanted), "The arrangement was not adopted");
assert(isequal(string(app.CatalogTable.Data.Properties.VariableNames), ...
    ["Section", "Notes", "Stain", key]), ...
    "The table shows %s", strjoin(string(app.CatalogTable.Data.Properties.VariableNames), ", "));

% Only the columns changed, so the selection has nothing to follow.
assert(string(app.selectedRows().Stem) == selected, ...
    "Rearranging the columns moved the selection");
assert(string(app.CatalogTable.Data.(key)(app.CatalogTable.Selection)) == selected, ...
    "Rearranging the columns lost the highlighted row");

% An arrangement naming columns that do not exist has to leave a usable table
% rather than an empty one.
app.applyCatalogColumns(["GoneAway", "AlsoGone"]);

assert(isequal(app.CatalogColumns, HistologyImageBrowser.DefaultCatalogColumns), ...
    "An unusable arrangement was adopted rather than refused");
assert(height(app.CatalogTable.Data) == height(app.View), "The table went empty");

% Hiding the column the rows are ordered by leaves nothing on screen to explain
% the order, so the sort goes with it.
app.CatalogSortColumn = "Stain";
app.CatalogSortDirection = "ascend";
app.applyCatalogColumns(["SectionID", "Hemisphere"]);

assert(app.CatalogSortColumn == "", "A sort on a hidden column was left in force");

end

function check_catalog_table_prefs(app)
%CHECK_CATALOG_TABLE_PREFS The arrangement and the sort come back next session.

group = char(HistologyImageBrowser.PrefGroup);

wanted = ["Stain", "SectionID", "Notes"];

app.applyCatalogColumns(wanted);
app.CatalogSortColumn = "Stain";
app.CatalogSortDirection = "descend";
app.savePreferences();

assert(isequal(string(getpref(group, "CatalogColumns")), wanted), ...
    "The arrangement was not written to preferences");

% Put back without persisting, so only the saved values can restore them.
app.applyCatalogColumns(HistologyImageBrowser.DefaultCatalogColumns, persist = false);
app.CatalogSortColumn = "";

app.loadPreferences();

assert(isequal(app.CatalogColumns, wanted), "The saved arrangement did not come back");
assert(app.CatalogSortColumn == "Stain" && app.CatalogSortDirection == "descend", ...
    "The saved sort came back as %s %s", app.CatalogSortColumn, app.CatalogSortDirection);

end

function check_stale_catalog_prefs(app)
%CHECK_STALE_CATALOG_PREFS A preference that no longer makes sense is dropped.
% Both halves have to be judged together: an arrangement can name a column this
% release stopped offering, and a sort can name a column the arrangement does
% not show. Either left standing gives a table ordered by something invisible,
% or no table at all.

group = char(HistologyImageBrowser.PrefGroup);

setpref(group, "CatalogColumns", ["GoneAway", "AlsoGone"]);
setpref(group, "CatalogSortColumn", "GoneAway");
app.loadPreferences();

assert(isequal(app.CatalogColumns, HistologyImageBrowser.DefaultCatalogColumns), ...
    "A stale arrangement was restored rather than replaced by the default");
assert(app.CatalogSortColumn == "", "A sort on a column that no longer exists was restored");
assert(height(app.CatalogTable.Data) == height(app.View), "The stale arrangement emptied the table");

setpref(group, "CatalogColumns", ["SectionID", "Stain"]);
setpref(group, "CatalogSortColumn", "Notes");
app.loadPreferences();

assert(isequal(app.CatalogColumns, ["SectionID", "Stain"]), "The saved arrangement was refused");
assert(app.CatalogSortColumn == "", "A sort on a column the arrangement hides was restored");

% A direction nothing can be sorted in falls back rather than reaching SORTROWS.
setpref(group, "CatalogSortColumn", "Stain");
setpref(group, "CatalogSortDirection", "sideways");
app.loadPreferences();

assert(app.CatalogSortColumn == "Stain", "A usable sort column was dropped with its direction");
assert(app.CatalogSortDirection == "ascend", ...
    "An unusable direction was restored as %s", app.CatalogSortDirection);

% Anything that is not text at all has to be refused before it is converted.
setpref(group, "CatalogColumns", 42);
app.loadPreferences();

assert(isequal(app.CatalogColumns, HistologyImageBrowser.DefaultCatalogColumns), ...
    "A preference that is not a column list was adopted");

end
