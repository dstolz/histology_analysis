function onSaveRoiEdits(obj)
%ONSAVEROIEDITS Write the edited ROI and its remeasured profile back to disk.
% The two files are rewritten together, because a moved line and the profile
% beside it are only meaningful as a pair. The ROI goes out in Fiji's own
% format, so the next run of the line-measure macro, and anyone opening the
% section in Fiji, sees exactly the line that was dragged here.
%
% Both files are overwritten in place. Nothing is backed up, so a profile is
% only ever as recoverable as the images it was measured from.

row = obj.editedRow();

if height(row) ~= 1
    obj.setWarning("No ROI is being edited.");
    return
end

geometry = obj.RoiEditGeom;

if hypot(geometry.x2 - geometry.x1, geometry.y2 - geometry.y1) < 1
    obj.setError("The ROI line has no length. Drag one end before saving.");
    return
end

P = obj.RoiPreview;

if ~(isfield(P, "hasData") && P.hasData)
    obj.updateRoiPreview();
    P = obj.RoiPreview;
end

if ~(isfield(P, "hasData") && P.hasData)
    obj.setError("Could not measure a profile for %s, so nothing was saved.", row.Stem);
    uialert(obj.Fig, ...
        "The profile could not be measured, so neither file was written.", ...
        "Save Failed");

    return
end

paths = resolve_output_paths(row);

if paths.roiPath == ""
    obj.setError("No folder to save into for %s.", row.Stem);
    return
end

if ~confirm_new_files(obj, paths)
    obj.setWarning("Save cancelled; no files were written.");
    return
end

obj.setBusy("Saving the ROI and profile for %s ...", row.Stem);

try
    write_imagej_roi(paths.roiPath, geometry, ...
        template = paths.template, ...
        name = roi_name(geometry, paths));

    write_values_csv(paths.valuesPath, P.distance, P.intensity);
catch ME
    obj.setError("Could not save %s: %s", row.Stem, ME.message);
    uialert(obj.Fig, ME.message, "Save Failed");

    return
end

apply_saved_paths(obj, row, paths);
update_combined_profile(obj, paths.valuesPath, P);

obj.RoiEditDirty = false;

% The files on disk are the truth from here on, so the preview is dropped and
% the redraw reads back what was just written.
obj.RoiPreview = struct();

obj.updateRoiEditControls();
obj.renderSelection();

obj.setSuccess("Saved %s and %s: %d samples, %s.%s", ...
    filename(paths.roiPath), filename(paths.valuesPath), P.nSamples, ...
    describe_calibration(P), extra_values_note(paths));

end

function proceed = confirm_new_files(obj, paths)
%CONFIRM_NEW_FILES Ask before adding files the dataset did not have before.
% Rewriting a pair that already exists is the ordinary case and goes through
% without a prompt. Creating one is different: it adds a section to what the
% analysis pipeline will pick up, so it is confirmed by name first.

proceed = true;

created = strings(0, 1);

if paths.isNewRoi
    created(end + 1, 1) = filename(paths.roiPath);
end

if paths.isNewValues
    created(end + 1, 1) = filename(paths.valuesPath);
end

if isempty(created)
    return
end

choice = uiconfirm(obj.Fig, ...
    "These files do not exist yet and will be created in" + newline + ...
    fileparts(paths.roiPath) + newline + newline + join(created, newline), ...
    "Create New Files?", ...
    Options = ["Create", "Cancel"], ...
    DefaultOption = "Create", ...
    CancelOption = "Cancel", ...
    Icon = "question");

proceed = string(choice) == "Create";

end

function paths = resolve_output_paths(row)
%RESOLVE_OUTPUT_PATHS Decide which .roi and values file this edit rewrites.
% An existing pair is rewritten where it already lives. A section that never
% had either gets the names the line-measure macro would have written.

paths = struct( ...
    "roiPath", "", ...
    "valuesPath", "", ...
    "template", "", ...
    "roiLabel", "", ...
    "isNewRoi", false, ...
    "isNewValues", false, ...
    "nOtherValues", 0);

stem = string(row.Stem);
folder = resolve_folder(row);

if folder == ""
    return
end

paths.roiPath = string(row.RoiPath);

if paths.roiPath == ""
    paths.roiPath = fullfile(folder, stem + "_proj_roi.roi");
    paths.isNewRoi = true;
end

if isfile(paths.roiPath)
    paths.template = paths.roiPath;
end

valuesPaths = row.ValuesPaths{1};
roiLabels = row.ROILabels{1};

if isempty(valuesPaths)
    paths.valuesPath = fullfile(folder, stem + "_proj_values.csv");
    paths.isNewValues = true;
    return
end

% The first profile is the one the browser plots, so it is the one an edit
% rewrites; any others are left alone and reported.
paths.valuesPath = valuesPaths(1);
paths.nOtherValues = numel(valuesPaths) - 1;

if ~isempty(roiLabels)
    paths.roiLabel = roiLabels(1);
end

end

function folder = resolve_folder(row)
%RESOLVE_FOLDER Find the folder the section's files belong in.

folder = string(row.Folder);

if folder ~= "" && isfolder(folder)
    return
end

candidates = [string(row.RoiPath), string(row.ProjPath), string(row.MidPath), ...
    string(row.CompositePath), string(row.RawPath)];
candidates = candidates(candidates ~= "");

folder = "";

for iCandidate = 1:numel(candidates)
    candidate = string(fileparts(candidates(iCandidate)));

    if candidate ~= "" && isfolder(candidate)
        folder = candidate;
        return
    end
end

end

function name = roi_name(geometry, paths)
%ROI_NAME Keep the ROI's stored name, or take the one Fiji would have given it.

name = string(geometry.name);

if name ~= ""
    return
end

[~, base] = fileparts(paths.roiPath);
name = string(base);

end

function apply_saved_paths(obj, row, paths)
%APPLY_SAVED_PATHS Point the catalog at files this save has just created.

if ~paths.isNewRoi && ~paths.isNewValues
    return
end

stem = string(row.Stem);

obj.Catalog = adopt_paths(obj.Catalog, stem, paths);
[obj.View, viewIndex] = adopt_paths(obj.View, stem, paths);

refresh_table_row(obj, viewIndex);

end

function [T, index] = adopt_paths(T, stem, paths)
%ADOPT_PATHS Record the new files on one catalog row.

index = [];

if height(T) == 0
    return
end

index = find(string(T.Stem) == stem, 1);

if isempty(index)
    return
end

T.RoiPath(index) = paths.roiPath;

if ~paths.isNewValues
    return
end

valuesPaths = T.ValuesPaths{index};
valuesPaths(end + 1, 1) = paths.valuesPath;
T.ValuesPaths{index} = valuesPaths;

roiLabels = T.ROILabels{index};
roiLabels(end + 1, 1) = paths.roiLabel;
T.ROILabels{index} = roiLabels;

T.NProfiles(index) = numel(valuesPaths);

if T.Status(index) == "image only"
    T.Status(index) = "image + profile";
end

end

function refresh_table_row(obj, viewIndex)
%REFRESH_TABLE_ROW Update the results table without disturbing the selection.
% REFRESHCATALOGTABLE would reset the selection to the first row and end the
% edit, so the two cells that can change here are written in place instead.

if isempty(viewIndex) || isempty(obj.CatalogTable) || ~isvalid(obj.CatalogTable)
    return
end

data = obj.CatalogTable.Data;

if ~istable(data) || height(data) < viewIndex
    return
end

data.Prof(viewIndex) = obj.View.NProfiles(viewIndex);
data.Status(viewIndex) = obj.View.Status(viewIndex);

obj.CatalogTable.Data = data;

end

function update_combined_profile(obj, valuesPath, P)
%UPDATE_COMBINED_PROFILE Put the new samples into the loaded dataset.
% READPROFILE prefers the COMBINE_VALUES_CSV output, so leaving the old rows
% in place would show the previous profile until the dataset was reloaded. A
% file the combiner never read is left out, and falls back to the CSV.

if ~isfield(obj.Data, "combined") || ~istable(obj.Data.combined) || height(obj.Data.combined) == 0
    return
end

T = obj.Data.combined;
varNames = string(T.Properties.VariableNames);

if ~all(ismember(["SourceFilePath", "distance_pixel_index", "intensity"], varNames))
    return
end

isFile = string(T.SourceFilePath) == valuesPath;

if ~any(isFile)
    return
end

% Every column except the samples is constant per file, so one existing row
% supplies the annotations for the replacements.
template = T(find(isFile, 1), :);
replacement = repmat(template, numel(P.distance), 1);
replacement.distance_pixel_index = P.distance;
replacement.intensity = P.intensity;

T(isFile, :) = [];
obj.Data.combined = [T; replacement];

end

function note = extra_values_note(paths)
%EXTRA_VALUES_NOTE Say when other profiles for the section were left alone.

note = "";

if paths.nOtherValues > 0
    note = sprintf(" %d other profile file(s) for this section were left unchanged.", ...
        paths.nOtherValues);
end

end

function text = describe_calibration(P)
%DESCRIBE_CALIBRATION State the distance units the profile was written with.

if isfield(P, "pixelSizeSource") && P.pixelSizeSource ~= ""
    text = sprintf("%.5g %s", P.pixelSize, P.pixelSizeSource);
    return
end

text = sprintf("%.5g per sample", P.pixelSize);

end

function name = filename(p)
%FILENAME Reduce a path to its filename for a status message.

[~, base, ext] = fileparts(p);
name = base + ext;

end
