function onAddRoi(obj)
%ONADDROI Give the selected section another line ROI and open it for editing.
%
% The new ROI takes the first letter the section is not already using, and is
% placed clear of the lines already on it. Its .roi and values files are
% written as soon as the line is placed, so adding an ROI creates its data
% without a separate Save; ONTOGGLEEDITROI does the writing.

rows = obj.selectedRows();

if height(rows) ~= 1
    obj.setWarning("Select exactly one section before adding an ROI to it.");
    return
end

row = rows(1, :);
key = HistologyImageBrowser.nextRoiKey(obj.roiKeysForRow(row));

% The handles belong to one ROI at a time, so whatever is open gives them up
% first, and an unsaved edit gets its usual offer before it does.
if obj.RoiEditStem ~= "" && ~obj.exitRoiEdit(true)
    return
end

obj.ActiveRoiKey = key;
obj.EditRoiButton.Value = true;
obj.onToggleEditRoi(key);

end
