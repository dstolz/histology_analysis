function key = histology_roi_key(label)
% histology_roi_key
%   key = histology_roi_key(label)
%
% Reduce the ROI label recovered from a sidecar filename to the key the
% section files that ROI under.
%
% MACRO_Batch_LineMeasure writes one unlabelled .roi and values.csv per
% section, so a section's first ROI carries no label at all. It is filed under
% "A", which is what lets a dataset measured before a section could hold more
% than one ROI read back as a section with one ROI called A rather than as a
% section with an anonymous one.
%
% Any other label is kept exactly as it was written, so a values file named
% for its region -- "_proj_ACxvalues.csv" -- files under ACx rather than being
% renumbered into a letter it never had.
%
% Parameters
%   label: ROI label from PARSE_HISTOLOGY_FILENAME, possibly "".
%
% Returns
%   key: The ROI's key, never empty.
%
% See also PARSE_HISTOLOGY_FILENAME, BUILD_HISTOLOGY_IMAGE_CATALOG,
% HISTOLOGYIMAGEBROWSER.

arguments
    label (1,1) string = ""
end

if ismissing(label)
    key = "A";
    return
end

key = strtrim(label);

if key == ""
    key = "A";
end

end
