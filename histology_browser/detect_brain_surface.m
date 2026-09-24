function S = detect_brain_surface(distance, intensity, options)
% detect_brain_surface
%   S = detect_brain_surface(distance, intensity)
%   S = detect_brain_surface(P.distance, P.intensity, Background = image_background(img))
%   S = detect_brain_surface(P.distance, P.intensity, Direction = "forward")
%
% Find where a line profile crosses from background into tissue, so a line ROI
% drawn across a section can be given the depth its brain surface sits at
% without that point having to be clicked on every section by hand.
%
% The profile is the mean intensity across the band at one sample per pixel of
% line length. For a line started off the section it is flat at the slide's
% level, climbs sharply where the band reaches the pia -- often to a bright rim
% that dips again below it -- and then rises slowly through the cortical layers
% to the bright ones in the middle. The surface is the sharp climb, not the
% slow one, and the two are told apart by what they are measured against.
%
% Background is the slide, which is the darkest part of the image, so the
% caller reads it off the image with IMAGE_BACKGROUND and passes it in. Tissue
% is the bright end of the profile. The trace is walked in from whichever end
% sits at background until it rises a small fraction of the way from one to the
% other and stays there, which is the pia arriving rather than the layers
% brightening. The mark goes halfway up that climb -- halfway to the top of the
% rim just inside it, not to the bright layers far beyond -- interpolated
% between the two samples that straddle the level, so it is not quantized to
% whole samples.
%
% A threshold split between the profile's two levels, which is what this used
% to do, puts the mark on the slow rise instead: layer 1 is dim, the split
% falls between it and the bright layers, and the mark lands a couple of
% hundred pixels inside the brain.
%
% Without a background from the caller it is taken from the darkest samples of
% the profile itself. That is right for a line that starts off the section and
% wrong for one that does not, which is why the image's is preferred: measured
% against the slide, a line that never leaves tissue never comes down to
% background at either end, and is refused for it.
%
% A climb has to be steep to be believed. A line that lies inside tissue and
% merely dims with depth rises too, slowly, and a mark in the middle of that
% gradient would look exactly like one on a real surface to everything
% downstream. So the steepest step of the climb has to be one that would cover
% the whole background-to-tissue range within MaxTransition of the profile.
% Nothing is ever asserted -- a line with no background, one that only slopes,
% and one that never leaves background all come back with found false and a
% message saying which, because a surface guessed off a trace with no edge in
% it would be worse than no surface at all.
%
% Parameters
%   distance: Distance of each sample along the line, as MEASURE_LINE_PROFILE
%       returns it. Only its scale matters; it need not start at zero.
%   intensity: Mean band intensity at each sample.
%   options.Background: Intensity of the slide, in the same units, from
%       IMAGE_BACKGROUND. NaN reads it off the darkest samples of the profile.
%   options.Direction: Which end of the line is outside the brain. "auto" reads
%       it off the two ends, which is right whichever way the line was drawn.
%       "forward" searches from the first sample, "reverse" from the last.
%   options.Smoothing: Width of the moving average, as a fraction of the
%       profile length. Enough to bridge the noise on a single sample; any more
%       spreads the climb and pulls the mark out toward the background.
%   options.EntryFraction: How far from background toward tissue the trace has
%       to rise to count as having left the background.
%   options.MinRun: How far past the entry the trace must stay above it, as a
%       fraction of the profile length, before the entry is accepted. This is
%       what keeps a speck of debris in the background from taking the mark.
%   options.EdgeWindow: How far past the entry the top of the climb is looked
%       for, as a fraction of the profile length. About the width of the rim at
%       the pia; much more and the slow rise through the layers is taken for
%       part of the edge.
%   options.MinContrast: Height of the climb, in noise sigmas, below which the
%       answer is reported as low confidence.
%   options.MaxTransition: How much of the profile the whole background-to-
%       tissue range may take to cover at the climb's steepest, as a fraction of
%       its length, before the climb is called a gradient rather than an edge
%       and refused.
%
% Returns
%   S: Struct with fields
%      - found: True when a crossing was located.
%      - distance: Distance of the crossing, in the units given.
%      - index: Fractional 1-based sample index of the crossing.
%      - fraction: Where the crossing sits along the sampled span, 0 to 1.
%      - direction: End the search actually ran from.
%      - background: Slide level the profile was measured against.
%      - backgroundSource: "caller" when it was passed in, "profile" when it
%        was read off the trace.
%      - tissue: Bright end of the profile.
%      - threshold: Level the trace had to rise past to leave the background.
%      - edge: Top of the climb at the surface, which the mark is halfway to.
%      - noise, contrast: Sample noise, and the height of the climb in units of
%        it.
%      - transition: Samples the whole background-to-tissue range would take
%        to cover at the climb's steepest. Small for an edge, large for a
%        gradient.
%      - confidence: "high" or "low"; see MinContrast.
%      - message: Empty on success, otherwise why nothing was marked.
%
% See also IMAGE_BACKGROUND, MEASURE_LINE_PROFILE, READ_SURFACE_MARK,
% WRITE_SURFACE_MARK.

arguments
    distance (:,1) double
    intensity (:,1) double
    options.Background (1,1) double = NaN
    options.Direction (1,1) string {mustBeMember(options.Direction, ...
        ["auto", "forward", "reverse"])} = "auto"
    options.Smoothing (1,1) double {mustBeInRange(options.Smoothing, 0, 0.5)} = 0.005
    options.EntryFraction (1,1) double {mustBeInRange(options.EntryFraction, 0, 1, ...
        "exclude-lower")} = 0.05
    options.MinRun (1,1) double {mustBeInRange(options.MinRun, 0, 0.5)} = 0.02
    options.EdgeWindow (1,1) double {mustBeInRange(options.EdgeWindow, 0, 0.5)} = 0.03
    options.MinContrast (1,1) double {mustBeNonnegative} = 3
    options.MaxTransition (1,1) double {mustBeInRange(options.MaxTransition, 0, 1)} = 0.5
end

S = struct( ...
    "found", false, ...
    "distance", NaN, ...
    "index", NaN, ...
    "fraction", NaN, ...
    "direction", "", ...
    "background", NaN, ...
    "backgroundSource", "", ...
    "tissue", NaN, ...
    "threshold", NaN, ...
    "edge", NaN, ...
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

if isfinite(options.Background)
    S.background = options.Background;
    S.backgroundSource = "caller";
else
    S.background = profile_floor(smoothed);
    S.backgroundSource = "profile";
end

S.tissue = upper_level(smoothed);

% Taken off the residual the smoothing removed rather than off the raw trace,
% so the layers a cortical profile is made of do not read as noise. Scaled by
% the usual constant that turns a median absolute deviation into a sigma.
S.noise = 1.4826 * median(abs(intensity - smoothed));

range = S.tissue - S.background;

if ~(range > 0)
    S.message = "The profile never rises above the background, so it has no edge to mark.";
    return
end

% A fraction of the range, so the entry scales with the stain, but never inside
% the noise, so a ripple on the slide cannot take it.
S.threshold = S.background + max(options.EntryFraction * range, ...
    options.MinContrast * S.noise);

if ~any(smoothed > S.threshold)
    S.message = "The profile never rises clear of the background, so it has no edge to mark.";
    return
end

[S.direction, message] = search_direction(smoothed, S.threshold, options.Direction);

if S.direction == ""
    S.message = message;
    return
end

% Everything past here walks forward from the background end. A reverse search
% flips the trace once and maps the answer back at the end, so there is one
% walk rather than two that have to be kept in step with each other.
if S.direction == "reverse"
    trace = flipud(smoothed);
else
    trace = smoothed;
end

runLength = max(2, round(options.MinRun * nSamples));

entry = first_sustained_entry(trace, S.threshold, runLength);

if isnan(entry)
    S.message = "The profile rises out of background but never stays out of it.";
    return
end

window = max(2, round(options.EdgeWindow * nSamples));

[S.edge, peak] = max(trace(entry:min(entry + window, nSamples)));
peak = entry + peak - 1;

% The steepest step on the way up, from the last background sample to the top
% of the rim. An edge takes it in a few samples; a gradient is still climbing
% the same slow slope it was at the entry.
S.transition = range / max(max(diff(trace(entry - 1:peak))), eps);

if S.transition > options.MaxTransition * nSamples
    S.message = "The profile slopes rather than stepping, so it has no edge to mark.";
    return
end

% Halfway up the climb, but never below the entry: a rim barely above it would
% otherwise put the half level back in the background the walk came out of.
level = max(S.background + 0.5 * (S.edge - S.background), S.threshold);

index = last_upward_crossing(trace, level, entry - 1, peak);

if S.direction == "reverse"
    index = nSamples + 1 - index;
end

S.index = index;
S.fraction = (index - 1) / (nSamples - 1);
S.distance = interp1(1:nSamples, distance, index);

S.contrast = (S.edge - S.background) / max(S.noise, eps);

% Reported rather than refused. A weak step is still the best estimate the
% trace supports, and the caller is a window with a marker the user can drag;
% saying so and letting it be corrected beats withholding a starting point.
if S.contrast >= options.MinContrast
    S.confidence = "high";
else
    S.confidence = "low";
    S.message = sprintf("The step at the surface is only %.1f noise sigmas high.", ...
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

function level = profile_floor(smoothed)
%PROFILE_FLOOR The background a trace shows by itself, for want of an image.
% The median of its darkest twentieth: low enough to be the slide the line
% started on, wide enough that one dark sample does not set it.

sorted = sort(smoothed);
level = median(sorted(1:max(1, ceil(0.05 * numel(sorted)))));

end

function level = upper_level(smoothed)
%UPPER_LEVEL The bright end of the trace, short of its brightest few samples.
% The 99th percentile, taken by sorting rather than from PRCTILE, which is in
% the Statistics Toolbox this file otherwise has no need of.

sorted = sort(smoothed);
level = sorted(max(1, ceil(0.99 * numel(sorted))));

end

function [direction, message] = search_direction(smoothed, threshold, requested)
%SEARCH_DIRECTION Decide which end of the line is outside the brain.
% The line can be drawn either way round, and which end is background is a fact
% about the trace rather than a convention anybody remembers to follow, so it
% is read off the two ends instead of assumed.
%
% An end is background when the trace comes down to background somewhere near
% it, not on average over it. A line is usually started only just off the
% section, so the stretch of slide at its end can be a few dozen samples; the
% rim of tissue after it would lift an average over the tenth of the line
% looked at above a threshold set this close to the slide.

message = "";

if requested ~= "auto"
    direction = requested;
    return
end

nEnd = max(1, round(0.1 * numel(smoothed)));

head = min(smoothed(1:nEnd));
tail = min(smoothed(end - nEnd + 1:end));

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

function entry = first_sustained_entry(trace, threshold, runLength)
%FIRST_SUSTAINED_ENTRY First sample above the threshold that has background
% before it and stays above for RUNLENGTH samples.
% The staying is what steps over a bright speck sitting on the slide, including
% one the line happens to start on. A trace that never comes down to
% background has nothing to come out of, and returns NaN, as does one that
% never stays up.

entry = NaN;

nSamples = numel(trace);

isAbove = trace(:) > threshold;

for iSample = 2:nSamples
    if ~isAbove(iSample) || isAbove(iSample - 1)
        continue
    end

    last = min(iSample + runLength - 1, nSamples);

    if all(isAbove(iSample:last))
        entry = iSample;
        return
    end
end

end

function index = last_upward_crossing(trace, level, first, last)
%LAST_UPWARD_CROSSING Where the trace last comes up through LEVEL before LAST.
% Walked back from the top of the climb, so a speck that pokes above the level
% and drops back before the climb proper is passed over rather than taken. The
% crossing is interpolated between the samples either side of it. FIRST is a
% sample known to sit at or below the level, which bounds the walk.

index = last;

while index > first && trace(index - 1) >= level
    index = index - 1;
end

if index <= first
    index = first;
    return
end

below = trace(index - 1);
above = trace(index);

index = (index - 1) + (level - below) / (above - below);

end
