function R = read_imagej_roi(roiPath)
% read_imagej_roi
%   R = read_imagej_roi(roiPath)
%
% Decode an ImageJ/Fiji .roi file into a MATLAB struct. Line ROIs (the type
% written by MACRO_Batch_LineMeasure) are fully supported, including the
% stroke width used for profile averaging. Polygon/polyline types are decoded
% on a best-effort basis so callers can at least draw their outline.
%
% Coordinates are returned in image pixel units with a 1-based origin so they
% can be used directly against an image drawn with IMAGESC.
%
% Parameters
%   roiPath: Path to a .roi file.
%
% Returns
%   R: Struct with fields
%      - isValid: True when the file was recognized and decoded.
%      - message: Empty on success, otherwise the reason decoding failed.
%      - roiPath: Path that was read.
%      - type: Numeric ImageJ ROI type code.
%      - typeName: Human readable ROI type.
%      - isLine: True for a straight line ROI.
%      - x1,y1,x2,y2: Line endpoints (straight line ROIs only).
%      - strokeWidth: Line width in pixels used for profile averaging.
%      - bounds: [left top width height] bounding box.
%      - x,y: Vertex coordinates for polygon/polyline types.
%      - name: ROI name stored in the file, when present.

arguments
    roiPath (1,1) string
end

R = initialize_roi_struct(roiPath);

if ~isfile(roiPath)
    R.message = "ROI file does not exist: " + roiPath;
    return
end

fid = fopen(roiPath, "r");

if fid < 0
    R.message = "Could not open ROI file: " + roiPath;
    return
end

cleanupFid = onCleanup(@() fclose(fid));
bytes = fread(fid, inf, "*uint8");
clear cleanupFid

if numel(bytes) < 64
    R.message = "ROI file is too small to be valid: " + roiPath;
    return
end

if ~isequal(char(bytes(1:4))', 'Iout')
    R.message = "ROI file is missing the ImageJ 'Iout' magic header: " + roiPath;
    return
end

R.isValid = true;
R.version = be_int16(bytes, 4);
R.type = double(bytes(7));
R.typeName = roi_type_name(R.type);

top = be_int16(bytes, 8);
left = be_int16(bytes, 10);
bottom = be_int16(bytes, 12);
right = be_int16(bytes, 14);

nCoordinates = be_int16(bytes, 16);
R.strokeWidth = be_int16(bytes, 34);
R.options = be_int16(bytes, 50);

% ImageJ stores pixel coordinates with a 0-based origin; MATLAB images are
% 1-based, so shift here once rather than at every call site.
R.bounds = [left + 1, top + 1, right - left, bottom - top];

if R.type == 3
    R.isLine = true;
    R.x1 = be_single(bytes, 18) + 1;
    R.y1 = be_single(bytes, 22) + 1;
    R.x2 = be_single(bytes, 26) + 1;
    R.y2 = be_single(bytes, 30) + 1;
    R.x = [R.x1; R.x2];
    R.y = [R.y1; R.y2];
    R.length = hypot(R.x2 - R.x1, R.y2 - R.y1);
elseif ismember(R.type, [0 4 5 7 8]) && nCoordinates > 0
    [R.x, R.y] = read_vertices(bytes, nCoordinates, left, top, R.options);
    if ~isempty(R.x)
        R.length = sum(hypot(diff(R.x), diff(R.y)));
    end
end

R.name = read_roi_name(bytes);

end

function R = initialize_roi_struct(roiPath)
%INITIALIZE_ROI_STRUCT Build the default (failed) decode result.

R = struct( ...
    "isValid", false, ...
    "message", "", ...
    "roiPath", roiPath, ...
    "version", NaN, ...
    "type", NaN, ...
    "typeName", "unknown", ...
    "isLine", false, ...
    "x1", NaN, "y1", NaN, "x2", NaN, "y2", NaN, ...
    "x", zeros(0, 1), "y", zeros(0, 1), ...
    "length", NaN, ...
    "strokeWidth", 0, ...
    "options", 0, ...
    "bounds", [NaN NaN NaN NaN], ...
    "name", "");

end

function [x, y] = read_vertices(bytes, nCoordinates, left, top, options)
%READ_VERTICES Read polygon/polyline vertices, honoring sub-pixel resolution.

x = zeros(0, 1);
y = zeros(0, 1);

subPixel = bitand(double(options), 128) > 0;
intBytesNeeded = 64 + 4 * nCoordinates;

if subPixel && numel(bytes) >= intBytesNeeded + 8 * nCoordinates
    base = intBytesNeeded;
    x = arrayfun(@(k) be_single(bytes, base + 4 * (k - 1)), (1:nCoordinates)') + 1;
    y = arrayfun(@(k) be_single(bytes, base + 4 * (nCoordinates + k - 1)), (1:nCoordinates)') + 1;
    return
end

if numel(bytes) < intBytesNeeded
    return
end

x = arrayfun(@(k) be_int16(bytes, 64 + 2 * (k - 1)), (1:nCoordinates)') + left + 1;
y = arrayfun(@(k) be_int16(bytes, 64 + 2 * (nCoordinates + k - 1)), (1:nCoordinates)') + top + 1;

end

function name = read_roi_name(bytes)
%READ_ROI_NAME Read the optional ROI name stored via the secondary header.

name = "";

header2 = be_int32(bytes, 60);

if header2 <= 0 || header2 + 24 > numel(bytes)
    return
end

nameOffset = be_int32(bytes, header2 + 16);
nameLength = be_int32(bytes, header2 + 20);

if nameOffset <= 0 || nameLength <= 0
    return
end

if nameOffset + 2 * nameLength > numel(bytes)
    return
end

chars = arrayfun(@(k) be_int16(bytes, nameOffset + 2 * (k - 1)), 1:nameLength);
name = string(char(chars));

end

function v = be_int16(bytes, offset)
%BE_INT16 Read a big-endian signed 16-bit integer at a 0-based byte offset.

v = double(typecast(uint8(bytes(offset + [2 1])), "int16"));

end

function v = be_int32(bytes, offset)
%BE_INT32 Read a big-endian signed 32-bit integer at a 0-based byte offset.

v = double(typecast(uint8(bytes(offset + [4 3 2 1])), "int32"));

end

function v = be_single(bytes, offset)
%BE_SINGLE Read a big-endian 32-bit float at a 0-based byte offset.

v = double(typecast(uint8(bytes(offset + [4 3 2 1])), "single"));

end

function name = roi_type_name(typeCode)
%ROI_TYPE_NAME Map an ImageJ ROI type code to a readable name.

names = ["polygon", "rect", "oval", "line", "freeline", "polyline", ...
    "noRoi", "freehand", "traced", "angle", "point"];

if typeCode >= 0 && typeCode < numel(names)
    name = names(typeCode + 1);
else
    name = "unknown";
end

end
