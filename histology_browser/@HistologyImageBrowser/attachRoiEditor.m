function attachRoiEditor(obj, ax, row)
%ATTACHROIEDITOR Put the draggable line onto the tile being edited.
% The handle is rebuilt on every redraw, so the geometry lives in the browser
% rather than in the graphics object; deleting and recreating the line never
% loses an edit.

if ~obj.isEditingRow(row)
    return
end

if exist("images.roi.Line", "class") ~= 8
    return
end

if ~isempty(obj.RoiEditor) && isvalid(obj.RoiEditor)
    delete(obj.RoiEditor);
end

geometry = obj.RoiEditGeom;

editor = images.roi.Line(ax, ...
    Position = [geometry.x1, geometry.y1; geometry.x2, geometry.y2], ...
    Color = [1 0.85 0.1], ...
    LineWidth = 1.5, ...
    MarkerSize = 7, ...
    Label = "", ...
    Tag = "roiEditor");

% The band and the shading follow the drag; the remeasure waits for the drag
% to finish, because reading a wide band off a full resolution page is far too
% slow to do on every mouse move.
addlistener(editor, "MovingROI", @(~, evt) obj.onRoiEditChanged(evt.CurrentPosition, false));
addlistener(editor, "ROIMoved", @(~, evt) obj.onRoiEditChanged(evt.CurrentPosition, true));

obj.RoiEditor = editor;

end
