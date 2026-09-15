function loadPreferences(obj)
%LOADPREFERENCES Restore saved paths and display settings.
% Every value is validated before use so a stale preference cannot leave a
% control in an invalid state.

group = char(obj.PrefGroup);

rootPath = read_pref(group, "LastRootPath", "");

if rootPath ~= "" && isfolder(rootPath)
    obj.RootPath = rootPath;
end

metadataPath = read_pref(group, "LastMetadataPath", "");

if metadataPath ~= "" && isfile(metadataPath)
    obj.MetadataPath = metadataPath;
end

apply_filename_pattern(obj, read_pref(group, "FilenamePattern", ""));

% Restored without being read. A saved URL is checked when it is set and again
% at every load, and opening the browser should not wait on the network to find
% out something the next load will say anyway.
publishedUrl = read_pref(group, "PublishedUrl", "");

if publishedUrl ~= "" && contains(publishedUrl, "/spreadsheets/d/e/")
    obj.PublishedUrl = publishedUrl;
end

apply_sheet_settings(obj, group);

apply_dropdown(obj.VariantDropDown, read_pref(group, "Variant", ""));
apply_dropdown(obj.ColormapDropDown, read_pref(group, "Colormap", ""));
apply_stain_colormaps(obj, group);
apply_catalog_columns(obj, group);
apply_roi_names(obj, group);

apply_numeric(obj.LowPercentileField, read_pref(group, "LowPercentile", []));
apply_numeric(obj.HighPercentileField, read_pref(group, "HighPercentile", []));
apply_numeric(obj.MaxTilesField, read_pref(group, "MaxTiles", []));

apply_checkbox(obj.ShowRoiCheck, read_pref(group, "ShowRoi", []));
apply_checkbox(obj.ShowBandCheck, read_pref(group, "ShowBand", []));
apply_checkbox(obj.ShowBandGridCheck, read_pref(group, "ShowBandGrid", []));
apply_checkbox(obj.ColorByIntensityCheck, read_pref(group, "ColorByIntensity", []));
apply_dropdown(obj.ProfileLayoutDropDown, profile_layout_pref(group));
apply_numeric(obj.ProfileSizeField, read_pref(group, "ProfileSize", []));

% APPLY_DROPDOWN drops a code the current release no longer offers, so a
% normalization that has been renamed or withdrawn comes back as the setting
% that changes nothing rather than leaving the dropdown showing a choice
% NORMALIZEPROFILES would then have to fall back from on every redraw.
apply_dropdown(obj.ProfileNormDropDown, read_pref(group, "ProfileNorm", ""));
apply_dropdown(obj.ProfileScopeDropDown, read_pref(group, "ProfileScope", ""));
apply_dropdown(obj.ProfileDistanceDropDown, read_pref(group, "ProfileDistance", ""));
apply_numeric(obj.RoiWidthField, read_pref(group, "RoiWidth", []));
apply_background(obj, read_pref(group, "ImageBackground", []));
apply_figure_geometry(obj, group);

% The restored paths are only visible on the Dataset menu and in the title bar.
obj.refreshDatasetMenu();

obj.applyViewLayout();

% Every control above was written without firing its callback, so the Display
% menu is told once, here, rather than a dozen times on the way down.
obj.syncDisplayMenu();

end

function apply_filename_pattern(obj, pattern)
%APPLY_FILENAME_PATTERN Restore a saved filename pattern that still compiles.
% This one preference is text a user wrote rather than a value the app chose,
% so it is the one most able to come back unusable: a preference file can be
% hand-edited or half-written, and a regular expression that compiled when it
% was saved is not guaranteed to compile under the release that reads it. It is
% therefore compiled here before it is adopted, and one that fails is dropped
% for the built-in convention rather than left to throw on the next load.

if isempty(pattern) || ~isstring(pattern) || ~isscalar(pattern) || pattern == ""
    return
end

if ~HistologyImageBrowser.checkFilenamePattern(pattern)
    return
end

% Restoring a choice is not making one, so nothing is written back and nothing
% is announced on a status bar the user has not looked at yet.
obj.applyFilenamePattern(pattern, persist = false);

end

function apply_sheet_settings(obj, group)
%APPLY_SHEET_SETTINGS Restore which sheet the tracker is read from.
% A key file that has since been moved or deleted is dropped, but the sheet
% itself is kept: naming a new key file is a smaller thing to ask than naming
% the spreadsheet again, and the sheet is still readable with one.

sheetUrl = read_pref(group, "SheetUrl", "");

if sheetUrl == ""
    return
end

try
    gsheet.spreadsheetId(sheetUrl);
catch
    return
end

obj.SheetUrl = sheetUrl;

sheetTab = read_pref(group, "SheetTab", "");

if sheetTab ~= ""
    obj.SheetTab = sheetTab;
end

credentials = read_pref(group, "SheetCredentials", "");

if credentials ~= "" && isfile(credentials)
    obj.SheetCredentials = credentials;
end

end

function apply_figure_geometry(obj, group)
%APPLY_FIGURE_GEOMETRY Restore where the window sat and how it was shown.

apply_figure_position(obj, read_pref(group, "FigurePosition", []));

state = read_pref(group, "FigureWindowState", "");

if ismember(state, ["maximized", "fullscreen"])
    obj.Fig.WindowState = state;
end

end

function apply_figure_position(obj, position)
%APPLY_FIGURE_POSITION Reopen the window where it was left, when that is still
% a place it can be reached. A position saved on a monitor that has since been
% detached, or one too small to work in, would strand the window, so it is
% dropped and BUILDUI's own placement stands.

if isempty(position) || ~isnumeric(position) || numel(position) ~= 4
    return
end

position = double(position(:)');

minSize = [400 300];

if any(~isfinite(position)) || any(position(3:4) < minSize)
    return
end

if ~on_screen(position)
    return
end

obj.Fig.Position = position;

end

function tf = on_screen(position)
%ON_SCREEN True when enough of a window rectangle lands on an attached monitor
% for its title bar to be grabbable.

minOverlap = [120 60];

monitors = get(groot, "MonitorPositions");
tf = false;

for iMonitor = 1:size(monitors, 1)
    monitor = monitors(iMonitor, :);

    overlap = [ ...
        min(position(1) + position(3), monitor(1) + monitor(3)) - max(position(1), monitor(1)), ...
        min(position(2) + position(4), monitor(2) + monitor(4)) - max(position(2), monitor(2))];

    if all(overlap >= minOverlap)
        tf = true;
        return
    end
end

end

function apply_background(obj, value)
%APPLY_BACKGROUND Restore the saved image panel background.
% Anything that is not a plain RGB triplet in range is ignored, leaving the
% panel's own default in place.

if isempty(value) || ~isnumeric(value) || numel(value) ~= 3
    return
end

value = double(value(:)');

if any(~isfinite(value)) || any(value < 0) || any(value > 1)
    return
end

obj.ImageBackground = value;
obj.applyImageBackground();

end

function code = profile_layout_pref(group)
%PROFILE_LAYOUT_PREF Read the saved layout, honoring the older on/off flag.

code = read_pref(group, "ProfileLayout", "");

if code ~= ""
    return
end

% Sessions saved before the layout choice existed recorded only whether the
% profile plot was shown at all.
wasShown = read_pref(group, "ShowProfile", []);

if ~isempty(wasShown) && (islogical(wasShown) || isnumeric(wasShown)) && ~logical(wasShown(1))
    code = "hidden";
end

end

function apply_stain_colormaps(obj, group)
%APPLY_STAIN_COLORMAPS Restore the colormap remembered for each stain.
% The pairs are dropped rather than trusted when the two saved lists disagree
% in length, or when a saved colormap is no longer offered, so a stale
% preference cannot name a colormap the dropdown does not have.

stains = string(read_pref(group, "ColormapStains", strings(0, 1)));
choices = string(read_pref(group, "ColormapChoices", strings(0, 1)));

stains = stains(:);
choices = choices(:);

if isempty(stains) || numel(stains) ~= numel(choices)
    return
end

keep = stains ~= "" & ismember(choices, string(obj.ColormapDropDown.Items));

obj.ColormapStains = stains(keep);
obj.ColormapChoices = choices(keep);

end

function apply_catalog_columns(obj, group)
%APPLY_CATALOG_COLUMNS Restore the Sections arrangement and the column sort.
% Two preferences that have to be judged together. A saved arrangement can name
% a column a later release stopped offering, and a saved sort can name a column
% the saved arrangement does not show -- either on its own would leave the
% table ordered by something invisible, or empty. APPLYCATALOGCOLUMNS settles
% the arrangement first and drops a sort its columns cannot account for, so
% this only has to refuse what is not a column name at all.
%
% Anything that is not text is refused before APPLYCATALOGCOLUMNS is asked to
% convert it, because a preference file can be hand-edited and STRING throws on
% some of what could be in one.

columns = read_pref(group, "CatalogColumns", strings(0, 1));

if ~is_text(columns)
    columns = strings(0, 1);
end

% Handed over even when it is empty, so an arrangement that validates down to
% nothing comes back as the default rather than as whatever the property held.
obj.applyCatalogColumns(string(columns(:))', persist = false);

column = read_pref(group, "CatalogSortColumn", "");
direction = read_pref(group, "CatalogSortDirection", "ascend");

% Cleared before the saved sort is judged, rather than only once one has been
% accepted. Preferences can be reloaded onto a browser that is already sorted,
% and a saved sort naming a column this arrangement no longer shows has to
% leave no sort at all: returning early without clearing would keep the table
% ordered by a column nobody can see, which is the state this validation
% exists to prevent rather than one it may fall back to.
obj.CatalogSortColumn = "";
obj.CatalogSortDirection = "ascend";
obj.CatalogSortPreset = "";

if ~is_text(column) || ~isscalar(string(column)) || ~ismember(string(column), obj.CatalogColumns)
    return
end

if ~is_text(direction) || ~ismember(string(direction), ["ascend", "descend"])
    direction = "ascend";
end

obj.CatalogSortColumn = string(column);
obj.CatalogSortDirection = string(direction);

% APPLYFILTERS clears the column sort when the Sort by preset has moved since
% the sort was made, and a restored sort was made under whatever the preset now
% reads, so it starts life agreeing with it rather than being thrown away on
% the first filter.
obj.CatalogSortPreset = string(obj.SortDropDown.Value);

end

function tf = is_text(value)
%IS_TEXT True for something STRING can be asked to convert without throwing.
% Cell arrays of char are included because that is the shape a preference
% written by an older release, or by hand, can come back in.

tf = isstring(value) || ischar(value) || iscellstr(value);

end

function apply_roi_names(obj, group)
%APPLY_ROI_NAMES Restore what each ROI key is called.
% The pairs are dropped rather than trusted when the two saved lists disagree
% in length, for the same reason the stain colormaps are: half a pairing says
% nothing about which name went with which key. Unlike the colormaps, nothing
% here is checked against a list of what is offered, because a key is whatever
% the filenames on disk turn out to hold.

keys = string(read_pref(group, "RoiNameKeys", strings(0, 1)));
labels = string(read_pref(group, "RoiNameLabels", strings(0, 1)));

keys = keys(:);
labels = labels(:);

if isempty(keys) || numel(keys) ~= numel(labels)
    return
end

keep = keys ~= "" & labels ~= "" & ~ismissing(keys) & ~ismissing(labels);

obj.RoiNameKeys = keys(keep);
obj.RoiNameLabels = labels(keep);

end

function value = read_pref(group, name, defaultValue)
%READ_PREF Read one preference, falling back to a default.

value = defaultValue;

if ~ispref(group, char(name))
    return
end

try
    value = getpref(group, char(name));
catch
    value = defaultValue;
end

if ischar(value)
    value = string(value);
end

end

function apply_dropdown(control, value)
%APPLY_DROPDOWN Apply a saved dropdown choice when it is still offered.

if isempty(value) || (isstring(value) && value == "")
    return
end

if isempty(control.ItemsData)
    if ismember(value, string(control.Items))
        control.Value = value;
    end

    return
end

for iItem = 1:numel(control.ItemsData)
    if isequal(string(control.ItemsData{iItem}), string(value))
        control.Value = control.ItemsData{iItem};
        return
    end
end

end

function apply_numeric(control, value)
%APPLY_NUMERIC Apply a saved numeric value when it is inside the limits.

if isempty(value) || ~isnumeric(value) || ~isscalar(value) || ~isfinite(value)
    return
end

if value < control.Limits(1) || value > control.Limits(2)
    return
end

control.Value = value;

end

function apply_checkbox(control, value)
%APPLY_CHECKBOX Apply a saved checkbox state.

if isempty(value) || ~(islogical(value) || isnumeric(value)) || ~isscalar(value)
    return
end

control.Value = logical(value);

end
