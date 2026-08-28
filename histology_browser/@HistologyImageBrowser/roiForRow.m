function R = roiForRow(obj, row)
%ROIFORROW Return the line ROI to draw and measure for one catalog row.
% While a section is being edited the unsaved geometry wins over the file on
% disk, so the overlay, the profile preview, and the save all read the same
% numbers instead of each going back to their own source.
%
% Returns
%   R: Struct with fields isValid, isLine, isEditing, state, x1, y1, x2, y2,
%      strokeWidth, name, and roiPath. The state is what the overlay draws
%      itself from: "none" when there is no line, "file" for one read off
%      disk, "clean" while editing a line that still matches its file,
%      "dirty" or "new" while it does not, and "saved" just after a write.

R = struct( ...
    "isValid", false, ...
    "isLine", false, ...
    "isEditing", false, ...
    "state", "none", ...
    "x1", NaN, "y1", NaN, "x2", NaN, "y2", NaN, ...
    "strokeWidth", 0, ...
    "name", "", ...
    "roiPath", string(row.RoiPath));

justSaved = obj.RoiSavedStem ~= "" && string(row.Stem) == obj.RoiSavedStem;

if obj.isEditingRow(row)
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

% A section written a moment ago keeps its confirmation after the edit session
% ends, so the save stays visible on the tile it was made on.
if justSaved
    R.state = "saved";
else
    R.state = "file";
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
