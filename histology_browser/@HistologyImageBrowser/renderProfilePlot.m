function renderProfilePlot(obj)
%RENDERPROFILEPLOT Plot the profiles of the selected sections on shared axes.
% Tile colors are reused so a trace is easy to match to its image. A section
% carrying several ROIs contributes one trace each, all in the tile's color
% and told apart by stroke, so which section a trace came from and which
% region of it are two separate things to read rather than one guess.
%
% The traces are read in one pass and drawn in another, with NORMALIZEPROFILES
% between them, because a normalization measured over all traces cannot be
% applied to the first one until the last one has been read. Reading and
% drawing in a single loop was what this did before there was anything to
% measure across the plot.
%
% A section whose brain surface has been marked gets a dashed rule at that
% depth in its own trace's color, on the same switch as the tick the tiles
% carry. Under "From brain surface" every rule lands on zero and they draw as
% one, which is exactly what that alignment is claiming.
%
% See also ATTACHCONTEXTMENU, NORMALIZEPROFILES, RENDERSELECTION.

ax = obj.ProfileAxes;

% Plain cla plus an explicit legend removal, rather than "cla reset", so the
% grid layout keeps managing the axes position.
cla(ax);
legend(ax, "off");

grid(ax, "on");
box(ax, "on");

draw_profiles(obj, ax);

% Attached once, from the one place this function ends. The traces are drawn by
% a helper for exactly that reason: with the four early returns inline, every
% one of them would have had to remember to hand out the menu, and the path
% that plots nothing is the one most likely to be forgotten and the one where a
% right-click is most likely to be a request to change the layout.
obj.attachContextMenu(ax, "profile");

end

function draw_profiles(obj, ax)
%DRAW_PROFILES Plot one trace per ROI of each selected section, or say why
% there is none.

% Set before the early returns, so an empty plot is still labelled for the
% normalization in force rather than for whatever the last selection used.
N = obj.normalizeProfiles(struct([]), ...
    Normalization = obj.profileNorm(), ...
    Distance = obj.profileDistance(), ...
    Scope = obj.profileScope());

xlabel(ax, N.xLabel);
ylabel(ax, N.yLabel);

if ~obj.showProfile()
    return
end

rows = obj.selectedRows();

if isempty(rows) || height(rows) == 0
    return
end

nDrawn = min(height(rows), max(1, round(obj.MaxTilesField.Value)));

% The same colors the tiles are framed and titled in, from the same place, so
% a trace can be matched to its picture without counting positions.
colors = HistologyImageBrowser.tileColors(nDrawn);

[traces, missingLabels] = read_traces(obj, rows, nDrawn);

if isempty(traces)
    text(ax, 0.5, 0.5, no_profile_message(missingLabels), ...
        Units = "normalized", ...
        HorizontalAlignment = "center", ...
        Interpreter = "none", ...
        Color = [0.4 0.4 0.4]);
    return
end

N = obj.normalizeProfiles(traces, ...
    Normalization = obj.profileNorm(), ...
    Distance = obj.profileDistance(), ...
    Scope = obj.profileScope());

xlabel(ax, N.xLabel);
ylabel(ax, N.yLabel);

% One stroke per ROI of a section, in the order the section lists them, so the
% same region draws the same way on every section that has it. The color stays
% the section's, so the two readings do not compete for it.
strokes = ["-", "--", ":", "-."];

hold(ax, "on");

traceLines = gobjects(numel(N.profiles), 1);

for iTrace = 1:numel(N.profiles)
    stroke = strokes(mod(N.profiles(iTrace).strokeIndex - 1, numel(strokes)) + 1);

    traceLines(iTrace) = plot(ax, N.profiles(iTrace).distance, N.profiles(iTrace).intensity, ...
        LineWidth = 1.25, ...
        LineStyle = stroke, ...
        Color = colors(N.profiles(iTrace).colorIndex, :), ...
        DisplayName = N.profiles(iTrace).label);
end

% Drawn after the traces so a rule sits over the curve it belongs to.
if obj.ShowSurfaceCheck.Value
    draw_surface_rules(ax, N.profiles, colors);
end

hold(ax, "off");

axis(ax, "tight");

% The traces are named rather than the axes being asked what is on it, so the
% surface rules cannot end up in a legend that is meant to name sections: a
% second entry per section would double a twelve-trace legend to say nothing.
if numel(N.profiles) <= 12
    legend(ax, traceLines, Interpreter = "none", Location = "best", Box = "off");
end

% With a mixed selection the plotted traces alone would not reveal that some
% sections contributed nothing, or that some of them are sitting on their line
% start because no surface was ever marked on them, so both are stated on the
% axes rather than left to be inferred from a plot that looks complete.
lines = notes(missingLabels, N);

if ~isempty(lines)
    text(ax, 0.99, 0.99, join(lines, "; "), ...
        Units = "normalized", ...
        HorizontalAlignment = "right", ...
        VerticalAlignment = "top", ...
        Interpreter = "none", ...
        FontSize = 8, ...
        Color = [0.4 0.4 0.4]);
end

end

function lines = notes(missingLabels, N)
%NOTES Collect what the plot has to say about what is not on it.

lines = strings(0, 1);

if ~isempty(missingLabels)
    lines(end + 1, 1) = missing_note(missingLabels);
end

% Only under the alignment that needed a mark. Under every other distance
% mapping an unmarked section is not missing anything.
if N.distance == "surface" && N.nUnmarked > 0
    lines(end + 1, 1) = sprintf("%d trace(s) not surface-marked, shown from the line start", ...
        N.nUnmarked);
end

end

function draw_surface_rules(ax, profiles, colors)
%DRAW_SURFACE_RULES Rule each trace at the depth its brain surface was marked.
% XLINE rather than a plotted pair of points, so the rule spans whatever the
% intensity axis turns out to be after the normalization has had it, and so it
% keeps spanning it if the axis is later zoomed.

for iProfile = 1:numel(profiles)
    surface = profiles(iProfile).surface;

    if ~isscalar(surface) || ~isfinite(surface)
        continue
    end

    xline(ax, surface, ...
        LineStyle = "--", ...
        LineWidth = 1, ...
        Color = colors(profiles(iProfile).colorIndex, :), ...
        Alpha = 0.9);
end

end

function [traces, missingLabels] = read_traces(obj, rows, nDrawn)
%READ_TRACES Collect the profiles that have data, and name the ones that do not.
% Each trace carries the color index, the stroke index, and the legend entry it
% earns, so the drawing pass never has to look at the catalog again -- which
% matters because NORMALIZEPROFILES returns a copy, and a copy that had to be
% lined back up against the rows by position would break the moment a row
% contributed nothing. With several ROIs to a section there is no one trace per
% row to line up against in the first place.

% Declared with its fields rather than as a bare empty struct, so the first
% append lands in an array that already has the shape it is growing.
traces = struct(distance = {}, intensity = {}, surface = {}, ...
    colorIndex = {}, strokeIndex = {}, label = {});
missingLabels = strings(0, 1);

for iRow = 1:nDrawn
    row = rows(iRow, :);
    keys = obj.roiKeysForRow(row);

    % A section with no ROI at all is named once, by itself: there is no key to
    % report it under, and listing it per missing ROI would report nothing.
    if isempty(keys)
        missingLabels(end + 1) = section_label(row); %#ok<AGROW>
        continue
    end

    for iKey = 1:numel(keys)
        P = obj.readProfile(row, keys(iKey));

        if ~P.hasData
            missingLabels(end + 1) = trace_label(obj, row, keys, keys(iKey)); %#ok<AGROW>
            continue
        end

        % The surface rides along on the trace rather than being looked up
        % again at drawing time, for the same reason the color, the stroke, and
        % the label do: NORMALIZEPROFILES returns a copy, and anything that had
        % to be lined back up against the rows by position would break the
        % moment a row contributed nothing. It is per ROI, not per section:
        % each line crosses the surface at its own depth.
        traces(end + 1, 1) = struct( ...
            distance = double(P.distance(:)), ...
            intensity = double(P.intensity(:)), ...
            surface = double(P.surface), ...
            colorIndex = iRow, ...
            strokeIndex = iKey, ...
            label = trace_label(obj, row, keys, keys(iKey))); %#ok<AGROW>
    end
end

end

function note = missing_note(missingLabels)
%MISSING_NOTE Name the omitted profiles, abbreviating a long list.

if numel(missingLabels) > 3
    note = sprintf("No profile: %s and %d more", ...
        join(missingLabels(1:3), ", "), numel(missingLabels) - 3);
    return
end

note = "No profile: " + join(missingLabels, ", ");

end

function message = no_profile_message(missingLabels)
%NO_PROFILE_MESSAGE Name the sections that had nothing to plot.

if isempty(missingLabels)
    message = "No profile data for the current selection.";
    return
end

if numel(missingLabels) <= 4
    message = "No profile data for " + join(missingLabels, ", ") + ".";
    return
end

message = sprintf("No profile data for the %d selected sections.", numel(missingLabels));

end

function label = section_label(row)
%SECTION_LABEL Identify one section compactly enough for an axes annotation.

subject = replace(string(row.SubjectID), "SUBJ-ID-", "");

if subject == ""
    label = string(row.Stem);
    return
end

label = subject + " " + row.SectionID + " " + row.Hemisphere;

end

function label = trace_label(obj, row, keys, key)
%TRACE_LABEL Build a concise legend entry for one ROI of one section.
% The ROI is named only when naming it says something. A section with a single
% ROI still called by the letter it was filed under would otherwise add "(A)"
% to every entry in the legend while distinguishing nothing; a key that is a
% region's own name always earns its place, and so does any ROI on a section
% that has more than one.

label = section_label(row);

name = obj.roiName(key);

if isscalar(keys) && name == key && strlength(key) == 1
    return
end

label = label + " (" + name + ")";

end
