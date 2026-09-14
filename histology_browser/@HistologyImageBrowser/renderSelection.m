function renderSelection(obj)
%RENDERSELECTION Draw every selected section as a tile, plus their profiles.
% This is the expensive path: the tiled layout is destroyed and rebuilt, so
% every image is read again and every pixel restretched. ONDISPLAYOPTIONCHANGED
% sends only the changes that actually alter the pixels here, and REFRESHOVERLAYS
% takes the rest.
%
% See also REFRESHOVERLAYS, DRAWIMAGETILE, RENDERPROFILEPLOT.

% Recorded before anything is drawn rather than after, so that every way out of
% this function -- including the early return on an empty selection -- leaves
% the key describing what is on screen. Nothing below changes a setting the key
% is built from, so the two moments are the same state.
obj.RenderKey = obj.displayRenderKey();

obj.applyViewLayout();

if ~isempty(obj.ImageLayout) && isvalid(obj.ImageLayout)
    delete(obj.ImageLayout);
end

rows = obj.selectedRows();

if isempty(rows) || height(rows) == 0
    cla(obj.ProfileAxes);
    obj.setStatus("No section selected.");
    return
end

maxTiles = max(1, round(obj.MaxTilesField.Value));
nSelected = height(rows);
nDrawn = min(nSelected, maxTiles);

% Reading and stretching several large sections is slow enough to look like a
% hang, so the bar says what is happening before the first tile is drawn.
if nDrawn > 1
    obj.setBusy("Drawing %d sections ...", nDrawn);
else
    obj.setBusy("Drawing 1 section ...");
end

% Tiles are skipped outright when the layout hides them, so "Profiles only"
% costs nothing in image loading.
if obj.showImages()
    obj.applyImageBackground();

    obj.ImageLayout = tiledlayout(obj.ImagePanel, "flow", ...
        Padding = "tight", ...
        TileSpacing = "tight");

    colors = tile_colors(nDrawn);

    for iRow = 1:nDrawn
        ax = nexttile(obj.ImageLayout);
        obj.drawImageTile(ax, rows(iRow, :), colors(iRow, :));
    end
end

obj.renderProfilePlot();

report_status(obj, nSelected, nDrawn, rows(1:nDrawn, :));

end

function colors = tile_colors(n)
%TILE_COLORS Assign one distinguishable color per tile.

if n <= 7
    colors = lines(max(n, 1));
    return
end

colors = turbo(n);

end

function report_status(obj, nSelected, nDrawn, drawnRows)
%REPORT_STATUS Say what was drawn, including anything the tile cap withheld.
% Sections lacking an atlas plate or a profile are still drawn, so the status
% line names the gap rather than letting a blank profile panel imply an error.
% A missing image file is the one gap that leaves an empty tile, so it is
% reported as a warning rather than as ordinary progress.

gaps = describe_gaps(drawnRows) + describe_missing_images(obj, drawnRows);
nMissing = count_missing_images(obj, drawnRows);

if nDrawn < nSelected
    obj.setWarning("Showing %d of %d selected sections.%s Raise Max tiles to see the rest.", ...
        nDrawn, nSelected, gaps);
    return
end

if nMissing > 0
    obj.setWarning("Showing %d of %d sections.%s", nDrawn - nMissing, nSelected, gaps);
    return
end

if nSelected == 1
    obj.setStatus("Showing 1 section.%s", gaps);
    return
end

obj.setStatus("Showing %d sections.%s", nSelected, gaps);

end

function text = describe_missing_images(obj, rows)
%DESCRIBE_MISSING_IMAGES Name the sections whose chosen rendition is absent.

text = "";
nMissing = count_missing_images(obj, rows);

if nMissing == 0
    return
end

text = sprintf(" %d image file(s) could not be found for the chosen variant.", nMissing);

end

function nMissing = count_missing_images(obj, rows)
%COUNT_MISSING_IMAGES Count the drawn rows with no readable image on disk.

nMissing = 0;

for iRow = 1:height(rows)
    imagePath = obj.resolveImagePath(rows(iRow, :));

    if imagePath == "" || ~isfile(imagePath)
        nMissing = nMissing + 1;
    end
end

end

function text = describe_gaps(rows)
%DESCRIBE_GAPS Summarize which annotations the drawn sections are missing.

text = "";

if height(rows) == 0
    return
end

if height(rows) == 1
    missing = HistologyImageBrowser.missingMetadata(rows);

    if missing ~= ""
        text = " Missing metadata: " + missing + ".";
    end

    return
end

nNoPlate = sum(isnan(rows.AtlasPlate));
nNoProfile = sum(rows.NProfiles == 0);

parts = strings(0, 1);

if nNoPlate > 0
    parts(end + 1) = sprintf("%d without an atlas plate", nNoPlate);
end

if nNoProfile > 0
    parts(end + 1) = sprintf("%d without a profile", nNoProfile);
end

if isempty(parts)
    return
end

text = " " + join(parts, ", ") + ".";

end
