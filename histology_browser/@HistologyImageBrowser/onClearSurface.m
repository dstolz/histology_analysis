function onClearSurface(obj)
%ONCLEARSURFACE Take the brain surface mark off the line being edited.
% A section whose surface cannot be told from its background is better left
% unmarked than marked in the wrong place: an unmarked trace plots on its own
% line start under "From brain surface" and is counted on the axes, where a
% wrong mark would quietly move it somewhere it never was.
%
% Like every other ROI edit this only changes the geometry in the window. Save
% ROI is what removes the sidecar from disk.
%
% See also ONMARKSURFACE, ONDETECTSURFACE, ONSAVEROIEDITS.

if obj.RoiEditStem == ""
    obj.setWarning("Edit a line ROI before clearing its brain surface.");
    return
end

geometry = obj.RoiEditGeom;

if ~isfield(geometry, "surface") || ~isfinite(geometry.surface)
    obj.setStatus("%s has no brain surface mark to clear.", obj.RoiEditStem);
    return
end

geometry.surface = NaN;
geometry.surfaceSource = "";

obj.RoiEditGeom = geometry;
obj.RoiEditDirty = true;
obj.RoiSavedStem = "";

obj.updateRoiEditControls();
obj.refreshRoiEdit();

obj.setStatus("Cleared the brain surface mark for %s. Save ROI removes it from disk.", ...
    obj.RoiEditStem);

end
