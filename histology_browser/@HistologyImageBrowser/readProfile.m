function P = readProfile(obj, row, key)
%READPROFILE Return the line profile of one of a section's ROIs.
%
% The already-loaded COMBINE_VALUES_CSV output is preferred, so the browser
% shows exactly the data the analysis pipeline sees. Reading the CSV directly
% is only a fallback for rows that combiner skipped, for example when the
% filename did not match the tracker.
%
% The brain surface mark comes back on the same axis as the samples, so a
% caller plotting the trace can put a marker on it, or shift the axis so the
% surface sits at zero, without knowing that the mark is stored in pixels along
% the line. The conversion is the fraction of the line the mark sits at, mapped
% onto the span of the trace, which is exact because the trace spans the line
% by construction and holds whether or not the page carries a calibration.
%
% Parameters
%   row: One catalog row.
%   key: Which of the section's ROIs to read. Defaults to the one the edit
%       controls are pointed at.
%
% Returns
%   P: Struct with fields hasData, distance, intensity, surface,
%      surfaceSource, roiKey, roiLabel, source, and message. The label is what
%      the ROI is called on screen, which is the key until somebody names it.
%      The surface is NaN when this ROI has no mark.

arguments
    obj
    row table
    key (1,1) string = obj.activeRoiKey(row)
end

P = struct( ...
    "hasData", false, ...
    "distance", zeros(0, 1), ...
    "intensity", zeros(0, 1), ...
    "surface", NaN, ...
    "surfaceSource", "", ...
    "roiKey", key, ...
    "roiLabel", obj.roiName(key), ...
    "source", "", ...
    "message", "");

% An unsaved edit is what the user is looking at, so the profile measured
% under the moved line takes precedence over whatever is still on disk.
P = read_from_preview(P, obj, row, key);

if P.hasData
    P = attach_surface(P, obj, row, key);
    return
end

valuesPath = obj.roiEntry(row, key).valuesPath;

if valuesPath == ""
    P.message = "No values file for ROI " + P.roiLabel + " of this section.";
    return
end

P = read_from_combined(P, obj.Data, valuesPath);

if P.hasData
    P = attach_surface(P, obj, row, key);
    return
end

P = read_from_csv(P, valuesPath);
P = attach_surface(P, obj, row, key);

end

function P = attach_surface(P, obj, row, key)
%ATTACH_SURFACE Put the brain surface mark onto the trace's own distance axis.
% ROIFORROW is what resolves the mark, so an unsaved one wins over the sidecar
% exactly as an unsaved line wins over the .roi file, and everything that draws
% the surface is reading the same number.
%
% Asked for this profile's own ROI rather than for the section's default one.
% Each line crosses the surface at its own depth and has its own length to
% scale that depth by, so reading the default would have put one ROI's mark on
% another ROI's trace whenever a section carries more than one.

if ~P.hasData
    return
end

R = obj.roiForRow(row, key);

if ~R.isValid || ~R.isLine || ~isfinite(R.surface)
    return
end

lineLength = hypot(R.x2 - R.x1, R.y2 - R.y1);

if ~isfinite(lineLength) || lineLength <= 0
    return
end

span = P.distance(end) - P.distance(1);

if ~isfinite(span) || span <= 0
    return
end

fraction = min(max(R.surface / lineLength, 0), 1);

P.surface = P.distance(1) + fraction * span;
P.surfaceSource = R.surfaceSource;

end

function P = read_from_preview(P, obj, row, key)
%READ_FROM_PREVIEW Return the profile measured under an unsaved ROI edit.

if ~obj.isEditingRoi(row, key)
    return
end

preview = obj.RoiPreview;

if ~isfield(preview, "hasData") || ~preview.hasData
    return
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
