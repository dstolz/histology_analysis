function onOpenInFigure(obj)
%ONOPENINFIGURE Redraw the current selection in a standard resizable figure.
% Useful for zooming, panning, and further editing before publication.

rows = obj.selectedRows();

if isempty(rows) || height(rows) == 0
    obj.setWarning("Select at least one section first.");
    uialert(obj.Fig, "Select at least one section first.", "Nothing Selected");
    return
end

nDrawn = min(height(rows), max(1, round(obj.MaxTilesField.Value)));

fig = figure( ...
    Name = "Histology Images", ...
    NumberTitle = "off", ...
    Color = "w");

layout = tiledlayout(fig, "flow", Padding = "tight", TileSpacing = "tight");

if nDrawn <= 7
    colors = lines(nDrawn);
else
    colors = turbo(nDrawn);
end

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
