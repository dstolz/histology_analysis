function onRoiEditChanged(obj, position, isFinal)
%ONROIEDITCHANGED Take a new line position from the draggable ROI.
% Endpoints are snapped to whole pixels because Fiji's line tool works on
% integer endpoints, so an ROI saved from here remeasures in Fiji as the same
% line rather than one rounded a fraction of a pixel away.
%
% Parameters
%   position: 2x2 [x1 y1; x2 y2] from the ROI event.
%   isFinal: True at the end of a drag, when the profile is remeasured.

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

if isFinal
    obj.updateRoiPreview();
end

obj.refreshRoiOverlay();

if ~isFinal
    return
end

obj.renderProfilePlot();
obj.updateRoiEditControls();

end
