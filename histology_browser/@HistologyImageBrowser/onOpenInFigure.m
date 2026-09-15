function onOpenInFigure(obj)
%ONOPENINFIGURE Redraw the current selection in a standard resizable figure.
% Useful for zooming, panning, and further editing before publication.
%
% The tiles drawn here deliberately carry no right-click menu. A context menu
% belongs to one figure and cannot be shared with another, and this window
% already has the toolbar and menu bar that the browser's own menu stands in
% for; ATTACHCONTEXTMENU declines any axes outside the app figure for exactly
% that reason.
%
% See also DRAWIMAGETILE, ATTACHCONTEXTMENU, ONEXPORTVIEW.

rows = obj.selectedRows();

if isempty(rows) || height(rows) == 0
    obj.setWarning("Select at least one section first.");
    uialert(obj.Fig, "Select at least one section first.", "Nothing Selected");
    return
end

nDrawn = min(height(rows), max(1, round(obj.MaxTilesField.Value)));

% The figure takes the background chosen in the app so what opens here, and
% anything exported from it, matches what was on screen.
fig = figure( ...
    Name = "Histology Images", ...
    NumberTitle = "off", ...
    Color = obj.ImageBackground);

layout = tiledlayout(fig, "flow", Padding = "tight", TileSpacing = "tight");

colors = HistologyImageBrowser.tileColors(nDrawn);

% No tile is marked active here. This figure is a picture to keep, not the
% surface an ROI is dragged on, and the ROI controls act on the browser's own
% tiles whatever this window is showing.
for iRow = 1:nDrawn
    ax = nexttile(layout);
    obj.drawImageTile(ax, rows(iRow, :), colors(iRow, :));
end

if height(rows) > nDrawn
    obj.setWarning("Opened %d of %d selected sections in a figure. Raise Max tiles for the rest.", ...
        nDrawn, height(rows));
else
    obj.setSuccess("Opened %d section(s) in a figure.", nDrawn);
end

end
