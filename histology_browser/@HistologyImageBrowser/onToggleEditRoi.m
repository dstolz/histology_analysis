function onToggleEditRoi(obj)
%ONTOGGLEEDITROI Enter or leave line ROI editing for the selected section.
% Editing is deliberately limited to a single section: the ROI is dragged on
% the tile itself, and a drag has to belong to exactly one image.

if ~obj.EditRoiButton.Value
    if obj.exitRoiEdit(true)
        obj.renderSelection();
    end

    return
end

if exist("images.roi.Line", "class") ~= 8
    obj.EditRoiButton.Value = false;
    obj.setError("Editing a line ROI needs the Image Processing Toolbox.");
    uialert(obj.Fig, ...
        "Editing a line ROI needs the Image Processing Toolbox, which is not installed.", ...
        "Toolbox Required");

    return
end

rows = obj.selectedRows();

if height(rows) ~= 1
    obj.EditRoiButton.Value = false;
    obj.setWarning("Select exactly one section before editing its ROI.");

    return
end

row = rows(1, :);
geometry = obj.initialRoiGeometry(row);

if isempty(geometry)
    obj.EditRoiButton.Value = false;
    obj.setError("No readable image for %s, so there is nothing to draw an ROI over.", row.Stem);

    return
end

obj.RoiEditStem = string(row.Stem);
obj.RoiEditGeom = geometry;

% A line that was just invented has nothing on disk to match, so it counts as
% an unsaved change from the moment it appears.
obj.RoiEditDirty = geometry.isNew;
obj.RoiPreview = struct();
obj.RoiWidthField.Value = geometry.strokeWidth;

% An untouched ROI already has its profile on disk, so reading the full
% resolution page waits until the line actually moves. A line with no file
% behind it has nothing to show until it is measured.
if geometry.isNew
    obj.updateRoiPreview();
end

obj.updateRoiEditControls();
obj.renderSelection();

if geometry.isNew
    obj.setStatus("Placed a new ROI on %s. Drag its ends, then Save ROI.", row.Stem);
    return
end

obj.setStatus("Editing the ROI for %s. Drag its ends, then Save ROI.", row.Stem);

end
