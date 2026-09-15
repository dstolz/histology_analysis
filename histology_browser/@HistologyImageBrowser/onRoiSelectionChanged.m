function onRoiSelectionChanged(obj)
%ONROISELECTIONCHANGED Point the ROI controls at a different ROI of the section.
%
% An edit already under way follows the choice: the handles move to the ROI
% just picked, after the usual offer to save whatever the last one had
% outstanding. Declining that offer puts the dropdown back rather than leaving
% it naming an ROI the handles are not on.

key = string(obj.RoiSelectDropDown.Value);

if key == "" || key == obj.ActiveRoiKey
    return
end

wasEditing = obj.RoiEditStem ~= "";

if wasEditing && ~obj.exitRoiEdit(true)
    obj.ActiveRoiKey = obj.RoiEditKey;
    obj.syncRoiSelector();

    return
end

obj.ActiveRoiKey = key;

if wasEditing
    obj.EditRoiButton.Value = true;
    obj.onToggleEditRoi(key);

    return
end

% Nothing on the tiles depends on which ROI the controls point at while
% nothing is being edited, so the picture is left alone and only the controls
% are told.
obj.updateRoiEditControls();

obj.setStatus("ROI %s selected. Edit ROI or Draw Line now works on it.", obj.roiName(key));

end
