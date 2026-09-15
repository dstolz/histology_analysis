function attachSurfaceEditor(obj, ax, row)
%ATTACHSURFACEEDITOR Put the draggable brain surface mark onto the edited tile.
% The mark is a point on the line, so it gets a handle of its own beside the
% line's: dragging it along the line is the quickest way to correct a detection
% that landed a little off, which is the common case and the one the Mark
% button is too many clicks for.
%
% Like ATTACHROIEDITOR, the handle is rebuilt on every redraw and the position
% lives in the browser rather than in the graphics object, so deleting and
% recreating it never loses a mark. A line with no mark gets no handle at all,
% which is what makes clearing one take its handle away.
%
% See also ATTACHROIEDITOR, ONSURFACEEDITCHANGED, ONMARKSURFACE.

if ~isempty(obj.SurfaceEditor) && isvalid(obj.SurfaceEditor)
    delete(obj.SurfaceEditor);
end

obj.SurfaceEditor = [];

if ~obj.isEditingRow(row)
    return
end

if exist("images.roi.Point", "class") ~= 8
    return
end

R = obj.roiForRow(row);
point = HistologyImageBrowser.surfacePoint(R);

if isempty(point)
    return
end

style = HistologyImageBrowser.roiStateStyle(R.state);

editor = images.roi.Point(ax, ...
    Position = point, ...
    Color = style.Color, ...
    MarkerSize = 10, ...
    LineWidth = 1.5, ...
    Label = "", ...
    Tag = "surfaceEditor");

addlistener(editor, "MovingROI", @(~, evt) obj.onSurfaceEditChanged(evt.CurrentPosition, false));
addlistener(editor, "ROIMoved", @(~, evt) obj.onSurfaceEditChanged(evt.CurrentPosition, true));

obj.SurfaceEditor = editor;

end
