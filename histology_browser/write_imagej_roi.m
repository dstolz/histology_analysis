function info = write_imagej_roi(roiPath, roi, options)
% write_imagej_roi
%   info = write_imagej_roi(roiPath, roi)
%   info = write_imagej_roi(roiPath, roi, template = existingRoiPath)
%   info = write_imagej_roi(roiPath, roi, name = "sectionA_roi")
%
% Encode a straight line ROI as an ImageJ/Fiji .roi file, the inverse of
% READ_IMAGEJ_ROI. Only line ROIs are written, because that is the type
% MACRO_Batch_LineMeasure produces and the only type this toolbox edits.
%
% Coordinates are supplied in 1-based MATLAB image pixel units and shifted to
% ImageJ's 0-based origin on the way out, so a file written here decodes back
% to the same numbers through READ_IMAGEJ_ROI and reopens in Fiji over the
% same pixels it was drawn on in MATLAB.
%
% When a template is given, every field this function does not manage (stroke
% and fill color, ROI name, slice position, and the display options) is copied
% across, so re-saving an existing ROI changes its geometry and nothing else.
%
% Parameters
%   roiPath: Destination .roi path.
%   roi: Struct with fields x1, y1, x2, y2 and, optionally, strokeWidth.
%   options.template: Existing .roi file to inherit unmanaged fields from.
%   options.name: ROI name to store. Defaults to the template's name, then to
%       the destination filename without its extension.
%
% Returns
%   info: Struct with fields roiPath, name, strokeWidth, and nBytes.
%
% See also READ_IMAGEJ_ROI, MEASURE_LINE_PROFILE.

arguments
    roiPath (1,1) string
    roi (1,1) struct
    options.template (1,1) string = ""
    options.name (1,1) string = ""
end

required = ["x1", "y1", "x2", "y2"];
absent = required(~isfield(roi, required));

if ~isempty(absent)
    error("write_imagej_roi:MissingField", ...
        "roi is missing the field(s): %s", join(absent, ", "));
end

strokeWidth = 0;

if isfield(roi, "strokeWidth") && isfinite(roi.strokeWidth)
    strokeWidth = max(0, round(double(roi.strokeWidth)));
end

template = read_template(options.template);
name = resolve_name(options.name, template, roiPath);

% ImageJ counts pixels from 0; READ_IMAGEJ_ROI added the offset on the way in.
x1 = double(roi.x1) - 1;
y1 = double(roi.y1) - 1;
x2 = double(roi.x2) - 1;
y2 = double(roi.y2) - 1;

bytes = zeros(128 + 2 * strlength(name), 1, "uint8");

bytes(1:4) = uint8('Iout');

% Version 228 is the first that carries the float stroke width in header 2,
% and is what current Fiji writes.
bytes = put_int16(bytes, 4, 228);
bytes(7) = 3;                                   % Roi.LINE
bytes(8) = 0;

bounds = line_bounds(x1, y1, x2, y2);
bytes = put_int16(bytes, 8, bounds(2));         % top
bytes = put_int16(bytes, 10, bounds(1));        % left
bytes = put_int16(bytes, 12, bounds(4));        % bottom
bytes = put_int16(bytes, 14, bounds(3));        % right
bytes = put_int16(bytes, 16, 0);                % nCoordinates

bytes = put_single(bytes, 18, x1);
bytes = put_single(bytes, 22, y1);
bytes = put_single(bytes, 26, x2);
bytes = put_single(bytes, 30, y2);

bytes = put_int16(bytes, 34, min(strokeWidth, 32767));

if isempty(template)
    % SCALE_STROKE_WIDTH, so a wide line still reads as wide when Fiji is
    % zoomed out. This is what Fiji stores for the macro-drawn ROIs.
    bytes = put_int16(bytes, 50, 8192);
else
    % Stroke color, fill color, subtype, options, arrow, and position fields.
    bytes(41:60) = template.bytes(41:60);
end

bytes = put_int32(bytes, 60, 64);               % header 2 offset

if numel(template) == 1 && numel(template.bytes) >= template.header2 + 16
    % Channel, slice, and frame position of the ROI.
    bytes(69:80) = template.bytes(template.header2 + (5:16));
end

bytes = put_int32(bytes, 80, 128);              % name offset
bytes = put_int32(bytes, 84, strlength(name));  % name length, in characters
bytes = put_single(bytes, 100, strokeWidth);    % float stroke width

bytes(129:end) = utf16be(name);

write_bytes(roiPath, bytes);

info = struct( ...
    "roiPath", roiPath, ...
    "name", name, ...
    "strokeWidth", strokeWidth, ...
    "nBytes", numel(bytes));

end

function template = read_template(templatePath)
%READ_TEMPLATE Load an existing .roi file to inherit its unmanaged fields.

template = [];

if templatePath == "" || ~isfile(templatePath)
    return
end

fid = fopen(templatePath, "r");

if fid < 0
    return
end

cleanupFid = onCleanup(@() fclose(fid));
bytes = fread(fid, inf, "*uint8");
clear cleanupFid

if numel(bytes) < 128 || ~isequal(char(bytes(1:4))', 'Iout')
    return
end

header2 = get_int32(bytes, 60);

if header2 <= 0 || header2 + 24 > numel(bytes)
    return
end

template = struct("bytes", bytes, "header2", header2);

end

function name = resolve_name(requested, template, roiPath)
%RESOLVE_NAME Pick the ROI name, preferring the caller, then the template.

if requested ~= ""
    name = requested;
    return
end

if numel(template) == 1
    name = template_name(template);

    if name ~= ""
        return
    end
end

[~, base] = fileparts(roiPath);
name = string(base);

end

function name = template_name(template)
%TEMPLATE_NAME Read the name stored in a template file's second header.

name = "";

nameOffset = get_int32(template.bytes, template.header2 + 16);
nameLength = get_int32(template.bytes, template.header2 + 20);

if nameOffset <= 0 || nameLength <= 0
    return
end

if nameOffset + 2 * nameLength > numel(template.bytes)
    return
end

chars = arrayfun(@(k) get_int16(template.bytes, nameOffset + 2 * (k - 1)), 1:nameLength);
name = string(char(chars));

end

function bounds = line_bounds(x1, y1, x2, y2)
%LINE_BOUNDS Build the [left top right bottom] box Fiji stores for a line.

left = floor(min(x1, x2));
top = floor(min(y1, y2));

% Fiji's box is one pixel wider and taller than the endpoint span, so the
% pixels under both endpoints fall inside it.
right = left + round(abs(x2 - x1)) + 1;
bottom = top + round(abs(y2 - y1)) + 1;

bounds = min(max(round([left top right bottom]), -32768), 32767);

end

function bytes = put_int16(bytes, offset, value)
%PUT_INT16 Write a big-endian signed 16-bit integer at a 0-based byte offset.

raw = typecast(int16(value), "uint8");
bytes(offset + [1 2]) = raw([2 1]);

end

function bytes = put_int32(bytes, offset, value)
%PUT_INT32 Write a big-endian signed 32-bit integer at a 0-based byte offset.

raw = typecast(int32(value), "uint8");
bytes(offset + (1:4)) = raw([4 3 2 1]);

end

function bytes = put_single(bytes, offset, value)
%PUT_SINGLE Write a big-endian 32-bit float at a 0-based byte offset.

raw = typecast(single(value), "uint8");
bytes(offset + (1:4)) = raw([4 3 2 1]);

end

function value = get_int16(bytes, offset)
%GET_INT16 Read a big-endian signed 16-bit integer at a 0-based byte offset.

value = double(typecast(uint8(bytes(offset + [2 1])), "int16"));

end

function value = get_int32(bytes, offset)
%GET_INT32 Read a big-endian signed 32-bit integer at a 0-based byte offset.

value = double(typecast(uint8(bytes(offset + [4 3 2 1])), "int32"));

end

function bytes = utf16be(text)
%UTF16BE Encode a string as big-endian UTF-16 code units.

chars = double(char(text));
bytes = zeros(2 * numel(chars), 1, "uint8");

bytes(1:2:end) = uint8(bitshift(chars, -8));
bytes(2:2:end) = uint8(bitand(chars, 255));

end

function write_bytes(roiPath, bytes)
%WRITE_BYTES Write the encoded ROI, creating the folder when needed.

folder = fileparts(roiPath);

if folder ~= "" && ~isfolder(folder)
    mkdir(folder);
end

fid = fopen(roiPath, "w");

if fid < 0
    error("write_imagej_roi:CannotOpen", "Could not open %s for writing.", roiPath);
end

cleanupFid = onCleanup(@() fclose(fid));
fwrite(fid, bytes, "uint8");

end
