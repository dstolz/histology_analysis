function drawImageTile(obj, ax, row, tileColor, isActive)
%DRAWIMAGETILE Draw one section image, contrast stretched, with its overlay.
% The image is drawn in full resolution coordinates even though the pixel data
% may be downsampled, so ROI coordinates need no rescaling.
%
% Parameters
%   tileColor: Frame, title and ROI color for this tile, from TILECOLORS.
%   isActive: Mark this tile as the one the ROI controls act on. RENDERSELECTION
%       sets it only when more than one tile is drawn, because on a single tile
%       the mark would be on the only thing it could be on.
%
% See also TILECOLORS, DRAWROIOVERLAY, ATTACHROIEDITOR, ACTIVEROISTEM, MARKTILE.

arguments
    obj
    ax
    row
    tileColor (1,3) double
    isActive (1,1) logical = false
end

% Stamped before the first early return, so a blank tile is still
% identifiable, and again once the picture is on it; see STAMP_TILE.
stamp_tile(ax, row, tileColor);

imagePath = obj.resolveImagePath(row);

ax.Color = obj.ImageBackground;

if imagePath == ""
    show_placeholder(obj, ax, row, tileColor, isActive, "No image file available");
    return
end

channel = obj.ChannelDropDown.Value;

if isequal(channel, "merge")
    [img, imageSize, reason] = build_merged_image(obj, imagePath);
else
    [raw, imageSize, reason] = obj.loadDisplayImage(imagePath, channel);
    img = stretch_to_display(obj, raw);
end

if isempty(img)
    show_placeholder(obj, ax, row, tileColor, isActive, read_failure_text(imagePath, reason));
    return
end

isRGB = ndims(img) == 3;

if isRGB
    hImage = image(ax, [1 imageSize(2)], [1 imageSize(1)], img);
else
    hImage = imagesc(ax, [1 imageSize(2)], [1 imageSize(1)], img);
    clim(ax, [0 1]);
    colormap(ax, resolve_colormap(obj.ColormapDropDown.Value));
end

% Hovering the picture used to raise a data tip over whatever was underneath
% the pointer, which got in the way of reading the section and of dragging an
% ROI across it. Zoom, pan and restore view still work on the axes.
hImage.PickableParts = "none";

% IMAGE and IMAGESC both go through NEWPLOT, which resets the axes to its
% defaults, and UserData is one of the properties reset. Stamping only before
% the picture is drawn therefore left every tile that actually had an image on
% it anonymous, and only the blank ones identifiable -- the exact opposite of
% what the stamp is for.
stamp_tile(ax, row, tileColor);

axis(ax, "image");
ax.XTick = [];
ax.YTick = [];
ax.XLim = [1 imageSize(2)];
ax.YLim = [1 imageSize(1)];
ax.Box = "on";
ax.XColor = tileColor;
ax.YColor = tileColor;

hold(ax, "on");
obj.drawRoiOverlay(ax, row, tileColor);
obj.attachRoiEditor(ax, row);
note_missing_metadata(ax, row);
place_title(ax, tile_title(row), tileColor);
hold(ax, "off");

% After the label exists, because the mark is written into it as well as into
% the frame. MARKROITARGET calls the same thing when the target moves later.
HistologyImageBrowser.markTile(ax, isActive);

% Attached last, so the title and the overlay drawn above are both covered by
% the one walk. The image is given the menu along with everything else even
% though the click can never reach it: its PickableParts were switched off a
% few lines up, which is what makes the axes behind it answer instead.
obj.attachContextMenu(ax, "tile");

end

function place_title(ax, label, tileColor)
%PLACE_TITLE Write the tile's label inside the axes box rather than above it.
% A MATLAB title sits outside the box and takes a strip of the layout with it,
% and on a grid of a dozen sections that is a strip taken a dozen times, out of
% the pictures the window exists to show. Pinned to the top of the axes in
% normalized units instead, the label costs the section nothing and stays put
% through a zoom or a pan.
%
% Sections are usually near-black fluorescence, so the label is set on an
% opaque plate rather than drawn straight onto the picture: over a dark section
% the plate disappears and only the color reads, and over a bright brightfield
% one the plate is what keeps it legible.
%
% Written unmarked, and MARKTILE restyles it afterwards. The plain wording is
% kept in UserData because that is what MARKTILE has to put back when the ROI
% target moves off this tile, and recovering it by trimming a suffix would mean
% the marked wording was spelled out in two files at once.
%
% Left aligned, because DRAWROIOVERLAY puts the ROI state badge in the opposite
% corner; the two share the top edge and must not be able to collide.

% Not tagged "roiOverlay": REFRESHTILEOVERLAY sweeps that tag away on every
% overlay change and would take the title with it, never to redraw it.
handle = text(ax, 0.012, 0.988, label, ...
    Units = "normalized", ...
    HorizontalAlignment = "left", ...
    VerticalAlignment = "top", ...
    Interpreter = "none", ...
    FontSize = 9, ...
    FontWeight = "normal", ...
    Color = tileColor, ...
    BackgroundColor = [0.09 0.09 0.09], ...
    Margin = 2, ...
    Tag = "tileTitle");

handle.UserData = string(label);

end

function stamp_tile(ax, row, tileColor)
%STAMP_TILE Record on the axes which section it shows and in what color.
% Anything reaching this axes later -- the ROI editor looking for its own tile,
% an overlay redrawn mid-drag, a context menu item asked to act on the tile
% under the pointer -- reads what it needs off the axes rather than
% recomputing the layout that produced it. TILESTEM and TILECOLOR are the
% readers; this is the one writer.

ax.UserData = struct(Stem = string(row.Stem), TileColor = tileColor);

end

function note_missing_metadata(ax, row)
%NOTE_MISSING_METADATA Say on the image itself which annotations are absent.
% The picture is always worth showing, so a section without an atlas plate or
% without a measured profile is labelled rather than withheld.

missing = HistologyImageBrowser.missingMetadata(row);

if missing == ""
    return
end

text(ax, 0.02, 0.02, missing, ...
    Units = "normalized", ...
    HorizontalAlignment = "left", ...
    VerticalAlignment = "bottom", ...
    Interpreter = "none", ...
    FontSize = 8, ...
    Color = [0.95 0.95 0.95], ...
    BackgroundColor = [0.35 0.15 0.15], ...
    Margin = 2);

end

function [img, imageSize, reason] = build_merged_image(obj, imagePath)
%BUILD_MERGED_IMAGE Combine the first channels into one RGB composite.

img = [];
imageSize = [0 0];
reason = "";

nPages = 1;

try
    [~, ~, ext] = fileparts(imagePath);

    if ismember(lower(string(ext)), [".tif", ".tiff"])
        nPages = numel(imfinfo(imagePath));
    end
catch
    nPages = 1;
end

% Green then magenta matches the usual two-marker fluorescence convention and
% stays readable for the most common forms of color vision deficiency.
channelColors = [0 1 0; 1 0 1; 0 1 1; 1 1 0];
nPages = min(nPages, size(channelColors, 1));

for iPage = 1:nPages
    [raw, thisSize, pageReason] = obj.loadDisplayImage(imagePath, iPage);

    if isempty(raw)
        if reason == ""
            reason = pageReason;
        end

        continue
    end

    if ndims(raw) == 3
        img = stretch_to_display(obj, raw);
        imageSize = thisSize;
        return
    end

    scaled = stretch_to_display(obj, raw);

    if isempty(img)
        img = zeros([size(scaled, 1), size(scaled, 2), 3]);
        imageSize = thisSize;
    end

    for iColor = 1:3
        img(:, :, iColor) = img(:, :, iColor) + scaled * channelColors(iPage, iColor);
    end
end

img = min(max(img, 0), 1);

end

function img = stretch_to_display(obj, raw)
%STRETCH_TO_DISPLAY Rescale using the requested display percentiles.

img = [];

if isempty(raw)
    return
end

% An RGB composite was already contrast-adjusted when it was written, so it
% is only converted to the [0 1] range rather than restretched.
if ndims(raw) == 3 && size(raw, 3) == 3
    img = rgb_to_unit_range(raw);
    return
end

img = double(raw);

lowPct = min(obj.LowPercentileField.Value, obj.HighPercentileField.Value);
highPct = max(obj.LowPercentileField.Value, obj.HighPercentileField.Value);

limits = percentile_limits(img, lowPct, highPct);

if limits(2) <= limits(1)
    img = zeros(size(img));
    return
end

img = (img - limits(1)) / (limits(2) - limits(1));
img = min(max(img, 0), 1);

end

function rgb = rgb_to_unit_range(raw)
%RGB_TO_UNIT_RANGE Convert an RGB image to double in [0 1].

if isinteger(raw)
    rgb = double(raw) / double(intmax(class(raw)));
else
    rgb = double(raw);

    peak = max(rgb(:));

    if peak > 1
        rgb = rgb / peak;
    end
end

rgb = min(max(rgb, 0), 1);

end

function limits = percentile_limits(img, lowPct, highPct)
%PERCENTILE_LIMITS Compute display limits without needing extra toolboxes.

values = img(isfinite(img));

if isempty(values)
    limits = [0 1];
    return
end

% Sorting every pixel of every tile on each redraw is the dominant cost here,
% and a subsample estimates display percentiles closely enough.
maxSamples = 200000;

if numel(values) > maxSamples
    values = values(1:ceil(numel(values) / maxSamples):end);
end

values = sort(values(:));
n = numel(values);

lowIdx = min(max(round(lowPct / 100 * n), 1), n);
highIdx = min(max(round(highPct / 100 * n), 1), n);

limits = [values(lowIdx), values(highIdx)];

end

function cmap = resolve_colormap(name)
%RESOLVE_COLORMAP Build the requested colormap, including two tinted ramps.

switch string(name)
    case "green"
        cmap = [zeros(256, 1), linspace(0, 1, 256)', zeros(256, 1)];
    case "magenta"
        ramp = linspace(0, 1, 256)';
        cmap = [ramp, zeros(256, 1), ramp];
    otherwise
        cmap = feval(char(name), 256);
end

end

function show_placeholder(obj, ax, row, tileColor, isActive, message)
%SHOW_PLACEHOLDER Explain why a tile is blank instead of leaving it empty.
% The reason has to stay readable whatever the panel background is, so it takes
% its color from the background rather than being fixed. The title does not:
% it sits on its own plate, which is opaque, so it reads the same here as on a
% tile that has a picture on it.

cla(ax);
ax.Color = obj.ImageBackground;
ax.XTick = [];
ax.YTick = [];
ax.XLim = [0 1];
ax.YLim = [0 1];
ax.Box = "on";
ax.XColor = obj.tileTextColor();
ax.YColor = obj.tileTextColor();

text(ax, 0.5, 0.5, message, ...
    HorizontalAlignment = "center", ...
    VerticalAlignment = "middle", ...
    Interpreter = "none", ...
    FontSize = 9, ...
    Color = obj.tileAlertColor());

place_title(ax, tile_title(row), tileColor);

% CLA leaves UserData alone, so the stamp made at the top of DRAWIMAGETILE is
% still there for MARKTILE to read the tile color back off.
HistologyImageBrowser.markTile(ax, isActive);

% A tile with no picture on it is still a tile: the colormap, the variant, and
% the channel are exactly the settings someone would reach for after seeing
% one, so it raises the same menu the drawn tiles do.
obj.attachContextMenu(ax, "tile");

end

function label = tile_title(row)
%TILE_TITLE Build a compact identifying label for one tile.

subject = replace(string(row.SubjectID), "SUBJ-ID-", "");

if subject == ""
    label = string(row.Stem);
else
    label = subject + " " + row.SectionID + " " + row.Hemisphere;

    if row.Stain ~= ""
        label = label + " " + row.Stain;
    end
end

% The plate is always stated, as "n/a" when unknown, so a section whose atlas
% assignment is simply missing cannot be mistaken for one never checked.
if isnan(row.AtlasPlate)
    label = label + " | plate n/a";
else
    label = label + sprintf(" | plate %g", row.AtlasPlate);
end

end

function txt = read_failure_text(imagePath, reason)
%READ_FAILURE_TEXT Say why a file would not read, not only that it would not.
% A missing Bio-Formats path and a corrupt file look identical on a blank tile,
% so the reader's own words go on the tile underneath the filename.

txt = "Could not read " + string(shorten(imagePath));

if reason ~= ""
    txt = [txt; reason];
end

end

function short = shorten(p)
%SHORTEN Reduce a path to its filename for message text.

[~, name, ext] = fileparts(p);
short = name + ext;

end
