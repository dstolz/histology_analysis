function info = parse_histology_filename(filename)
% parse_histology_filename
%   info = parse_histology_filename(filename)
%
% Parse the metadata encoded in a histology image or values filename. Unlike
% the parser embedded in COMBINE_VALUES_CSV, this reports failures through an
% isValid flag rather than raising, so browsing tools can list files whose
% names do not follow the convention instead of aborting.
%
% Recognized pattern (parsed from the right so SampleID may contain "_"):
%   SUBJ-ID-<n><SampleID>_<Section>_<Hemi>_<Stain>_<Z>_<Date>_<ImageNumber>
%
% Recognized trailing variant markers: _proj, _mid, _composite, and the
% _values / _proj_<ROI>values suffixes written by the Fiji line-measure macro.
%
% Parameters
%   filename: Image or values filename, with or without a path and extension.
%
% Returns
%   info: Struct with fields
%      - isValid: True when the stem matched the expected pattern.
%      - stem: Base name with extension and variant markers removed.
%      - variant: One of raw, proj, mid, or composite.
%      - roi: ROI label recovered from a values filename, when present.
%      - SubjectID, SampleID, SectionID, Hemisphere, Stain, ZPlane,
%        DateCode, ImageNumber, Protocol, Series: Parsed name components.

arguments
    filename (1,1) string
end

info = initialize_info();

[~, baseName, ext] = fileparts(filename);

if baseName == ""
    return
end

% A name such as "sample.ome" leaves a residual extension after one split.
if ext == "" && ~contains(baseName, ".")
    baseName = string(baseName);
end

stem = string(baseName);

[stem, info.variant, info.roi] = strip_markers(stem);

info.stem = stem;

parts = split(stem, "_");

if numel(parts) < 7
    return
end

samplePrefix = join(parts(1:end-6), "_");
subjectInfo = regexp(samplePrefix, "^(?<SubjectID>SUBJ-ID-[0-9]+)(?<SampleID>.*)$", "names");

if isempty(subjectInfo)
    return
end

info.SubjectID = string(subjectInfo.SubjectID);
info.SampleID = string(subjectInfo.SampleID);
info.SectionID = string(parts(end-5));
info.Hemisphere = string(parts(end-4));
info.Stain = string(parts(end-3));
info.ZPlane = string(parts(end-2));
info.DateCode = string(parts(end-1));
info.ImageNumber = string(parts(end));

sampleInfo = regexp(info.SampleID, "^(?<Protocol>.*?)\d{6}S(?<Series>\d+)$", "names");

if ~isempty(sampleInfo)
    info.Protocol = string(sampleInfo.Protocol);
    info.Series = string(sampleInfo.Series);
end

info.isValid = true;

end

function info = initialize_info()
%INITIALIZE_INFO Build the default (unparsed) result.

info = struct( ...
    "isValid", false, ...
    "stem", "", ...
    "variant", "raw", ...
    "roi", "", ...
    "SubjectID", "", ...
    "SampleID", "", ...
    "SectionID", "", ...
    "Hemisphere", "", ...
    "Stain", "", ...
    "ZPlane", "", ...
    "DateCode", "", ...
    "ImageNumber", "", ...
    "Protocol", "", ...
    "Series", "");

end

function [stem, variant, roi] = strip_markers(stem)
%STRIP_MARKERS Remove values/variant markers and report what was found.
% Tolerates every naming convention emitted by the Fiji macros:
%   <base>_proj.tif / <base>_mid.tif / <base>_composite.png
%   <base>_proj_roi.roi
%   <base>_values / <base>_proj_values
%   <base>_proj_<ROI>_values / <base>_proj_<ROI>values   (macro omits the "_")

roi = "";
variant = "raw";

% Values files carry the ROI label between the projection marker and "values",
% so match the whole tail at once rather than peeling it off in stages.
valuesToken = regexp(stem, "^(?<base>.*?)_proj_(?<roi>\w*?)_?values$", "names", "once");

if ~isempty(valuesToken)
    stem = string(valuesToken.base);
    roi = string(valuesToken.roi);
    variant = "proj";
    return
end

if endsWith(stem, "values")
    stem = regexprep(stem, "_?values$", "");
end

if endsWith(stem, "_roi")
    stem = extractBefore(stem, strlength(stem) - 3);
end

markers = ["proj", "mid", "composite"];

for iMarker = 1:numel(markers)
    thisMarker = markers(iMarker);

    if endsWith(stem, "_" + thisMarker)
        stem = extractBefore(stem, strlength(stem) - strlength(thisMarker));
        variant = thisMarker;
        return
    end
end

end
