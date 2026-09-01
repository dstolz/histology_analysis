function drawRoiOverlay(obj, ax, row, tileColor)
%DRAWROIOVERLAY Draw every line ROI of one section and, optionally, its profile.
%
% A section may carry several ROIs, one per region measured across it. All of
% them are drawn, and each is captioned with what it is called, because a tile
% showing two lines and no names says only that two things were measured.
%
% The profile in a *values.csv file is the mean intensity across the full line
% width at each step along the line, so the shaded overlay is drawn as a strip
% of quads spanning that width rather than as a thin line. That keeps the
% picture honest about which pixels each sample actually came from.
%
% The line and the band outline are stroked by ROISTATESTYLE, so how an ROI
% stands against the .roi file beside it -- read from disk, being edited,
% edited and not yet written, or just written -- is readable off the tile.

% Every overlay object is tagged so a drag can replace just these graphics
% without redrawing, and so rereading, the image underneath them.
keys = obj.roiKeysForRow(row);

if isempty(keys)
    return
end

badges = strings(0, 1);
badgeStyles = {};

for iKey = 1:numel(keys)
    style = draw_one_roi(obj, ax, row, tileColor, keys(iKey));

    if isempty(style) || style.Badge == ""
        continue
    end

    badges(end + 1, 1) = style.Badge; %#ok<AGROW>
    badgeStyles{end + 1} = style; %#ok<AGROW>
end

label_states(ax, badges, badgeStyles);

end

function style = draw_one_roi(obj, ax, row, tileColor, key)
%DRAW_ONE_ROI Draw one ROI's band, shading, line, and caption.
% Returns the style it was drawn in, or [] when nothing was drawn, so the
% caller can collect the badges and stack them rather than let two ROIs in
% different states write over each other in the same corner of the tile.

style = [];

R = obj.roiForRow(row, key);

if ~R.isValid || ~R.isLine
    return
end

wantsRoi = obj.ShowRoiCheck.Value;
wantsShading = obj.ColorByIntensityCheck.Value;

% A line being dragged has nothing measured under it yet, so the band is left
% fully transparent until the mouse comes up and the new profile is read.
if R.isEditing && obj.RoiEditDragging
    wantsShading = false;
end

% While a line is being edited its width is one of the things being set, so
% the band is outlined and labelled whether or not the overlay is switched on.
wantsBand = obj.ShowBandCheck.Value || R.isEditing;

if ~(wantsRoi || wantsBand || wantsShading)
    return
end

geometry = line_geometry(R);
style = HistologyImageBrowser.roiStateStyle(R.state, tileColor);

if wantsShading
    P = obj.readProfile(row, key);

    if P.hasData
        draw_intensity_strip(ax, geometry, P);
    end
end

if wantsBand && geometry.halfWidth > 0
    corners = band_corners(geometry);

    plot(ax, corners(:, 1), corners(:, 2), ...
        LineStyle = style.BandLineStyle, ...
        LineWidth = style.BandLineWidth, ...
        Color = style.Color, ...
        Tag = "roiOverlay");

    if R.isEditing
        label_band(ax, geometry, style, obj.describeRoiWidth(R.strokeWidth));
    end
end

% While the ROI is being edited the draggable line is the line, so drawing a
% second one over it would only make the handles harder to grab.
if wantsRoi && ~R.isEditing
    plot(ax, [geometry.x1 geometry.x2], [geometry.y1 geometry.y2], ...
        LineStyle = style.LineStyle, ...
        LineWidth = style.LineWidth, ...
        Color = style.Color, ...
        Tag = "roiOverlay");

    % Mark the start so the profile direction is unambiguous.
    plot(ax, geometry.x1, geometry.y1, ...
        Marker = style.Marker, ...
        MarkerSize = style.MarkerSize, ...
        MarkerFaceColor = style.Color, ...
        MarkerEdgeColor = "w", ...
        LineStyle = "none", ...
        Tag = "roiOverlay");
end

label_roi(ax, geometry, style, obj.roiName(key));

end

function label_roi(ax, geometry, style, name)
%LABEL_ROI Write what an ROI is called at the end its profile starts from.
% Two lines across one section are only ever told apart by name, and the name
% belongs where the profile begins, so it says which way along the line the
% trace in the plot runs as well as which line it came from.
%
% The caption sits just short of the first endpoint rather than on it, so it
% clears both the start marker and the sampling band; clipping keeps it inside
% the tile when a line starts at the very edge of the image.

if name == ""
    return
end

anchor = [geometry.x1, geometry.y1] - geometry.unit * (0.05 * geometry.length);

text(ax, anchor(1), anchor(2), name, ...
    Color = style.BadgeTextColor, ...
    BackgroundColor = style.Color, ...
    FontSize = 8, ...
    FontWeight = "bold", ...
    Margin = 2, ...
    Interpreter = "none", ...
    HorizontalAlignment = "center", ...
    VerticalAlignment = "middle", ...
    Clipping = "on", ...
    Tag = "roiOverlay");

end

function label_states(ax, badges, styles)
%LABEL_STATES Name the ROI save states in the corner of the tile they belong to.
% The on-disk state is deliberately unlabelled: it is the ordinary case, on
% every tile of a grid at once, and a badge on all of them would say nothing.
% What is left is at most one ROI being edited and at most one just written,
% and those two are stacked rather than drawn over each other.

for iBadge = 1:numel(badges)
    style = styles{iBadge};

    text(ax, 0.02, 0.98 - 0.07 * (iBadge - 1), badges(iBadge), ...
        Units = "normalized", ...
        HorizontalAlignment = "left", ...
        VerticalAlignment = "top", ...
        Color = style.BadgeTextColor, ...
        BackgroundColor = style.Color, ...
        FontSize = 8, ...
        FontWeight = "bold", ...
        Margin = 3, ...
        Tag = "roiOverlay");
end

end

function geometry = line_geometry(R)
%LINE_GEOMETRY Derive the unit direction and normal of the line ROI.

geometry = struct();
geometry.x1 = R.x1;
geometry.y1 = R.y1;
geometry.x2 = R.x2;
geometry.y2 = R.y2;

delta = [R.x2 - R.x1, R.y2 - R.y1];
geometry.length = hypot(delta(1), delta(2));

if geometry.length > 0
    unit = delta / geometry.length;
else
    unit = [1 0];
end

geometry.unit = unit;
geometry.normal = [-unit(2), unit(1)];
geometry.halfWidth = max(R.strokeWidth, 0) / 2;

end

function label_band(ax, geometry, style, widthText)
%LABEL_BAND Write the band width on the edge of the band it describes.
% A 994 px band on a downsampled tile is easy to misjudge by eye, so the
% number sits on the edge being set rather than only in the control panel.

midpoint = [(geometry.x1 + geometry.x2) / 2, (geometry.y1 + geometry.y2) / 2];
anchor = midpoint + geometry.normal * geometry.halfWidth;

text(ax, anchor(1), anchor(2), "band " + widthText, ...
    Color = style.BadgeTextColor, ...
    BackgroundColor = style.Color, ...
    FontSize = 8, ...
    Margin = 2, ...
    HorizontalAlignment = "center", ...
    VerticalAlignment = "middle", ...
    Clipping = "on", ...
    Tag = "roiOverlay");

end

function corners = band_corners(geometry)
%BAND_CORNERS Compute the closed outline of the averaged sampling band.

offset = geometry.normal * geometry.halfWidth;

p1 = [geometry.x1, geometry.y1];
p2 = [geometry.x2, geometry.y2];

corners = [ ...
    p1 + offset; ...
    p2 + offset; ...
    p2 - offset; ...
    p1 - offset; ...
    p1 + offset];

end

function draw_intensity_strip(ax, geometry, P)
%DRAW_INTENSITY_STRIP Shade the sampled band by the measured intensity.
% Colors are supplied as explicit RGB so the overlay never competes with the
% colormap the image itself is drawn with.

maxQuads = 200;

span = P.distance(end) - P.distance(1);

if span <= 0
    return
end

t = (P.distance - P.distance(1)) / span;

nQuads = min(maxQuads, numel(t) - 1);

if nQuads < 1
    return
end

edges = linspace(0, 1, nQuads + 1)';
faceValues = interp1(t, P.intensity, (edges(1:end-1) + edges(2:end)) / 2, "linear", "extrap");

p1 = [geometry.x1, geometry.y1];
delta = [geometry.x2 - geometry.x1, geometry.y2 - geometry.y1];

halfWidth = geometry.halfWidth;

if halfWidth <= 0
    halfWidth = max(geometry.length * 0.02, 2);
end

offset = geometry.normal * halfWidth;

centers = p1 + edges .* delta;
upper = centers + offset;
lower = centers - offset;

vertices = [upper; lower];

nEdges = nQuads + 1;
idx = (1:nQuads)';
faces = [idx, idx + 1, idx + 1 + nEdges, idx + nEdges];

patch(ax, ...
    Faces = faces, ...
    Vertices = vertices, ...
    FaceVertexCData = intensity_to_rgb(faceValues), ...
    FaceColor = "flat", ...
    FaceAlpha = 0.55, ...
    EdgeColor = "none", ...
    Tag = "roiOverlay");

end

function rgb = intensity_to_rgb(values)
%INTENSITY_TO_RGB Map profile intensities onto a fixed perceptual colormap.

cmap = turbo(256);

finiteValues = values(isfinite(values));

if isempty(finiteValues)
    rgb = repmat(cmap(1, :), numel(values), 1);
    return
end

lo = min(finiteValues);
hi = max(finiteValues);

if hi <= lo
    scaled = zeros(size(values));
else
    scaled = (values - lo) / (hi - lo);
end

scaled(~isfinite(scaled)) = 0;

idx = round(scaled * (size(cmap, 1) - 1)) + 1;
idx = min(max(idx, 1), size(cmap, 1));

rgb = cmap(idx, :);

end
