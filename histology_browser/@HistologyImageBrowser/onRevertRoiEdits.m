function onRevertRoiEdits(obj)
%ONREVERTROIEDITS Drop unsaved changes and go back to the ROI on disk.

row = obj.editedRow();

if height(row) ~= 1
    return
end

% Clearing the edit first makes INITIALROIGEOMETRY read the file rather than
% hand back the geometry being reverted.
stem = obj.RoiEditStem;
key = obj.RoiEditKey;
obj.RoiEditStem = "";

geometry = obj.initialRoiGeometry(row, key);

obj.RoiEditStem = stem;

if isempty(geometry)
    obj.setWarning("Nothing to revert ROI %s of %s to.", obj.roiName(key), stem);
    return
end

obj.RoiEditGeom = geometry;
obj.RoiEditDirty = geometry.isNew;

% Back on the file's geometry, so the tile reads as the file rather than as
% whatever was last written from here.
obj.RoiSavedStem = "";
obj.RoiSavedKey = "";
obj.RoiWidthField.Value = geometry.strokeWidth;

% Back on the saved geometry, the file beside it is the profile to show; only
% a line with nothing on disk needs one measured for it.
obj.RoiPreview = struct();

if geometry.isNew
    obj.updateRoiPreview();
end

obj.updateRoiEditControls();
obj.renderSelection();

obj.setStatus("Reverted ROI %s of %s to the file on disk.", obj.roiName(key), stem);

end
