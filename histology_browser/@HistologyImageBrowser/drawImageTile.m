function drawImageTile(obj, ax, row, tileColor)
%DRAWIMAGETILE Draw one section image, contrast stretched, with its overlay.
% The image is drawn in full resolution coordinates even though the pixel data
% may be downsampled, so ROI coordinates need no rescaling.

imagePath = obj.resolveImagePath(row);

if imagePath == ""
    show_placeholder(ax, row, "No image file available");
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
    show_placeholder(ax, row, read_failure_text(imagePath, reason));
    return
end

isRGB = ndims(img) == 3;

if isRGB
    image(ax, [1 imageSize(2)], [1 imageSize(1)], img);
else
    imagesc(ax, [1 imageSize(2)], [1 imageSize(1)], img);
    clim(ax, [0 1]);
    colormap(ax, resolve_colormap(obj.ColormapDropDown.Value));
end

axis(ax, "image");
ax.XTick = [];
ax.YTick = [];
ax.XLim = [1 imageSize(2)];
ax.YLim = [1 imageSize(1)];
ax.Box = "on";
ax.XColor = tileColor;
ax.YColor = tileColor;
ax.LineWidth = 1.5;

hold(ax, "on");
obj.drawRoiOverlay(ax, row, tileColor);
obj.attachRoiEditor(ax, row);
note_missing_metadata(ax, row);
hold(ax, "off");

title(ax, tile_title(row), Interpreter = "none", FontSize = 9, Color = tileColor);

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

function show_placeholder(ax, row, message)
%SHOW_PLACEHOLDER Explain why a tile is blank instead of leaving it empty.

cla(ax);
ax.XTick = [];
ax.YTick = [];
ax.XLim = [0 1];
ax.YLim = [0 1];
ax.Box = "on";

text(ax, 0.5, 0.5, message, ...
    HorizontalAlignment = "center", ...
    VerticalAlignment = "middle", ...
    Interpreter = "none", ...
    FontSize = 9, ...
    Color = [0.6 0.2 0.2]);

title(ax, tile_title(row), Interpreter = "none", FontSize = 9);

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
