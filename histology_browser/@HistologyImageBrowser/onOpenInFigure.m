function fig = onOpenInFigure(obj)
%ONOPENINFIGURE Redraw the current view in a standard resizable figure.
% Useful for zooming, panning, and further editing before publication.
%
% The current view is the image tiles and the profile plot together, placed
% the way the Position and Size % controls place them in the browser: profiles
% below, above, or beside the tiles in the same proportions, the plot alone
% under "Profiles only", and the tiles alone when the profiles are hidden. This
% used to draw the tiles and nothing else, so asking for the plot -- from the
% plot's own right-click menu, even -- opened the pictures without it.
%
% Both halves go in one tiled layout: the tiles in a layout nested in it and
% the plot in an axes beside that, each spanning its share of a fine grid. Not
% two panels, which is how the browser itself splits them, because
% EXPORTGRAPHICS refuses a figure holding more than one panel, and exporting
% from this window is the reason it exists. Without a panel of its own the plot
% sits on the image background, so its axis text takes the color the tiles'
% own text does, and stays legible on a dark background.
%
% The tiles and the plot drawn here deliberately carry no right-click menu. A
% context menu belongs to one figure and cannot be shared with another, and
% this window already has the toolbar and menu bar that the browser's own menu
% stands in for; ATTACHCONTEXTMENU declines any axes outside the app figure
% for exactly that reason.
%
% Returns
%   fig: The figure opened, or an empty graphics array when there was nothing
%       selected to open. The plot's axes carries the Tag "profilePlot".
%
% See also DRAWIMAGETILE, RENDERPROFILEPLOT, APPLYVIEWLAYOUT, ONEXPORTVIEW.

fig = gobjects(0);

rows = obj.selectedRows();

if isempty(rows) || height(rows) == 0
    obj.setWarning("Select at least one section first.");
    uialert(obj.Fig, "Select at least one section first.", "Nothing Selected");
    return
end

nDrawn = min(height(rows), max(1, round(obj.MaxTilesField.Value)));

fig = figure( ...
    Name = "Histology View", ...
    NumberTitle = "off");

% The figure takes the background chosen in the app whenever there are tiles
% in it, so what opens here, and anything exported from it, matches what was
% on screen.
if obj.showImages()
    fig.Color = obj.ImageBackground;
end

[imageLayout, profileAxes] = split_view(obj, fig);

% No tile is marked active here. This figure is a picture to keep, not the
% surface an ROI is dragged on, and the ROI controls act on the browser's own
% tiles whatever this window is showing.
if ~isempty(imageLayout)
    colors = HistologyImageBrowser.tileColors(nDrawn);

    for iRow = 1:nDrawn
        ax = nexttile(imageLayout);
        obj.drawImageTile(ax, rows(iRow, :), colors(iRow, :));
    end
end

% Drawn by the code that draws the browser's own plot, so the traces, their
% colors and strokes, the normalization, the surface rules and the notes are
% the ones on screen, and the colors still match the tiles beside them.
if ~isempty(profileAxes)
    obj.renderProfilePlot(profileAxes);
    frame_legend(obj, profileAxes);
end

if height(rows) > nDrawn
    obj.setWarning("Opened %d of %d selected sections in a figure. Raise Max tiles for the rest.", ...
        nDrawn, height(rows));
else
    obj.setSuccess("Opened %d section(s) in a figure.", nDrawn);
end

end

function [imageLayout, profileAxes] = split_view(obj, fig)
%SPLIT_VIEW Make the tile layout and the plot axes the layout calls for.
% Either comes back empty when the layout hides it. With only one of them shown
% it has the figure to itself; with both, they divide a grid of SLOTS cells
% along the edge APPLYVIEWLAYOUT splits the browser on, by the same share.

imageLayout = [];
profileAxes = [];

if ~obj.showProfile()
    imageLayout = image_layout(fig);
    return
end

if ~obj.showImages()
    profileAxes = axes(fig, Tag = "profilePlot");
    return
end

slots = 20;
nProfile = min(max(round(obj.profileShare() * slots), 1), slots - 1);
nImage = slots - nProfile;

layout = obj.profileLayout();

% Stacked layouts split by row, side-by-side ones by column.
if ismember(layout, ["left", "right"])
    grid = [1 slots];
    imageSpan = [1 nImage];
    profileSpan = [1 nProfile];
else
    grid = [slots 1];
    imageSpan = [nImage 1];
    profileSpan = [nProfile 1];
end

% Whichever comes first along the split takes tile 1, the other the tile
% after it.
if ismember(layout, ["top", "left"])
    profileTile = 1;
    imageTile = nProfile + 1;
else
    imageTile = 1;
    profileTile = nImage + 1;
end

outer = tiledlayout(fig, grid(1), grid(2), Padding = "compact", TileSpacing = "compact");

imageLayout = image_layout(outer);
imageLayout.Layout.Tile = imageTile;
imageLayout.Layout.TileSpan = imageSpan;

profileAxes = nexttile(outer, profileTile, profileSpan);
profileAxes.Tag = "profilePlot";

% Its ticks and labels sit on the image background rather than on a panel of
% their own, so they take the tiles' text color. The plot area keeps its own
% white, which is what the traces were colored to read against.
textColor = obj.tileTextColor();
profileAxes.XColor = textColor;
profileAxes.YColor = textColor;

end

function frame_legend(obj, ax)
%FRAME_LEGEND Keep the legend legible on a dark background.
% RENDERPROFILEPLOT draws it without a box, dark text straight on the plot. A
% plot squeezed beside the tiles can push it partly past the axes onto the
% figure, and on a dark background that half vanishes, so there it is given a
% white box of its own. On a light background it is left exactly as the browser
% draws it.

if ~HistologyImageBrowser.isDarkColor(obj.ImageBackground)
    return
end

lgd = ax.Legend;

if isempty(lgd) || ~isvalid(lgd)
    return
end

lgd.Box = "on";
lgd.Color = [1 1 1];
lgd.EdgeColor = [0.75 0.75 0.75];
lgd.TextColor = [0.15 0.15 0.15];

end

function layout = image_layout(parent)
%IMAGE_LAYOUT The flowing grid the tiles are drawn into, as in the browser.

layout = tiledlayout(parent, "flow", Padding = "tight", TileSpacing = "tight");

end
