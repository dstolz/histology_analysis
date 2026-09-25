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
% snapshots the whole preference group before the first check and puts it back
% on the way out. That cannot protect a run from another MATLAB writing the
% same preference file at the same time, and PREFDIR is fixed at startup: give
% concurrent runs a preference directory of their own by launching them with
% MATLAB_PREFDIR set to a folder that exists, since a path that does not is
% ignored and the real preferences are used instead.
%
% Nothing here reaches the network. The saved published sheet is unset for the
% length of the run, and the download itself is checked against a stand-in
% fetch, so the suite runs offline and gives the same answer every time.
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
% this folder so the dataset generator and the shared test fixtures beside
% this file resolve with them.
addpath(fileparts(fileparts(mfilename("fullpath"))));
addpath(fileparts(mfilename("fullpath")));

% Snapshotted before the first check rather than before the GUI ones, because
% the browser saves its preferences whenever it loads, redraws, or closes, and
% the published-sheet check builds one. Without this a run would leave the
% user's own root folder, colormaps, ROI band width, and window geometry set
% to whatever these checks needed.
restorePreferences = preserve_preferences(); %#ok<NASGU>  Restores on the way out.

% Taken out of the run's way once the group is safe. A published sheet in the
% preference file is read by every browser these checks build, which sends
% each of their loads to the network: minutes of waiting when it answers, and
% an unrelated check failing on an empty catalog when it does not. What the
% published sheet path itself does is checked against a stand-in fetch instead.
clear_published_pref();

nFailed = 0;

nFailed = nFailed + run_case("filename parser", @check_filename_parser);
nFailed = nFailed + run_case("ROI keys", @check_roi_keys);
nFailed = nFailed + run_case("multi-ROI catalog", @check_multi_roi_catalog);
nFailed = nFailed + run_case("macro ROI pairing", @check_macro_roi_pairing);
nFailed = nFailed + run_case("ImageJ ROI decoder", @check_roi_decoder);
nFailed = nFailed + run_case("ImageJ ROI encoder", @check_roi_encoder);
nFailed = nFailed + run_case("line profile measurement", @check_profile_measurement);
nFailed = nFailed + run_case("profile normalization", @check_profile_normalization);
nFailed = nFailed + run_case("brain surface detection", @check_surface_detection);
nFailed = nFailed + run_case("image background level", @check_image_background);
nFailed = nFailed + run_case("brain surface sidecar", @check_surface_mark_files);
nFailed = nFailed + run_case("crop to an ROI", @check_roi_crop);
nFailed = nFailed + run_case("missing metadata labels", @check_missing_metadata);
nFailed = nFailed + run_case("published sheet URLs", @check_published_url);
nFailed = nFailed + run_case("published sheet settings", @check_published_settings);
nFailed = nFailed + run_case("tracker table joins without a CSV", @check_metadata_table_option);
nFailed = nFailed + run_case("sheet tracker settings", @check_sheet_settings);
nFailed = nFailed + run_case("review writes to the tracker", @check_review_writes);
nFailed = nFailed + run_case("review target follows the selection", @check_review_target);

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
    nFailed = nFailed + run_case("image catalog", @() check_catalog(rootPath, options.metadataCSV));
    nFailed = nFailed + run_case("browser GUI", @() check_gui(rootPath, options.metadataCSV));
    nFailed = nFailed + run_case("export to workspace", ...
        @() check_workspace_export(rootPath, options.metadataCSV));
    nFailed = nFailed + run_case("ROI edit grid", ...
        @() check_roi_edit_grid(rootPath, options.metadataCSV));
    nFailed = nFailed + run_case("brain surface marking", ...
        @() check_surface_marking(rootPath, options.metadataCSV));
    nFailed = nFailed + run_case("custom filename pattern", ...
        @() check_filename_pattern(rootPath));
    nFailed = nFailed + run_case("incremental overlay redraw", ...
        @() check_incremental_redraw(rootPath, options.metadataCSV));
    nFailed = nFailed + run_case("plot context menus", ...
        @() check_plot_context_menus(rootPath, options.metadataCSV));
    nFailed = nFailed + run_case("sections table sorting and columns", ...
        @() check_catalog_table(rootPath, options.metadataCSV));
    nFailed = nFailed + run_case("load without the published tracker", ...
        @() check_tracker_download_failure(rootPath, options.metadataCSV));
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

function clear_published_pref()
%CLEAR_PUBLISHED_PREF Unset the saved published sheet for the length of a run.
% Only safe to call once PRESERVE_PREFERENCES has snapshotted the group, which
% is what puts the user's sheet back on the way out.

group = char(HistologyImageBrowser.PrefGroup);

if ispref(group, "PublishedUrl")
    rmpref(group, "PublishedUrl");
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
% Builds a browser, which loads and saves the whole preference group rather
% than the one value this is about, so it runs inside the snapshot the caller
% takes before the first check. It leaves no sheet set, which is how the rest
% of the run wants it.

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

function check_metadata_table_option()
%CHECK_METADATA_TABLE_OPTION A tracker already in memory annotates a dataset.
% This is the path a tracker read from Google Sheets takes. It has to land in
% exactly the same place the CSV did, so the check is that the columns come out
% on the combined table the same way.

stem = "SUBJ-ID-1174IHC_ECM26A260608S1_1A_L_WFA-PV_Z3_260616_1";

root = string(tempname);
mkdir(root);
cleanup = onCleanup(@() rmdir(root, "s"));

write_values_csv(fullfile(root, stem + "_values.csv"), (0:9)', rand(10, 1));

tracker = table( ...
    stem, "42", "Left ACx", ...
    VariableNames = ["Image Filename", "Atlas Plate #", "Notes"]);

S = combine_values_csv(root, metadataTable = tracker);

assert(S.metadata.hasMetadata, "The in-memory tracker was not used");
assert(S.metadata.source == "table", ...
    "The tracker source was reported as '%s' rather than 'table'", S.metadata.source);
assert(height(S.combined) == 10, ...
    "Combined %d rows rather than 10", height(S.combined));

vars = string(S.combined.Properties.VariableNames);
assert(ismember("Atlas Plate #", vars), "A tracker column did not reach the combined table");
assert(all(S.combined.("Notes") == "Left ACx"), "A tracker value was not carried across");

% A tracker with no key column cannot be joined, and saying so beats producing
% a catalog that silently has no metadata on it.
try
    combine_values_csv(root, metadataTable = table("x", VariableNames = "Something Else"));
    error("A tracker with no Image Filename column was accepted");
catch ME
    assert(ME.identifier == "combine_values_csv:MissingImageFilenameColumn", ...
        "Wrong error for a tracker with no key column: %s", ME.identifier);
end

end

function check_sheet_settings()
%CHECK_SHEET_SETTINGS The sheet menu reflects what is configured.
% No network is touched: building a tracker object and labelling the menu are
% both offline, and they are what breaks when the wiring is wrong.

% Closing the browser saves preferences, so this check would otherwise leave
% its scratch settings behind as the real configuration. They are put back
% however the check ends.
saved = snapshot_sheet_prefs();
restorePrefs = onCleanup(@() restore_sheet_prefs(saved));

app = HistologyImageBrowser();
cleanup = onCleanup(@() delete(app.Fig));

% Whatever was configured on this machine is beside the point here, so the
% starting state is set rather than assumed.
app.SheetUrl = "";
app.SheetTab = "Sections";
app.SheetCredentials = "";
app.Tracker = [];
app.refreshDatasetMenu();

assert(contains(app.SheetMenu.Text, "(none)"), ...
    "The sheet menu did not start out empty");
assert(app.SheetPrepareMenu.Enable == "off", ...
    "Preparing the sheet was offered with no sheet configured");
assert(isempty(app.sheetTracker()), "A tracker was built with no sheet configured");

app.SheetUrl = "https://docs.google.com/spreadsheets/d/1yz6v2yP/edit?gid=108";
app.refreshDatasetMenu();

% Naming the spreadsheet is enough to read it once a key file is named too,
% but writing is only offered when there is a key file to write with.
assert(app.SheetClearMenu.Enable == "on", "Clearing a configured sheet was not offered");
assert(app.SheetPrepareMenu.Enable == "off", ...
    "Preparing the sheet was offered without a key file");

app.SheetCredentials = "definitely-not-a-real-key.json";
app.refreshDatasetMenu();

assert(app.SheetPrepareMenu.Enable == "on", ...
    "Preparing the sheet was not offered once a key file was named");
assert(contains(app.SheetMenu.Text, "Sections"), ...
    "The sheet menu does not name the tab: %s", app.SheetMenu.Text);

tracker = app.sheetTracker();
assert(tracker.SpreadsheetId == "1yz6v2yP", ...
    "The spreadsheet ID was not taken from the URL");

% The same object comes back until something about the configuration changes.
assert(tracker == app.sheetTracker(), "A second tracker was built needlessly");

app.SheetTab = "Other";
assert(app.sheetTracker().SheetName == "Other", ...
    "The tracker was not rebuilt after the tab changed");

app.onClearSheet();
assert(app.SheetUrl == "", "Clearing the sheet left it configured");
assert(contains(app.SheetMenu.Text, "(none)"), "The menu still names a sheet");

end

function check_review_writes()
%CHECK_REVIEW_WRITES Marking a section reaches the sheet and the table.
% The whole point of a review write is that it changes two things: the
% tracker, and what the person doing the reviewing is looking at. A write that
% reached the sheet but left the table showing the old value would look like it
% had not worked.

[app, state, cleanup] = review_fixture(); %#ok<ASGLU>

% The second section in the fixture, selected as it would be by clicking it.
app.CatalogTable.Selection = 2;
app.onSelectionChanged();

app.onSetMeasured(true);

grid = state("grid");
row = find(strtrim(grid(:, 4)) == "SUBJ-ID-896_2A_R_WFA-PV-DAPI_Z3_250408_1");

assert(strtrim(grid(row, 11)) == "yes", "The flag did not reach the sheet");
assert(strtrim(grid(row, 10)) ~= "", "The write was not stamped");
assert(app.View.Measured(2), "The catalog still says the section is unmeasured");
assert(app.CatalogTable.Data.Meas(2) ~= "", "The table still shows the section unmarked");

% Nothing else was touched.
assert(~any(app.View.Measured([1 3])), "Sections that were not selected were marked");

% Working through a stack of sections means the selection must not jump back to
% the top after every mark.
assert(isequal(app.CatalogTable.Selection, 2), ...
    "The selection moved when the table was refreshed");

% Several sections at once is the ordinary case for a stack from one slide.
app.CatalogTable.Selection = [1 3];
app.onSelectionChanged();
app.onSetMeasured(true);

% The fourth section has no tracker row and so can never be marked; the first
% three are the ones a write reaches.
assert(all(app.View.Measured(1:3)), "Marking a multiple selection missed a section");
assert(~app.View.Measured(4), "A section with no tracker row was marked");

% The keyboard toggle clears only once there is nothing left to mark, which is
% what makes it safe to press repeatedly down a stack. It has to reckon that
% against the sections it can actually write to: counting the fourth would
% leave it forever trying to mark a section it can never reach.
app.onSelectAll();
app.runShortcut("toggleMeasured");
assert(~any(app.View.Measured), "The toggle did not clear an all-measured selection");

app.runShortcut("toggleMeasured");
assert(all(app.View.Measured(1:3)), "The toggle did not mark an unmeasured selection");

end

function check_review_target()
%CHECK_REVIEW_TARGET A review write reaches the sections it can, and says why not.

[app, state, cleanup] = review_fixture(); %#ok<ASGLU>

app.CatalogTable.Selection = 3;
app.onSelectionChanged();

target = app.reviewTarget();
assert(target.writable, "Reviewing was not offered for a tracker row");
assert(isequal(target.writableRows, 3), "The write would not reach the selected section");

% The fourth fixture row has no tracker identifier, standing for a section the
% tracker has no row for.
app.CatalogTable.Selection = 4;
app.onSelectionChanged();

target = app.reviewTarget();
assert(~target.writable, "Reviewing was offered for a section with no tracker row");
assert(contains(target.reason, "no row in the tracker"), ...
    "The reason does not say why: %s", target.reason);

% Pressing the key anyway writes nothing, and says why on the status bar.
app.onSetMeasured(true);
assert(~app.View.Measured(4), "A section with no tracker row was marked");
assert(contains(app.StatusLabel.Text, "no row in the tracker"), ...
    "The status bar does not say why nothing was written: %s", app.StatusLabel.Text);

% A mixed selection writes what it can and says what it skipped.
app.CatalogTable.Selection = [1 4];
app.onSelectionChanged();

target = app.reviewTarget();
assert(target.writable, "A selection with one writable section was refused entirely");
assert(contains(target.reason, "skipped"), ...
    "The reason does not warn that a section will be skipped: %s", target.reason);

app.onSetMeasured(true);
assert(app.View.Measured(1), "The writable section of a mixed selection was not marked");

grid = state("grid");
assert(sum(strtrim(grid(:, 11)) == "yes") == 1, "More rows were written than expected");

end

function [app, state, cleanup] = review_fixture()
%REVIEW_FIXTURE A browser holding a catalog that maps onto the fake sheet.
% The catalog is built by hand rather than by loading a dataset, because what
% is under test is the path from a selection to a tracker write, and no images
% on disk are needed to exercise it.

saved = snapshot_sheet_prefs();
restorePrefs = onCleanup(@() restore_sheet_prefs(saved));

[tracker, state] = fake_section_tracker();
tracker.ensureSchema();
tracker.read();

app = HistologyImageBrowser();
closeApp = onCleanup(@() delete(app.Fig));

% Matched to the fake tracker so SHEETTRACKER hands back that one rather than
% building a live one against a spreadsheet that does not exist.
app.SheetUrl = "fake-spreadsheet";
app.SheetTab = "Sections";
app.SheetCredentials = "fake-key.json";
app.Tracker = tracker;

% Built by the real cataloger against an empty folder, so the join that puts a
% tracker row's identifier onto a catalog row is the one under test rather than
% something arranged by hand to look like its output.
root = string(tempname);
mkdir(root);
removeRoot = onCleanup(@() rmdir(root, "s"));

app.Catalog = build_histology_image_catalog(root, ...
    metadataTable = tracker.metadataTable(), includeMissing = true);

assert(height(app.Catalog) == 4, ...
    "The fixture catalog has %d rows rather than 4", height(app.Catalog));
assert(all(app.Catalog.TrackerUid ~= ""), ...
    "The catalog did not carry the tracker identifiers across");

% The last row stands for a section the tracker has no row for, which is the
% state a write has to refuse rather than guess at.
app.Catalog.TrackerUid(4) = "";
app.Catalog.InTracker(4) = false;

app.View = app.Catalog;

% Measured is not in the default arrangement, because it says nothing at all
% until a sheet tracker is configured. Reviewing is exactly the sitting that
% wants it, so the fixture asks for it the way a reviewer would, and the checks
% below can then read the column off the table. Not persisted: the arrangement
% is a property of this fixture, not a choice the person running the tests made.
app.applyCatalogColumns( ...
    [HistologyImageBrowser.DefaultCatalogColumns, "Measured"], persist = false);

app.refreshCatalogTable();

cleanup = onCleanup(@() release(restorePrefs, closeApp, removeRoot));

end

function release(varargin)
%RELEASE Hold several cleanup objects until the caller's own one is destroyed.

clear varargin

end

function saved = snapshot_sheet_prefs()
%SNAPSHOT_SHEET_PREFS Record the sheet preferences as they stand.

group = char(HistologyImageBrowser.PrefGroup);
names = ["SheetUrl", "SheetTab", "SheetCredentials"];

saved = struct(group = group, names = names, values = {cell(size(names))}, ...
    existed = false(size(names)));

for iName = 1:numel(names)
    saved.existed(iName) = ispref(group, char(names(iName)));

    if saved.existed(iName)
        saved.values{iName} = getpref(group, char(names(iName)));
    end
end

end

function restore_sheet_prefs(saved)
%RESTORE_SHEET_PREFS Put the sheet preferences back as they were.

for iName = 1:numel(saved.names)
    name = char(saved.names(iName));

    if saved.existed(iName)
        setpref(saved.group, name, saved.values{iName});
    elseif ispref(saved.group, name)
        rmpref(saved.group, name);
    end
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

check_surface_normalization();
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

function check_surface_detection()
%CHECK_SURFACE_DETECTION The background-to-signal step DETECT_BRAIN_SURFACE finds.
% Built rather than measured, so the answer can be written down: the profile
% steps out of background at a known sample, and the crossing has to come back
% there whichever way round the line was drawn.

nSamples = 300;
edgeSample = 101;
pixelSize = 2;

distance = (0:nSamples - 1)' * pixelSize;
intensity = synthetic_section_profile(nSamples, edgeSample);

S = detect_brain_surface(distance, intensity);

assert(S.found, "No surface was found in a profile with an obvious edge: %s", S.message);
assert(S.direction == "forward", "The background end was misread as %s", S.direction);
assert(abs(S.index - edgeSample) <= 5, ...
    "The crossing came back at sample %.1f rather than near %d", S.index, edgeSample);
assert(abs(S.distance - (edgeSample - 1) * pixelSize) <= 5 * pixelSize, ...
    "The crossing distance %.1f does not match its sample index", S.distance);
assert(S.confidence == "high", "A clean step was reported as low confidence");
assert(S.background < S.threshold && S.tissue > S.threshold, ...
    "The threshold did not fall between the background and tissue levels");

% Drawn the other way round, the same section has its background at the far
% end. Reading which end that is off the trace is the whole reason the search
% direction is not a convention nobody remembers to follow.
R = detect_brain_surface(distance, flipud(intensity));

assert(R.found, "No surface was found in the reversed profile: %s", R.message);
assert(R.direction == "reverse", "The reversed profile was searched from the wrong end");
assert(abs(R.index - (nSamples + 1 - edgeSample)) <= 5, ...
    "The reversed crossing came back at sample %.1f rather than near %d", ...
    R.index, nSamples + 1 - edgeSample);

% Named directions override the reading, so a caller who knows can say so.
F = detect_brain_surface(distance, flipud(intensity), direction = "forward");
assert(F.direction == "forward", "An explicit direction was not honored");

% A line that never leaves tissue has no surface on it, and saying so is the
% point: a mark guessed off a trace with no edge in it would be worse than
% none, because nothing downstream could tell the two apart.
inside = detect_brain_surface(distance, 200 - 0.2 * (0:nSamples - 1)');
assert(~inside.found, "A surface was invented in a profile with no background in it");
assert(inside.message ~= "", "Nothing was found and no reason was given");

flat = detect_brain_surface(distance, ones(nSamples, 1));
assert(~flat.found, "A surface was found in a flat profile");

% Below eight samples any answer would be decided by one or two of them.
short = detect_brain_surface((1:5)', [1; 1; 9; 9; 9]);
assert(~short.found, "A surface was found in a profile too short to hold one");

% Mismatched inputs are reported rather than thrown, because these come from a
% values file that anything on disk could have written.
ragged = detect_brain_surface((1:10)', (1:5)');
assert(~ragged.found, "Mismatched distance and intensity were not refused");

% What a cortical line actually looks like: slide, a dim rim at the pia, and
% then a slow climb to bright layers far inside. The mark belongs on the rim.
% A split between the trace's two levels puts it on the climb instead, a few
% hundred samples deep, which is the failure this shape is here to catch.
nCortex = 1300;
cortexEdge = 101;

cortex = synthetic_cortex_profile(nCortex, cortexEdge);

C = detect_brain_surface((0:nCortex - 1)', cortex, Background = 0);

assert(C.found, "No surface was found on a cortical profile: %s", C.message);
assert(C.backgroundSource == "caller", "The background passed in was not the one used");
assert(abs(C.index - cortexEdge) <= 5, ...
    "The cortical surface came back at sample %.1f rather than near %d, on the layers " + ...
    "rather than at the pia", C.index, cortexEdge);

% Measured against the slide, a line that never leaves tissue never comes down
% to background at either end, however dim one end of it is.
tissueOnly = cortex(cortexEdge + 50:end);
indoors = detect_brain_surface((0:numel(tissueOnly) - 1)', tissueOnly, Background = 0);
assert(~indoors.found, "A surface was found on a line lying wholly in tissue");
assert(contains(indoors.message, "inside tissue"), ...
    "A line lying in tissue was refused for the wrong reason: %s", indoors.message);

end

function check_image_background()
%CHECK_IMAGE_BACKGROUND The slide level IMAGE_BACKGROUND reads off the darkest
% part of an image.
% The point of averaging blocks before picking the darkest is that a noisy
% slide comes back at its mean, where a profile averaged across a band will sit,
% rather than at the low tail its darkest single pixels are. The noise is a
% fixed pattern rather than RANDN, so the check gives the same answer on every
% machine and every run.

[cols, rows] = meshgrid(1:400, 1:300);

noise = 20 * sin(7.3 * rows + 3.1 * cols) .* cos(2.9 * rows - 5.7 * cols);

img = 100 + noise;
img(:, 151:end) = img(:, 151:end) + 400;

level = image_background(img);

assert(abs(level - 100) < 3, ...
    "The slide came back at %.1f rather than near its mean of 100", level);
assert(min(img(:)) < 90, "The noise pattern is too weak to test anything");

% A background-subtracted page has a slide of zero, and must say so.
subtracted = max(img - 100, 0);
subtracted(:, 1:150) = 0;

assert(image_background(subtracted) == 0, "A zero slide did not read as zero");

% Colour planes are averaged, as MEASURE_LINE_PROFILE averages them.
rgb = cat(3, img, img, img);
assert(abs(image_background(rgb) - level) < 1e-9, "An RGB page read differently from its plane");

% Smaller than one block is not an error.
assert(image_background(magic(4)) == 1, "An image smaller than a block was not read pixel by pixel");

end

function intensity = synthetic_cortex_profile(nSamples, edgeSample)
%SYNTHETIC_CORTEX_PROFILE A line from the slide across the pia into cortex.
% Zero outside, as on a background-subtracted projection. Inside, a rim that
% fades over a dozen samples on top of layers that start dim and brighten
% slowly with depth, as far as the band reaches. The ripple is deterministic.

index = (1:nSamples)';

depth = index - edgeSample;
inside = depth >= 0;

intensity = zeros(nSamples, 1);
intensity(inside) = 20 + 230 * min(depth(inside) / 600, 1) .^ 2 + 30 * exp(-depth(inside) / 12);

intensity(inside) = intensity(inside) + 0.5 * sin(index(inside));

end

function intensity = synthetic_section_profile(nSamples, edgeSample)
%SYNTHETIC_SECTION_PROFILE A line that starts off the section and runs into it.
% Background, a step at EDGESAMPLE, then a slow falloff into the depth of the
% cortex, which is the shape these profiles actually have. The ripple stands in
% for sample noise and is deterministic, so the check gives the same answer on
% every machine and every run.

index = (1:nSamples)';

intensity = 10 * ones(nSamples, 1);

inside = index >= edgeSample;
intensity(inside) = 200 - 0.2 * (index(inside) - edgeSample);

intensity = intensity + 0.5 * sin(index);

end

function check_surface_mark_files()
%CHECK_SURFACE_MARK_FILES The sidecar a brain surface is stored in.
% The mark lives beside the .roi rather than inside it, so what is checked is
% the pairing of the two paths, the round trip, and -- the part that is easy to
% get wrong -- clearing a mark by removing the file rather than writing an
% empty one.

roiPath = string(tempname) + "_proj_roi.roi";
markPath = surface_mark_path(roiPath);

assert(markPath == erase(roiPath, ".roi") + "_surface.json", ...
    "The sidecar was not named after its ROI: %s", markPath);
assert(surface_mark_path("") == "", "A missing ROI path produced a sidecar path anyway");

cleanup = onCleanup(@() delete_if_present(markPath)); %#ok<NASGU>

% Nothing on disk yet, which has to read as "no mark" rather than as an error.
M = read_surface_mark(markPath);
assert(~M.isValid, "An absent sidecar was read as a mark");
assert(M.message ~= "", "An absent sidecar gave no reason");

geometry = struct( ...
    "x1", 100, "y1", 200, "x2", 700, "y2", 260, ...
    "surface", 123.5, ...
    "surfaceSource", "auto");

info = write_surface_mark(markPath, geometry);
assert(info.written, "The sidecar was not written");
assert(isfile(markPath), "WRITE_SURFACE_MARK reported a write but left no file");

M = read_surface_mark(markPath);
assert(M.isValid, "The written sidecar did not read back: %s", M.message);
assert(abs(M.offset - geometry.surface) < 1e-9, ...
    "The offset came back as %.6f rather than %.6f", M.offset, geometry.surface);
assert(M.x1 == geometry.x1 && M.y2 == geometry.y2, ...
    "The line the mark was made against did not survive the round trip");
assert(M.source == "auto", "The mark source came back as ""%s""", M.source);

% Clearing has to leave the section in the state it was in before it was ever
% marked, which is no file at all: a sidecar saying nothing would be a third
% state for everything downstream to distinguish.
geometry.surface = NaN;
info = write_surface_mark(markPath, geometry);

assert(~info.written, "Clearing a mark reported a write");
assert(~isfile(markPath), "Clearing a mark left the sidecar behind");

% A file that is not a mark must not throw when it is read: these sit in a data
% folder beside files written by Fiji and by hand.
fid = fopen(markPath, "w");
fprintf(fid, "not json at all");
fclose(fid);

M = read_surface_mark(markPath);
assert(~M.isValid, "A damaged sidecar was read as a mark");
assert(M.message ~= "", "A damaged sidecar gave no reason");

end

function check_roi_crop()
%CHECK_ROI_CROP Cut an image down to a line ROI's band, and turn it upright.
% Two ramps, one per page, make every pixel say where it came from: page 1
% holds 10*x and page 2 holds 10*y. So the crop can be checked for which
% pixels it took, which way it was turned, and that it was not mirrored.

folder = string(tempname);
mkdir(folder);
cleanup = onCleanup(@() rmdir(folder, "s")); %#ok<NASGU>

nRows = 120;
nCols = 200;
rampX = uint16(repmat(10 * (1:nCols), nRows, 1));
rampY = uint16(repmat(10 * (1:nRows)', 1, nCols));

pixelSize = 1.6572864;
description = sprintf("ImageJ=1.54f\nimages=2\nchannels=2\nslices=1\nunit=um\n");
imagePath = fullfile(folder, "sec_proj.tif");

imwrite(rampX, imagePath, "tif", Description = description, ...
    Resolution = 1 / pixelSize, Compression = "none");
imwrite(rampY, imagePath, "tif", WriteMode = "append", Description = description, ...
    Resolution = 1 / pixelSize, Compression = "none");

roi = struct("x1", 41, "y1", 61, "x2", 141, "y2", 61, "strokeWidth", 11, "surface", 20);

% Unrotated, the crop is the band's bounding box cut straight out: the same
% pixels, every page, in the same class and calibration.
C = crop_roi_image(imagePath, roi);

assert(C.outputPath == fullfile(folder, "sec_proj_roiCropped.tif"), ...
    "The crop was not saved beside the original with the default suffix: %s", C.outputPath);
assert(numel(imfinfo(C.outputPath)) == 2, "Not every page was cropped");

a = imread(C.outputPath, 1);
b = imread(C.outputPath, 2);

assert(isa(a, "uint16"), "The crop came back as %s rather than uint16", class(a));
assert(isequal(a, rampX(56:66, 41:141)) && isequal(b, rampY(56:66, 41:141)), ...
    "The unrotated crop is not the band's pixels unchanged");
assert(isequal(C.bounds, [41 56 101 11]), "Bounds came back as %s", mat2str(C.bounds));
assert(isequal(C.surfacePoint, [21 6]), ...
    "The surface mark landed at %s in the crop", mat2str(C.surfacePoint));

cal = imagej_pixel_size(C.outputPath);
assert(cal.isCalibrated && cal.unit == "um" && abs(cal.pixelSize - pixelSize) < 1e-6, ...
    "The crop lost the original's calibration");

% An existing crop is not replaced unless asked.
threw = false;

try
    crop_roi_image(imagePath, roi);
catch ME
    threw = ME.identifier == "crop_roi_image:exists";
end

assert(threw, "An existing crop was overwritten without overwrite = true");

% Rotated, the line runs down the crop from its start: row k is sample k of
% the profile, so page 1 climbs 10*x down the rows. Across, the band's upper
% edge (lower y) ends up on the right, which is a quarter turn clockwise and
% not its mirror image.
R = crop_roi_image(imagePath, roi, rotate = true, overwrite = true);

a = imread(R.outputPath, 1);
b = imread(R.outputPath, 2);

assert(isequal(size(a), [101 11]), "The rotated crop is %s", mat2str(size(a)));
assert(all(a == uint16(10 * (41:141)'), "all"), "Rows do not run along the line from its start");
assert(all(b(:, 1) == 660) && all(b(:, end) == 560), "The rotated crop is mirrored");
assert(isequal(R.surfacePoint, [6 21]), ...
    "The surface mark landed at %s in the rotated crop", mat2str(R.surfacePoint));

P = measure_line_profile(double(rampX), roi);
assert(max(abs(mean(double(a), 2) - P.intensity)) < 1e-9, ...
    "The rows of the rotated crop do not average to the measured profile");

% surfaceAt = "end" turns the line around.
E = crop_roi_image(imagePath, roi, rotate = true, surfaceAt = "end", suffix = "_end");
a = imread(E.outputPath, 1);

assert(a(1, 1) == 1410 && a(end, 1) == 410, "surfaceAt = ""end"" did not put the line's end on top");
assert(isequal(E.surfacePoint, [6 81]), ...
    "The surface mark measured from the end landed at %s", mat2str(E.surfacePoint));

% At an angle the samples are interpolated and rounded back to uint16, so the
% row means follow the profile to within half a count.
slanted = struct("x1", 30, "y1", 20, "x2", 150, "y2", 100, "strokeWidth", 7);
D = crop_roi_image(imagePath, slanted, rotate = true, suffix = "_slanted");
P = measure_line_profile(double(rampX), slanted);

assert(D.nOutside == 0, "A band inside the image reported samples outside it");
assert(max(abs(mean(double(imread(D.outputPath, 1)), 2) - P.intensity)) <= 0.5, ...
    "The rows of a slanted crop do not follow the measured profile");

% Padding past the image edge is filled and counted rather than invented;
% unrotated, it is clipped to the image instead.
edge = struct("x1", 3, "y1", 61, "x2", 50, "y2", 61, "strokeWidth", 5);
O = crop_roi_image(imagePath, edge, rotate = true, padding = 5, suffix = "_padded");
a = imread(O.outputPath, 1);

assert(isequal(size(a), [58 15]), "The padded crop is %s", mat2str(size(a)));
assert(O.nOutside == 45 && all(a(1:3, :) == 0, "all"), ...
    "Samples past the image edge were not filled: %d reported", O.nOutside);

U = crop_roi_image(imagePath, edge, padding = 5, suffix = "_clipped");
assert(isequal(U.bounds, [1 54 55 15]), "The padded crop was not clipped: %s", mat2str(U.bounds));

% A .roi path reads the same line and the sidecar's surface mark.
roiPath = fullfile(folder, "sec_proj_roi.roi");
write_imagej_roi(roiPath, roi);
write_surface_mark(surface_mark_path(roiPath), roi);

F = crop_roi_image(imagePath, roiPath, suffix = "_file");
assert(isequal(imread(F.outputPath, 1), imread(C.outputPath, 1)), ...
    "Cropping from the .roi file cut different pixels");
assert(isequal(F.surfacePoint, C.surfacePoint), "The sidecar's surface mark was not read");

end

function delete_if_present(filePath)
%DELETE_IF_PRESENT Remove a file the check may or may not have left behind.

if isfile(filePath)
    delete(filePath);
end

end

function check_surface_normalization()
%CHECK_SURFACE_NORMALIZATION Lining traces up on the brain surface they carry.
% The alignment this whole mark exists for, and the fallback that keeps it
% honest: a trace with no mark is put on its own line start and counted, rather
% than being left where it was and reading as though it had been aligned.

profiles = struct( ...
    distance = {(0:10:100)'; (0:10:100)'; (0:10:100)'}, ...
    intensity = {(1:11)'; (1:11)'; (1:11)'}, ...
    surface = {30; 70; NaN});

N = HistologyImageBrowser.normalizeProfiles(profiles, Distance = "surface");

assert(N.profiles(1).distance(1) == -30, ...
    "The first trace was not shifted onto its own surface");
assert(N.profiles(2).distance(1) == -70, ...
    "The second trace was not shifted onto its own surface");
assert(N.profiles(1).distance(4) == 0 && N.profiles(2).distance(8) == 0, ...
    "The marked surfaces did not land on zero");

% Unmarked falls back on the line start, which is the axis it already had.
assert(N.profiles(3).distance(1) == 0, ...
    "An unmarked trace was not put on its own line start");
assert(N.nUnmarked == 1, "Expected one unmarked trace, counted %d", N.nUnmarked);
assert(contains(N.xLabel, "surface"), "The distance axis was not relabelled: %s", N.xLabel);

% A trace built by a caller that knows nothing about surfaces has no field at
% all, which has to mean the same thing as an unmarked one rather than throw.
plain = struct(distance = (0:10:50)', intensity = (1:6)');
N = HistologyImageBrowser.normalizeProfiles(plain, Distance = "surface");

assert(N.nUnmarked == 1, "A trace with no surface field was not counted as unmarked");
assert(N.profiles(1).distance(1) == 0, "A trace with no surface field was not shifted to zero");

% Nothing but the distance axis moves, and the other mappings ignore the mark.
N = HistologyImageBrowser.normalizeProfiles(profiles, ...
    Distance = "percent", Normalization = "range");
assert(N.nUnmarked == 0, "A mapping that needs no mark counted unmarked traces");
assert(N.profiles(1).distance(end) == 100, ...
    "Percent of line stopped working once surfaces were in the traces");

end

function check_surface_marking(rootPath, metadataCSV)
%CHECK_SURFACE_MARKING Placing, moving, and clearing a brain surface in the GUI.
% Nothing is saved: this can run against the real dataset, so it stops short of
% the write exactly as CHECK_ROI_EDITING does, and leaves the edit reverted.

app = HistologyImageBrowser(rootPath, metadataCSV = metadataCSV);
closeApp = onCleanup(@() close(app.Fig)); %#ok<NASGU>

editable = find(app.View.RoiPath ~= "" & isfile(app.View.RoiPath), 1);

if isempty(editable)
    return
end

app.MaxTilesField.Value = 1;
app.ShowSurfaceCheck.Value = true;
app.CatalogTable.Selection = editable;
app.onSelectionChanged();

app.EditRoiButton.Value = true;
app.onToggleEditRoi();
leaveEdit = onCleanup(@() app.exitRoiEdit(false)); %#ok<NASGU>

assert(app.RoiEditStem == app.View.Stem(editable), "Editing did not start on the selected section");

% An ROI that came off disk keeps whatever mark it has. Opening an edit on one
% must not turn it into an unsaved change, which is what an automatic detect on
% every edit session would have done.
assert(~app.RoiEditDirty, "Opening an edit on an existing ROI marked it unsaved");

app.onClearSurface();

assert(~isfinite(app.RoiEditGeom.surface), "Clearing the mark left one behind");
assert(app.ClearSurfaceButton.Enable == "off", "Clear stayed live with nothing to clear");
assert(isempty(surface_marks(app)), "A tick was drawn for a line with no mark");

% Placed by hand, on the line, wherever the click lands. The projection is what
% makes a click near the line mean a depth along it.
G = app.RoiEditGeom;
lineLength = hypot(G.x2 - G.x1, G.y2 - G.y1);
unit = [G.x2 - G.x1, G.y2 - G.y1] / lineLength;
normal = [-unit(2), unit(1)];

target = 0.4 * lineLength;
click = [G.x1, G.y1] + target * unit + 25 * normal;

app.onSurfaceEditChanged(click, true);

assert(abs(app.RoiEditGeom.surface - target) < 1e-6, ...
    "A point 25 px off the line did not project onto it at %.1f, got %.1f", ...
    target, app.RoiEditGeom.surface);
assert(app.RoiEditDirty, "Marking the surface did not mark the edit unsaved");
assert(app.ClearSurfaceButton.Enable == "on", "Clear stayed grey with a mark to clear");

% A drag past either end stops at the end rather than running off the line,
% because the profile only exists between them.
app.onSurfaceEditChanged([G.x1, G.y1] - 500 * unit, true);
assert(app.RoiEditGeom.surface == 0, "A mark dragged past the start did not stop at it");

app.onSurfaceEditChanged([G.x2, G.y2] + 500 * unit, true);
assert(abs(app.RoiEditGeom.surface - lineLength) < 1e-6, ...
    "A mark dragged past the end did not stop at it");

app.onSurfaceEditChanged(click, true);

% The mark has to be readable off the tile and off the plot, and both follow
% the one switch.
point = HistologyImageBrowser.surfacePoint(app.RoiEditGeom);
assert(~isempty(point), "A marked line produced no surface point");
assert(abs(dot(point - [G.x1, G.y1], normal)) < 1e-6, "The surface point came off the line");

assert(~isempty(surface_marks(app)), "The marked surface was not ticked on the tile");
assert(~isempty(surface_rules(app)), "The marked surface was not ruled on the profile plot");

% The one overlay switch drawn in two places, so it has to reach both. Through
% the key rather than the callback, because RUNSHORTCUT is the route that could
% most easily have been left redrawing only the tiles.
app.runShortcut("toggleSurfaceOverlay");
assert(~app.ShowSurfaceCheck.Value, "The shortcut did not turn the marks off");
assert(isempty(surface_marks(app)), "The tick stayed on the tile with its switch off");
assert(isempty(surface_rules(app)), "The rule stayed on the plot with its switch off");

app.runShortcut("toggleSurfaceOverlay");
assert(app.ShowSurfaceCheck.Value, "The shortcut did not turn the marks back on");
assert(~isempty(surface_marks(app)), "The tick did not come back with its switch on");
assert(~isempty(surface_rules(app)), "The rule did not come back with its switch on");

% The profile the plot draws carries the mark on its own distance axis, which
% is what the alignment on that plot is done with.
P = app.readProfile(app.editedRow());
assert(P.hasData, "The edited section lost its profile");
assert(isfinite(P.surface), "The profile did not carry the brain surface mark");

expected = P.distance(1) + (app.RoiEditGeom.surface / lineLength) * ...
    (P.distance(end) - P.distance(1));
assert(abs(P.surface - expected) < 1e-6, ...
    "The mark landed at %.3f on the distance axis rather than %.3f", P.surface, expected);

% Aligning on it puts the surface at zero, which is the whole claim.
N = HistologyImageBrowser.normalizeProfiles( ...
    struct(distance = P.distance, intensity = P.intensity, surface = P.surface), ...
    Distance = "surface");
assert(abs(interp1(P.distance, N.profiles(1).distance, P.surface)) < 1e-6, ...
    "Aligning on the surface did not put it at zero");

% The plot itself has to survive the alignment, which is the one path that
% reads a field READ_TRACES has to have put on every trace.
app.ProfileDistanceDropDown.Value = "surface";
app.onProfileOptionChanged();

assert(~isempty(findobj(app.ProfileAxes, Type = "line")), ...
    "Aligning on the brain surface left the profile plot empty");

app.ProfileDistanceDropDown.Value = "none";
app.onProfileOptionChanged();

% Detection runs off the profile under the line, and either finds an edge or
% says it did not; both are acceptable against an arbitrary dataset, and
% neither may throw or leave the mark half set.
app.onDetectSurface();

if isfinite(app.RoiEditGeom.surface)
    assert(app.RoiEditGeom.surface >= 0 && app.RoiEditGeom.surface <= lineLength, ...
        "Detection put the surface off the line at %.1f", app.RoiEditGeom.surface);
    assert(app.RoiEditGeom.surfaceSource ~= "", ...
        "A placed mark was recorded with no source");
end

% Back to the file, mark and all, with nothing written.
app.onRevertRoiEdits();

assert(~app.RoiEditDirty, "Revert left the edit marked unsaved");

end

function marks = surface_marks(app)
%SURFACE_MARKS The brain surface ticks now drawn across the tiles.

marks = findobj(app.ImagePanel, Tag = "roiOverlay", UserData = "roiSurfaceMark");

end

function rules = surface_rules(app)
%SURFACE_RULES The brain surface rules now drawn on the profile plot.

rules = findobj(app.ProfileAxes, Type = "constantline");

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

% One row per ROI, not per section. A section measured across two regions has
% two sets of coordinates and two profiles, and there is no honest way to put
% them both on one row -- nor to pick one of them and call it the section's.
[expectedStems, expectedKeys] = expected_export_rows(app, rows);

assert(height(T) == numel(expectedStems), ...
    "Exported %d rows for the %d ROI(s) of %d selected sections", ...
    height(T), numel(expectedStems), height(rows));
assert(isequal(string(T.Stem), expectedStems), ...
    "The exported rows are not the sections that were selected");
assert(isequal(string(T.ROIKey), expectedKeys), ...
    "The exported rows are not the ROIs those sections carry");

wanted = ["SubjectID", "SampleID", "SectionID", "Hemisphere", "Stain", "ZPlane", ...
    "DateCode", "ImageNumber", "Protocol", "Series", "NameParsed", ...
    "Folder", "ImagePath", "RoiPath", "ValuesPaths", "AtlasPlate", "Status", "Notes", ...
    "ROIKey", "ROIName", ...
    "RoiState", "RoiX1", "RoiY1", "RoiX2", "RoiY2", "RoiWidth", "RoiLength", ...
    "SurfaceOffset", "SurfaceX", "SurfaceY", "SurfaceSource", ...
    "PixelSize", "PixelUnit", "ROILabel", "Profile"];

absent = wanted(~ismember(wanted, string(T.Properties.VariableNames)));
assert(isempty(absent), "The export is missing columns: %s", strjoin(absent, ", "));

for iRow = 1:height(T)
    source = rows(string(rows.Stem) == T.Stem(iRow), :);
    check_exported_row(app, T, source(1, :), T.ROIKey(iRow), iRow);
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

function [stems, keys] = expected_export_rows(app, rows)
%EXPECTED_EXPORT_ROWS The section and ROI of every row the export should hold.
% Built from the browser's own idea of which ROIs a section carries, so this
% says the export must cover all of them rather than restating the loop that
% produces it. A section with none still owes one row, which is where an
% unmeasured section shows up.

stems = strings(0, 1);
keys = strings(0, 1);

for iRow = 1:height(rows)
    rowKeys = app.roiKeysForRow(rows(iRow, :));

    if isempty(rowKeys)
        rowKeys = app.activeRoiKey(rows(iRow, :));
    end

    stems = [stems; repmat(string(rows.Stem(iRow)), numel(rowKeys), 1)]; %#ok<AGROW>
    keys = [keys; string(rowKeys(:))];                                   %#ok<AGROW>
end

end

function check_exported_row(app, T, row, key, iRow)
%CHECK_EXPORTED_ROW One exported row must agree with what the browser shows.
% ROIFORROW and READPROFILE are asked again rather than the files being read,
% because they are what the tiles and the profile plot are drawn from and the
% export is supposed to hand over exactly that. They are asked for the row's
% own ROI rather than for the section's default one, which is the whole point:
% an export that read the default would pass this check while quietly holding
% the wrong ROI's numbers.

R = app.roiForRow(row, key);
P = app.readProfile(row, key);
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

    % The brain surface belongs to this ROI, not to the section: each line
    % crosses it at its own depth, so an export reading the section's default
    % ROI would put one line's mark on another line's row.
    assert(isequaln(T.SurfaceOffset(iRow), R.surface), ...
        "Row %d exported the brain surface of a different ROI", iRow);
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

% The question the grid answers -- is this band square to the boundary -- is
% asked of a saved line as often as of one being dragged, so leaving the edit
% has to leave the rules on the tile.
stem = app.RoiEditStem;
app.EditRoiButton.Value = false;
app.exitRoiEdit(false);
app.refreshRoiEdit(stem);
clear leaveEdit

assert(app.RoiEditStem == "", "The edit session did not end");
assert(~isempty(band_grid_rules(app)), "The grid was dropped when the edit ended");

% The rules are interior ones, so they follow the band they rule: with the
% band overlay off there is no outline to bound them and no grid either.
app.ShowBandCheck.Value = false;
app.onDisplayOptionChanged();

assert(isempty(band_grid_rules(app)), "The grid outlived the band it rules");

app.ShowBandCheck.Value = true;
app.onDisplayOptionChanged();

assert(~isempty(band_grid_rules(app)), "The grid did not come back with the band");

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
check_roi_edit_keeps_images(app);
check_active_tile_is_marked(app);

end

function check_roi_edit_keeps_images(app)
%CHECK_ROI_EDIT_KEEPS_IMAGES An ROI session leaves the pictures where they are.
% Opening an edit, finishing a drag, reverting it, and closing the session all
% used to go through RENDERSELECTION, which destroys the tiled layout: with a
% grid of sections on screen that reread and restretched every one of them to
% move a line on one of them. Identity is the measure here for the same reason
% it is for an overlay toggle -- the layout and the drawn images have to be the
% same handles at the end as at the start.

if exist("images.roi.Line", "class") ~= 8
    return
end

editable = find(app.View.RoiPath ~= "" & isfile(app.View.RoiPath), 1);

if isempty(editable)
    return
end

% Two tiles wherever the dataset allows it, because the section that is not
% being edited is the one with something to lose by a full redraw.
last = min(editable + 1, height(app.View));

app.MaxTilesField.Value = 2;
app.CatalogTable.Selection = editable:last;
app.onSelectionChanged();

layout = app.ImageLayout;
images = findall(app.ImageLayout, Type = "image");

assert(~isempty(images), "No image was drawn for an ROI edit to leave alone");

app.EditRoiButton.Value = true;
app.onToggleEditRoi();
leaveEdit = onCleanup(@() app.exitRoiEdit(false)); %#ok<NASGU>

assert(app.RoiEditStem == app.View.Stem(editable), ...
    "The edit did not open on the first selected section");
assert(~isempty(app.RoiEditor) && isvalid(app.RoiEditor), "Opening an edit attached no line");

check_tiles_intact(app, layout, images, "Opening an ROI edit");

G = app.RoiEditGeom;
app.onRoiEditChanged([G.x1 + 1, G.y1; G.x2, G.y2], true);

assert(app.RoiEditDirty, "Moving an endpoint left the edit reading as clean");

check_tiles_intact(app, layout, images, "Finishing a drag");

app.onRevertRoiEdits();

assert(~app.RoiEditDirty, "Reverting left the edit dirty");

check_tiles_intact(app, layout, images, "Reverting an ROI edit");

% Clean by now, so closing the session cannot raise the unsaved-changes prompt
% and block the run on a dialog nobody is there to answer.
app.EditRoiButton.Value = false;
app.onToggleEditRoi();

assert(app.RoiEditStem == "", "Closing the session left the edit open");

check_tiles_intact(app, layout, images, "Leaving an ROI edit");

end

function check_tiles_intact(app, layout, images, what)
%CHECK_TILES_INTACT Assert one step reused the tiles rather than rebuilding them.

assert(isvalid(layout) && isequal(app.ImageLayout, layout), ...
    "%s rebuilt the tiled layout", what);
assert(all(isvalid(images)), "%s reread and redrew the images", what);

end

function check_active_tile_is_marked(app)
%CHECK_ACTIVE_TILE_IS_MARKED The tile the ROI controls act on says so, follows
%the user's pick, and every title is written inside its axes rather than above it.
% Which section Edit ROI lands on used to be a choice the browser made on the
% user's behalf -- the first of the selected rows -- and a silent choice is one
% the user only discovers by having to undo it. So exactly one drawn tile
% carries the mark, it is the tile ACTIVEROISTEM names, and SETROITARGET can
% move both to any other tile on screen without the pictures being redrawn:
% picking which section to edit must not cost a dozen images off disk, and must
% not narrow the selection either, which is what used to blow the picked
% section up to full screen.

nWanted = min(3, height(app.View));

if nWanted < 2
    return
end

app.MaxTilesField.Value = nWanted;
app.CatalogTable.Selection = 1:nWanted;
app.onSelectionChanged();

tiles = findall(app.ImageLayout, Type = "axes");

assert(numel(tiles) == nWanted, "Expected %d tiles, found %d", nWanted, numel(tiles));

assert(app.activeRoiStem() == app.View.Stem(1), ...
    "With nothing picked the ROI controls named a section other than the first drawn one");

check_one_tile_marked(app, string(app.View.Stem(1)));

layout = app.ImageLayout;
images = findall(app.ImageLayout, Type = "image");
selection = app.Selection;

wanted = string(app.View.Stem(nWanted));

assert(app.setRoiTarget(wanted), "The last drawn tile could not be made the ROI target");
assert(app.activeRoiStem() == wanted, ...
    "The ROI controls stayed on %s after %s was targeted", app.activeRoiStem(), wanted);

check_one_tile_marked(app, wanted);
check_tiles_intact(app, layout, images, "Moving the ROI target");

assert(isequal(app.Selection, selection), ...
    "Moving the ROI target changed the selection, which is what used to blow the tile up to full screen");

% A section with no tile on screen is declined outright rather than accepted
% and then quietly ignored, so the mark and the buttons cannot come apart.
assert(~app.setRoiTarget("not-a-section-in-this-view"), ...
    "A section with no tile on screen was accepted as the ROI target");

check_one_tile_marked(app, wanted);

% Handed back to the browser's own choice, so a later check starts where it
% expects rather than on whichever tile this one finished on.
app.RoiTargetStem = "";
app.markRoiTarget();

check_one_tile_marked(app, string(app.View.Stem(1)));

end

function check_one_tile_marked(app, wanted)
%CHECK_ONE_TILE_MARKED Exactly one drawn tile says the ROI controls act on it.

tiles = findall(app.ImageLayout, Type = "axes");

nMarked = 0;

for iTile = 1:numel(tiles)
    ax = tiles(iTile);
    label = findobj(ax, Tag = "tileTitle");

    assert(numel(label) == 1, "A tile drew %d labels inside its box", numel(label));
    assert(isempty(char(ax.Title.String)), ...
        "A tile left its label above the box as well as inside it");

    isMarked = contains(string(label.String), "ROI target");

    assert(isMarked == (HistologyImageBrowser.tileStem(ax) == wanted), ...
        "The ROI target mark is on the wrong tile: expected it on %s", wanted);

    % The frame is the half of the mark that survives being printed in grey,
    % so it has to agree with the words rather than being set once and left.
    assert((ax.LineWidth > 2) == isMarked, ...
        "A tile's frame weight disagreed with its label about being the ROI target");

    nMarked = nMarked + isMarked;
end

assert(nMarked == 1, "Expected exactly one tile marked as the ROI target, found %d", nMarked);

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

check_click_moves_roi_target(app);
check_context_targets_clicked_tile(app, menu);
check_context_item_writes_panel(app, menu);
check_stranded_menu_is_rebuilt(app);

end

function check_stranded_menu_is_rebuilt(app)
%CHECK_STRANDED_MENU_IS_REBUILT A menu found in another figure is replaced.
% MATLAB refuses to hand an object a menu from a different figure, and it
% errors rather than declining, so a menu that had come to belong elsewhere
% used to fail every redraw after it. The next redraw has to build a fresh one
% in the app figure instead.

other = figure(Visible = "off");
closeOther = onCleanup(@() close(other));

stranded = app.TileContextMenu;
stranded.Parent = other;

app.onSelectionChanged();

menu = app.TileContextMenu;

assert(isvalid(menu) && isequal(menu.Parent, app.Fig), ...
    "The redraw kept a context menu that belongs to another figure");
assert(~isvalid(stranded), "The stranded context menu was left behind");

check_tiles_carry_menu(app, menu);
check_profile_carries_menu(app);

end

function check_tiles_carry_menu(app, menu)
%CHECK_TILES_CARRY_MENU Every graphic on every tile answers both mouse buttons.
% The menu and the left-click that picks the tile ride on one walk over the
% axes and its contents, so they are checked together: an overlay object the
% walk missed would take the menu and the pick away at once, and would do it
% silently on whichever option happened to be switched on.

tiles = findall(app.ImageLayout, Type = "axes");

assert(~isempty(tiles), "No tiles were drawn to right-click");

for iTile = 1:numel(tiles)
    ax = tiles(iTile);

    assert(isequal(ax.ContextMenu, menu), "A tile axes raised no context menu");
    assert(isequal(ax.Title.ContextMenu, menu), "A tile title raised no context menu");
    assert(~isempty(ax.ButtonDownFcn), "A tile axes answered no left-click");

    % The image never receives the click itself, because DRAWIMAGETILE switches
    % its PickableParts off and the axes behind it answers instead; it still
    % has to carry the same menu, so the two cannot come apart.
    targets = [findobj(ax, Type = "image"); findobj(ax, Tag = "roiOverlay")];

    assert(~isempty(targets), "A tile drew neither an image nor an overlay");

    for iTarget = 1:numel(targets)
        assert(isequal(targets(iTarget).ContextMenu, menu), ...
            "A %s on a tile raised no context menu", targets(iTarget).Type);
        assert(~isempty(targets(iTarget).ButtonDownFcn), ...
            "A %s on a tile answered no left-click", targets(iTarget).Type);
    end
end

end

function check_profile_carries_menu(app)
%CHECK_PROFILE_CARRIES_MENU The profile axes and its traces raise their own menu.

menu = app.ProfileContextMenu;

assert(~isempty(menu) && isvalid(menu), "No profile context menu was built");
assert(isequal(app.ProfileAxes.ContextMenu, menu), "The profile axes raised no context menu");

% No left-click handler here. The plot draws every selected section at once, so
% there is no one section a click on it could be picking.
assert(isempty(app.ProfileAxes.ButtonDownFcn), ...
    "The profile axes took the tile click handler, which has no section to pick");

traces = findobj(app.ProfileAxes, Type = "line");

for iTrace = 1:numel(traces)
    assert(isequal(traces(iTrace).ContextMenu, menu), ...
        "A profile trace raised no context menu");
end

end

function check_click_moves_roi_target(app)
%CHECK_CLICK_MOVES_ROI_TARGET A left-click on a tile hands it the ROI controls.
% The click is answered by whatever graphic the pointer landed on rather than
% by the axes alone, so an overlay object is the thing clicked here: a tile
% that only answered clicks on its bare background would ignore the click
% wherever the band, the line, or the label covers the picture, which is most
% of where anyone aims.
%
% What it must not do is move the selection. Narrowing the selection to the
% clicked row is how this used to be done from the context menu, and it threw
% every other section off screen in the act of picking one of them.

rows = app.selectedRows();

if height(rows) < 2
    return
end

before = app.Selection;
wanted = string(rows.Stem(2));
ax = tile_for_stem(app, wanted);

clicked = findobj(ax, Tag = "roiOverlay");

if isempty(clicked)
    clicked = ax;
end

assert(~isempty(clicked(1).ButtonDownFcn), ...
    "A %s on a tile answered no left-click", clicked(1).Type);

clicked(1).ButtonDownFcn(clicked(1), struct());

assert(app.activeRoiStem() == wanted, ...
    "Clicking a tile left the ROI controls on %s rather than on %s", ...
    app.activeRoiStem(), wanted);

assert(isequal(app.Selection, before), ...
    "Clicking a tile changed the selection, which is what blew it up to full screen");

end

function check_context_targets_clicked_tile(app, menu)
%CHECK_CONTEXT_TARGETS_CLICKED_TILE Edit ROI edits the tile under the pointer.
% With several sections on screen the panel's own Edit ROI takes the marked
% tile, which starts out as the first drawn one, so the check that matters is
% on the second tile: right-clicking it has to reach its section rather than
% the one the panel would have chosen, and has to leave the rest of the
% selection on screen while it does.

if exist("images.roi.Line", "class") ~= 8
    return
end

rows = app.selectedRows();

if height(rows) < 2
    return
end

% Handed back to the browser's own choice first, so this check exercises the
% menu moving the target rather than finding it already moved by the click
% check above.
app.RoiTargetStem = "";
app.markRoiTarget();

before = app.Selection;
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

assert(isequal(app.Selection, before), ...
    "Edit ROI from the context menu narrowed the selection, which used to make the tile full screen");

assert(numel(findall(app.ImageLayout, Type = "axes")) == numel(before), ...
    "Editing from the context menu left %d of %d sections on screen", ...
    numel(findall(app.ImageLayout, Type = "axes")), numel(before));

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

function check_tracker_download_failure(rootPath, metadataCSV)
%CHECK_TRACKER_DOWNLOAD_FAILURE A tracker that cannot be reached costs only itself.
% The images, the profiles, and the catalog built from them are all on local
% disk. A published sheet that will not download used to unwind the whole load
% and leave the browser holding a table with no variables at all, which then
% failed a long way from the cause. What is checked here is that the load goes
% ahead, that it says what it lost, and that a configured CSV is read in place
% of the download when there is one.

app = HistologyImageBrowser(rootPath, metadataCSV = metadataCSV);
closeApp = onCleanup(@() delete(app.Fig));

loaded = height(app.Catalog);
assert(loaded > 0, "The dataset did not load before the tracker was broken");

% A link to the spreadsheet rather than to a published copy of it is refused
% before anything is sent, so this is the failure a dead sheet gives without
% needing a network to produce it.
app.PublishedUrl = "https://docs.google.com/spreadsheets/d/1abcdef/edit";

% Nothing to fall back to, so the load has to go ahead on the images alone.
app.MetadataPath = "";
app.onLoadData();

assert(height(app.Catalog) == loaded, ...
    "A failed download cost the catalog: %d sections of %d", height(app.Catalog), loaded);
assert(ismember("RoiPath", string(app.View.Properties.VariableNames)), ...
    "The view came back without the catalog's variables");
assert(~any(app.Catalog.InTracker), "Sections were marked tracked with no tracker read");
assert(all(isnan(app.Catalog.AtlasPlate)), "A plate number arrived with no tracker read");

assert(app.StatusLevel == "warning", ...
    "A degraded load was reported as %s rather than a warning", app.StatusLevel);

status = string(app.StatusLabel.Text);

assert(contains(status, "without the published tracker"), ...
    "The status bar does not say the tracker was missed: %s", status);
assert(~contains(status, newline), ...
    "The download error reached the status bar with its line breaks: %s", status);
assert(contains(status, "Plate") && contains(status, "Notes"), ...
    "The status bar does not name the columns that went blank: %s", status);

if metadataCSV == ""
    return
end

% With a CSV configured as well, the load is worth running against it rather
% than against nothing: it is the same tracker, exported by hand.
app.MetadataPath = metadataCSV;
app.onLoadData();

assert(any(app.Catalog.InTracker), ...
    "The tracker CSV was not read in place of the download");
assert(app.StatusLevel == "warning", ...
    "A load that fell back to the CSV was reported as %s", app.StatusLevel);
assert(contains(string(app.StatusLabel.Text), "tracker CSV"), ...
    "The status bar does not say which tracker was read: %s", app.StatusLabel.Text);

end
