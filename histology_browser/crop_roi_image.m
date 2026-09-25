function C = crop_roi_image(imagePath, roi, options)
% crop_roi_image
%   C = crop_roi_image(imagePath, roiPath)
%   C = crop_roi_image(imagePath, roi, rotate = true)
%   C = crop_roi_image(imagePath, roi, suffix = "_ACx", outputFolder = "D:/crops")
%
% Crop an image to the band of a line ROI drawn in HistologyImageBrowser and
% save the crop as a new file beside the original, named <name>_roiCropped
% with the original's extension.
%
% The band is the line and its stroke width: every pixel the profile
% measurement (MEASURE_LINE_PROFILE) reads from. Every page of a multi-page
% TIFF is cropped, in its own data class, and the TIFF resolution tags and
% ImageJ description are copied across, so the crop keeps the original's
% calibration.
%
% Without rotation the crop is the axis-aligned bounding box of the band, cut
% straight out of the image: the pixel values are the original ones, unchanged.
%
% With rotate = true the band is resampled so the line runs straight down the
% crop, the surface end at the top, one row per profile sample and one column
% per pixel of line width -- the samples MEASURE_LINE_PROFILE averages, so the
% mean of each row of a bilinear crop is the measured profile. The rotation is
% a rotation, never a mirror. Resampling at an angle interpolates, so the
% values are no longer the original pixels: bilinear by default, rounded back
% to the image's integer class, or interpolation = "nearest" to keep every
% value one that was in the image.
%
% Which end of the line is the surface end is not inferred from the image.
% Lines are drawn starting outside the tissue, so the start is taken as the
% surface end; surfaceAt = "end" says a line was drawn the other way.
%
% Parameters
%   imagePath: The image the ROI was drawn against. ROI coordinates are pixels
%       of the image profiles are measured from -- the projection, ProjPath in
%       the browser's catalog -- so a rendition of another size would be cut
%       in the wrong place. TIFF and PNG are supported.
%   roi: Path to a line .roi file, whose *_surface.json sidecar is read when
%       there is one, or a struct with x1, y1, x2, y2 (1-based pixels) and
%       strokeWidth, and optionally surface (pixels along the line from its
%       start), as returned by READ_IMAGEJ_ROI or HistologyImageBrowser.roiForRow.
%   options.rotate: Resample so the line runs top to bottom from its surface
%       end. false by default.
%   options.surfaceAt: "start" or "end", the end of the line that is the brain
%       surface side. "start" by default.
%   options.padding: Pixels of image kept around the band on every side. 0 by
%       default.
%   options.interpolation: "linear" or "nearest", for rotate = true.
%   options.fillValue: Written where a rotated crop reaches past the image
%       edge. The count of such pixels is returned in C.nOutside.
%   options.suffix: Appended to the original's name. "_roiCropped" by default.
%   options.outputFolder: Where the crop is written. "" means the original's
%       folder.
%   options.overwrite: Replace an existing file of the same name. false by
%       default, in which case an existing file is an error.
%
% Returns
%   C: Struct with fields
%      - outputPath: The file written.
%      - rotated: Whether the crop was resampled.
%      - bounds: [left top width height] of the region read from the image,
%        in its pixels. Without rotation this is the crop itself.
%      - lineAngle: Direction of the line from its surface end, in degrees in
%        image coordinates (0 points right, 90 points down).
%      - surfacePoint: [x y] of the brain surface mark in the crop's pixels,
%        [NaN NaN] when the ROI has none.
%      - rowStep: Distance along the line between rows of a rotated crop, in
%        image pixels (1 to within 1/length), NaN without rotation.
%      - nOutside: Pixels of a rotated crop that lay outside the image and
%        hold fillValue.
%      - nPages, size, class: What was written.
%
% See also READ_IMAGEJ_ROI, MEASURE_LINE_PROFILE, READ_SURFACE_MARK,
% IMAGEJ_PIXEL_SIZE.

arguments
    imagePath (1,1) string
    roi
    options.rotate (1,1) logical = false
    options.surfaceAt (1,1) string {mustBeMember(options.surfaceAt, ["start", "end"])} = "start"
    options.padding (1,1) double {mustBeNonnegative, mustBeInteger} = 0
    options.interpolation (1,1) string {mustBeMember(options.interpolation, ["linear", "nearest"])} = "linear"
    options.fillValue (1,1) double = 0
    options.suffix (1,1) string = "_roiCropped"
    options.outputFolder (1,1) string = ""
    options.overwrite (1,1) logical = false
end

if ~isfile(imagePath)
    error("crop_roi_image:noImage", "Image file does not exist: %s", imagePath)
end

[folder, name, ext] = fileparts(imagePath);
format = image_format(ext);

L = resolve_line(roi, options.surfaceAt);

outFolder = options.outputFolder;

if outFolder == ""
    outFolder = string(folder);
end

outputPath = fullfile(outFolder, name + options.suffix + ext);

if outputPath == imagePath
    error("crop_roi_image:wouldOverwriteSource", ...
        "The crop would replace the original image. Give a suffix or an output folder.")
end

if isfile(outputPath) && ~options.overwrite
    error("crop_roi_image:exists", ...
        "%s already exists. Pass overwrite = true to replace it.", outputPath)
end

if ~isfolder(outFolder)
    mkdir(outFolder);
end

info = imfinfo(imagePath);
imageSize = [info(1).Height, info(1).Width];

G = band_geometry(L, options.padding);
[rows, cols] = region(G, imageSize);

if strcmp(format, "tiff")
    nPages = numel(info);
else
    nPages = 1;
end

pages = cell(nPages, 1);
nOutside = 0;

for iPage = 1:nPages
    raw = read_region(imagePath, format, iPage, rows, cols);

    if options.rotate
        [pages{iPage}, nOutside] = resample_band(raw, G, rows, cols, imageSize, options);
    else
        pages{iPage} = raw;
    end
end

if strcmp(format, "tiff")
    write_tiff(outputPath, pages, info);
else
    imwrite(pages{1}, outputPath);
end

C = struct( ...
    "outputPath", outputPath, ...
    "rotated", options.rotate, ...
    "bounds", [cols(1), rows(1), numel(cols), numel(rows)], ...
    "lineAngle", atan2d(L.u(2), L.u(1)), ...
    "surfacePoint", surface_point(L, G, rows, cols, options.rotate), ...
    "rowStep", NaN, ...
    "nOutside", nOutside, ...
    "nPages", nPages, ...
    "size", size(pages{1}), ...
    "class", string(class(pages{1})));

if options.rotate
    C.rowStep = G.step;
end

end

function format = image_format(ext)
%IMAGE_FORMAT Name the formats a crop can be written back to without loss.
% JPEG would recompress the crop and a .czi cannot be written at all, so both
% are refused rather than saved as something that is not the original data.

switch lower(string(ext))
    case {".tif", ".tiff"}
        format = "tiff";
    case ".png"
        format = "png";
    otherwise
        error("crop_roi_image:unsupportedFormat", ...
            "Cannot crop a %s file. Crop the TIFF projection the ROI was measured on.", ext)
end

end

function L = resolve_line(roi, surfaceAt)
%RESOLVE_LINE Read the line, its width, and its surface mark.
% Returned running from the surface end, with the mark measured from that end,
% so nothing downstream has to know which way the line was drawn.

surface = NaN;

if isstring(roi) || ischar(roi)
    roiPath = string(roi);
    R = read_imagej_roi(roiPath);

    if ~R.isValid
        error("crop_roi_image:badRoi", "%s", R.message)
    end

    M = read_surface_mark(surface_mark_path(roiPath));

    if M.isValid
        surface = M.offset;
    end
elseif isstruct(roi) && isscalar(roi)
    R = roi;

    if isfield(R, "surface") && isscalar(R.surface) && isfinite(R.surface)
        surface = double(R.surface);
    end
else
    error("crop_roi_image:badRoi", "roi must be a .roi path or a struct with x1, y1, x2, y2.")
end

if isfield(R, "isLine") && ~R.isLine
    error("crop_roi_image:notLine", "Only straight line ROIs can be cropped to.")
end

required = ["x1", "y1", "x2", "y2"];

if ~all(isfield(R, required))
    error("crop_roi_image:badRoi", "The ROI is missing one of x1, y1, x2, y2.")
end

p1 = double([R.x1, R.y1]);
p2 = double([R.x2, R.y2]);
lineLength = hypot(p2(1) - p1(1), p2(2) - p1(2));

if ~all(isfinite([p1, p2])) || ~isfinite(lineLength) || lineLength <= 0
    error("crop_roi_image:badRoi", "The ROI line has no length.")
end

% The width MEASURE_LINE_PROFILE averages over, so the crop holds exactly the
% pixels the profile was read from.
strokeWidth = 1;

if isfield(R, "strokeWidth") && isscalar(R.strokeWidth) && isfinite(R.strokeWidth)
    strokeWidth = max(1, round(double(R.strokeWidth)));
end

if surfaceAt == "end"
    [p1, p2] = deal(p2, p1);
    surface = lineLength - surface;
end

L = struct( ...
    "p1", p1, ...
    "u", (p2 - p1) / lineLength, ...
    "length", lineLength, ...
    "strokeWidth", strokeWidth, ...
    "surface", surface);

end

function G = band_geometry(L, padding)
%BAND_GEOMETRY Lay out the samples of the band, padding included.
% Rows run along the line and columns across it. Along the line the samples
% are MEASURE_LINE_PROFILE's -- one per pixel of length, both endpoints
% included -- continued past each end at the same step into the padding.
% Across it they are the stroke width's pixel offsets, centered on the line.
%
% The across direction is the along direction turned a quarter turn, chosen
% so that a line already pointing straight down maps onto the image as it is:
% the crop is the image rotated, and never its mirror image.

nSamples = max(2, round(L.length) + 1);
step = L.length / (nSamples - 1);

t = [(-padding:-1) * step, linspace(0, L.length, nSamples), L.length + (1:padding) * step]';

w = L.strokeWidth;
o = (0:w - 1 + 2 * padding) - (w - 1) / 2 - padding;

across = [L.u(2), -L.u(1)];

G = struct( ...
    "t", t, ...
    "o", o, ...
    "step", step, ...
    "padding", padding, ...
    "X", L.p1(1) + t * L.u(1) + o * across(1), ...
    "Y", L.p1(2) + t * L.u(2) + o * across(2));

end

function [rows, cols] = region(G, imageSize)
%REGION The pixels of the image the band's samples read from.
% Floor and ceiling of the extreme samples, so every pixel a bilinear sample
% touches is inside, clipped to the image.

rows = max(1, floor(min(G.Y(:)))) : min(imageSize(1), ceil(max(G.Y(:))));
cols = max(1, floor(min(G.X(:)))) : min(imageSize(2), ceil(max(G.X(:))));

if isempty(rows) || isempty(cols)
    error("crop_roi_image:outsideImage", ...
        "The ROI lies outside the %d x %d image. Is this the image it was drawn on?", ...
        imageSize(2), imageSize(1))
end

end

function raw = read_region(imagePath, format, page, rows, cols)
%READ_REGION Read only the pixels the crop needs from one page.

if strcmp(format, "tiff")
    raw = imread(imagePath, page, "PixelRegion", {[rows(1), rows(end)], [cols(1), cols(end)]});
    return
end

raw = imread(imagePath);
raw = raw(rows, cols, :);

end

function [out, nOutside] = resample_band(raw, G, rows, cols, imageSize, options)
%RESAMPLE_BAND Sample the band so the line runs down the crop.
% Integer data is rounded back to its own class, which is what keeps the file
% the same kind of image as the original. A sample off the edge of the image
% is not extrapolated: it gets fillValue and is counted.

outside = G.X < 1 | G.X > imageSize(2) | G.Y < 1 | G.Y > imageSize(1);
nOutside = nnz(outside);

X = G.X - (cols(1) - 1);
Y = G.Y - (rows(1) - 1);

nPlanes = size(raw, 3);
out = zeros([size(X), nPlanes], class(raw));

for iPlane = 1:nPlanes
    plane = double(raw(:, :, iPlane));

    % INTERP2 needs two points in each direction. A region one pixel across
    % only arises when every sample in that direction sits exactly on it, so
    % repeating the pixel changes no sample inside the image.
    if size(plane, 1) == 1
        plane = [plane; plane]; %#ok<AGROW>
    end

    if size(plane, 2) == 1
        plane = [plane, plane]; %#ok<AGROW>
    end

    values = interp2(plane, X, Y, options.interpolation, NaN);
    values(outside) = options.fillValue;

    out(:, :, iPlane) = cast(values, class(raw));
end

end

function point = surface_point(L, G, rows, cols, rotated)
%SURFACE_POINT Where the brain surface mark lands in the crop's pixels.

point = [NaN NaN];

if ~isfinite(L.surface)
    return
end

if rotated
    % Rows are samples along the line from the first padded one, and the line
    % itself runs down the middle column.
    point = [G.padding + (L.strokeWidth + 1) / 2, G.padding + 1 + L.surface / G.step];
    return
end

point = L.p1 + L.surface * L.u - [cols(1) - 1, rows(1) - 1];

end

function write_tiff(outputPath, pages, info)
%WRITE_TIFF Write the cropped pages with the original's calibration.
% The Tiff class rather than IMWRITE, because IMWRITE always records the
% resolution in inches: a file calibrated in centimeters, or carrying no unit,
% would come back with a different pixel size.

t = Tiff(outputPath, "w");
closer = onCleanup(@() close(t));

for iPage = 1:numel(pages)
    img = pages{iPage};
    source = info(min(iPage, numel(info)));

    tags = struct();
    tags.ImageLength = size(img, 1);
    tags.ImageWidth = size(img, 2);
    tags.SamplesPerPixel = size(img, 3);
    tags.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
    tags.Compression = Tiff.Compression.None;
    [tags.BitsPerSample, tags.SampleFormat] = sample_format(img);

    if size(img, 3) == 3
        tags.Photometric = Tiff.Photometric.RGB;
    else
        tags.Photometric = Tiff.Photometric.MinIsBlack;
    end

    if has_value(source, "XResolution")
        tags.XResolution = double(source.XResolution);
        tags.YResolution = double(source.XResolution);

        if has_value(source, "YResolution")
            tags.YResolution = double(source.YResolution);
        end

        tags.ResolutionUnit = resolution_unit(source);
    end

    if has_value(source, "ImageDescription")
        tags.ImageDescription = char(source.ImageDescription);
    end

    t.setTag(tags);
    t.write(img);

    if iPage < numel(pages)
        t.writeDirectory();
    end
end

end

function [bits, format] = sample_format(img)
%SAMPLE_FORMAT The TIFF sample layout of a MATLAB data class.

switch class(img)
    case "uint8"
        bits = 8;
        format = Tiff.SampleFormat.UInt;
    case "uint16"
        bits = 16;
        format = Tiff.SampleFormat.UInt;
    case "uint32"
        bits = 32;
        format = Tiff.SampleFormat.UInt;
    case "int8"
        bits = 8;
        format = Tiff.SampleFormat.Int;
    case "int16"
        bits = 16;
        format = Tiff.SampleFormat.Int;
    case "int32"
        bits = 32;
        format = Tiff.SampleFormat.Int;
    case "single"
        bits = 32;
        format = Tiff.SampleFormat.IEEEFP;
    case "double"
        bits = 64;
        format = Tiff.SampleFormat.IEEEFP;
    otherwise
        error("crop_roi_image:unsupportedClass", "Cannot write %s pixel data to TIFF.", class(img))
end

end

function unit = resolution_unit(source)
%RESOLUTION_UNIT The original's resolution unit, as a Tiff class constant.

unit = Tiff.ResolutionUnit.None;

if ~has_value(source, "ResolutionUnit")
    return
end

switch lower(string(source.ResolutionUnit))
    case "inch"
        unit = Tiff.ResolutionUnit.Inch;
    case "centimeter"
        unit = Tiff.ResolutionUnit.Centimeter;
end

end

function tf = has_value(S, name)
%HAS_VALUE True when an IMFINFO field is there and not empty.

tf = isfield(S, name) && ~isempty(S.(name));

end
