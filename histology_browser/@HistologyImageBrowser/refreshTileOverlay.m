function refreshTileOverlay(obj, ax)
%REFRESHTILEOVERLAY Replace one tile's overlay graphics without touching its image.
% Every overlay object carries Tag "roiOverlay", so the whole overlay can be
% swept away and drawn again while the image, the axis limits, the frame color,
% the title, and the missing-metadata note underneath it all stay exactly as
% DRAWIMAGETILE left them. That tag, not a list of handles, is the invariant:
% anything DRAWROIOVERLAY adds later is swept with the rest for free.
%
% Which section the tile shows is read off the stamp DRAWIMAGETILE leaves on the
% axes rather than from the selection, because the caller may be redrawing a
% tile that is not the first selected row -- REFRESHOVERLAYS walks all of them.
%
% Parameters
%   ax: Tile axes to redraw the overlay of. A placeholder tile, an axes that
%       was never stamped, or one whose section has left the view is left
%       alone rather than being drawn on in the wrong coordinates.
%
% See also REFRESHOVERLAYS, REFRESHROIOVERLAY, DRAWROIOVERLAY, DRAWIMAGETILE.

if isempty(ax) || ~isvalid(ax)
    return
end

% A tile that could not read its image is a placeholder: SHOW_PLACEHOLDER puts
% it in normalized [0 1] limits with a message in the middle, so an ROI drawn in
% full resolution pixel coordinates would land far outside it. The image object
% is what separates the two, because it is exactly what the placeholder lacks.
if isempty(findobj(ax, Type = "image"))
    return
end

row = tile_row(obj, ax);

if height(row) ~= 1
    return
end

delete(findobj(ax, Tag = "roiOverlay"));

hold(ax, "on");

% Drawn in the color this tile was framed in rather than in the first tile
% color, so a redraw across a grid of tiles cannot recolor any of them.
obj.drawRoiOverlay(ax, row, HistologyImageBrowser.tileColor(ax));

hold(ax, "off");

% The objects just drawn are new ones, so the right-click menu has to be handed
% out again. Without this the band, the shading, the grid, and the badge would
% quietly stop raising a menu the first time one of them was switched off and
% back on, which is the failure this whole incremental path could most easily
% have introduced.
obj.attachContextMenu(ax, "tile");

restack_editor(obj, ax);

end

function row = tile_row(obj, ax)
%TILE_ROW Find the catalog row a tile was drawn for, or an empty table.
% The stem is looked up in the filtered view rather than in the selection,
% because the two agree whenever a tile is on screen and the view is the table
% every other reader of a row uses.

row = obj.View([], :);

stem = HistologyImageBrowser.tileStem(ax);

if stem == "" || height(obj.View) == 0
    return
end

index = find(string(obj.View.Stem) == stem, 1);

if isempty(index)
    return
end

row = obj.View(index, :);

end

function restack_editor(obj, ax)
%RESTACK_EDITOR Lift the draggable line back above the overlay it now sits under.
% The shaded band and the grid are drawn after the handle was created, so
% without this the line the mouse is holding ends up underneath them and its
% end markers stop being grabbable. Only the tile actually carrying the editor
% is restacked; the others have no handle to lift.

if isempty(obj.RoiEditor) || ~isvalid(obj.RoiEditor)
    return
end

if ~isequal(obj.RoiEditor.Parent, ax)
    return
end

try
    uistack(obj.RoiEditor, "top");
catch
    % Not every release lets an ROI object restack; the overlay is
    % semi-transparent, so the line stays visible either way.
end

end
