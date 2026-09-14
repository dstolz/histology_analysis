function onRoiWidthChanged(obj)
%ONROIWIDTHCHANGED Apply a new sampling band width.
% The width is what the profile averages over, so changing it changes the
% measurement as much as moving the line does. It is also the width the next
% drawn line will use, which is why it is kept between sessions whether or not
% anything is being edited right now.

width = max(1, round(obj.RoiWidthField.Value));
obj.RoiWidthField.Value = width;
obj.savePreferences();

if obj.RoiEditStem == ""
    obj.updateRoiEditControls();
    obj.setStatus("New lines will be drawn %s wide.", obj.describeRoiWidth(width));

    return
end

geometry = obj.RoiEditGeom;

if geometry.strokeWidth == width
    obj.updateRoiEditControls();
    return
end

geometry.strokeWidth = width;
obj.RoiEditGeom = geometry;
obj.RoiEditDirty = true;

obj.updateRoiPreview();
obj.refreshRoiOverlay();
obj.renderProfilePlot();
obj.updateRoiEditControls();

obj.setStatus("Sampling band is now %s wide.", obj.describeRoiWidth(width));

end
