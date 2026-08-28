function onRoiEditChanged(obj, position, isFinal)
%ONROIEDITCHANGED Take a new line position from the draggable ROI.
% Endpoints are snapped to whole pixels because Fiji's line tool works on
% integer endpoints, so an ROI saved from here remeasures in Fiji as the same
% line rather than one rounded a fraction of a pixel away.
%
% Parameters
%   position: 2x2 [x1 y1; x2 y2] from the ROI event.
%   isFinal: True at the end of a drag, when the profile is remeasured and
%       the shaded band is drawn again.

if obj.RoiEditStem == "" || ~isequal(size(position), [2 2])
    return
end

geometry = obj.RoiEditGeom;
geometry.x1 = round(position(1, 1));
geometry.y1 = round(position(1, 2));
geometry.x2 = round(position(2, 1));
geometry.y2 = round(position(2, 2));

obj.RoiEditGeom = geometry;
obj.RoiEditDirty = true;

% Moving the line makes the last save no longer describe it, so the green
% confirmation goes as soon as the geometry does.
obj.RoiSavedStem = "";

% While the line is moving, the shading still belongs to the old position, so
% the band is left empty and the measurement waits for the button to come up.
obj.RoiEditDragging = ~isFinal;

if ~isFinal
    obj.refreshRoiOverlay();
    return
end

obj.updateRoiPreview();
obj.refreshRoiOverlay();

obj.renderProfilePlot();
obj.updateRoiEditControls();

end
