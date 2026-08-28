function refreshRoiOverlay(obj)
%REFRESHROIOVERLAY Redraw the overlay of the tile being edited, in place.
% Redrawing the whole tile on every mouse move would reload and restretch the
% image, so only the ROI graphics are replaced while a line is being dragged.

if isempty(obj.RoiEditor) || ~isvalid(obj.RoiEditor)
    return
end

ax = obj.RoiEditor.Parent;

if isempty(ax) || ~isvalid(ax)
    return
end

row = obj.editedRow();

if height(row) ~= 1
    return
end

delete(findobj(ax, Tag = "roiOverlay"));

% The first move of a drag is what turns a clean edit dirty, so the handle is
% restyled here rather than waiting for the redraw at the end of the drag.
obj.applyRoiEditorStyle();

hold(ax, "on");
% Editing shows one tile at a time, which always takes the first tile color.
obj.drawRoiOverlay(ax, row, lines(1));
hold(ax, "off");

% The shaded band is drawn after the line, so the handles have to be lifted
% back above it to stay grabbable.
try
    uistack(obj.RoiEditor, "top");
catch
    % Not every release lets an ROI object restack; the overlay is
    % semi-transparent, so the line stays visible either way.
end

end
