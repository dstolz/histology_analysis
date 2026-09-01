function S = detect_brain_surface(distance, intensity, options)
% detect_brain_surface
%   S = detect_brain_surface(distance, intensity)
%   S = detect_brain_surface(P.distance, P.intensity, direction = "forward")
%
% Find where a line profile crosses from background into tissue, so a line ROI
% drawn across a section can be given the depth its brain surface sits at
% without that point having to be clicked on every section by hand.
%
% The profile is the mean intensity across the band at one sample per pixel of
% line length, which for a line started off the section is a stretch of
% background followed by a step up into tissue. That step is what is looked
% for: the trace is smoothed, split into background and tissue by Otsu's
% threshold, and walked in from whichever end is background until it crosses
% and stays across. The crossing is interpolated between the two samples that
% straddle it, so the answer is not quantized to whole samples.
%
% Otsu rather than a fixed threshold because nothing here is calibrated in
% absolute intensity: exposure, gain, and stain vary between sections, and the
% only thing they all share is that the histogram of a profile crossing the
% edge of a section has two modes.
%
% Otsu will cut anything in two, though, including a trace that only slopes, so
% the crossing has to be shown to be an edge before it is believed: the run
% between a tenth and nine tenths of the step has to be a small part of the
% profile. A section edge crosses that in a few samples; a line that lies
% entirely inside tissue and merely dims with depth takes most of its length to,
% and is refused. Nothing is ever asserted -- a line that never leaves tissue,
% one that only slopes, and one whose two modes are within the noise all come
% back with found false and a message saying which, because a surface guessed
% off a trace with no edge in it would be worse than no surface at all.
%
% Parameters
%   distance: Distance of each sample along the line, as MEASURE_LINE_PROFILE
%       returns it. Only its scale matters; it need not start at zero.
%   intensity: Mean band intensity at each sample.
%   options.Direction: Which end of the line is outside the brain. "auto" reads
%       it off the two ends, which is right whichever way the line was drawn.
%       "forward" searches from the first sample, "reverse" from the last.
%   options.Smoothing: Width of the moving average, as a fraction of the
%       profile length. Enough to bridge the noise on a single sample without
%       rounding off the edge being found.
%   options.MinRun: How far past the crossing the trace must stay above
%       threshold, as a fraction of the profile length, before the crossing is
%       accepted. This is what keeps a speck of debris in the background from
%       taking the mark.
%   options.MinContrast: Separation between the background and tissue levels,
%       in noise sigmas, below which the answer is reported as low confidence.
%   options.MaxTransition: How much of the profile the step is allowed to be
%       spread over, as a fraction of its length, before it is called a
%       gradient rather than an edge and refused.
%
% Returns
%   S: Struct with fields
%      - found: True when a crossing was located.
%      - distance: Distance of the crossing, in the units given.
%      - index: Fractional 1-based sample index of the crossing.
%      - fraction: Where the crossing sits along the sampled span, 0 to 1.
%      - direction: End the search actually ran from.
%      - threshold, background, tissue: Levels the split was made at.
%      - noise, contrast: Sample noise, and the level separation in units of
%        it.
%      - transition: Samples the step takes to go from a tenth of the way up to
%        nine tenths of the way up. Small for an edge, large for a gradient.
%      - confidence: "high" or "low"; see MinContrast.
%      - message: Empty on success, otherwise why nothing was marked.
%
% See also MEASURE_LINE_PROFILE, READ_SURFACE_MARK, WRITE_SURFACE_MARK.

arguments
    distance (:,1) double
    intensity (:,1) double
    options.Direction (1,1) string {mustBeMember(options.Direction, ...
        ["auto", "forward", "reverse"])} = "auto"
    options.Smoothing (1,1) double {mustBeInRange(options.Smoothing, 0, 0.5)} = 0.02
    options.MinRun (1,1) double {mustBeInRange(options.MinRun, 0, 0.5)} = 0.02
    options.MinContrast (1,1) double {mustBeNonnegative} = 3
    options.MaxTransition (1,1) double {mustBeInRange(options.MaxTransition, 0, 1)} = 0.25
end

S = struct( ...
    "found", false, ...
    "distance", NaN, ...
    "index", NaN, ...
    "fraction", NaN, ...
    "direction", "", ...
    "threshold", NaN, ...
    "background", NaN, ...
    "tissue", NaN, ...
    "noise", NaN, ...
    "contrast", NaN, ...
    "transition", NaN, ...
    "confidence", "none", ...
    "message", "");

if numel(distance) ~= numel(intensity)
    S.message = sprintf("distance has %d samples but intensity has %d.", ...
        numel(distance), numel(intensity));
    return
end

keep = isfinite(distance) & isfinite(intensity);
distance = distance(keep);
intensity = intensity(keep);

[distance, order] = sort(distance);
intensity = intensity(order);

nSamples = numel(distance);

% Eight is where a smoothing window, a run length, and a background and a
% tissue side can all exist at once. Below it the answer would be decided by
% one or two samples, which is guessing dressed as measurement.
if nSamples < 8
    S.message = "Too few samples to find a surface in.";
    return
end

smoothed = smooth_profile(intensity, options.Smoothing);

S.threshold = otsu_threshold(smoothed);

isTissue = smoothed > S.threshold;

if ~any(isTissue) || all(isTissue)
    S.message = "The profile has no background-to-signal step in it.";
    return
end

S.background = median(smoothed(~isTissue));
S.tissue = median(smoothed(isTissue));

% Taken off the residual the smoothing removed rather than off the raw trace,
% so the layers a cortical profile is made of do not read as noise. Scaled by
% the usual constant that turns a median absolute deviation into a sigma.
S.noise = 1.4826 * median(abs(intensity - smoothed));

S.contrast = (S.tissue - S.background) / max(S.noise, eps);

[S.direction, message] = search_direction(smoothed, S.threshold, options.Direction);

if S.direction == ""
    S.message = message;
    return
end

runLength = max(2, round(options.MinRun * nSamples));

index = first_sustained_crossing(smoothed, S.threshold, S.direction, runLength);

if isnan(index)
    S.message = "The profile crosses into signal but never stays there.";
    return
end

S.transition = transition_width(smoothed, index, S.direction, S.background, S.tissue);

% An edge steps; a line that lies inside tissue and merely dims with depth
% slopes, and Otsu cuts that in half just as readily. The width of the step is
% what tells the two apart, and refusing the second is the whole reason it is
% measured: a mark in the middle of a gradient would look exactly like one on a
% real surface to everything downstream.
if S.transition > options.MaxTransition * nSamples
    S.message = "The profile slopes rather than stepping, so it has no edge to mark.";
    return
end

S.index = index;
S.fraction = (index - 1) / (nSamples - 1);
S.distance = interp1(1:nSamples, distance, index);

% Reported rather than refused. A weak step is still the best estimate the
% trace supports, and the caller is a window with a marker the user can drag;
% saying so and letting it be corrected beats withholding a starting point.
if S.contrast >= options.MinContrast
    S.confidence = "high";
else
    S.confidence = "low";
    S.message = sprintf("Background and tissue differ by only %.1f noise sigmas.", ...
        S.contrast);
end

S.found = true;

end

function smoothed = smooth_profile(y, fraction)
%SMOOTH_PROFILE Moving-average the trace over an odd, at-least-3 sample window.
% The endpoints are averaged over what there is rather than being padded, which
% is MOVMEAN's own default and the right one here: a padded end would pull the
% first samples toward zero and invent an edge at the start of every line.

window = max(3, round(fraction * numel(y)));

% An even window is centered half a sample off, which would bias every crossing
% in the same direction by half a sample.
if mod(window, 2) == 0
    window = window + 1;
end

smoothed = movmean(y, window);

end

function level = otsu_threshold(y)
%OTSU_THRESHOLD Split the samples into two classes at minimum within-class
% variance, which for a profile running off the section is background and
% tissue.
%
% Written out rather than taken from GRAYTHRESH or MULTITHRESH, both of which
% are Image Processing Toolbox and would put the whole automatic mark behind a
% licence that the rest of this file does not need.

nBins = 256;

lo = min(y);
hi = max(y);

if ~isfinite(lo) || ~isfinite(hi) || hi <= lo
    level = hi;
    return
end

edges = linspace(lo, hi, nBins + 1);
centers = (edges(1:end - 1) + edges(2:end)) / 2;

counts = histcounts(y, edges);
p = counts / sum(counts);

omega = cumsum(p);
mu = cumsum(p .* centers);
muTotal = mu(end);

% Between-class variance for a cut after each bin. The two bins where one class
% would be empty divide by zero, so they are left at zero and never chosen.
denominator = omega .* (1 - omega);
between = zeros(size(denominator));

usable = denominator > 0;
between(usable) = (muTotal * omega(usable) - mu(usable)).^2 ./ denominator(usable);

[~, cut] = max(between);
level = centers(cut);

end

function width = transition_width(smoothed, index, direction, background, tissue)
%TRANSITION_WIDTH How many samples the step takes to happen.
% Measured from the crossing outward rather than over the whole trace, so a
% second edge further along -- the far side of the section, say -- cannot
% widen the one being judged. A walk that runs off the end returns the whole
% distance to it, which fails the test it is measured for, and rightly: a step
% that never finishes inside the profile is not an edge in it.

nSamples = numel(smoothed);

step = tissue - background;

if ~isfinite(step) || step <= 0
    width = nSamples;
    return
end

low = background + 0.1 * step;
high = background + 0.9 * step;

start = min(max(round(index), 1), nSamples);

if direction == "reverse"
    towardTissue = -1;
else
    towardTissue = 1;
end

foot = walk(smoothed, start, -towardTissue, @(v) v <= low);
shoulder = walk(smoothed, start, towardTissue, @(v) v >= high);

width = abs(shoulder - foot);

end

function index = walk(smoothed, start, step, reached)
%WALK Step along the trace until a level is reached, or the end runs out.

nSamples = numel(smoothed);

index = start;

while index >= 1 && index <= nSamples
    if reached(smoothed(index))
        return
    end

    index = index + step;
end

index = min(max(index, 1), nSamples);

end

function [direction, message] = search_direction(smoothed, threshold, requested)
%SEARCH_DIRECTION Decide which end of the line is outside the brain.
% The line can be drawn either way round, and which end is background is a fact
% about the trace rather than a convention anybody remembers to follow, so it
% is read off the two ends instead of assumed.

message = "";

if requested ~= "auto"
    direction = requested;
    return
end

nEnd = max(1, round(0.1 * numel(smoothed)));

head = mean(smoothed(1:nEnd));
tail = mean(smoothed(end - nEnd + 1:end));

if head > threshold && tail > threshold
    direction = "";
    message = "The line begins and ends inside tissue, so neither end is background.";
    return
end

% With background at both ends the line spans the whole section. Forward is
% then the answer, because that is the end a line is conventionally drawn from
% and the mark is a starting point to be dragged rather than a verdict.
if head <= threshold
    direction = "forward";
    return
end

direction = "reverse";

end

function index = first_sustained_crossing(smoothed, threshold, direction, runLength)
%FIRST_SUSTAINED_CROSSING Walk in from the background end to the edge.
% The crossing is interpolated between the last sample below the threshold and
% the first one above it, and it only counts once the trace has stayed above
% for RUNLENGTH samples, so a bright speck sitting in the background is stepped
% over rather than marked as the surface.
%
% Reverse is handled by flipping the trace, searching forward, and mapping the
% index back, so there is one search rather than two that have to be kept in
% step with each other.

index = NaN;

nSamples = numel(smoothed);

if direction == "reverse"
    forwardIndex = first_sustained_crossing(flipud(smoothed(:)), threshold, ...
        "forward", runLength);

    if ~isnan(forwardIndex)
        index = nSamples + 1 - forwardIndex;
    end

    return
end

isTissue = smoothed(:) > threshold;

% Every sample from the first one on is already tissue, so there is no
% background stretch to cross out of.
if isTissue(1)
    return
end

for iSample = 2:nSamples
    if ~isTissue(iSample)
        continue
    end

    last = min(iSample + runLength - 1, nSamples);

    if ~all(isTissue(iSample:last))
        continue
    end

    below = smoothed(iSample - 1);
    above = smoothed(iSample);

    step = above - below;

    if step > 0
        index = (iSample - 1) + (threshold - below) / step;
    else
        index = iSample;
    end

    return
end

end
