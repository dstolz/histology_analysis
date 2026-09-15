function T = metadataTable(obj, options)
%METADATATABLE The tracker in the shape the rest of the pipeline expects.
% COMBINE_VALUES_CSV and BUILD_HISTOLOGY_IMAGE_CATALOG take the tracker as a
% table and join it on Image Filename. They neither know nor care that it came
% from a spreadsheet rather than a CSV, and this is what keeps it that way.
%
% Every column arrives as text, which is what the exported CSV gave them for
% most columns anyway; the two that are read as numbers are converted where
% they are used.
%
% Parameters
%   options.refresh: Read the tab again first. Off by default so a caller that
%     has just read does not pay for a second round trip.
%
% Returns
%   T: One row per tracker entry, all columns as strings.
%
% See also COMBINE_VALUES_CSV, BUILD_HISTOLOGY_IMAGE_CATALOG.

arguments
    obj (1,1) SectionTracker
    options.refresh (1,1) logical = false
end

if options.refresh || ~obj.hasData()
    obj.read();
end

T = obj.Table;

end
