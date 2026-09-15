function geometry = initialRoiGeometry(obj, row, key)
%INITIALROIGEOMETRY Build the geometry an edit session starts from.
% An existing ROI is loaded as it stands. An ROI that does not exist yet gets a
% line across the image, wide enough to see, which is faster to drag into place
% than starting from a click.
%
% Parameters
%   row: One catalog row.
%   key: Which of the section's ROIs to open. Defaults to the active one.
%
% The brain surface mark comes along with the line, because it is a point on
% that line and reverting to the file has to put both back. A line that never
% had one starts unmarked, and AUTODETECTSURFACE is what offers a first guess
% once the profile under it has been measured.
%
% Returns
%   geometry: Struct with fields x1, y1, x2, y2, strokeWidth, name, key,
%      surface, surfaceSource, and isNew, or an empty array when there is no
%      image to place a line over.

arguments
    obj
    row table
    key (1,1) string = obj.activeRoiKey(row)
end

geometry = [];

width = default_width(obj);

R = obj.roiForRow(row, key);

if R.isValid && R.isLine
    if R.strokeWidth >= 1
        width = round(R.strokeWidth);
    end

    geometry = struct( ...
        "x1", R.x1, "y1", R.y1, "x2", R.x2, "y2", R.y2, ...
        "strokeWidth", width, ...
        "name", R.name, ...
        "key", key, ...
        "surface", R.surface, ...
        "surfaceSource", R.surfaceSource, ...
        "isNew", false);

    return
end

imagePath = obj.resolveImagePath(row);

if imagePath == "" || ~isfile(imagePath)
    return
end

[img, imageSize] = obj.loadDisplayImage(imagePath, 1);

if isempty(img) || any(imageSize < 2)
    return
end

nRows = imageSize(1);
nCols = imageSize(2);

y = round(placement(obj, row, key) * nRows);

geometry = struct( ...
    "x1", round(0.2 * nCols), "y1", y, ...
    "x2", round(0.8 * nCols), "y2", y, ...
    "strokeWidth", min(width, max(1, round(0.5 * nRows))), ...
    "name", "", ...
    "key", key, ...
    "surface", NaN, ...
    "surfaceSource", "", ...
    "isNew", true);

end

function fraction = placement(obj, row, key)
%PLACEMENT Height to drop a brand new line at, down the image.
% The section's first ROI goes across the middle. Each one after it is offset,
% because a second line placed exactly over the first would read as the new
% line having failed to appear rather than as one waiting to be dragged.

keys = obj.roiKeysForRow(row);
slot = find(keys == string(key), 1);

if isempty(slot)
    % An ROI being added is not on the section's list yet, and it will sit
    % after everything that is.
    slot = numel(keys) + 1;
end

fraction = min(max(0.5 + 0.15 * (slot - 1), 0.15), 0.85);

end

function width = default_width(obj)
%DEFAULT_WIDTH Read the width field, falling back to the standing default.
% The field is the width every new line is drawn at, and it survives between
% sessions, so a section drawn today samples the band the last one did.

width = HistologyImageBrowser.DefaultRoiWidth;

if isempty(obj.RoiWidthField) || ~isvalid(obj.RoiWidthField)
    return
end

value = obj.RoiWidthField.Value;

if isnumeric(value) && isscalar(value) && isfinite(value) && value >= 1
    width = round(value);
end

end
