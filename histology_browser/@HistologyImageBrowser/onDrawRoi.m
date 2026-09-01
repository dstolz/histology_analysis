function onDrawRoi(obj)
%ONDRAWROI Redraw the active line ROI by dragging across the image.
% The line is created at the width in the Width field rather than at whatever
% the previous ROI happened to use, so a section drawn today samples the same
% band as one drawn last week. Nothing is written until Save ROI.
%
% This replaces the ROI the dropdown is on rather than adding one, so that a
% line dragged badly can simply be dragged again. ONADDROI is what gives a
% section another ROI.

if exist("drawline", "file") == 0
    obj.setError("Drawing a line ROI needs the Image Processing Toolbox.");
    uialert(obj.Fig, ...
        "Drawing a line ROI needs the Image Processing Toolbox, which is not installed.", ...
        "Toolbox Required");

    return
end

rows = obj.selectedRows();

if height(rows) ~= 1
    obj.setWarning("Select exactly one section before drawing a line.");
    return
end

% Drawing is an edit like any other, so it goes through the same session:
% the same preview, the same Save, the same prompt when leaving.
if ~obj.isEditingRow(rows(1, :))
    obj.EditRoiButton.Value = true;
    obj.onToggleEditRoi();

    if obj.RoiEditStem == ""
        return
    end
end

ax = drawing_axes(obj);

if isempty(ax)
    obj.setError("No image is on screen to draw over.");
    return
end

width = max(1, round(obj.RoiWidthField.Value));

% The existing handle would swallow the first click, so it goes away for the
% duration of the drag and is rebuilt from the new geometry afterwards.
if ~isempty(obj.RoiEditor) && isvalid(obj.RoiEditor)
    delete(obj.RoiEditor);
    obj.RoiEditor = [];
end

obj.setStatus("Drag across the image to draw ROI %s as a %d px wide line.", ...
    obj.roiName(obj.RoiEditKey), width);

% Drawn in the unsaved color, because that is what the line will be the
% instant the mouse comes up: nothing is written until Save ROI.
drawStyle = HistologyImageBrowser.roiStateStyle("new");

try
    drawn = drawline(ax, Color = drawStyle.Color, LineWidth = drawStyle.LineWidth);
catch ME
    obj.setError("Could not start drawing: %s", ME.message);
    obj.renderSelection();

    return
end

position = [];

if ~isempty(drawn) && isvalid(drawn)
    position = drawn.Position;
    delete(drawn);
end

if ~isequal(size(position), [2 2]) || hypot(diff(position(:, 1)), diff(position(:, 2))) < 1
    obj.setWarning("No line was drawn; the ROI is unchanged.");
    obj.renderSelection();

    return
end

geometry = obj.RoiEditGeom;
geometry.x1 = round(position(1, 1));
geometry.y1 = round(position(1, 2));
geometry.x2 = round(position(2, 1));
geometry.y2 = round(position(2, 2));
geometry.strokeWidth = width;

obj.RoiEditGeom = geometry;
obj.RoiEditDirty = true;
obj.RoiEditDragging = false;
obj.RoiSavedStem = "";
obj.RoiSavedKey = "";

obj.updateRoiPreview();
obj.updateRoiEditControls();
obj.renderSelection();

obj.setStatus("Drew ROI %s as a %d px line over %.0f px. Save ROI writes it to disk.", ...
    obj.roiName(obj.RoiEditKey), width, ...
    hypot(geometry.x2 - geometry.x1, geometry.y2 - geometry.y1));

end

function ax = drawing_axes(obj)
%DRAWING_AXES Find the tile to draw on, which is the only one on screen.

ax = [];

if ~isempty(obj.RoiEditor) && isvalid(obj.RoiEditor) && isvalid(obj.RoiEditor.Parent)
    ax = obj.RoiEditor.Parent;
    return
end

candidates = findobj(obj.ImagePanel, Type = "axes");

if isempty(candidates)
    return
end

ax = candidates(1);

end
