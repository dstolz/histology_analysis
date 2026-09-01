function updateRoiEditControls(obj)
%UPDATEROIEDITCONTROLS Enable the ROI controls that make sense right now, say
% which ROIs the section has, and say what the band width currently is. The
% width governs every line drawn from here on, so it is stated whether or not
% an edit is under way.

if isempty(obj.EditRoiButton) || ~isvalid(obj.EditRoiButton)
    return
end

editing = obj.RoiEditStem ~= "";

% Saving an unchanged ROI is still worth allowing: it is how a section that
% has a line but no profile beside it gets one.
obj.SaveRoiButton.Enable = on_off(editing);
obj.RevertRoiButton.Enable = on_off(editing && obj.RoiEditDirty);

% Which ROI is being worked on only means something for one section at a time,
% for the same reason editing does: the line is dragged on a tile.
rows = obj.selectedRows();
onOneSection = height(rows) == 1;

obj.RoiSelectDropDown.Enable = on_off(onOneSection);
obj.AddRoiButton.Enable = on_off(onOneSection);

obj.syncRoiSelector();

obj.RoiListLabel.Text = roi_list_text(obj, rows, onOneSection);
obj.RoiEditLabel.Text = hint(obj, editing);

% The ROI items on the Display menu follow these same Enable states, and this
% is the one place they are decided.
obj.syncDisplayMenu();

end

function text = roi_list_text(obj, rows, onOneSection)
%ROI_LIST_TEXT Name the ROIs the selection holds, beside the ROI dropdown.
% The dropdown shows only the one in use, and how many others there are is
% what decides whether Add ROI or the dropdown is the next thing to reach for.

if ~onOneSection
    if height(rows) == 0
        text = "No section selected.";
        return
    end

    text = sprintf("%d sections selected; ROI editing needs one.", height(rows));
    return
end

names = obj.describeRoiList(rows(1, :));

if names == ""
    text = "No ROI on this section yet. Draw Line or Add ROI starts one.";
    return
end

text = "On this section: " + names + ".";

end

function text = hint(obj, editing)
%HINT Say what the ROI controls will do, and how wide the band is.
% The wording tracks the same states the overlay is stroked from, so the panel
% and the tile never disagree about whether the line is on disk.

width = obj.describeRoiWidth(obj.RoiWidthField.Value);

if ~editing
    text = "Band " + width + ". Select one section, then Edit ROI or Draw Line.";
    return
end

name = obj.roiName(obj.RoiEditKey);

if obj.RoiEditDirty
    text = "ROI " + name + ", band " + width ...
        + ", UNSAVED. Save ROI rewrites its .roi and values.csv.";
    return
end

if obj.RoiSavedStem == obj.RoiEditStem && obj.RoiSavedKey == obj.RoiEditKey
    text = "ROI " + name + ", band " + width + ". Saved to disk; the line matches its file.";
    return
end

text = "ROI " + name + ", band " + width ...
    + ", from file. Drag the line ends, or Draw Line to replace it.";

end

function state = on_off(tf)
%ON_OFF Convert a logical to the matlab.lang.OnOffSwitchState text.

if tf
    state = "on";
else
    state = "off";
end

end
