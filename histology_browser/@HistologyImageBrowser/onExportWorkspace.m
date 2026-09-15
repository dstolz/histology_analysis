function onExportWorkspace(obj, variableName)
%ONEXPORTWORKSPACE Copy the selected sections into a table in the base workspace.
% Finding the sections happens in this window, but the analysis that follows
% happens at the command line, and the only way across used to be rebuilding
% the catalog by hand and re-reading every ROI and values file. This hands over
% exactly what is on screen instead: one row per ROI of each selected section,
% carrying the tokenized name, the files it was read from, the tracker's
% annotations, the line ROI in pixel coordinates, and the profile measured
% through it. A section measured across several regions contributes one row per
% region, told apart by ROIKey, with its own columns repeated down them.
%
% The profile is packed into a single cell per row, each holding its own
% two-column table, rather than being unnested into one row per sample. A
% flattened export would repeat all forty section columns for each of the
% hundreds of samples in a profile, and the first thing any analysis does is
% group those samples back by ROI anyway.
%
% ROI coordinates are exported in pixels, as they are stored and as the overlay
% draws them, with the calibration beside them rather than applied to them.
% Converting here would have discarded the pixel geometry that the .roi files,
% Fiji, and this window all speak, and a section whose image carries no
% calibration would have come out with no coordinates at all.
%
% ROIFORROW and READPROFILE supply the geometry and the samples, so a line that
% has been dragged but not saved exports as the line the user can see rather
% than as the one still on disk.
%
% Parameters
%   variableName: Name to assign in the base workspace. Asked for when it is
%       omitted. A name passed in is taken as already decided and overwrites
%       without a prompt, which is what keeps this callable from a script or a
%       test where a modal dialog would stall.
%
% See also ONEXPORTVIEW, SELECTEDROWS, ROIFORROW, READPROFILE, IMAGEJ_PIXEL_SIZE.

arguments
    obj
    variableName (1,1) string = ""
end

rows = obj.selectedRows();

if isempty(rows) || height(rows) == 0
    % The status bar rather than a dialog: the table the selection is missing
    % from is right beside it, and a modal would only stand between the user
    % and the fix.
    obj.setWarning("Select at least one section to export.");
    return
end

% Only a name the user typed here gets the prompts. One handed in came from a
% caller that has already decided, and stopping to ask would defeat the point.
asked = variableName == "";

if asked
    variableName = ask_for_name();

    if variableName == ""
        obj.setStatus("Export to the workspace was cancelled.");
        return
    end
end

if ~isvarname(variableName)
    obj.setWarning("""%s"" is not a valid MATLAB variable name, so nothing was exported.", ...
        variableName);
    return
end

replacing = exists_in_base(variableName);

if replacing && asked && ~confirm_overwrite(obj, variableName)
    obj.setStatus("Export to the workspace was cancelled.");
    return
end

obj.setBusy("Building a table of %d selected section(s) ...", height(rows));

try
    T = build_export_table(obj, rows);
catch ME
    obj.setError("Export to the workspace failed: %s", ME.message);
    uialert(obj.Fig, ME.message, "Export Failed");
    return
end

assignin("base", char(variableName), T);

% HEAD is what makes the export visible, and it prints rows without naming the
% variable they went into, so the name is written above them.
fprintf("\n%s =\n\n", variableName);
head(T);

if replacing
    obj.setWarning("Exported %d ROI(s) from %d section(s) to ""%s"", replacing what was there.", ...
        height(T), height(rows), variableName);
    return
end

obj.setSuccess("Exported %d ROI(s) from %d section(s) to ""%s"" in the base workspace.", ...
    height(T), height(rows), variableName);

end

function name = ask_for_name()
%ASK_FOR_NAME Ask which variable the table should land in.
% INPUTDLG rather than a hand-built modal, because it is already what
% PROMPTDISPLAYNUMBER uses for the one other typed value this window asks for.
% Returns "" when the prompt was cancelled.

answer = inputdlg("Base workspace variable name:", "Export to Workspace", ...
    [1 50], {'histology'});

if isempty(answer)
    name = "";
    return
end

name = strtrim(string(answer{1}));

end

function tf = exists_in_base(name)
%EXISTS_IN_BASE True when the base workspace already holds this name.
% WHO is asked rather than EXIST, which also answers for every function on the
% path and would warn about clobbering a variable that is not there.

tf = ismember(name, string(evalin("base", "who")));

end

function tf = confirm_overwrite(obj, name)
%CONFIRM_OVERWRITE Ask before replacing a variable that is already there.

choice = uiconfirm(obj.Fig, ...
    """" + name + """ already exists in the base workspace. Replace it?", ...
    "Replace Variable", ...
    Options = ["Replace", "Cancel"], ...
    DefaultOption = "Cancel", ...
    CancelOption = "Cancel", ...
    Icon = "warning");

tf = string(choice) == "Replace";

end

function T = build_export_table(obj, rows)
%BUILD_EXPORT_TABLE Assemble one row per ROI of each selected section.
% Columns the catalog already carries are copied across rather than rebuilt, so
% an exported column cannot come out under a different name or a different type
% than the one the browser filters and sorts on.
%
% A section carrying several ROIs contributes one row each, identified by
% ROIKey. One row per section would have had to pick an ROI to export, and the
% only available answer -- the one the edit controls happen to be pointed at --
% would have made the same selection export different numbers depending on
% where a dropdown was left, and dropped the rest of the measurements without
% saying so. The section's own columns repeat down its ROIs, which is what
% makes the table joinable and groupable on either.

tokens = ["Stem", "SubjectID", "SampleID", "SectionID", "Hemisphere", ...
    "Stain", "ZPlane", "DateCode", "ImageNumber", "Protocol", "Series", "NameParsed"];

% Everything the tracker contributes. It is provenance for the numbers sitting
% in the same row -- which plate, which slide, how hard it was lit -- so it
% travels with them instead of having to be joined on again downstream.
tracker = ["Status", "InTracker", "AtlasPlate", "Content", "Slide", ...
    "SliceID", "ImageDate", "LaserPower", "ProcessingID", "Notes"];

[nSections, rows, keys] = expand_by_roi(obj, rows);

% Read once and handed to both the geometry and the profile, because a
% profile's distance axis is in the same unit as the pixel size that measured
% it and neither should be able to report a different one.
C = calibrations(obj, rows);

T = [ ...
    pick_columns(rows, tokens), ...
    roi_identity(obj, keys), ...
    source_files(obj, rows), ...
    pick_columns(rows, tracker), ...
    roi_geometry(obj, rows, C, keys), ...
    profile_column(obj, rows, C, keys)];

T.Properties.Description = sprintf( ...
    "%d ROI(s) across %d histology section(s) exported from %s on %s.", ...
    height(T), nSections, obj.RootPath, ...
    string(datetime("now", Format = "yyyy-MM-dd HH:mm:ss")));

end

function [nSections, rows, keys] = expand_by_roi(obj, rows)
%EXPAND_BY_ROI Repeat each selected section once per ROI it carries.
% A section with no ROI at all still gets exactly one row, under the key a new
% ROI on it would take, so that it appears in the export with its coordinates
% NaN and its state "none" rather than vanishing from it. That is the same
% treatment an unmeasured section has always had.
%
% Returns
%   nSections: How many sections went in, for the counts that are reported in
%       sections rather than in rows.
%   rows: The selected rows, repeated.
%   keys: The ROI key each repeated row stands for.

nSections = height(rows);

index = zeros(0, 1);
keys = strings(0, 1);

for iRow = 1:nSections
    rowKeys = obj.roiKeysForRow(rows(iRow, :));

    if isempty(rowKeys)
        rowKeys = obj.activeRoiKey(rows(iRow, :));
    end

    index = [index; repmat(iRow, numel(rowKeys), 1)];  %#ok<AGROW>
    keys = [keys; string(rowKeys(:))];                 %#ok<AGROW>
end

rows = rows(index, :);

end

function R = roi_identity(obj, keys)
%ROI_IDENTITY Name the ROI each row stands for, by key and by display name.
% The key is what the filenames on disk are keyed by and is what an analysis
% should group on; the name is whatever it has been called in this browser,
% which is a label rather than an identifier and may not have been set at all.

R = table(keys, arrayfun(@(k) obj.roiName(k), keys), ...
    VariableNames = ["ROIKey", "ROIName"]);

end

function P = pick_columns(rows, names)
%PICK_COLUMNS Copy the named catalog columns, skipping any this catalog lacks.
% Every catalog carries all of them today, tracker loaded or not, but one built
% by an older or a newer scan might not, and losing a column is a far better
% outcome than refusing to export anything.

names = names(ismember(names, string(rows.Properties.VariableNames)));

P = rows(:, names);
P.Properties.RowNames = {};

end

function F = source_files(obj, rows)
%SOURCE_FILES Name the files each section was read from.
% The four rendition columns collapse to the one path RESOLVEIMAGEPATH settled
% on, because that is the image the exported coordinates and calibration belong
% to; exporting all four would have left the reader to work out which of them
% the numbers referred to. The chosen variant travels beside it so that choice
% is not lost with them.

n = height(rows);
imagePath = strings(n, 1);

for iRow = 1:n
    imagePath(iRow) = obj.resolveImagePath(rows(iRow, :));
end

chosen = table( ...
    repmat(string(obj.VariantDropDown.Value), n, 1), ...
    imagePath, ...
    VariableNames = ["Variant", "ImagePath"]);

F = [pick_columns(rows, "Folder"), chosen, ...
    pick_columns(rows, ["RoiPath", "ValuesPaths", "NProfiles"])];

end

function C = calibrations(obj, rows)
%CALIBRATIONS Read the spatial calibration behind each selected section.
% The image profiles are measured from rather than the one on screen, because
% that is what both the ROI coordinates and the distance axis were measured in;
% a section being viewed as a downsized composite would otherwise report a
% scale that fits none of the numbers beside it.

n = height(rows);
C = repmat(imagej_pixel_size(""), n, 1);

for iRow = 1:n
    C(iRow) = imagej_pixel_size(obj.measureImagePath(rows(iRow, :)));
end

end

function G = roi_geometry(obj, rows, C, keys)
%ROI_GEOMETRY Export each line ROI in pixels, with its calibration beside it.
% One row per ROI, in the order EXPAND_BY_ROI put them in. An ROI with no line
% still gets a row: its coordinates are NaN and its state says "none", which
% keeps the columns numeric and lets an analysis filter on ISFINITE rather than
% on a column of mixed types.

n = height(rows);

state = strings(n, 1);
x1 = nan(n, 1);
y1 = nan(n, 1);
x2 = nan(n, 1);
y2 = nan(n, 1);
strokeWidth = nan(n, 1);
lineLength = nan(n, 1);
pixelSize = nan(n, 1);

for iRow = 1:n
    R = obj.roiForRow(rows(iRow, :), keys(iRow));
    state(iRow) = R.state;

    if ~R.isValid || ~R.isLine
        continue
    end

    x1(iRow) = R.x1;
    y1(iRow) = R.y1;
    x2(iRow) = R.x2;
    y2(iRow) = R.y2;
    strokeWidth(iRow) = R.strokeWidth;

    % Measured off the endpoints rather than read from the file, because an
    % unsaved drag has no file to read it from and the two have to agree.
    lineLength(iRow) = hypot(R.x2 - R.x1, R.y2 - R.y1);
end

% NaN wherever the image carries no calibration, so a distance in pixels can
% never be read as one in microns.
calibrated = [C.isCalibrated]';
pixelSize(calibrated) = [C(calibrated).pixelSize]';

G = table(state, x1, y1, x2, y2, strokeWidth, lineLength, pixelSize, [C.unit]', ...
    VariableNames = ["RoiState", "RoiX1", "RoiY1", "RoiX2", "RoiY2", ...
    "RoiWidth", "RoiLength", "PixelSize", "PixelUnit"]);

end

function P = profile_column(obj, rows, C, keys)
%PROFILE_COLUMN Pack each ROI's measured profile into a single cell.
% An ROI that was never measured gets an empty two-column table rather than an
% empty cell, so VERTCAT over the column works without testing every element
% first and a plotting loop draws nothing instead of erroring.

n = height(rows);

samples = cell(n, 1);
roiLabel = strings(n, 1);
source = strings(n, 1);
nSamples = zeros(n, 1);

for iRow = 1:n
    D = obj.readProfile(rows(iRow, :), keys(iRow));

    roiLabel(iRow) = D.roiLabel;
    source(iRow) = D.source;

    if D.hasData
        samples{iRow} = profile_table(D.distance, D.intensity, C(iRow).unit);
        nSamples(iRow) = numel(D.distance);
        continue
    end

    samples{iRow} = profile_table(zeros(0, 1), zeros(0, 1), C(iRow).unit);
end

P = table(roiLabel, source, nSamples, samples, ...
    VariableNames = ["ROILabel", "ProfileSource", "NSamples", "Profile"]);

end

function S = profile_table(distance, intensity, unit)
%PROFILE_TABLE Build the two-column table one section's profile is packed as.
% The distance axis is in whatever unit the profile was measured in, which is
% the image's own calibration and is pixels when it had none, so the unit is
% recorded on the column instead of being left to be inferred from the numbers.

S = table(double(distance(:)), double(intensity(:)), ...
    VariableNames = ["Distance", "Intensity"]);

S.Properties.VariableUnits = [string(unit), ""];

end
