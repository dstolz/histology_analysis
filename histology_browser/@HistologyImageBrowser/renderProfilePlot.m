function renderProfilePlot(obj)
%RENDERPROFILEPLOT Plot the profiles of the selected sections on shared axes.
% Tile colors are reused so a trace is easy to match to its image.
%
% See also ATTACHCONTEXTMENU, RENDERSELECTION.

ax = obj.ProfileAxes;

% Plain cla plus an explicit legend removal, rather than "cla reset", so the
% grid layout keeps managing the axes position.
cla(ax);
legend(ax, "off");

xlabel(ax, "distance along line (\mum)");
ylabel(ax, "intensity");
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
%DRAW_PROFILES Plot one trace per selected section, or say why there is none.

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

hold(ax, "on");

nPlotted = 0;
missingLabels = strings(0, 1);

for iRow = 1:nDrawn
    P = obj.readProfile(rows(iRow, :));

    if ~P.hasData
        missingLabels(end + 1) = section_label(rows(iRow, :)); %#ok<AGROW>
        continue
    end

    plot(ax, P.distance, P.intensity, ...
        LineWidth = 1.25, ...
        Color = colors(iRow, :), ...
        DisplayName = trace_label(rows(iRow, :), P));

    nPlotted = nPlotted + 1;
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
%MISSING_NOTE Name the omitted sections, abbreviating a long list.

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

function label = trace_label(row, P)
%TRACE_LABEL Build a concise legend entry for one profile.

label = section_label(row);

if P.roiLabel ~= ""
    label = label + " (" + P.roiLabel + ")";
end

end
