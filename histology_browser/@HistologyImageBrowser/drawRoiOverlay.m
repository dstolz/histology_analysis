function drawRoiOverlay(obj, ax, row, tileColor)
%DRAWROIOVERLAY Draw the Fiji line ROI and, optionally, the measured profile.
%
% The profile in a *values.csv file is the mean intensity across the full line
% width at each step along the line, so the shaded overlay is drawn as a strip
% of quads spanning that width rather than as a thin line. That keeps the
% picture honest about which pixels each sample actually came from.
%
% The line and the band outline are stroked by ROISTATESTYLE, so how the ROI
% stands against the .roi file beside it -- read from disk, being edited,
% edited and not yet written, or just written -- is readable off the tile.
%
% The band can also be ruled with an optional grid. It is drawn in the band's
% own rotated frame rather than the axes', because the only thing anyone wants
% to know from it is whether the band is square to the boundary it is being
% aimed at, and an axis-aligned grid cannot answer that.
%
% See also ROISTATESTYLE, REFRESHTILEOVERLAY, REFRESHROIOVERLAY,
% BUILDDISPLAYPANEL, ATTACHCONTEXTMENU.

% Every overlay object is tagged so a drag can replace just these graphics
% without redrawing, and so rereading, the image underneath them.
R = obj.roiForRow(row);

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

% The grid answers one question -- is the band square to the boundary I am
% aiming it at -- and that question is only ever asked while the line is being
% placed. Ruling the band on every tile of a twelve-tile view would veil a
% dozen sections to answer it for nobody, so the grid follows the edit the way
% the width label below it does, and the checkbox says whether an edit gets one.
wantsGrid = R.isEditing && obj.ShowBandGridCheck.Value;

if ~(wantsRoi || wantsBand || wantsShading)
    return
end

geometry = line_geometry(R);
style = HistologyImageBrowser.roiStateStyle(R.state, tileColor);

if wantsShading
    P = obj.readProfile(row);

    if P.hasData
        draw_intensity_strip(ax, geometry, P);
    end
end

if wantsBand && geometry.halfWidth > 0
    % Ruled before the outline so the outline, the line, and the drag handles
    % all sit above the grid rather than being broken up by it.
    if wantsGrid
        draw_band_grid(ax, geometry, style);
    end

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

% The badge is the part that survives being glanced at. The stroke says what
% state the ROI is in to anyone reading the line; the badge says it in words
% to anyone reading the tile, and it is the only thing on screen that names an
% unsaved edit without the control panel being in view.
label_state(ax, style);

% The right-click menu is handed out by whichever function finishes the tile --
% DRAWIMAGETILE on a full redraw, REFRESHTILEOVERLAY on an overlay change --
% rather than from here. Both would then walk the same tile twice on every
% redraw, and the objects created here are still on the axes when either of
% them does its walk, so nothing is missed by leaving it to them.

end

function label_state(ax, style)
%LABEL_STATE Name the ROI's save state in the corner of the tile it belongs to.
% The on-disk state is deliberately unlabelled: it is the ordinary case, on
% every tile of a grid at once, and a badge on all of them would say nothing.

if style.Badge == ""
    return
end

text(ax, 0.02, 0.98, style.Badge, ...
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

function draw_band_grid(ax, geometry, style)
%DRAW_BAND_GRID Rule the sampling band in the band's own rotated frame.
% Every rule is built from the band's unit direction and its normal rather than
% from x and y, so the whole grid turns with the line: a layer boundary running
% along a rule is parallel to the line, and one running across a rule is square
% to it. An axis-aligned grid was the obvious thing to draw first and is no use
% here, because it says nothing about the line unless the line happens to point
% along an axis, which is the one case nobody needs help with.
%
% The pitch comes from the band width rather than from the tile, the image, or
% a field of its own, because the band is the thing being lined up. Eight
% divisions across put a rule every 75 to 125 px for the 600 to 1000 px bands
% this study samples with: close enough that a couple of degrees of tilt shows
% as a visible drift between a boundary and the rule beside it, and far enough
% apart that the section stays readable between them. That same pitch is
% repeated along the length so the cells come out square, which is what lets an
% angle be judged the same way whichever direction the line points; a fixed
% count of divisions in both directions was the alternative, and it stretches
% the cells with the line, so the grid would read differently on a long line
% than on a short one.
%
% Endpoints land on the band's own edges, so the grid is bounded by the band by
% construction and needs no clipping mask to keep it off the rest of the tile.

divisions = 8;
maxRules = 200;

spacing = 2 * geometry.halfWidth / divisions;

if ~isfinite(spacing) || spacing <= 0 || ~isfinite(geometry.length) || geometry.length <= 0
    return
end

origin = [geometry.x1, geometry.y1];

% Interior rules only: the band outline already strokes the perimeter, and a
% second stroke along it would thicken the very edge being judged. DIVISIONS is
% even, so the middle rule lands on the line itself.
half = divisions / 2 - 1;
across = (-half:half)' * spacing;

alongSpacing = spacing;
nAlong = floor(geometry.length / alongSpacing) - 1;

% A band many times longer than it is wide would otherwise be ruled into
% hundreds of cells. Square cells give way to a bounded count there, because a
% wash of rules hides the section the grid exists to be read against.
if nAlong > maxRules
    alongSpacing = geometry.length / (maxRules + 1);
    nAlong = maxRules;
end

along = (1:max(nAlong, 0))' * alongSpacing;

starts = [ ...
    origin + across .* geometry.normal; ...
    origin + along .* geometry.unit - geometry.normal * geometry.halfWidth];

spans = [ ...
    repmat(geometry.unit * geometry.length, numel(across), 1); ...
    repmat(geometry.normal * 2 * geometry.halfWidth, numel(along), 1)];

% One patch of two-vertex faces rather than a line object per rule: a drag
% replaces a single object instead of a few dozen, and a patch edge is the only
% documented way to hold the alpha that keeps the grid off the section. The tag
% is what REFRESHROIOVERLAY sweeps up mid-drag, so it has to be the shared one;
% UserData is what names this particular overlay.
nRules = size(starts, 1);

patch(ax, ...
    Faces = [(1:nRules)', (1:nRules)' + nRules], ...
    Vertices = [starts; starts + spans], ...
    FaceColor = "none", ...
    EdgeColor = style.Color, ...
    EdgeAlpha = 0.35, ...
    LineWidth = 0.5, ...
    Tag = "roiOverlay", ...
    UserData = "roiBandGrid");

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
