function applyRoiEditorStyle(obj)
%APPLYROIEDITORSTYLE Recolor the draggable line for the ROI's current state.
% The handle outlives a drag, so the moment an edit makes the geometry differ
% from the file the line it is being dragged with has to say so too. Setting
% the color in place keeps that instant, without deleting and rebuilding the
% object the mouse is currently holding.

if isempty(obj.RoiEditor) || ~isvalid(obj.RoiEditor)
    return
end

row = obj.editedRow();

if height(row) ~= 1
    return
end

style = HistologyImageBrowser.roiStateStyle(obj.roiForRow(row).state);

obj.RoiEditor.Color = style.Color;
obj.RoiEditor.LineWidth = style.LineWidth;

end
