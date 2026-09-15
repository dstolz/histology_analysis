function onSurfaceEditChanged(obj, position, isFinal)
%ONSURFACEEDITCHANGED Take a new brain surface position from its draggable mark.
% The point is free in the image while the mouse holds it and only means
% something on the line, so every position is projected onto the line and the
% handle is put back where the projection landed. That is what makes the marker
% slide along the line rather than come off it: the mouse can wander anywhere,
% and the mark follows it only in the one direction the profile has.
%
% Unlike a line drag, nothing has to be remeasured. The profile under the band
% is unchanged -- only where along it the surface sits has moved -- so the
% overlay and the plot are redrawn and the full resolution page is left alone,
% on every mouse move as well as at the end.
%
% Parameters
%   position: 1x2 [x y] from the ROI event.
%   isFinal: True at the end of a drag, when the profile plot and the controls
%       are brought back into step.
%
% See also ATTACHSURFACEEDITOR, ONROIEDITCHANGED, ONMARKSURFACE.

if obj.RoiEditStem == "" || ~isequal(size(position), [1 2]) || any(~isfinite(position))
    return
end

geometry = obj.RoiEditGeom;

offset = HistologyImageBrowser.projectOntoLine(geometry, position);

if ~isfinite(offset)
    return
end

geometry.surface = offset;
geometry.surfaceSource = "manual";

obj.RoiEditGeom = geometry;
obj.RoiEditDirty = true;

% Moving the mark makes the last save no longer describe it, so the green
% confirmation goes as soon as the geometry does.
obj.RoiSavedStem = "";

obj.SurfaceEditDragging = ~isFinal;

% Snapped back onto the line. Written straight to the handle rather than
% through ATTACHSURFACEEDITOR, because the object being corrected is the one
% the mouse is holding and rebuilding it mid-drag would drop the grab.
snapped = HistologyImageBrowser.surfacePoint(geometry);

if ~isempty(snapped) && ~isempty(obj.SurfaceEditor) && isvalid(obj.SurfaceEditor)
    obj.SurfaceEditor.Position = snapped;
end

obj.refreshRoiOverlay();

if ~isFinal
    return
end

obj.renderProfilePlot();
obj.updateRoiEditControls();

end
