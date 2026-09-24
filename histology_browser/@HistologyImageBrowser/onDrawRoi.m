function onDrawRoi(obj)
%ONDRAWROI Redraw the active line ROI by dragging across the image.
% The line is created at the width in the Width field rather than at whatever
% the previous ROI happened to use, so a section drawn today samples the same
% band as one drawn last week. A line redrawn over an ROI already on disk is not
% written until Save ROI; one drawn for an ROI still being added is saved as it
% lands.
%
% Several sections can be selected while this runs. The line goes to the tile
% ACTIVEROISTEM names -- an edit already open owns it whichever tile it sits on,
% and otherwise it is the tile marked "(ROI target)", which the user moves by
% clicking one. Either way it is the same tile ONTOGGLEEDITROI would choose.
%
% This replaces the ROI the dropdown is on rather than adding one, so that a
% line dragged badly can simply be dragged again. ONADDROI is what gives a
% section another ROI.
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

row = obj.rowForStem(obj.activeRoiStem());

if height(row) ~= 1
    obj.setWarning("Select a section before drawing a line.");
    return
end

% Drawing is an edit like any other, so it goes through the same session:
% the same preview, the same Save, the same prompt when leaving.
% A section with no such ROI yet gets no line until one is dragged out, so if
% the drag comes to nothing the session is closed again rather than left
% holding a line that was never drawn.
startedBlank = false;

if ~obj.isEditingRow(row)
    obj.EditRoiButton.Value = true;
    obj.onToggleEditRoi(Deferred = true);

    if obj.RoiEditStem == ""
        return
    end

    startedBlank = obj.RoiEditCreated && ~obj.RoiEditDirty;
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

obj.setStatus("Drag across the image to draw ROI %s as a %d px wide line.", ...
    obj.roiName(obj.RoiEditKey), width);

% Drawn in the unsaved color, because that is what the line will be the
% instant the mouse comes up: nothing is written until Save ROI.
drawStyle = HistologyImageBrowser.roiStateStyle("new");

% Set around the placement rather than only before it, so a click that lands on
% another tile while this is waiting cannot retarget the ROI controls out from
% under it. ONCLEANUP rather than a plain assignment after the call, because
% DRAWLINE can be cancelled with Escape or throw, and a flag left set would
% make every later click on a tile do nothing at all.
obj.RoiPlacing = true;
placing = onCleanup(@() set_placing(obj, false));

try
    drawn = drawline(ax, Color = drawStyle.Color, LineWidth = drawStyle.LineWidth);
catch ME
    obj.setError("Could not start drawing: %s", ME.message);

    % The handle was deleted a few lines up to keep it from swallowing the
    % first click, so it has to be put back whether or not a line was drawn.
    % A full redraw would also have overwritten the message just set with
    % "Showing N sections", which is not what happened here.
    abandon_or_refresh(obj, startedBlank);

    return
end

position = [];

if ~isempty(drawn) && isvalid(drawn)
    position = drawn.Position;
    delete(drawn);
end

clear placing

if ~isequal(size(position), [2 2]) || hypot(diff(position(:, 1)), diff(position(:, 2))) < 1
    abandon_or_refresh(obj, startedBlank);
    obj.setWarning("No line was drawn; the ROI is unchanged.");

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
obj.RoiSavedKey = "";

obj.updateRoiPreview();

% After the preview, because the surface is read off the profile the line
% measures and there is nothing to read until it exists.
detected = obj.detectSurface(Announce = false);

drew = sprintf("Drew ROI %s as a %d px line over %.0f px.", ...
    obj.roiName(obj.RoiEditKey), width, ...
    hypot(geometry.x2 - geometry.x1, geometry.y2 - geometry.y1));

% An ROI this session created is still being added, so the line drawn for it is
% saved as it lands, the same as the line ONTOGGLEEDITROI placed for it. An ROI
% that was already on disk keeps waiting for Save ROI, so that a line redrawn
% over one does not replace the file until it is meant to.
saved = false;

if obj.RoiEditCreated
    obj.onSaveRoiEdits();
    saved = ~obj.RoiEditDirty;
end

if saved
    obj.setSuccess("%s%s saved to disk.", drew, surface_note(obj, detected));
    return
end

obj.updateRoiEditControls();
obj.refreshRoiEdit();

% A save that failed has already said why, and that is the message to leave up.
if obj.RoiEditCreated
    return
end

obj.setStatus("%s%s Save ROI writes it to disk.", drew, surface_note(obj, detected));

end

function abandon_or_refresh(obj, startedBlank)
%ABANDON_OR_REFRESH Put the tile back after a drag that produced no line.
% An edit this call opened only to draw into is closed again, since it has no
% line to edit; otherwise the handles that were removed for the drag return.

if startedBlank
    stem = obj.RoiEditStem;
    obj.exitRoiEdit(false);
    obj.refreshRoiEdit(stem);

    return
end

obj.refreshRoiEdit();

end

function set_placing(obj, tf)
%SET_PLACING Clear the placement flag without minding a browser already closed.
% ONCLEANUP fires while the window is being torn down as readily as at the end
% of a normal draw, and a deleted handle object cannot be written to.

if isempty(obj) || ~isvalid(obj)
    return
end

obj.RoiPlacing = tf;

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
