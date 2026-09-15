function refreshRoiEdit(obj, stem)
%REFRESHROIEDIT Redraw what an ROI edit changed, and nothing else.
% Starting an edit, drawing a line, saving it, reverting it, and leaving all
% change the same three things: the draggable handle, the overlay on the one
% tile the line belongs to, and the profile plot beside it. Not one of them
% changes a pixel of any image, so not one of them is a reason to tear the
% tiled layout down and read every selected section off disk again -- which is
% what RENDERSELECTION does, and what each of those five used to ask for. With
% a dozen sections on screen that was a dozen files reread and restretched to
% move one line.
%
% The tile is found by the stem stamped on it rather than by position, so the
% cost is the same whether one section is selected or twelve. This is the
% coarse counterpart of REFRESHROIOVERLAY, which does strictly less because it
% runs on every mouse move: it leaves the handle the mouse is holding alone,
% and it leaves the profile plot for the end of the drag.
%
% A full redraw is still the answer when there is no tile to update in place --
% the layout may not have been built yet, or the section may have failed to
% read and be showing a placeholder, which has no image coordinates to put a
% line in.
%
% Parameters
%   stem: Section whose tile carries the ROI. Defaults to the section being
%       edited, which is what every caller wants except the one leaving an
%       edit: by then the session has been cleared, so it passes the stem it
%       captured beforehand.
%
% See also REFRESHROIOVERLAY, REFRESHTILEOVERLAY, ATTACHROIEDITOR, RENDERSELECTION.

arguments
    obj
    stem (1,1) string = obj.RoiEditStem
end

if ~refresh_tile(obj, stem)
    obj.renderSelection();
    return
end

% The geometry under the line is what the plot is drawn from, so the profile
% follows the ROI even when nothing about the images did.
obj.renderProfilePlot();

end

function done = refresh_tile(obj, stem)
%REFRESH_TILE Put one tile's handle and overlay in step, or say it cannot.

done = false;

if stem == "" || ~obj.showImages()
    return
end

ax = obj.tileAxes(stem);

if isempty(ax)
    return
end

% A tile that could not read its image is a placeholder: it sits in normalized
% [0 1] limits with a message in the middle, so a line in full resolution pixel
% coordinates would land far outside it. REFRESHTILEOVERLAY declines such a
% tile for the same reason, and DRAWIMAGETILE never hangs an editor on one.
if isempty(findobj(ax, Type = "image"))
    return
end

row = obj.rowForStem(stem);

if height(row) ~= 1
    return
end

% The handles are rebuilt rather than moved, because the geometry they were
% created at is not the geometry any of these callers leaves behind. Both
% ATTACHROIEDITOR and ATTACHSURFACEEDITOR decline a row that is no longer being
% edited, which is what makes leaving an edit take them away rather than put
% fresh ones back.
obj.attachRoiEditor(ax, row);

% The surface mark is a second handle on the same line and is rebuilt with it,
% so clearing a mark takes its handle away and detecting one puts a handle
% there, both without the tile being read off disk again.
obj.attachSurfaceEditor(ax, row);

obj.refreshTileOverlay(ax);

done = true;

end
