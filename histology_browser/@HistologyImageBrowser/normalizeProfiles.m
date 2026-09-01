function N = normalizeProfiles(profiles, options)
%NORMALIZEPROFILES Rescale a set of line profiles for plotting.
%
% Two independent choices, one per axis, plus what the intensity one is
% measured over. Nothing here reads or writes the app: it takes the numbers,
% returns a rescaled copy and the axis labels that describe it, and is a static
% method so the arithmetic can be checked without a window on screen.
%
% The copy is the point. A values file is the measurement, and a normalization
% is a way of looking at it, so RENDERPROFILEPLOT normalizes what it is about
% to draw and nothing else. Nothing that leaves the app -- the exported table,
% a remeasured ROI, the CSV rewritten beside a saved line -- is touched by
% anything chosen here.
%
% "From brain surface" is the one distance mapping that needs something beyond
% the samples: the depth the section's brain surface was marked at, carried on
% each trace as a SURFACE field on the trace's own distance axis. A trace
% without one falls back to "from line start", which is what its distance axis
% already meant, rather than being left where it was or dropped -- and the
% caller is told which traces those were, so an unmarked section reads as
% unaligned instead of as aligned at a surface nobody found.
%
% Scope applies to the intensity axis alone. "each" scales every trace by its
% own statistics, which puts sections of very different brightness on one scale
% and, in doing so, throws away how they differed; "all" scales every trace by
% one set of statistics pooled over the whole plot, which keeps that difference
% and is what a comparison between sections needs. Distance is normalized per
% trace either way, because a line's own start and its own length are the only
% things "from line start" and "percent of line" can mean.
%
% Degenerate cases are left alone rather than forced. A trace that is flat has
% no range to divide by, and one measured at a single point has no length; both
% would come back as a column of NaN or Inf, which plots as nothing at all and
% looks exactly like a missing file. Their offset is still applied, so a flat
% trace under "Min-max (0-1)" lands on zero -- true, and visible -- instead of
% disappearing.
%
% Parameters
%   profiles: Struct array with fields distance and intensity, one entry per
%       trace, and optionally surface -- the depth of the brain surface on that
%       trace's distance axis, NaN or absent when it has no mark. May be empty,
%       in which case only the labels come back.
%   options.Normalization: Code from PROFILENORMCODES. "none" by default.
%   options.Distance: Code from PROFILEDISTANCECODES. "none" by default.
%   options.Scope: Code from PROFILESCOPECODES. "each" by default.
%
% Returns
%   N: Struct with fields
%      - profiles: The input, rescaled, in the same order.
%      - xLabel, yLabel: What the axes should now be called.
%      - normalization, distance, scope: The codes actually applied, after any
%        unrecognized one has fallen back to the setting that changes nothing.
%      - nUnmarked: How many traces "from brain surface" had to fall back on,
%        for the caller to say so. Zero under every other distance mapping.
%
% See also RENDERPROFILEPLOT, READPROFILE.

arguments
    profiles struct
    options.Normalization (1,1) string = "none"
    options.Distance (1,1) string = "none"
    options.Scope (1,1) string = "each"
end

% An unrecognized code becomes the one that changes nothing, rather than an
% error. These arrive from a preference file, which can be hand-edited or
% written by a release that offered a normalization this one has dropped, and
% a stale preference should cost the user a normalization rather than a plot.
normalization = fall_back(options.Normalization, ...
    HistologyImageBrowser.ProfileNormCodes, "none");
distance = fall_back(options.Distance, ...
    HistologyImageBrowser.ProfileDistanceCodes, "none");
scope = fall_back(options.Scope, ...
    HistologyImageBrowser.ProfileScopeCodes, "each");

N = struct( ...
    "profiles", profiles, ...
    "nUnmarked", 0, ...
    "xLabel", axis_label(distance, HistologyImageBrowser.ProfileDistanceCodes, ...
        HistologyImageBrowser.ProfileDistanceLabels), ...
    "yLabel", axis_label(normalization, HistologyImageBrowser.ProfileNormCodes, ...
        HistologyImageBrowser.ProfileNormLabels), ...
    "normalization", normalization, ...
    "distance", distance, ...
    "scope", scope);

if isempty(profiles)
    return
end

[N.profiles, N.nUnmarked] = scale_distance(N.profiles, distance);
N.profiles = scale_intensity(N.profiles, normalization, scope);

end

function [profiles, nUnmarked] = scale_distance(profiles, code)
%SCALE_DISTANCE Put every trace's distance axis through the chosen mapping.

nUnmarked = 0;

if code == "none"
    return
end

for iProfile = 1:numel(profiles)
    d = double(profiles(iProfile).distance(:));

    if isempty(d)
        continue
    end

    if code == "surface"
        surface = trace_surface(profiles(iProfile));

        if isnan(surface)
            % No mark to align on, so the trace falls back on its own start --
            % the same axis "from line start" would give it. Counted rather
            % than annotated here, because how to say so belongs to whatever is
            % drawing the plot.
            nUnmarked = nUnmarked + 1;
            surface = min(d);
        end

        profiles(iProfile).distance = d - surface;
        continue
    end

    span = max(d) - min(d);
    d = d - min(d);

    % A single sample, or every sample at one distance, has no length to be a
    % percentage of. The shifted axis is the honest answer for it.
    if code == "percent" && span > 0
        d = 100 * d / span;
    end

    profiles(iProfile).distance = d;
end

end

function surface = trace_surface(profile)
%TRACE_SURFACE Read a trace's brain surface depth, or NaN when it has none.
% Absent on a trace built by a caller that knows nothing about surfaces, which
% is the same thing here as a section that was never marked.

surface = NaN;

if ~isfield(profile, "surface")
    return
end

candidate = double(profile.surface);

if isscalar(candidate) && isfinite(candidate)
    surface = candidate;
end

end

function profiles = scale_intensity(profiles, code, scope)
%SCALE_INTENSITY Put every trace's intensity axis through the chosen mapping.
% The statistics come from one trace or from all of them, which is the only
% thing scope decides; the arithmetic below is the same either way.

if code == "none"
    return
end

% Pooled once, here, rather than inside the loop. Needing statistics the whole
% plot contributed to is the only reason this cannot be a per-trace map.
if scope == "all"
    shared = intensity_stats(pooled_intensity(profiles));
else
    shared = struct([]);
end

for iProfile = 1:numel(profiles)
    y = double(profiles(iProfile).intensity(:));

    if isempty(y)
        continue
    end

    if isempty(shared)
        stats = intensity_stats(y);
    else
        stats = shared;
    end

    profiles(iProfile).intensity = apply_intensity(y, code, stats);
end

end

function y = pooled_intensity(profiles)
%POOLED_INTENSITY Every sample on the plot, as one column.
% Built through a cell array rather than by concatenating the field directly,
% so a trace stored as a row cannot turn the pool into a matrix.

parts = cell(numel(profiles), 1);

for iProfile = 1:numel(profiles)
    parts{iProfile} = double(profiles(iProfile).intensity(:));
end

y = vertcat(parts{:});

end

function stats = intensity_stats(y)
%INTENSITY_STATS Summarize the samples a normalization is measured over.

y = double(y(:));

stats = struct( ...
    "min", min(y), ...
    "max", max(y), ...
    "mean", mean(y), ...
    "std", std(y));

end

function y = apply_intensity(y, code, stats)
%APPLY_INTENSITY Rescale one trace by statistics already taken.
% Every divisor is checked before it is used, and a divisor of zero leaves the
% offset applied and the scale alone. That is what keeps a flat trace on the
% plot: dividing its zero range would put the whole trace at NaN, which draws
% as nothing and reads as a section whose file failed to load.

switch code
    case "baseline"
        y = y - stats.min;

    case "range"
        y = y - stats.min;
        y = divide(y, stats.max - stats.min);

    case "max"
        y = 100 * divide(y, stats.max);

    case "mean"
        y = divide(y, stats.mean);

    case "zscore"
        y = y - stats.mean;
        y = divide(y, stats.std);
end

end

function y = divide(y, denominator)
%DIVIDE Scale by a denominator, or leave the trace alone when there is none.

if ~isfinite(denominator) || denominator == 0
    return
end

y = y / denominator;

end

function code = fall_back(code, allowed, defaultCode)
%FALL_BACK Keep a code the current release offers, or take the neutral one.

code = string(code);

if ~ismember(code, allowed)
    code = defaultCode;
end

end

function label = axis_label(code, codes, labels)
%AXIS_LABEL Name an axis for the mapping now on it.

label = labels(codes == code);
label = label(1);

end
