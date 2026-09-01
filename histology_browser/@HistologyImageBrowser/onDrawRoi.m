function onDrawRoi(obj)
%ONDRAWROI Draw a new line ROI by dragging across the image.
% The line is created at the width in the Width field rather than at whatever
% the previous ROI happened to use, so a section drawn today samples the same
% band as one drawn last week. Nothing is written until Save ROI.
%
% Several sections can be selected while this runs. An edit already open owns
% the line whichever tile it sits on; otherwise the first drawn tile takes it,
% which is the same tile ONTOGGLEEDITROI would have chosen.
%
% A new line takes a new brain surface. The old mark was a distance along the
% old line and means nothing on this one, so it is dropped rather than carried
% over, and DETECTSURFACE is asked for a fresh one off the profile the new line
% measures. It is asked quietly: a guess offered unbidden should not push the
% message about the line that was just drawn off the status bar.

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

% The existing handles would swallow the first click, so both go away for the
% duration of the drag and are rebuilt from the new geometry afterwards.
if ~isempty(obj.RoiEditor) && isvalid(obj.RoiEditor)
    delete(obj.RoiEditor);
    obj.RoiEditor = [];
end

if ~isempty(obj.SurfaceEditor) && isvalid(obj.SurfaceEditor)
    delete(obj.SurfaceEditor);
    obj.SurfaceEditor = [];
end

obj.setStatus("Drag across the image to draw a %d px wide line.", width);

% Drawn in the unsaved color, because that is what the line will be the
% instant the mouse comes up: nothing is written until Save ROI.
drawStyle = HistologyImageBrowser.roiStateStyle("new");

try
    drawn = drawline(ax, Color = drawStyle.Color, LineWidth = drawStyle.LineWidth);
catch ME
    obj.setError("Could not start drawing: %s", ME.message);

    % The handle was deleted a few lines up to keep it from swallowing the
    % first click, so it has to be put back whether or not a line was drawn.
    % A full redraw would also have overwritten the message just set with
    % "Showing N sections", which is not what happened here.
    obj.refreshRoiEdit();

    return
end

position = [];

if ~isempty(drawn) && isvalid(drawn)
    position = drawn.Position;
    delete(drawn);
end

if ~isequal(size(position), [2 2]) || hypot(diff(position(:, 1)), diff(position(:, 2))) < 1
    obj.setWarning("No line was drawn; the ROI is unchanged.");
    obj.refreshRoiEdit();

    return
end

geometry = obj.RoiEditGeom;
geometry.x1 = round(position(1, 1));
geometry.y1 = round(position(1, 2));
geometry.x2 = round(position(2, 1));
geometry.y2 = round(position(2, 2));
geometry.strokeWidth = width;

% Belonged to the line that has just been replaced, so it is dropped before the
% new one is measured rather than left pointing somewhere along it.
geometry.surface = NaN;
geometry.surfaceSource = "";

obj.RoiEditGeom = geometry;
obj.RoiEditDirty = true;
obj.RoiEditDragging = false;
obj.RoiSavedStem = "";

obj.updateRoiPreview();

% After the preview, because the surface is read off the profile the line
% measures and there is nothing to read until it exists.
detected = obj.detectSurface(Announce = false);

obj.updateRoiEditControls();
obj.refreshRoiEdit();

obj.setStatus("Drew a %d px line over %.0f px.%s Save ROI writes it to disk.", ...
    width, hypot(geometry.x2 - geometry.x1, geometry.y2 - geometry.y1), ...
    surface_note(obj, detected));

end

function note = surface_note(obj, detected)
%SURFACE_NOTE Say whether a brain surface was found under the new line.
% Both outcomes are worth a few words: one says a mark appeared that nobody
% asked for and can be dragged, and the other says the line has no mark, which
% is the state the alignment on the profile plot falls back from.

if detected
    note = " Marked the brain surface " + obj.describeSurface(obj.RoiEditGeom) + ";";
    return
end

note = " No brain surface found under it;";

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
