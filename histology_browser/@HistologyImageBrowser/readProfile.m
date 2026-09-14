function P = readProfile(obj, row)
%READPROFILE Return the line profile associated with one catalog row.
%
% The already-loaded COMBINE_VALUES_CSV output is preferred, so the browser
% shows exactly the data the analysis pipeline sees. Reading the CSV directly
% is only a fallback for rows that combiner skipped, for example when the
% filename did not match the tracker.
%
% Returns
%   P: Struct with fields hasData, distance, intensity, roiLabel, source,
%      and message.

P = struct( ...
    "hasData", false, ...
    "distance", zeros(0, 1), ...
    "intensity", zeros(0, 1), ...
    "roiLabel", "", ...
    "source", "", ...
    "message", "");

% An unsaved edit is what the user is looking at, so the profile measured
% under the moved line takes precedence over whatever is still on disk.
P = read_from_preview(P, obj, row);

if P.hasData
    return
end

valuesPaths = row.ValuesPaths{1};

if isempty(valuesPaths)
    P.message = "No values file for this section.";
    return
end

valuesPath = valuesPaths(1);
roiLabels = row.ROILabels{1};

if ~isempty(roiLabels)
    P.roiLabel = roiLabels(1);
end

P = read_from_combined(P, obj.Data, valuesPath);

if P.hasData
    return
end

P = read_from_csv(P, valuesPath);

end

function P = read_from_preview(P, obj, row)
%READ_FROM_PREVIEW Return the profile measured under an unsaved ROI edit.

if ~obj.isEditingRow(row)
    return
end

preview = obj.RoiPreview;

if ~isfield(preview, "hasData") || ~preview.hasData
    return
end

roiLabels = row.ROILabels{1};

if ~isempty(roiLabels)
    P.roiLabel = roiLabels(1);
end

P.distance = preview.distance;
P.intensity = preview.intensity;
P.source = "remeasured in MATLAB (unsaved)";
P.hasData = true;

end

function P = read_from_combined(P, S, valuesPath)
%READ_FROM_COMBINED Pull one file worth of rows out of the combined table.

if ~isfield(S, "combined") || ~istable(S.combined) || height(S.combined) == 0
    return
end

T = S.combined;
varNames = string(T.Properties.VariableNames);

if ~all(ismember(["SourceFilePath", "distance_pixel_index", "intensity"], varNames))
    return
end

isFile = string(T.SourceFilePath) == valuesPath;

if ~any(isFile)
    return
end

P.distance = double(T.distance_pixel_index(isFile));
P.intensity = double(T.intensity(isFile));
P.source = "combine_values_csv";

P = finalize(P);

end

function P = read_from_csv(P, valuesPath)
%READ_FROM_CSV Read a values CSV directly.

if ~isfile(valuesPath)
    P.message = "Values file is missing: " + valuesPath;
    return
end

try
    T = readtable(valuesPath);
catch ME
    P.message = "Could not read values file: " + string(ME.message);
    return
end

varNames = string(T.Properties.VariableNames);

if ~all(ismember(["distance_pixel_index", "intensity"], varNames))
    P.message = "Values file does not contain distance_pixel_index and intensity.";
    return
end

P.distance = double(T.distance_pixel_index);
P.intensity = double(T.intensity);
P.source = "values csv";

P = finalize(P);

end

function P = finalize(P)
%FINALIZE Drop non-finite samples and sort by distance.

valid = isfinite(P.distance) & isfinite(P.intensity);
P.distance = P.distance(valid);
P.intensity = P.intensity(valid);

if isempty(P.distance)
    P.message = "Values file contained no finite samples.";
    return
end

[P.distance, order] = sort(P.distance);
P.intensity = P.intensity(order);
P.hasData = true;

end
