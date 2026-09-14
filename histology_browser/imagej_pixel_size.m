function C = imagej_pixel_size(imagePath)
% imagej_pixel_size
%   C = imagej_pixel_size(imagePath)
%
% Read the spatial calibration of a TIFF written by ImageJ/Fiji. The pixel
% size is what turns a profile's sample index into the distance axis stored in
% a *values.csv file, so it has to come from the image rather than be assumed.
%
% ImageJ records the unit in its ImageDescription tag and the scale in the
% resolution tags, which is the combination read here. A file carrying only
% standard TIFF resolution tags is still honored, converting inches or
% centimeters to microns.
%
% Parameters
%   imagePath: Path to an image file.
%
% Returns
%   C: Struct with fields
%      - isCalibrated: True when a real pixel size was found.
%      - pixelSize: Pixel width in C.unit, or 1 when uncalibrated.
%      - unit: Unit name, "pixel" when uncalibrated.
%      - source: Where the value came from, for reporting.
%      - message: Empty on success, otherwise why calibration was unavailable.
%
% See also MEASURE_LINE_PROFILE, READ_IMAGEJ_ROI.

arguments
    imagePath (1,1) string
end

C = struct( ...
    "isCalibrated", false, ...
    "pixelSize", 1, ...
    "unit", "pixel", ...
    "source", "", ...
    "message", "");

if ~isfile(imagePath)
    C.message = "Image file does not exist: " + imagePath;
    return
end

try
    info = imfinfo(imagePath);
catch ME
    C.message = "Could not read image metadata: " + string(ME.message);
    return
end

info = info(1);

if ~isfield(info, "XResolution") || isempty(info.XResolution) || ~isfinite(info.XResolution) ...
        || info.XResolution <= 0
    C.message = "Image carries no resolution tag.";
    return
end

% TIFF resolution is pixels per unit, so the pixel size is its reciprocal.
pixelSize = 1 / double(info.XResolution);

[unit, unitSource] = resolve_unit(info);

switch unit
    case "cm"
        pixelSize = pixelSize * 1e4;
        unit = "um";
    case "inch"
        pixelSize = pixelSize * 25400;
        unit = "um";
end

C.isCalibrated = true;
C.pixelSize = pixelSize;
C.unit = unit;
C.source = "tiff resolution tag (" + unitSource + ")";

end

function [unit, unitSource] = resolve_unit(info)
%RESOLVE_UNIT Prefer ImageJ's own unit over the coarse TIFF resolution unit.

unit = imagej_unit(info);

if unit ~= ""
    unitSource = "ImageJ unit";
    return
end

unitSource = "TIFF ResolutionUnit";
unit = "pixel";

if ~isfield(info, "ResolutionUnit")
    return
end

switch lower(string(info.ResolutionUnit))
    case "centimeter"
        unit = "cm";
    case "inch"
        unit = "inch";
end

end

function unit = imagej_unit(info)
%IMAGEJ_UNIT Pull the unit out of the ImageJ ImageDescription tag.

unit = "";

if ~isfield(info, "ImageDescription") || isempty(info.ImageDescription)
    return
end

token = regexp(string(info.ImageDescription), "unit=([^\r\n]+)", "tokens", "once");

if isempty(token)
    return
end

raw = lower(strtrim(string(token{1})));

if ismember(raw, ["um", "micron", "microns", "micrometer", "micrometre", char(181) + "m"])
    unit = "um";
    return
end

if ismember(raw, ["cm", "centimeter", "centimetre"])
    unit = "cm";
    return
end

if ismember(raw, ["inch", "in"])
    unit = "inch";
    return
end

if ismember(raw, ["pixel", "pixels", ""])
    return
end

unit = raw;

end
