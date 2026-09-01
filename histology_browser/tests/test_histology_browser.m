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
nFailed = nFailed + run_case("ROI keys", @check_roi_keys);
nFailed = nFailed + run_case("multi-ROI catalog", @check_multi_roi_catalog);
nFailed = nFailed + run_case("macro ROI pairing", @check_macro_roi_pairing);
nFailed = nFailed + run_case("ImageJ ROI decoder", @check_roi_decoder);
nFailed = nFailed + run_case("ImageJ ROI encoder", @check_roi_encoder);
nFailed = nFailed + run_case("line profile measurement", @check_profile_measurement);
nFailed = nFailed + run_case("missing metadata labels", @check_missing_metadata);
nFailed = nFailed + run_case("published sheet URLs", @check_published_url);
nFailed = nFailed + run_case("published sheet settings", @check_published_settings);

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

function check_roi_keys()
%CHECK_ROI_KEYS An ROI must be keyed by the label in its filenames.
% This is what ties a .roi file to the values.csv beside it once a section can
% hold more than one of each, and what lets a dataset measured before that was
% possible keep working: the macro's unlabelled pair is the section's ROI A.

assert(histology_roi_key("") == "A", "An unlabelled sidecar was not filed under A");
assert(histology_roi_key("   ") == "A", "A blank label was not filed under A");
assert(histology_roi_key(missing) == "A", "A missing label was not filed under A");
assert(histology_roi_key("B") == "B", "A lettered label was renamed");
assert(histology_roi_key("  ACx  ") == "ACx", "A label written by hand was not kept");

base = "SUBJ-ID-1174IHC_ECM26A260608S1_1A_L_WFA-PV_Z3_260616_1";

cases = [ ...
    base + "_proj_roi.roi",      ""; ...
    base + "_proj_B_roi.roi",    "B"; ...
    base + "_proj_ACx_roi.roi",  "ACx"];

for iCase = 1:size(cases, 1)
    info = parse_histology_filename(cases(iCase, 1));

    assert(info.isValid, "Failed to parse %s", cases(iCase, 1));
    assert(info.stem == base, "Wrong stem for %s: %s", cases(iCase, 1), info.stem);
    assert(info.variant == "proj", "Wrong variant for %s", cases(iCase, 1));
    assert(info.roi == cases(iCase, 2), "Wrong ROI label for %s: %s", ...
        cases(iCase, 1), info.roi);
end

% A new ROI takes the first letter its section is not already using, so the
% keys stay short and a gap left by a deleted ROI is filled rather than
% skipped.
assert(HistologyImageBrowser.nextRoiKey(strings(0, 1)) == "A", ...
    "The first ROI of a section was not A");
assert(HistologyImageBrowser.nextRoiKey(["A"; "B"]) == "C", ...
    "The third ROI of a section was not C");
assert(HistologyImageBrowser.nextRoiKey(["A"; "C"]) == "B", ...
    "A gap in the letters was not filled");

end

function check_multi_roi_catalog()
%CHECK_MULTI_ROI_CATALOG A section's ROI sidecars must pair up by their label.
% Every file is synthetic, so this runs without a dataset: what it checks is
% that .roi and values.csv files land on the same ROI when they share a label
% and on different ROIs when they do not.

root = string(fullfile(tempdir, "histology_multi_roi_test"));

if isfolder(root)
    rmdir(root, "s");
end

base = "SUBJ-ID-1174IHC_ECM26A260608S1_1A_L_WFA-PV_Z3_260616_1";
folder = fullfile(root, base);
mkdir(folder);

cleanup = onCleanup(@() rmdir(root, "s"));

geometry = struct("x1", 40, "y1", 90, "x2", 210, "y2", 100, "width", 40);

% ROI A is written the way MACRO_Batch_LineMeasure writes it, with no label at
% all. ROI B carries its key in both filenames. ROI C has a line but was never
% measured, which is still an ROI.
write_line_roi(fullfile(folder, base + "_proj_roi.roi"), geometry);
write_values_csv(fullfile(folder, base + "_proj_values.csv"), (0:9)', ones(10, 1));

write_line_roi(fullfile(folder, base + "_proj_B_roi.roi"), geometry);
write_values_csv(fullfile(folder, base + "_proj_B_values.csv"), (0:9)', 2 * ones(10, 1));

write_line_roi(fullfile(folder, base + "_proj_C_roi.roi"), geometry);

C = build_histology_image_catalog(root);

assert(height(C) == 1, "Expected one section, got %d", height(C));
assert(isequal(C.RoiKeys{1}, ["A"; "B"; "C"]), ...
    "The section's ROIs were not keyed A, B, C: %s", join(C.RoiKeys{1}', ", "));
assert(C.NRois == 3, "Wrong ROI count: %g", C.NRois);
assert(C.ROI == "A, B, C", "The ROI column did not name every ROI: %s", C.ROI);

assert(all(C.RoiPaths{1} ~= ""), "An ROI lost its .roi file");
assert(endsWith(C.RoiValues{1}(1), "_proj_values.csv"), ...
    "A took the wrong values file: %s", C.RoiValues{1}(1));
assert(endsWith(C.RoiPaths{1}(2), "_proj_B_roi.roi"), ...
    "B took the wrong .roi file: %s", C.RoiPaths{1}(2));
assert(endsWith(C.RoiValues{1}(2), "_proj_B_values.csv"), ...
    "B took the wrong values file: %s", C.RoiValues{1}(2));

% An ROI with no profile must be reported as having none rather than
% borrowing one from the ROI beside it.
assert(C.RoiValues{1}(3) == "", "C was given a values file it does not have");
assert(C.NProfiles == 2, "Wrong profile count: %g", C.NProfiles);

end

function check_macro_roi_pairing()
%CHECK_MACRO_ROI_PAIRING One line measured by the Fiji macro must stay one ROI.
% MACRO_Batch_LineMeasure names the values file after the region it was run
% for but always writes the .roi as "<base>_roi.roi", so the two sidecars of a
% single line disagree about their label. Reading them literally would split
% that line into an ROI with no profile and an ROI with no geometry, which is
% what every section measured so far would look like.

root = string(fullfile(tempdir, "histology_macro_pairing_test"));

if isfolder(root)
    rmdir(root, "s");
end

base = "SUBJ-ID-1174IHC_ECM26A260608S1_1A_L_WFA-PV_Z3_260616_1";
folder = fullfile(root, base);
mkdir(folder);

cleanup = onCleanup(@() rmdir(root, "s"));

write_line_roi(fullfile(folder, base + "_proj_roi.roi"), ...
    struct("x1", 40, "y1", 90, "x2", 210, "y2", 100, "width", 40));
write_values_csv(fullfile(folder, base + "_proj_ACxvalues.csv"), (0:9)', ones(10, 1));

C = build_histology_image_catalog(root);

assert(height(C) == 1, "Expected one section, got %d", height(C));
assert(C.NRois == 1, "One measured line was read as %g ROIs", C.NRois);
assert(C.RoiKeys{1} == "ACx", "The line was not keyed by its profile: %s", C.RoiKeys{1});
assert(C.RoiPaths{1} ~= "" && C.RoiValues{1} ~= "", ...
    "The line lost one of its two sidecars");

% A .roi that carries a label of its own is never reassigned, because the
% label already says which ROI it belongs to.
write_line_roi(fullfile(folder, base + "_proj_B_roi.roi"), ...
    struct("x1", 40, "y1", 170, "x2", 210, "y2", 180, "width", 40));

C = build_histology_image_catalog(root);

assert(isequal(C.RoiKeys{1}, ["B"; "ACx"]), ...
    "A labelled .roi was not kept apart: %s", join(C.RoiKeys{1}', ", "));

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
check_roi_names(app);
check_roi_editing(app);

end

function check_roi_names(app)
%CHECK_ROI_NAMES Naming an ROI key must rename it everywhere and outlive the
% session. The names are what makes a second line across a section readable as
% a region rather than as a letter, so they have to reach the overlay and the
% legend, and they have to be there again next time the browser opens.

savedPrefs = snapshot_roi_name_prefs();
savedNames = struct(keys = app.RoiNameKeys, labels = app.RoiNameLabels);
restore = onCleanup(@() restore_roi_names(app, savedNames, savedPrefs));

% Started from no names at all, so what this checks does not depend on which
% regions the person running it happens to have named already.
app.RoiNameKeys = strings(0, 1);
app.RoiNameLabels = strings(0, 1);

app.setRoiName("A", "ACx");

assert(app.roiName("A") == "ACx", "A was not renamed");
assert(app.roiName("B") == "B", "An unnamed key stopped standing for itself");

% Written and read back, because a name belongs to the study rather than to
% one sitting with the browser.
app.savePreferences();
app.RoiNameKeys = strings(0, 1);
app.RoiNameLabels = strings(0, 1);
app.loadPreferences();

assert(app.roiName("A") == "ACx", "The ROI name did not survive preferences");

% The dropdown names the ROI and still carries the key, which is what says
% which files an edit would write.
app.updateRoiEditControls();
assert(any(contains(string(app.RoiSelectDropDown.Items), "ACx")), ...
    "The renamed ROI was not offered by name: %s", ...
    join(string(app.RoiSelectDropDown.Items), " | "));

% The tile has to carry it too, on the section that is actually on screen.
select_row(app, 1);
captions = string({findobj(app.ImagePanel, Type = "text", Tag = "roiOverlay").String});

if ~isempty(captions) && any(app.roiKeysForRow(app.View(1, :)) == "A")
    assert(ismember("ACx", captions), ...
        "The renamed ROI was not captioned on the tile: %s", join(captions, ", "));
end

% Clearing a name puts the key back to standing for itself, and stores
% nothing rather than storing a blank.
app.setRoiName("A", "");

assert(app.roiName("A") == "A", "Clearing a name did not restore the key");
assert(~ismember("A", app.RoiNameKeys), "A cleared name was stored as a blank");

end

function saved = snapshot_roi_name_prefs()
%SNAPSHOT_ROI_NAME_PREFS Record the saved ROI names as they stand.
% This check writes preferences to prove they survive a round trip, so it has
% to put the real ones back afterwards.

group = char(HistologyImageBrowser.PrefGroup);
names = ["RoiNameKeys", "RoiNameLabels"];

saved = struct(group = group, names = names, existed = false(size(names)), ...
    values = {cell(size(names))});

for iName = 1:numel(names)
    saved.existed(iName) = ispref(group, char(names(iName)));

    if saved.existed(iName)
        saved.values{iName} = getpref(group, char(names(iName)));
    end
end

end

function restore_roi_names(app, savedNames, savedPrefs)
%RESTORE_ROI_NAMES Put both the browser and the preferences back as they were.

app.RoiNameKeys = savedNames.keys;
app.RoiNameLabels = savedNames.labels;

for iName = 1:numel(savedPrefs.names)
    name = char(savedPrefs.names(iName));

    if savedPrefs.existed(iName)
        setpref(savedPrefs.group, name, savedPrefs.values{iName});
    elseif ispref(savedPrefs.group, name)
        rmpref(savedPrefs.group, name);
    end
end

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

check_roi_scope(app);

end

function check_roi_scope(app)
%CHECK_ROI_SCOPE An edit must reach the chosen ROI and no other.
% Nothing is saved here either: what is checked is that the browser knows
% which of a section's ROIs the handles are on, so that the one being dragged
% is the only one whose profile stops being the file on disk.

row = app.editedRow();

if height(row) ~= 1
    return
end

keys = app.roiKeysForRow(row);

% Adding an ROI is the one part of this that works on a section with only one
% to begin with, so it is checked whatever the dataset holds. Nothing is
% written, so the section is left exactly as it was found.
expected = HistologyImageBrowser.nextRoiKey(keys);

app.onAddRoi();

assert(app.RoiEditKey == expected, ...
    "Add ROI opened %s rather than %s", app.RoiEditKey, expected);
assert(app.RoiEditDirty, "A brand new ROI was not marked unsaved");
assert(ismember(expected, app.roiKeysForRow(app.editedRow())), ...
    "The added ROI was not listed on its section");

app.exitRoiEdit(false);

if numel(keys) < 2
    return
end

% With two ROIs on the section, moving one must leave the other reading from
% its own file.
app.RoiSelectDropDown.Value = keys(2);
app.onRoiSelectionChanged();

app.EditRoiButton.Value = true;
app.onToggleEditRoi();
leaveEdit = onCleanup(@() app.exitRoiEdit(false));

assert(app.RoiEditKey == keys(2), ...
    "Editing opened %s rather than %s", app.RoiEditKey, keys(2));

edited = app.RoiEditGeom;
app.onRoiEditChanged([edited.x1, edited.y1 + 15; edited.x2, edited.y2], true);

moved = app.readProfile(app.editedRow(), keys(2));
untouched = app.readProfile(app.editedRow(), keys(1));

assert(contains(moved.source, "unsaved"), ...
    "The edit did not reach the chosen ROI: %s", moved.source);
assert(~contains(untouched.source, "unsaved"), ...
    "Editing one ROI disturbed another: %s", untouched.source);

app.onRevertRoiEdits();

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
