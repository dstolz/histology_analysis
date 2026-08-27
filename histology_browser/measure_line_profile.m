function P = measure_line_profile(source, roi, options)
% measure_line_profile
%   P = measure_line_profile(imagePath, roi)
%   P = measure_line_profile(imagePath, roi, page = 1)
%   P = measure_line_profile(img, roi, pixelSize = 1.6573)
%
% Measure the intensity profile along a wide straight line ROI the way
% ImageJ's ROI Manager multi-plot does: the mean intensity across the full
% line width at one sample per pixel along the line, read with bilinear
% interpolation. This is what regenerates a *values.csv file after a line ROI
% has been moved in MATLAB, without a round trip through Fiji.
%
% Checked against profiles MACRO_Batch_LineMeasure wrote for the GM6001
% sections: the two agree to about 0.03% of the profile's range. They are not
% bit-identical, because ImageJ walks its resampled line in unit steps while
% this samples the endpoints exactly, so the two sample grids drift by a small
% fraction of a pixel along the line.
%
% Parameters
%   source: Image path, or pixel data already in memory.
%   roi: Struct with fields x1, y1, x2, y2 (1-based image pixels) and
%       strokeWidth, as returned by READ_IMAGEJ_ROI.
%   options.page: Page to read from a multi-page file. Channel 1 by default,
%       matching the channel the line-measure macro profiles.
%   options.pixelSize: Distance per pixel for the distance axis. Read from the
%       file when it is omitted and a path was given.
%
% Returns
%   P: Struct with fields
%      - hasData: True when a profile was measured.
%      - distance: Distance of each sample from the start of the line.
%      - intensity: Mean intensity across the line width at each sample.
%      - pixelSize, pixelSizeUnit, pixelSizeSource: Calibration actually used.
%      - nSamples, strokeWidth, length: Geometry the profile was taken with.
%      - message: Empty on success, otherwise why nothing was measured.
%
% See also READ_IMAGEJ_ROI, WRITE_IMAGEJ_ROI, IMAGEJ_PIXEL_SIZE,
% WRITE_VALUES_CSV.

arguments
    source
    roi (1,1) struct
    options.page (1,1) double = 1
    options.pixelSize (1,1) double = NaN
end

P = struct( ...
    "hasData", false, ...
    "distance", zeros(0, 1), ...
    "intensity", zeros(0, 1), ...
    "pixelSize", NaN, ...
    "pixelSizeUnit", "", ...
    "pixelSizeSource", "", ...
    "nSamples", 0, ...
    "strokeWidth", NaN, ...
    "length", NaN, ...
    "message", "");

[img, C, message] = resolve_source(source, options);

if isempty(img)
    P.message = message;
    return
end

P.pixelSize = C.pixelSize;
P.pixelSizeUnit = C.unit;
P.pixelSizeSource = C.source;

required = ["x1", "y1", "x2", "y2"];

if ~all(isfield(roi, required))
    P.message = "ROI is missing one of x1, y1, x2, y2.";
    return
end

delta = [double(roi.x2) - double(roi.x1), double(roi.y2) - double(roi.y1)];
lineLength = hypot(delta(1), delta(2));

if ~isfinite(lineLength) || lineLength <= 0
    P.message = "ROI line has no length.";
    return
end

strokeWidth = 1;

if isfield(roi, "strokeWidth") && isfinite(roi.strokeWidth)
    strokeWidth = max(1, round(double(roi.strokeWidth)));
end

P.strokeWidth = strokeWidth;
P.length = lineLength;

% One sample per pixel of line length, including both endpoints, which is the
% sample count ImageJ's straightened line produces.
nSamples = max(2, round(lineLength) + 1);

unit = delta / lineLength;
normal = [-unit(2), unit(1)];

t = linspace(0, lineLength, nSamples)';
centerX = double(roi.x1) + t * unit(1);
centerY = double(roi.y1) + t * unit(2);

% Offsets are centered on the line, so the band is symmetric about it.
offsets = (0:strokeWidth - 1) - (strokeWidth - 1) / 2;

P.intensity = band_mean(img, centerX, centerY, normal, offsets);
P.distance = (0:nSamples - 1)' * C.pixelSize;
P.nSamples = nSamples;
P.hasData = true;

end

function [img, C, message] = resolve_source(source, options)
%RESOLVE_SOURCE Load the pixel data and settle the distance calibration.

img = [];
message = "";

C = struct("pixelSize", 1, "unit", "pixel", "source", "assumed (uncalibrated)");

if isnumeric(source) || islogical(source)
    img = flatten_channels(double(source));
else
    imagePath = string(source);

    if ~isfile(imagePath)
        message = "Image file does not exist: " + imagePath;
        return
    end

    try
        img = flatten_channels(double(read_page(imagePath, options.page)));
    catch ME
        message = "Could not read image: " + string(ME.message);
        img = [];
        return
    end

    calibration = imagej_pixel_size(imagePath);

    if calibration.isCalibrated
        C.pixelSize = calibration.pixelSize;
        C.unit = calibration.unit;
        C.source = calibration.source;
    end
end

if isfinite(options.pixelSize) && options.pixelSize > 0
    C.pixelSize = options.pixelSize;
    C.unit = "um";
    C.source = "caller supplied";
end

if isempty(img)
    message = "Image contained no pixels.";
end

end

function raw = read_page(imagePath, page)
%READ_PAGE Read one page of a possibly multi-page image.

[~, ~, ext] = fileparts(imagePath);

if ~ismember(lower(string(ext)), [".tif", ".tiff"])
    raw = imread(imagePath);
    return
end

info = imfinfo(imagePath);
page = min(max(round(page), 1), numel(info));
raw = imread(imagePath, page);

end

function img = flatten_channels(img)
%FLATTEN_CHANNELS Reduce an RGB rendition to one plane to measure against.
% Single-channel data, which is what the projections used for measurement
% hold, passes through untouched.

if ndims(img) == 3
    img = mean(img, 3);
end

end

function values = band_mean(img, centerX, centerY, normal, offsets)
%BAND_MEAN Average bilinear samples across the width of the line.
% Sample positions are clamped to the image, matching how ImageJ holds edge
% pixels rather than dropping samples that fall outside.

[nRows, nCols] = size(img);
nSamples = numel(centerX);

total = zeros(nSamples, 1);

% Offsets are taken in blocks so a long, wide band never needs one large
% coordinate matrix.
blockSize = max(1, floor(4e6 / nSamples));

for iStart = 1:blockSize:numel(offsets)
    block = offsets(iStart:min(iStart + blockSize - 1, numel(offsets)));

    sampleX = min(max(centerX + block * normal(1), 1), nCols);
    sampleY = min(max(centerY + block * normal(2), 1), nRows);

    total = total + sum(interp2(img, sampleX, sampleY, "linear"), 2);
end

values = total / numel(offsets);

end
