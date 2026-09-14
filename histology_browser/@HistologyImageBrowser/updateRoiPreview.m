function updateRoiPreview(obj)
%UPDATEROIPREVIEW Remeasure the profile under the unsaved ROI position.
% The preview is what the profile plot and the ROI shading show while a line
% is being moved, and it is what gets written when the edit is saved, so the
% picture on screen and the file on disk cannot disagree.

obj.RoiPreview = struct();

row = obj.editedRow();

if height(row) ~= 1
    return
end

M = obj.loadMeasureImage(row);

if ~M.hasImage
    obj.setWarning("Cannot remeasure %s: %s.", row.Stem, M.message);
    return
end

P = measure_line_profile(M.img, obj.RoiEditGeom, pixelSize = M.pixelSize);

if ~P.hasData
    obj.setWarning("Cannot remeasure %s: %s", row.Stem, P.message);
    return
end

P.pixelSizeSource = M.pixelSizeSource;
obj.RoiPreview = P;

end
