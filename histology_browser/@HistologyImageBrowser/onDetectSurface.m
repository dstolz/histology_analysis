function onDetectSurface(obj)
%ONDETECTSURFACE Find the brain surface from the profile and mark the line.
% The Detect button, which is the loud, overwriting form of the same pass that
% runs on its own when a line is created. DETECTSURFACE holds the work; this
% file is the button's half of it -- the guard, and the redraw that puts the
% new mark on the tile and the profile plot.
%
% See also DETECTSURFACE, ONMARKSURFACE, ONCLEARSURFACE.

if obj.RoiEditStem == ""
    obj.setWarning("Edit a line ROI before detecting its brain surface.");
    return
end

if ~obj.detectSurface()
    return
end

obj.updateRoiEditControls();
obj.refreshRoiEdit();

end
