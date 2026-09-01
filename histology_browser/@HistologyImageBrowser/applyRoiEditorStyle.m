function applyRoiEditorStyle(obj)
%APPLYROIEDITORSTYLE Recolor the draggable handles for the ROI's current state.
% The handles outlive a drag, so the moment an edit makes the geometry differ
% from the file the line it is being dragged with has to say so too. Setting
% the color in place keeps that instant, without deleting and rebuilding the
% object the mouse is currently holding.
%
% The brain surface mark is recolored with the line because it is part of the
% same unsaved edit: moving either one is what the stroke is reporting, and a
% marker left in the old color beside a line that has changed would say the two
% stand differently against the file when they cannot.

hasLine = ~isempty(obj.RoiEditor) && isvalid(obj.RoiEditor);
hasSurface = ~isempty(obj.SurfaceEditor) && isvalid(obj.SurfaceEditor);

if ~hasLine && ~hasSurface
    return
end

row = obj.editedRow();

if height(row) ~= 1
    return
end

style = HistologyImageBrowser.roiStateStyle(obj.roiForRow(row).state);

if hasLine
    obj.RoiEditor.Color = style.Color;
    obj.RoiEditor.LineWidth = style.LineWidth;
end

if hasSurface
    obj.SurfaceEditor.Color = style.Color;
end

end
