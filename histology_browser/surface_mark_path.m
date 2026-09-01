function markPath = surface_mark_path(roiPath)
% surface_mark_path
%   markPath = surface_mark_path(roiPath)
%
% Name the sidecar that holds the brain surface mark for one line ROI.
%
% The mark is a point on the line, so it is stored beside the line rather than
% in a catalog of its own: the path is the .roi path with its extension
% replaced by "_surface.json", which keeps the pairing one-to-one and needs
% nothing added to BUILD_HISTOLOGY_IMAGE_CATALOG's scan. That scan looks for
% images, .roi files and *values.csv, so a .json beside them is invisible to it
% and cannot turn up as a stray section.
%
% Fiji does not read or write this file. The .roi format has no field for a
% point along a line, and inventing one would produce files the line-measure
% macro could no longer open, so the mark travels beside the ROI instead of
% inside it.
%
% Parameters
%   roiPath: Path of the .roi file the mark belongs to.
%
% Returns
%   markPath: Path of the sidecar, or "" when no ROI path was given.
%
% See also READ_SURFACE_MARK, WRITE_SURFACE_MARK, DETECT_BRAIN_SURFACE.

arguments
    roiPath (1,1) string
end

markPath = "";

if roiPath == ""
    return
end

[folder, base] = fileparts(roiPath);

markPath = fullfile(string(folder), string(base) + "_surface.json");

end
