function onLoadData(obj)
%ONLOADDATA Run COMBINE_VALUES_CSV and build the image catalog from its output.

rootPath = strtrim(obj.RootPath);
metadataPath = strtrim(obj.MetadataPath);

if rootPath == "" || ~isfolder(rootPath)
    obj.setError("Root folder does not exist: %s", rootPath);
    uialert(obj.Fig, "Select a valid root folder first.", "Invalid Root Folder");
    return
end

if metadataPath ~= "" && ~isfile(metadataPath)
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

    if metadataPath ~= ""
        combineArgs = [{"metadataCSV", metadataPath}, combineArgs];
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
    obj.pushStatus(level, "%s", summary);

catch ME
    obj.setError("Load failed: %s", ME.message);
    uialert(obj.Fig, ME.message, "Load Failed");
end

clear restoreMenu

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
