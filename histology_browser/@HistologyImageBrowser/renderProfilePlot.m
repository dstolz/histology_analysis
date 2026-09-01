function renderProfilePlot(obj)
%RENDERPROFILEPLOT Plot the profiles of the selected sections on shared axes.
% Tile colors are reused so a trace is easy to match to its image. A section
% carrying several ROIs contributes one trace each, all in the tile's color
% and told apart by stroke, so which section a trace came from and which
% region of it are two separate things to read rather than one guess.

ax = obj.ProfileAxes;

% Plain cla plus an explicit legend removal, rather than "cla reset", so the
% grid layout keeps managing the axes position.
cla(ax);
legend(ax, "off");

xlabel(ax, "distance along line (\mum)");
ylabel(ax, "intensity");
grid(ax, "on");
box(ax, "on");

if ~obj.showProfile()
    return
end

rows = obj.selectedRows();

if isempty(rows) || height(rows) == 0
    return
end

nDrawn = min(height(rows), max(1, round(obj.MaxTilesField.Value)));

if nDrawn <= 7
    colors = lines(nDrawn);
else
    colors = turbo(nDrawn);
end

% One stroke per ROI of a section, in the order the section lists them, so the
% same region draws the same way on every section that has it.
strokes = ["-", "--", ":", "-."];

hold(ax, "on");

nPlotted = 0;
missingLabels = strings(0, 1);

for iRow = 1:nDrawn
    row = rows(iRow, :);
    keys = obj.roiKeysForRow(row);

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

        plot(ax, P.distance, P.intensity, ...
            LineWidth = 1.25, ...
            LineStyle = strokes(mod(iKey - 1, numel(strokes)) + 1), ...
            Color = colors(iRow, :), ...
            DisplayName = trace_label(obj, row, keys, keys(iKey)));

        nPlotted = nPlotted + 1;
    end
end

hold(ax, "off");

if nPlotted == 0
    text(ax, 0.5, 0.5, no_profile_message(missingLabels), ...
        Units = "normalized", ...
        HorizontalAlignment = "center", ...
        Interpreter = "none", ...
        Color = [0.4 0.4 0.4]);
    return
end

axis(ax, "tight");

if nPlotted <= 12
    legend(ax, Interpreter = "none", Location = "best", Box = "off");
end

% With a mixed selection the plotted traces alone would not reveal that some
% sections contributed nothing, so the omission is stated on the axes.
if ~isempty(missingLabels)
    text(ax, 0.99, 0.99, missing_note(missingLabels), ...
        Units = "normalized", ...
        HorizontalAlignment = "right", ...
        VerticalAlignment = "top", ...
        Interpreter = "none", ...
        FontSize = 8, ...
        Color = [0.4 0.4 0.4]);
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
