function text = diagnosticsReport(obj)
%DIAGNOSTICSREPORT Describe the build, the machine, and the settings in use.
% A bug report that says only what went wrong is rarely enough to reproduce it.
% Which commit is checked out, which MATLAB release is running, whether the
% Image Processing Toolbox is installed, and what the display settings were all
% change what this app does, and nobody types a commit hash from memory. So the
% report is assembled here and ONREPORTISSUE drops it into the issue body.
%
% Everything is gathered defensively: a missing git, a source tree that is not
% a repository, or a preference group that was never written must each produce
% a report saying so rather than an error in place of the report.
%
% Returns
%   text: Multi-line string, ready to drop into an issue body.
%
% See also ONREPORTISSUE, BUILDHELPMENU, HISTOLOGY_CODE_VERSION.

lines = strings(0, 1);

% Asked afresh rather than taken from the minute-long cache: a report is
% written once, and the edit that caused the bug may be seconds old. The
% checkout is histology_analysis as a whole, so only edits to the browser's
% own folder count; work elsewhere in the repository says nothing about a bug.
code = histology_code_version(Scope = "browser", Refresh = true);

lines = section(lines, "App", [ ...
    "commit", code.Text; ...
    "source", HistologyImageBrowser.repositoryRoot()]);

lines = section(lines, "MATLAB", [ ...
    "release", code.MatlabRelease; ...
    "platform", string(computer("arch")); ...
    "image toolbox", toolbox_state()]);

lines = section(lines, "Display", [ ...
    "screen", screen_description(); ...
    "window", window_description(obj)]);

lines = section(lines, "Dataset", dataset_facts(obj));

lines = section(lines, "Settings", preference_facts(obj));

lines = [lines; "Recent status messages"; status_lines(obj)];

text = strjoin(lines, newline);

end

function lines = section(lines, heading, facts)
%SECTION Append one headed block of name/value pairs.
% The names are padded to a common width so the block stays readable in the
% fixed-width code fence the report puts it in.

if isempty(lines)
    lines = strings(0, 1);
else
    lines(end + 1, 1) = "";
end

lines(end + 1, 1) = heading;

if isempty(facts)
    lines(end + 1, 1) = "  (nothing to report)";
    return
end

names = facts(:, 1);
values = facts(:, 2);
width = max(strlength(names));

for iFact = 1:numel(names)
    lines(end + 1, 1) = "  " + pad(names(iFact), width) + " : " + values(iFact); %#ok<AGROW>
end

end

function text = toolbox_state()
%TOOLBOX_STATE Say whether ROI editing is available on this installation.
% Editing needs images.roi.Line, so the class rather than the license is what
% settles it; a licensed but uninstalled toolbox would still refuse the edit.

if exist("images.roi.Line", "class") == 8
    text = "installed";
    return
end

text = "not installed (ROI editing is unavailable)";

end

function text = screen_description()
%SCREEN_DESCRIPTION Report every attached monitor, since layout bugs depend on it.

try
    monitors = get(groot, "MonitorPositions");
catch
    text = "unknown";
    return
end

parts = strings(size(monitors, 1), 1);

for iMonitor = 1:size(monitors, 1)
    parts(iMonitor) = sprintf("%gx%g at (%g,%g)", monitors(iMonitor, [3 4 1 2]));
end

text = strjoin(parts, ", ");

end

function text = window_description(obj)
%WINDOW_DESCRIPTION Report the window size and which panels are collapsed.

if isempty(obj.Fig) || ~isvalid(obj.Fig)
    text = "no window";
    return
end

text = sprintf("%gx%g, %s", obj.Fig.Position(3), obj.Fig.Position(4), obj.Fig.WindowState);

hidden = strings(0, 1);

if obj.DataColumnHidden
    hidden(end + 1, 1) = "data column";
end

if obj.DisplayRowHidden
    hidden(end + 1, 1) = "display row";
end

if ~isempty(hidden)
    text = text + ", hidden: " + strjoin(hidden, " and ");
end

end

function facts = dataset_facts(obj)
%DATASET_FACTS Summarize what is loaded, without naming the images themselves.
% The row counts and the failure states are what a report needs; the file names
% are the user's data and would only make the block long.

facts = [ ...
    "root folder", quoted(obj.RootPath); ...
    "tracker CSV", quoted(obj.MetadataPath); ...
    "catalog rows", string(height(obj.Catalog)); ...
    "rows in view", string(height(obj.View)); ...
    "rows selected", string(numel(obj.Selection))];

if height(obj.Catalog) == 0
    return
end

unparsed = sum(~obj.Catalog.NameParsed);
noImage = sum(obj.Catalog.Status == "no image");

facts = [facts; ...
    "unparsed names", string(unparsed); ...
    "rows with no image", string(noImage)];

end

function facts = preference_facts(obj)
%PREFERENCE_FACTS List the saved settings, which is what "settings" means here.
% Read from the preference group rather than from the controls, so a report
% made before the window is fully built still says what the app will do.

facts = strings(0, 2);

group = char(obj.PrefGroup);

if ~ispref(group)
    return
end

try
    P = getpref(group);
catch
    return
end

names = string(fieldnames(P));

for iName = 1:numel(names)
    facts(end + 1, :) = [names(iName), describe_setting(names(iName), P.(names(iName)))]; %#ok<AGROW>
end

end

function text = describe_setting(name, value)
%DESCRIBE_SETTING Render one preference, withholding anything that reads as a
% secret. The report goes onto a public tracker, and the preference group is
% shared with whatever else has ever written to it, so a stored token must not
% ride along just because it happened to be saved under the same group. The
% name is reported either way, because knowing a credential is set is itself a
% fact a bug report may turn on.

if contains(name, ["credential", "password", "secret", "token", "apikey"], ...
        IgnoreCase = true)
    text = withheld(value);
    return
end

text = describe_value(value);

end

function text = withheld(value)
%WITHHELD Say whether a secret is set without saying what it is.

if isempty(value) || (isscalar(string(value)) && strlength(string(value)) == 0)
    text = "(none)";
    return
end

text = "(set, withheld)";

end

function text = describe_value(value)
%DESCRIBE_VALUE Render one preference compactly, whatever type it holds.
% Char and cell forms are handled beside string because preferences outlive the
% code that wrote them: a group written by an older release still holds the
% types that release used, and indexing one of those as a string array would
% report a path one character per line.

if ischar(value)
    % A char matrix becomes one string per row; a char row vector, one string.
    value = string(value);
end

if iscell(value)
    try
        value = string(value);
    catch
        text = "<cell>";
        return
    end
end

if isstring(value)
    text = quoted(strjoin(value(:)', ", "));
    return
end

if islogical(value) || isnumeric(value)
    text = strjoin(compose("%g", double(value(:))'), " ");

    if text == ""
        text = "(empty)";
    end

    return
end

text = "<" + string(class(value)) + ">";

end

function lines = status_lines(obj)
%STATUS_LINES Include the status bar history, which is the app's own log.
% Whatever the app already said about the failure is usually the most useful
% sentence in the whole report, and it is otherwise lost when the window
% closes.

if isempty(obj.StatusHistory)
    lines = "  (none)";
    return
end

lines = "  " + flipud(obj.StatusHistory(:));

end

function text = quoted(value)
%QUOTED Show a path or a blank in a way that cannot be read as missing text.

value = string(value);

if strlength(value) == 0
    text = "(none)";
    return
end

text = value;

end
