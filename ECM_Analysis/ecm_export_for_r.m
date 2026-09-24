function outFiles = ecm_export_for_r(matFile, outDir)
% ecm_export_for_r
%   outFiles = ecm_export_for_r(matFile, outDir)
%
% Flatten the ECM section table into plain CSVs that R (or anything else that
% is not MATLAB) can read.
%
% "ECM Projects - GM6001 - full.mat" carries a single 85x52 table variable that
% nests one 1148x2 (Distance, Intensity) profile table per section inside a
% cell. No flat format can hold that nesting, so writetable on it does not fail
% -- it silently emits 1148 empty fields per row and shifts every column after
% Profile out of alignment with the header, losing all 110762 samples. This
% unnests the profiles into a long, one-row-per-sample file instead, and writes
% the section-level metadata alongside it.
%
% Each section's brain surface, as marked in the histology browser, goes out
% as data: SurfaceDistance, on the same axis as Distance, placed by
% ECM_SURFACE_DISTANCE exactly as ecm_prepare_analysis_data places it. R reads
% it rather than finding the surface again. A section with no mark gets NaN
% (NA in R), and a table with no marks at all is refused, because R would
% have nothing to align on.
%
% Parameters
%   matFile: Path to the saved table. Defaults to the GM6001 full export.
%   outDir:  Where the CSVs go. Defaults to the folder holding matFile.
%
% Returns
%   outFiles: Struct with fields profiles and sections, the two paths written.

arguments
    matFile (1,1) string = "D:/GM6001_HISTOLOGY/ECM Projects - GM6001 - full.mat"
    outDir  (1,1) string = ""
end

if outDir == "", outDir = string(fileparts(matFile)); end
if ~isfolder(outDir), mkdir(outDir); end

S = load(matFile, '-mat');
fn = fieldnames(S);
isTbl = cellfun(@(f) istable(S.(f)), fn);
assert(any(isTbl), "ecm_export_for_r:noTable", ...
    "%s holds no table variable (found: %s).", matFile, strjoin(fn', ', '));
T = S.(fn{find(isTbl, 1)});

% Section metadata: everything that is one value per section. Cells hold the
% nested profile and the values-file paths, neither of which flattens.
meta = T(:, ~varfun(@iscell, T, OutputFormat = "uniform"));
for j = 1:width(meta)
    if isdatetime(meta.(j)), meta.(j) = string(meta.(j), "yyyy-MM-dd HH:mm:ss"); end
end

assert(any(T.Properties.VariableNames == "Profile"), "ecm_export_for_r:noProfile", ...
    "The table has no Profile column to unnest.");

meta.SurfaceDistance = surface_distances(T);

profFile = fullfile(outDir, "ECM Projects - GM6001 - profiles.csv");
sectFile = fullfile(outDir, "ECM Projects - GM6001 - sections.csv");

writetable(meta, sectFile);

% Long profiles: repeat each section's metadata across its samples. Sections
% differ in sample count, so build per section and stack.
parts = cell(height(T), 1);
for i = 1:height(T)
    p = T.Profile{i};
    if isempty(p), continue; end
    n = height(p);
    part = repmat(meta(i, :), n, 1);
    part.SampleIndex = (1:n)';
    part.Distance    = p.Distance;
    part.Intensity   = p.Intensity;
    parts{i} = part;
end
long = vertcat(parts{:});
writetable(long, profFile);

fprintf("Wrote %s (%d rows x %d vars)\n", sectFile, height(meta), width(meta));
fprintf("Wrote %s (%d rows x %d vars)\n", profFile, height(long), width(long));

nMarked = sum(isfinite(meta.SurfaceDistance));
fprintf("%d of %d sections carry a brain surface mark; the other %d have SurfaceDistance NaN.\n", ...
    nMarked, height(meta), height(meta) - nMarked);

outFiles = struct(profiles = profFile, sections = sectFile);
end

function s = surface_distances(T)
%SURFACE_DISTANCES Place each section's surface mark on its profile's axis.
% The profile is read the way ecm_prepare_analysis_data reads it -- finite
% samples, sorted by distance -- so both hand on the same number.

names = string(T.Properties.VariableNames);

assert(ismember("SurfaceOffset", names), "ecm_export_for_r:noSurfaceMark", ...
    "The table has no SurfaceOffset column, so there is no brain surface to hand to R. " + ...
    "Export the sections again from the histology browser, which carries the marks.");

endpoints = ["RoiX1", "RoiY1", "RoiX2", "RoiY2"];

if ismember("RoiLength", names)
    lineLength = double(T.RoiLength);
elseif all(ismember(endpoints, names))
    lineLength = hypot(double(T.RoiX2) - double(T.RoiX1), double(T.RoiY2) - double(T.RoiY1));
else
    error("ecm_export_for_r:noLineLength", ...
        "The table has surface marks but no RoiLength or RoiX1..RoiY2 to place them with.");
end

offset = double(T.SurfaceOffset);
s = nan(height(T), 1);
unplaced = strings(0, 1);

for i = 1:height(T)
    p = T.Profile{i};
    d = zeros(0, 1);

    if ~isempty(p)
        d = double(p.Distance);
        d = sort(d(isfinite(d) & isfinite(double(p.Intensity))));
    end

    [s(i), hasMark] = ecm_surface_distance(offset(i), lineLength(i), d);

    if hasMark && ~isfinite(s(i))
        unplaced(end+1, 1) = string(i); %#ok<AGROW>
    end
end

if ~isempty(unplaced)
    warning("ecm_export_for_r:unplacedSurfaceMark", ...
        "Row(s) %s carry a surface mark that could not be placed on the profile; SurfaceDistance is NaN there.", ...
        strjoin(unplaced, ", "));
end

end
