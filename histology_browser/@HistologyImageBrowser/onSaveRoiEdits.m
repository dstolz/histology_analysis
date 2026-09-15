function onSaveRoiEdits(obj)
%ONSAVEROIEDITS Write the edited ROI and its remeasured profile back to disk.
% The two files are rewritten together, because a moved line and the profile
% beside it are only meaningful as a pair. The ROI goes out in Fiji's own
% format, so the next run of the line-measure macro, and anyone opening the
% section in Fiji, sees exactly the line that was dragged here.
%
% Only the ROI being edited is touched. A section's other ROIs live in their
% own pair of files, named for their own key, so writing one can neither
% overwrite nor invalidate another.
%
% The brain surface mark goes out with them, into a small sidecar named after
% the .roi file. Fiji has no field for a point along a line, so the mark
% travels beside the ROI rather than inside it -- which also means clearing a
% mark has to remove that sidecar rather than write an empty one, so that an
% ROI either has a surface beside it or does not. Being named after the .roi
% file, the sidecar is per ROI as well.
%
% All three files are overwritten in place. Nothing is backed up, so a profile
% is only ever as recoverable as the images it was measured from.

row = obj.editedRow();

if height(row) ~= 1
    obj.setWarning("No ROI is being edited.");
    return
end

key = obj.RoiEditKey;
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

paths = resolve_output_paths(obj, row, key);

if paths.roiPath == ""
    obj.setError("No folder to save into for %s.", row.Stem);
    return
end

if ~confirm_new_files(obj, paths)
    obj.setWarning("Save cancelled; no files were written.");
    return
end

obj.setBusy("Saving ROI %s of %s ...", obj.roiName(key), row.Stem);

try
    write_imagej_roi(paths.roiPath, geometry, ...
        template = paths.template, ...
        name = roi_name(obj, geometry, paths));

    write_values_csv(paths.valuesPath, P.distance, P.intensity);

    % Last of the three, and the only one that can remove a file: a geometry
    % whose surface is NaN takes the sidecar away rather than leaving one
    % behind that says nothing.
    surface = write_surface_mark(surface_mark_path(paths.roiPath), geometry);
catch ME
    obj.setError("Could not save %s: %s", row.Stem, ME.message);
    uialert(obj.Fig, ME.message, "Save Failed");

    return
end

apply_saved_paths(obj, row, paths);
update_combined_profile(obj, paths.valuesPath, P);

obj.RoiEditDirty = false;

% The line now has a file behind it, so it is no longer a new one, and the ROI
% is flagged so the tile shows the write rather than only reporting it in a
% status message that the next action pushes off the bar.
if isfield(geometry, "isNew")
    geometry.isNew = false;
    obj.RoiEditGeom = geometry;
end

obj.RoiSavedStem = string(row.Stem);
obj.RoiSavedKey = key;

% The files on disk are the truth from here on, so the preview is dropped and
% the redraw reads back what was just written.
obj.RoiPreview = struct();

obj.updateRoiEditControls();
obj.refreshRoiEdit();

obj.setSuccess("Saved %s and %s for ROI %s: %d samples, %s.%s", ...
    filename(paths.roiPath), filename(paths.valuesPath), obj.roiName(key), ...
    P.nSamples, describe_calibration(P), surface_note(surface));

end

function proceed = confirm_new_files(obj, paths)
%CONFIRM_NEW_FILES Ask before adding files the dataset did not have before.
% Rewriting a pair that already exists is the ordinary case and goes through
% without a prompt. Creating one is different: it adds a profile the analysis
% pipeline will pick up, so it is confirmed by name first.

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

function paths = resolve_output_paths(obj, row, key)
%RESOLVE_OUTPUT_PATHS Decide which .roi and values file this edit rewrites.
% An ROI that already has either file keeps it where it already lives. One
% that has neither gets the names the line-measure macro would have written
% for it, so a file written here and a file written by Fiji are the same file.

paths = struct( ...
    "roiPath", "", ...
    "valuesPath", "", ...
    "template", "", ...
    "key", key, ...
    "isNewRoi", false, ...
    "isNewValues", false);

stem = string(row.Stem);
folder = resolve_folder(row);

if folder == ""
    return
end

entry = obj.roiEntry(row, key);
base = stem + "_proj" + key_suffix(key);

paths.roiPath = entry.roiPath;

if paths.roiPath == ""
    paths.roiPath = fullfile(folder, base + "_roi.roi");
    paths.isNewRoi = true;
end

if isfile(paths.roiPath)
    paths.template = paths.roiPath;
end

paths.valuesPath = entry.valuesPath;

if paths.valuesPath == ""
    paths.valuesPath = fullfile(folder, base + "_values.csv");
    paths.isNewValues = true;
end

end

function suffix = key_suffix(key)
%KEY_SUFFIX The part of a sidecar filename that names which ROI it holds.
% A section's first ROI carries no label, because that is what
% MACRO_Batch_LineMeasure writes and what every dataset measured before a
% section could hold more than one ROI already has on disk. Rewriting those
% files under a new name would leave the originals behind as a second copy of
% the same ROI, so A keeps the macro's name and the letters after it are
% spelled out.

if string(key) == "A"
    suffix = "";
    return
end

suffix = "_" + string(key);

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

function name = roi_name(obj, geometry, paths)
%ROI_NAME Settle the name stored inside the .roi file, which is what Fiji's
% ROI manager shows.
%
% A name already in the file is kept, because it may have been set in Fiji and
% overwriting it is not this save's business. Otherwise the ROI is given what
% the browser calls it, so a key that has been named after its region carries
% that name into Fiji rather than only appearing here.

name = string(geometry.name);

if name ~= ""
    return
end

name = obj.roiName(paths.key);

if name ~= paths.key
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
% The ROI may be one the section did not have at all a moment ago, so it is
% added to the section's ROI list when it is not already on it, and the two
% path columns beside that list are filled in for it either way.

index = [];

if height(T) == 0
    return
end

index = find(string(T.Stem) == stem, 1);

if isempty(index)
    return
end

keys = string(T.RoiKeys{index});
roiPaths = string(T.RoiPaths{index});
valuesPaths = string(T.RoiValues{index});

slot = find(keys == paths.key, 1);

if isempty(slot)
    keys(end + 1, 1) = paths.key;
    roiPaths(end + 1, 1) = "";
    valuesPaths(end + 1, 1) = "";
    slot = numel(keys);
end

roiPaths(slot) = paths.roiPath;
valuesPaths(slot) = paths.valuesPath;

T.RoiKeys{index} = keys;
T.RoiPaths{index} = roiPaths;
T.RoiValues{index} = valuesPaths;
T.NRois(index) = numel(keys);
T.ROI(index) = join(keys(:)', ", ");

% The primary ROI path settles which folder a section belongs to, so a section
% that had no .roi file at all now has one.
if T.RoiPath(index) == ""
    T.RoiPath(index) = paths.roiPath;
end

if paths.isNewValues
    allValues = T.ValuesPaths{index};
    allValues(end + 1, 1) = paths.valuesPath;
    T.ValuesPaths{index} = allValues;

    labels = T.ROILabels{index};
    labels(end + 1, 1) = paths.key;
    T.ROILabels{index} = labels;

    T.NProfiles(index) = numel(allValues);

    if T.Status(index) == "image only"
        T.Status(index) = "image + profile";
    end
end

end

function refresh_table_row(obj, viewIndex)
%REFRESH_TABLE_ROW Update the results table without disturbing the selection.
% REFRESHCATALOGTABLE would reset the selection to the first row and end the
% edit, so the cells that can change here are written in place instead.

if isempty(viewIndex) || isempty(obj.CatalogTable) || ~isvalid(obj.CatalogTable)
    return
end

data = obj.CatalogTable.Data;

if ~istable(data) || height(data) < viewIndex
    return
end

data.ROIs(viewIndex) = obj.describeRoiList(obj.View(viewIndex, :));
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

function note = surface_note(surface)
%SURFACE_NOTE Say what happened to the brain surface sidecar.
% Written and removed are both worth a word, because neither is visible in the
% two filenames the message already names and both change what the profile
% plot can align on.

if surface.written
    note = sprintf(" Brain surface at %.0f px written beside it.", surface.offset);
    return
end

note = " No brain surface marked.";

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
