function onRevertRoiEdits(obj)
%ONREVERTROIEDITS Drop unsaved changes and go back to the ROI on disk.
% The brain surface goes back with the line, because the mark is a point on it
% and the two are saved together: reverting to a file that carries a mark puts
% that mark back, and reverting to no file at all leaves the line where a fresh
% edit session would have left it, guess and all.

row = obj.editedRow();

if height(row) ~= 1
    return
end

% Clearing the edit first makes INITIALROIGEOMETRY read the file rather than
% hand back the geometry being reverted.
stem = obj.RoiEditStem;
obj.RoiEditStem = "";

geometry = obj.initialRoiGeometry(row);

obj.RoiEditStem = stem;

if isempty(geometry)
    obj.setWarning("Nothing to revert to for %s.", stem);
    return
end

obj.RoiEditGeom = geometry;
obj.RoiEditDirty = geometry.isNew;

% Back on the file's geometry, so the tile reads as the file rather than as
% whatever was last written from here.
obj.RoiSavedStem = "";
obj.RoiWidthField.Value = geometry.strokeWidth;

% Back on the saved geometry, the file beside it is the profile to show; only
% a line with nothing on disk needs one measured for it.
obj.RoiPreview = struct();

% INITIALROIGEOMETRY brings the brain surface back with the line, so a section
% that had one on disk is already marked. Only a line with nothing on disk gets
% a fresh guess, which is the same offer opening an edit on one makes, and it
% is the same guess -- so reverting a new line lands exactly where the edit
% session opened rather than a step short of it.
if geometry.isNew
    obj.updateRoiPreview();
    obj.detectSurface(Announce = false, Overwrite = false);
end

obj.updateRoiEditControls();
obj.refreshRoiEdit();

obj.setStatus("Reverted the ROI for %s to the file on disk.", stem);

end
