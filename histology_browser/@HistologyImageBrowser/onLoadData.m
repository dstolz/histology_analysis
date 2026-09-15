function onLoadData(obj)
%ONLOADDATA Run COMBINE_VALUES_CSV and build the image catalog from its output.

rootPath = strtrim(obj.RootPath);
metadataPath = strtrim(obj.MetadataPath);

% The three tracker sources in the order they are preferred: the sheet read
% over the API is the most current and the only one a review can be written
% back to, the published copy is current and needs no credentials, and the CSV
% is whatever was last exported by hand. Only the first one that is set is
% read, so the others stay configured as fallbacks rather than having to be
% cleared to get out of the way.
useSheet = obj.SheetUrl ~= "";
usePublished = ~useSheet && obj.PublishedUrl ~= "";

if rootPath == "" || ~isfolder(rootPath)
    obj.setError("Root folder does not exist: %s", rootPath);
    uialert(obj.Fig, "Select a valid root folder first.", "Invalid Root Folder");
    return
end

% The CSV is only checked when it is the one that will be used. A stale path
% left over from before either sheet was configured is not worth refusing a
% load over, since nothing is going to read it.
if ~useSheet && ~usePublished && metadataPath ~= "" && ~isfile(metadataPath)
    obj.setError("Tracker CSV does not exist: %s", metadataPath);
    uialert(obj.Fig, "The tracker CSV does not exist: " + metadataPath, "Invalid Tracker CSV");
    return
end

obj.setBusy("Loading %s ...", rootPath);

dlg = uiprogressdlg(obj.Fig, ...
    Title = "Loading Histology Dataset", ...
    Message = "Scanning for values files...", ...
    Cancelable = "on", ...
    Indeterminate = "off", ...
    Value = 0);

obj.LoadMenu.Enable = "off";
restoreMenu = onCleanup(@() restore_load_menu(obj, dlg));

try
    combineArgs = { ...
        "continueOnError", true, ...
        "progressFcn", @(i, n, f) update_progress(dlg, i, n, f), ...
        "cancelRequestedFcn", @() dlg.CancelRequested};

    % Either sheet is read before the values files are walked, so a tracker
    % that cannot be reached is reported before the slow part of the load
    % rather than after it. The published copy arrives as a temporary CSV,
    % which is removed when this function returns, however it returns.
    if useSheet
        dlg.Message = "Reading the tracker from Google Sheets...";
        drawnow;

        trackerTable = read_sheet_tracker(obj);
        combineArgs = [{"metadataTable", trackerTable}, combineArgs];
    else
        if usePublished
            dlg.Message = "Downloading the published tracker...";
            drawnow;

            metadataPath = fetch_published_tracker(obj.PublishedUrl);
            removeDownload = onCleanup(@() delete(metadataPath));
        end

        if metadataPath ~= ""
            combineArgs = [{"metadataCSV", metadataPath}, combineArgs];
        end
    end

    S = combine_values_csv(rootPath, combineArgs{:});

    dlg.Indeterminate = "on";
    dlg.Message = "Cataloging images...";

    if isfield(S, "metadata") && isfield(S.metadata, "table")
        metadataTable = S.metadata.table;
    else
        metadataTable = table();
    end

    % The pattern is handed down rather than read from preferences inside the
    % catalog builder, so the same build can be run from a script against a
    % pattern the browser is not configured with.
    C = build_histology_image_catalog(rootPath, ...
        metadataTable = metadataTable, ...
        filenamePattern = obj.FilenamePattern);

    obj.Data = S;
    obj.Catalog = C;
    obj.ImageCache = containers.Map("KeyType", "char", "ValueType", "any");
    obj.CacheOrder = strings(0, 1);

    obj.refreshFilterChoices();
    obj.applyFilters();
    obj.savePreferences();

    [summary, level] = summarize_load(S, C);

    if useSheet
        summary = summary + sprintf(" Tracker read from the '%s' tab.", obj.SheetTab);
    elseif usePublished
        summary = summary + " Tracker downloaded from the published sheet.";
    end

    obj.pushStatus(level, "%s", summary);

catch ME
    obj.setError("Load failed: %s", ME.message);
    uialert(obj.Fig, ME.message, "Load Failed");
end

clear restoreMenu

end

function trackerTable = read_sheet_tracker(obj)
%READ_SHEET_TRACKER Fetch the tracker, saying plainly when it cannot be reached.
% The Sheets errors are precise about what is wrong but say it in Google's
% terms, so the one thing they cannot say is added here: which of the browser's
% settings to go and look at.

tracker = obj.sheetTracker();

try
    trackerTable = tracker.metadataTable(refresh = true);
catch ME
    error("HistologyImageBrowser:SheetUnreadable", ...
        "Could not read the '%s' tab: %s\n\nCheck Dataset > Google Sheet " + ...
        "Tracker > Configure, and that the sheet is shared with the " + ...
        "service account.", obj.SheetTab, ME.message)
end

for iWarning = 1:numel(tracker.Warnings)
    obj.pushStatus("warning", "%s", tracker.Warnings(iWarning));
end

end

function update_progress(dlg, iFile, nFiles, filePath)
%UPDATE_PROGRESS Advance the progress dialog while values files are read.

if ~isvalid(dlg)
    return
end

dlg.Value = min(1, iFile / max(nFiles, 1));

[~, name, ext] = fileparts(char(filePath));
dlg.Message = sprintf("%d/%d: %s", iFile, nFiles, [name ext]);

end

function restore_load_menu(obj, dlg)
%RESTORE_LOAD_MENU Re-enable the load menu item and close the dialog.

if isvalid(obj.LoadMenu)
    obj.LoadMenu.Enable = "on";
end

if isvalid(dlg)
    close(dlg);
end

end

function [text, level] = summarize_load(S, C)
%SUMMARIZE_LOAD Describe what was loaded, including anything that failed.
% The severity follows the content: anything skipped or unparsed is a warning,
% because the browser still opens and the gap is easy to miss otherwise.

level = "success";

nSections = height(C);

if nSections == 0
    text = "No images found under the selected root folder.";
    level = "warning";
    return
end

nWithProfile = sum(C.NProfiles > 0);

text = sprintf("%d sections, %d with profile data. Values files: %d of %d read.", ...
    nSections, nWithProfile, S.summary.nSucceeded, S.summary.nDiscoveredFiles);

if S.summary.nFailed > 0
    text = text + sprintf(" %d values file(s) failed to parse.", S.summary.nFailed);
    level = "warning";
end

nUnparsed = sum(~C.NameParsed);

if nUnparsed > 0
    text = text + sprintf(" %d filename(s) did not match the naming convention.", nUnparsed);
    level = "warning";
end

end
