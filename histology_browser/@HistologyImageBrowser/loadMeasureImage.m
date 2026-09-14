function M = loadMeasureImage(obj, row)
%LOADMEASUREIMAGE Load the full resolution page a profile is measured from.
% Measurements come from the first channel of the image MEASUREIMAGEPATH
% picks, the same pixels MACRO_Batch_LineMeasure profiled. The page is kept in
% memory because remeasuring on every drag would otherwise reread tens of
% megabytes.
%
% Returns
%   M: Struct with fields hasImage, img, imagePath, pixelSize,
%      pixelSizeSource, and message.

M = struct( ...
    "hasImage", false, ...
    "img", [], ...
    "imagePath", "", ...
    "pixelSize", NaN, ...
    "pixelSizeSource", "", ...
    "message", "");

imagePath = obj.measureImagePath(row);

if imagePath == ""
    M.message = "no image file to measure from";
    return
end

M.imagePath = imagePath;

if obj.MeasureKey == imagePath && ~isempty(obj.MeasureImage)
    M.img = obj.MeasureImage;
    M.pixelSize = obj.MeasurePixelSize;
    M.pixelSizeSource = obj.MeasurePixelSizeSource;
    M.hasImage = true;

    return
end

[~, name, ext] = fileparts(imagePath);
obj.setBusy("Reading %s at full resolution ...", name + ext);

try
    img = read_first_page(imagePath);
catch ME
    M.message = string(ME.message);
    return
end

if isempty(img)
    M.message = "image contained no pixels";
    return
end

[pixelSize, pixelSizeSource] = resolve_pixel_size(imagePath, row);

obj.MeasureImage = img;
obj.MeasureKey = imagePath;
obj.MeasurePixelSize = pixelSize;
obj.MeasurePixelSizeSource = pixelSizeSource;

M.img = img;
M.pixelSize = pixelSize;
M.pixelSizeSource = pixelSizeSource;
M.hasImage = true;

end

function img = read_first_page(imagePath)
%READ_FIRST_PAGE Read channel 1, the channel the line-measure macro profiles.

[~, ~, ext] = fileparts(imagePath);

if ismember(lower(string(ext)), [".tif", ".tiff"])
    img = imread(imagePath, 1);
    return
end

img = imread(imagePath);

end

function [pixelSize, source] = resolve_pixel_size(imagePath, row)
%RESOLVE_PIXEL_SIZE Settle the distance calibration of the rewritten profile.
% The image's own calibration comes first. An uncalibrated image falls back to
% the spacing of the profile already beside it, so a rewritten file keeps the
% distance axis its earlier version was published with.

C = imagej_pixel_size(imagePath);

if C.isCalibrated
    pixelSize = C.pixelSize;
    source = C.unit + "/px from the " + C.source;

    return
end

pixelSize = spacing_from_values(row);

if isfinite(pixelSize)
    source = "spacing of the existing profile";
    return
end

pixelSize = NaN;
source = "uncalibrated, distance in pixels";

end

function pixelSize = spacing_from_values(row)
%SPACING_FROM_VALUES Recover the pixel size from an existing values file.

pixelSize = NaN;

valuesPaths = row.ValuesPaths{1};

if isempty(valuesPaths) || ~isfile(valuesPaths(1))
    return
end

try
    T = readtable(valuesPaths(1));
catch
    return
end

if ~ismember("distance_pixel_index", string(T.Properties.VariableNames)) || height(T) < 2
    return
end

steps = diff(double(T.distance_pixel_index));
steps = steps(isfinite(steps) & steps > 0);

if isempty(steps)
    return
end

pixelSize = median(steps);

end
