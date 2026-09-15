function R = roiForRow(obj, row, key)
%ROIFORROW Return one of a section's line ROIs, to draw and to measure.
% While an ROI is being edited the unsaved geometry wins over the file on
% disk, so the overlay, the profile preview, and the save all read the same
% numbers instead of each going back to their own source.
%
% Parameters
%   row: One catalog row.
%   key: Which of the section's ROIs to return. Defaults to the one the edit
%       controls are pointed at, which is what a caller wanting "the" ROI of a
%       section means.
%
% Returns
%   R: Struct with fields isValid, isLine, isEditing, state, key, x1, y1, x2,
%      y2, strokeWidth, name, surface, surfaceSource, and roiPath. The name is
%      the one stored inside the .roi file, which Fiji shows; what the browser
%      calls the ROI comes from ROINAME and the key. The state is what the
%      overlay draws itself from: "none" when there is no line, "file" for one
%      read off disk, "clean" while editing a line that still matches its file,
%      "dirty" or "new" while it does not, and "saved" just after a write.
%
% The surface is the distance from the line's start to the brain surface, in
% pixels along the line, and NaN when the line has none. It is resolved here
% rather than beside each of its readers for the same reason the geometry is:
% the tick on the tile, the marker on the profile plot, the save, and the
% workspace export all have to agree about where it is, and an unsaved mark has
% to win over the sidecar exactly as an unsaved line wins over the .roi file.
%
% It belongs to the ROI rather than to the section: each line crosses the
% surface at its own depth, so the sidecar read is the one beside this ROI's
% own .roi file.

arguments
    obj
    row table
    key (1,1) string = obj.activeRoiKey(row)
end

entry = obj.roiEntry(row, key);

R = struct( ...
    "isValid", false, ...
    "isLine", false, ...
    "isEditing", false, ...
    "state", "none", ...
    "key", key, ...
    "x1", NaN, "y1", NaN, "x2", NaN, "y2", NaN, ...
    "strokeWidth", 0, ...
    "name", "", ...
    "surface", NaN, ...
    "surfaceSource", "", ...
    "roiPath", entry.roiPath);

justSaved = obj.RoiSavedStem ~= "" && height(row) == 1 ...
    && string(row.Stem) == obj.RoiSavedStem && key == obj.RoiSavedKey;

if obj.isEditingRoi(row, key)
    geometry = obj.RoiEditGeom;

    R.isValid = true;
    R.isLine = true;
    R.isEditing = true;
    R.state = edit_state(obj, geometry, justSaved);
    R.x1 = geometry.x1;
    R.y1 = geometry.y1;
    R.x2 = geometry.x2;
    R.y2 = geometry.y2;
    R.strokeWidth = geometry.strokeWidth;
    R.name = geometry.name;
    [R.surface, R.surfaceSource] = edit_surface(geometry);

    return
end

if R.roiPath == "" || ~isfile(R.roiPath)
    return
end

F = read_imagej_roi(R.roiPath);

if ~F.isValid || ~F.isLine
    return
end

R.isValid = true;
R.isLine = true;
R.x1 = F.x1;
R.y1 = F.y1;
R.x2 = F.x2;
R.y2 = F.y2;
R.strokeWidth = F.strokeWidth;
R.name = F.name;

[R.surface, R.surfaceSource] = file_surface(R.roiPath);

% An ROI written a moment ago keeps its confirmation after the edit session
% ends, so the save stays visible on the line it was made on.
if justSaved
    R.state = "saved";
else
    R.state = "file";
end

end

function [surface, source] = edit_surface(geometry)
%EDIT_SURFACE Read the surface off the geometry an edit session carries.
% Absent on a geometry built before this field existed, and on one that was
% never marked, which are the same thing to everything downstream.

surface = NaN;
source = "";

if ~isfield(geometry, "surface")
    return
end

candidate = double(geometry.surface);

if ~isscalar(candidate) || ~isfinite(candidate)
    return
end

surface = candidate;
source = "manual";

if isfield(geometry, "surfaceSource") && geometry.surfaceSource ~= ""
    source = string(geometry.surfaceSource);
end

end

function [surface, source] = file_surface(roiPath)
%FILE_SURFACE Read the surface mark stored beside a line ROI on disk.
% A damaged or absent sidecar leaves the line unmarked rather than raising:
% these files sit in a data folder beside ones written by Fiji and by hand,
% and one bad sidecar must not stop a section from being drawn.

surface = NaN;
source = "";

M = read_surface_mark(surface_mark_path(roiPath));

if ~M.isValid
    return
end

surface = M.offset;
source = M.source;

if source == ""
    source = "manual";
end

end

function state = edit_state(obj, geometry, justSaved)
%EDIT_STATE Name where the geometry being edited stands against its file.

if obj.RoiEditDirty
    if isfield(geometry, "isNew") && geometry.isNew
        state = "new";
    else
        state = "dirty";
    end

    return
end

if justSaved
    state = "saved";
    return
end

state = "clean";

end
