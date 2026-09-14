function onDrawRoi(obj)
%ONDRAWROI Draw a new line ROI by dragging across the image.
% The line is created at the width in the Width field rather than at whatever
% the previous ROI happened to use, so a section drawn today samples the same
% band as one drawn last week. Nothing is written until Save ROI.
%
% Several sections can be selected while this runs. An edit already open owns
% the line whichever tile it sits on; otherwise the first drawn tile takes it,
% which is the same tile ONTOGGLEEDITROI would have chosen.

if exist("drawline", "file") == 0
    obj.setError("Drawing a line ROI needs the Image Processing Toolbox.");
    uialert(obj.Fig, ...
        "Drawing a line ROI needs the Image Processing Toolbox, which is not installed.", ...
        "Toolbox Required");

    return
end

rows = obj.selectedRows();

if height(rows) == 0
    obj.setWarning("Select a section before drawing a line.");
    return
end

% An edit already under way owns the line, whichever tile it is on; otherwise
% the first drawn tile takes it, exactly as ONTOGGLEEDITROI decides.
if obj.RoiEditStem ~= ""
    activeRow = obj.editedRow();

    if height(activeRow) == 1
        rows = activeRow;
    end
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

obj.setStatus("Drag across the image to draw a %d px wide line.", width);

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

obj.updateRoiPreview();
obj.updateRoiEditControls();
obj.renderSelection();

obj.setStatus("Drew a %d px line over %.0f px. Save ROI writes it to disk.", ...
    width, hypot(geometry.x2 - geometry.x1, geometry.y2 - geometry.y1));

end

function ax = drawing_axes(obj)
%DRAWING_AXES Find the tile the new line is drawn on.
% The editor's own parent settles it whenever there is an editor. Otherwise the
% stem DRAWIMAGETILE stamps on each tile is what picks the right one out of
% several: FINDOBJ returns tiles newest first, so taking the first would draw
% on the last section of the selection rather than on the one being edited.

ax = [];

if ~isempty(obj.RoiEditor) && isvalid(obj.RoiEditor) && isvalid(obj.RoiEditor.Parent)
    ax = obj.RoiEditor.Parent;
    return
end

candidates = findobj(obj.ImagePanel, Type = "axes");

for iAxes = 1:numel(candidates)
    if HistologyImageBrowser.tileStem(candidates(iAxes)) == obj.RoiEditStem
        ax = candidates(iAxes);
        return
    end
end

end
