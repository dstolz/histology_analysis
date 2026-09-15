function refreshRoiOverlay(obj)
%REFRESHROIOVERLAY Redraw the overlay of the tile being edited, in place.
% Redrawing the whole tile on every mouse move would reload and restretch the
% image, so only the ROI graphics are replaced while a line is being dragged.
%
% The replacement itself is REFRESHTILEOVERLAY, which is the same work an
% overlay checkbox now asks for on every tile at once. Keeping a copy of it
% here was the alternative and would have meant two places deciding what
% counts as an overlay object; this file is left holding only what is peculiar
% to a drag -- finding the tile from the handle being dragged, and recoloring
% that handle the instant the edit turns dirty.
%
% Every other step of an ROI session -- opening it, drawing a line, saving,
% reverting, closing -- goes through REFRESHROIEDIT instead, which also rebuilds
% the handle and redraws the profile. Neither belongs in a drag: the handle is
% the object the mouse is holding, and remeasuring a wide band off a full
% resolution page on every mouse move is far too slow.
%
% See also REFRESHROIEDIT, REFRESHTILEOVERLAY, REFRESHOVERLAYS, ONROIEDITCHANGED.

if isempty(obj.RoiEditor) || ~isvalid(obj.RoiEditor)
    return
end

% The first move of a drag is what turns a clean edit dirty, so the handle is
% restyled here rather than waiting for the redraw at the end of the drag.
obj.applyRoiEditorStyle();

obj.refreshTileOverlay(obj.RoiEditor.Parent);

end
