function T = batch_detect_brain_surface(rootPath, options)
% batch_detect_brain_surface
%   T = batch_detect_brain_surface(rootPath)
%   T = batch_detect_brain_surface(rootPath, DryRun = true)
%   T = batch_detect_brain_surface(rootPath, Overwrite = "none")
%
% Run the browser's automatic brain surface detection over every line ROI
% found under a root folder, and write the result to each ROI's surface
% sidecar. This is the Detect button followed by Save, for every ROI at once,
% without the rest of the save: the .roi and *values.csv files are read but
% never written.
%
% Each ROI is measured and detected exactly as DETECTSURFACE does it: the
% profile is remeasured under the line from the image MEASUREIMAGEPATH would
% pick (the _proj rendition, else _mid, else _composite; never the raw .czi),
% the background is IMAGE_BACKGROUND of that same page, and the mark is
% DETECT_BRAIN_SURFACE's fraction times the line length, in pixels from the
% line's start point.
%
% Existing marks are handled by Overwrite. The default replaces marks the
% detector placed and fills in missing ones, but leaves marks placed by hand
% alone, since those are a person's correction of the detector.
%
% Progress is printed one line per ROI, and the returned table (optionally
% written to CSV) carries, for every ROI, what was done and the surface's
% distance from the line's top point -- the endpoint with the smaller image y,
% which is the upper one on screen. Where the two endpoints share a y the
% start point is used and TopEnd says "tie".
%
% Parameters
%   rootPath: Folder scanned recursively, as BUILD_HISTOLOGY_IMAGE_CATALOG
%       scans it.
%   options.Overwrite: Which existing marks may be replaced.
%       "auto" (default): missing marks and marks with source "auto".
%       "all": every mark, including manual ones.
%       "none": only ROIs that have no mark.
%   options.DryRun: Detect and report, but write no sidecar.
%   options.WriteLowConfidence: Write marks the detector reports as low
%       confidence. True matches the browser, which marks them too.
%   options.OutputCsv: Where to write the results table. "" writes none.
%       Defaults to a timestamped file in rootPath.
%   options.FilenamePattern: Passed through to BUILD_HISTOLOGY_IMAGE_CATALOG.
%
% Returns
%   T: One row per ROI, with columns
%      - Stem, RoiKey, RoiPath, ImagePath
%      - Action: "written", "would write" (dry run), "kept", or "skipped".
%      - Reason: Why a mark was kept or skipped, or the detector's warning.
%      - PreviousSource, PreviousOffsetPx: The mark on disk before this run.
%      - Confidence: "high", "low", or "none".
%      - Contrast: Height of the step at the surface, in noise sigmas.
%      - OffsetPx: Surface distance from the line's start point (x1,y1), px.
%      - LineLengthPx: Length of the line, px.
%      - TopEnd: "start", "end", or "tie" -- which endpoint is the top one.
%      - TopX, TopY: The top point, image pixels.
%      - FromTopPx: Surface distance from the top point, px.
%      - FromTop: Same, in the image's calibrated unit; NaN if uncalibrated.
%      - Unit: The unit of FromTop, as the image states it.
%      - FromTopPercent: FromTopPx as a percentage of the line length.
%
% See also DETECT_BRAIN_SURFACE, IMAGE_BACKGROUND, MEASURE_LINE_PROFILE,
% WRITE_SURFACE_MARK, BUILD_HISTOLOGY_IMAGE_CATALOG.

arguments
    rootPath (1,1) string
    options.Overwrite (1,1) string {mustBeMember(options.Overwrite, ...
        ["auto", "all", "none"])} = "auto"
    options.DryRun (1,1) logical = false
    options.WriteLowConfidence (1,1) logical = true
    options.OutputCsv (1,1) string = fullfile(rootPath, ...
        "surface_detection_" + string(datetime("now", Format = "yyyyMMdd_HHmmss")) + ".csv")
    options.FilenamePattern (1,1) string = ""
end

fprintf("Scanning %s ...\n", rootPath);

C = build_histology_image_catalog(rootPath, filenamePattern = options.FilenamePattern);

jobs = list_jobs(C);
nJobs = numel(jobs);

fprintf("Found %d line ROI file(s) on %d section(s).\n", nJobs, height(C));

if options.DryRun
    fprintf("Dry run: nothing will be written.\n");
end

T = empty_results(nJobs);

if nJobs == 0
    return
end

% Every ROI of a section is measured off the same page, so it is read once per
% section rather than once per ROI.
cache = struct("imagePath", "", "img", [], "background", NaN, "calibration", []);

tStart = tic;

for iJob = 1:nJobs
    job = jobs(iJob);
    row = C(job.row, :);

    T.Stem(iJob) = string(row.Stem);
    T.RoiKey(iJob) = job.key;
    T.RoiPath(iJob) = job.roiPath;

    try
        [T(iJob, :), cache] = process_roi(T(iJob, :), row, job, cache, options);
    catch ME
        T.Action(iJob) = "skipped";
        T.Reason(iJob) = "error: " + string(ME.message);
    end

    print_progress(iJob, nJobs, tStart, T(iJob, :));
end

print_summary(T, toc(tStart));

if options.OutputCsv ~= ""
    writetable(T, options.OutputCsv);
    fprintf("Results written to %s\n", options.OutputCsv);
end

end

function jobs = list_jobs(C)
%LIST_JOBS One entry per ROI that has a .roi file behind it.
% A values file with no .roi has no line to measure under and no path to name
% a sidecar after, so it is not a job.

jobs = struct("row", {}, "key", {}, "roiPath", {});

for iRow = 1:height(C)
    keys = string(C.RoiKeys{iRow});
    roiPaths = string(C.RoiPaths{iRow});

    for iRoi = 1:numel(roiPaths)
        if roiPaths(iRoi) == ""
            continue
        end

        jobs(end + 1) = struct("row", iRow, "key", keys(iRoi), ...
            "roiPath", roiPaths(iRoi)); %#ok<AGROW>
    end
end

end

function T = empty_results(n)
%EMPTY_RESULTS Preallocate the results table.

text = strings(n, 1);
number = NaN(n, 1);

T = table(text, text, text, text, text, text, text, number, text, number, ...
    number, number, text, number, number, number, number, text, number, ...
    VariableNames = ["Stem", "RoiKey", "RoiPath", "ImagePath", "Action", ...
    "Reason", "PreviousSource", "PreviousOffsetPx", "Confidence", "Contrast", ...
    "OffsetPx", "LineLengthPx", "TopEnd", "TopX", "TopY", "FromTopPx", ...
    "FromTop", "Unit", "FromTopPercent"]);

T.Confidence(:) = "none";

end

function [r, cache] = process_roi(r, row, job, cache, options)
%PROCESS_ROI Detect and, where allowed, write the surface for one ROI.

R = read_imagej_roi(job.roiPath);

if ~R.isValid
    r.Action = "skipped";
    r.Reason = R.message;
    return
end

if ~R.isLine
    r.Action = "skipped";
    r.Reason = "not a straight line ROI (" + string(R.typeName) + ")";
    return
end

lineLength = hypot(R.x2 - R.x1, R.y2 - R.y1);
r.LineLengthPx = lineLength;

if ~(lineLength >= 1)
    r.Action = "skipped";
    r.Reason = "line has no length";
    return
end

markPath = surface_mark_path(job.roiPath);
previous = read_surface_mark(markPath);

if previous.isValid
    r.PreviousSource = previous.source;
    r.PreviousOffsetPx = previous.offset;
end

imagePath = measure_image_path(row);
r.ImagePath = imagePath;

[allowed, reason] = may_overwrite(previous, options.Overwrite);

if ~allowed
    r.Action = "kept";
    r.Reason = reason;

    % Only the calibration is needed to report a kept mark, so the pixels are
    % not read for it.
    calibration = [];

    if imagePath ~= ""
        calibration = imagej_pixel_size(imagePath);
    end

    r = fill_distances(r, R, previous.offset, calibration);
    return
end

if imagePath == ""
    r.Action = "skipped";
    r.Reason = "no _proj, _mid or _composite image to measure from";
    return
end

cache = load_image(cache, imagePath);

P = measure_line_profile(cache.img, R, pixelSize = cache.calibration.pixelSize);

if ~P.hasData
    r.Action = "skipped";
    r.Reason = "could not measure profile: " + P.message;
    return
end

S = detect_brain_surface(P.distance, P.intensity, Background = cache.background);

r.Confidence = S.confidence;
r.Contrast = S.contrast;

if ~S.found
    r.Action = "skipped";
    r.Reason = "no surface found: " + S.message;
    return
end

if S.confidence ~= "high" && ~options.WriteLowConfidence
    r.Action = "skipped";
    r.Reason = "low confidence: " + S.message;
    return
end

% The same conversion DETECTSURFACE makes: the detector's fraction of the
% trace, which spans the line, onto pixels along the line from its start.
offset = S.fraction * lineLength;

r = fill_distances(r, R, offset, cache.calibration);
r.Reason = S.message;

if options.DryRun
    r.Action = "would write";
    return
end

mark = struct("x1", R.x1, "y1", R.y1, "x2", R.x2, "y2", R.y2, ...
    "surface", offset, "surfaceSource", "auto");

write_surface_mark(markPath, mark);

r.Action = "written";

end

function [allowed, reason] = may_overwrite(previous, policy)
%MAY_OVERWRITE Decide whether an existing mark may be replaced.

allowed = true;
reason = "";

if ~previous.isValid
    return
end

switch policy
    case "all"
        return
    case "auto"
        if previous.source == "auto"
            return
        end

        allowed = false;
        reason = "existing " + describe_source(previous.source) + " mark";
    case "none"
        allowed = false;
        reason = "existing " + describe_source(previous.source) + " mark";
end

end

function text = describe_source(source)
%DESCRIBE_SOURCE Name a mark's source for the report.

text = source;

if text == ""
    text = "unlabelled";
end

end

function r = fill_distances(r, R, offset, calibration)
%FILL_DISTANCES Express a surface offset from the line's start as distance
% from its top point.
% The offset is along the line from (x1,y1). When (x2,y2) is the upper end,
% distance from it is the rest of the line.

lineLength = hypot(R.x2 - R.x1, R.y2 - R.y1);

r.OffsetPx = offset;

if R.y1 < R.y2
    r.TopEnd = "start";
    r.TopX = R.x1;
    r.TopY = R.y1;
    r.FromTopPx = offset;
elseif R.y2 < R.y1
    r.TopEnd = "end";
    r.TopX = R.x2;
    r.TopY = R.y2;
    r.FromTopPx = lineLength - offset;
else
    r.TopEnd = "tie";
    r.TopX = R.x1;
    r.TopY = R.y1;
    r.FromTopPx = offset;
end

r.FromTopPercent = 100 * r.FromTopPx / lineLength;

if ~isempty(calibration) && calibration.isCalibrated
    r.FromTop = r.FromTopPx * calibration.pixelSize;
    r.Unit = calibration.unit;
end

end

function imagePath = measure_image_path(row)
%MEASURE_IMAGE_PATH The image a profile is measured from, in the browser's
% order of preference. Raw .czi is excluded, as it is there.

imagePath = "";

candidates = [string(row.ProjPath), string(row.MidPath), string(row.CompositePath)];

for iCandidate = 1:numel(candidates)
    if candidates(iCandidate) ~= "" && isfile(candidates(iCandidate))
        imagePath = candidates(iCandidate);
        return
    end
end

end

function cache = load_image(cache, imagePath)
%LOAD_IMAGE Read channel 1 of the page, its background and calibration,
% unless it is the page already held.

if cache.imagePath == imagePath
    return
end

[~, ~, ext] = fileparts(imagePath);

if ismember(lower(string(ext)), [".tif", ".tiff"])
    img = imread(imagePath, 1);
else
    img = imread(imagePath);
end

if isempty(img)
    error("image contains no pixels: %s", imagePath);
end

cache.imagePath = imagePath;
cache.img = img;
cache.background = image_background(img);
cache.calibration = imagej_pixel_size(imagePath);

end

function print_progress(iJob, nJobs, tStart, r)
%PRINT_PROGRESS One line per ROI: position, elapsed and remaining time, outcome.

elapsed = toc(tStart);
remaining = elapsed / iJob * (nJobs - iJob);

if isfinite(r.FromTopPx)
    distance = sprintf("%.1f px from top", r.FromTopPx);

    if isfinite(r.FromTop)
        distance = distance + sprintf(" (%.1f %s)", r.FromTop, r.Unit);
    end
else
    distance = "-";
end

detail = "";

if r.Reason ~= ""
    detail = " [" + r.Reason + "]";
end

fprintf("[%*d/%d %5.1f%%  %s elapsed, ~%s left] %s  ROI %s: %s, %s%s\n", ...
    numel(num2str(nJobs)), iJob, nJobs, 100 * iJob / nJobs, ...
    format_duration(elapsed), format_duration(remaining), ...
    r.Stem, r.RoiKey, r.Action, distance, detail);

end

function text = format_duration(seconds)
%FORMAT_DURATION Seconds as m:ss or h:mm:ss.

seconds = round(seconds);

if seconds >= 3600
    text = sprintf("%d:%02d:%02d", floor(seconds / 3600), ...
        floor(mod(seconds, 3600) / 60), mod(seconds, 60));
    return
end

text = sprintf("%d:%02d", floor(seconds / 60), mod(seconds, 60));

end

function print_summary(T, elapsed)
%PRINT_SUMMARY Count outcomes.

fprintf("\nDone in %s. ", format_duration(elapsed));

actions = ["written", "would write", "kept", "skipped"];

for iAction = 1:numel(actions)
    fprintf("%s: %d  ", actions(iAction), nnz(T.Action == actions(iAction)));
end

fprintf("\nLow-confidence marks written or pending: %d\n", ...
    nnz(ismember(T.Action, ["written", "would write"]) & T.Confidence == "low"));

end
