function onMarkSurface(obj)
%ONMARKSURFACE Click on the image to place the brain surface on the line.
% The automatic pass gets it right on a clean section and wrong on one whose
% edge is dim, folded, or has a piece of another section beside it, so the mark
% has to be placeable by hand as well. This is the way in for a line that has
% no mark at all; once there is one, dragging its marker is quicker than coming
% back here.
%
% The click is taken with DRAWPOINT, exactly as a new line is taken with
% DRAWLINE, and lands wherever the mouse does. It is then projected onto the
% line, because a surface off the line has no depth along the profile -- the
% only thing the mark is for -- so what the click really says is how far along
% the line the surface is, not where in the image it is.
%
% Nothing is written to disk. The mark lands on the edit geometry, turns the
% ROI dirty, and goes out with Save ROI.
%
% See also ONDRAWROI, ONDETECTSURFACE, ONCLEARSURFACE, ONSURFACEEDITCHANGED.

if exist("drawpoint", "file") == 0
    obj.setError("Marking the brain surface needs the Image Processing Toolbox.");
    uialert(obj.Fig, ...
        "Marking the brain surface needs the Image Processing Toolbox, which is not installed.", ...
        "Toolbox Required");

    return
end

if obj.RoiEditStem == ""
    obj.setWarning("Edit a line ROI before marking its brain surface.");
    return
end

ax = obj.tileAxes(obj.RoiEditStem);

if isempty(ax)
    obj.setError("The tile for %s is not on screen, so there is nothing to click on.", ...
        obj.RoiEditStem);
    return
end

geometry = obj.RoiEditGeom;

if hypot(geometry.x2 - geometry.x1, geometry.y2 - geometry.y1) < 1
    obj.setError("The ROI line has no length, so it has no surface along it.");
    return
end

% The line handle and the existing surface marker both sit under the pointer
% and would swallow the click, so both go away for the duration and are put
% back from the new geometry afterwards.
delete_editors(obj);

obj.setStatus("Click where the brain surface crosses the line for %s.", obj.RoiEditStem);

style = HistologyImageBrowser.roiStateStyle("dirty");

% Set around the placement rather than only before it, so a click that lands on
% another tile while this is waiting cannot retarget the ROI controls out from
% under it. ONCLEANUP rather than a plain assignment after the call, because
% DRAWPOINT can be cancelled with Escape or throw, and a flag left set would
% make every later click on a tile do nothing at all.
obj.RoiPlacing = true;
placing = onCleanup(@() set_placing(obj, false));

try
    drawn = drawpoint(ax, Color = style.Color, MarkerSize = 8);
catch ME
    obj.setError("Could not start marking: %s", ME.message);
    obj.refreshRoiEdit();

    return
end

position = [];

if ~isempty(drawn) && isvalid(drawn)
    position = drawn.Position;
    delete(drawn);
end

clear placing

if ~isequal(size(position), [1 2]) || any(~isfinite(position))
    obj.setWarning("No point was placed; the brain surface mark is unchanged.");
    obj.refreshRoiEdit();

    return
end

geometry.surface = HistologyImageBrowser.projectOntoLine(geometry, position);
geometry.surfaceSource = "manual";

obj.RoiEditGeom = geometry;
obj.RoiEditDirty = true;
obj.RoiSavedStem = "";

obj.updateRoiEditControls();
obj.refreshRoiEdit();

obj.setStatus("Marked the brain surface for %s %s. Save ROI writes it beside the .roi file.", ...
    obj.RoiEditStem, obj.describeSurface(geometry));

end

function set_placing(obj, tf)
%SET_PLACING Clear the placement flag without minding a browser already closed.
% ONCLEANUP fires while the window is being torn down as readily as at the end
% of a normal placement, and a deleted handle object cannot be written to.

if isempty(obj) || ~isvalid(obj)
    return
end

obj.RoiPlacing = tf;

end

function delete_editors(obj)
%DELETE_EDITORS Take both draggable handles off the tile for the click.
% REFRESHROIEDIT rebuilds them from the geometry, which every path out of this
% function goes through.

if ~isempty(obj.SurfaceEditor) && isvalid(obj.SurfaceEditor)
    delete(obj.SurfaceEditor);
end

obj.SurfaceEditor = [];

if ~isempty(obj.RoiEditor) && isvalid(obj.RoiEditor)
    delete(obj.RoiEditor);
end

obj.RoiEditor = [];

end
