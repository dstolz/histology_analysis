function updateRoiEditControls(obj)
%UPDATEROIEDITCONTROLS Enable the ROI controls that make sense right now, and
% say what the band width currently is. The width governs every line drawn
% from here on, so it is stated whether or not an edit is under way.

if isempty(obj.EditRoiButton) || ~isvalid(obj.EditRoiButton)
    return
end

editing = obj.RoiEditStem ~= "";

% Saving an unchanged ROI is still worth allowing: it is how a section that
% has a line but no profile beside it gets one.
obj.SaveRoiButton.Enable = on_off(editing);
obj.RevertRoiButton.Enable = on_off(editing && obj.RoiEditDirty);

obj.RoiEditLabel.Text = hint(obj, editing);

% The ROI items on the Display menu follow these same Enable states, and this
% is the one place they are decided.
obj.syncDisplayMenu();

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

if obj.RoiEditDirty
    text = "Band " + width + ", UNSAVED. Save ROI rewrites the .roi and values.csv.";
    return
end

if obj.RoiSavedStem == obj.RoiEditStem
    text = "Band " + width + ". Saved to disk; the line matches its .roi file.";
    return
end

text = "Band " + width + ", from file. Drag the line ends, or Draw Line to replace it.";

end

function state = on_off(tf)
%ON_OFF Convert a logical to the matlab.lang.OnOffSwitchState text.

if tf
    state = "on";
else
    state = "off";
end

end
