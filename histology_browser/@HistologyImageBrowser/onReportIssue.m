function onReportIssue(obj, kind)
%ONREPORTISSUE Open a prefilled GitHub issue for a bug or a feature request.
% Nothing is posted from here. GitHub's new-issue page opens with the title and
% body already written, and the user still has to press the button on it.
%
% A bug report carries a description of the machine it was raised on, including
% the folders being worked in, so the body is shown for review and left
% editable rather than sent unseen. It also goes on the clipboard, because a
% long body does not survive a URL on every platform and pasting it is then the
% only way it gets there.
%
% Parameters
%   kind: "bug" or "feature".
%
% See also ISSUETEMPLATE, DIAGNOSTICSREPORT, BUILDHELPMENU.

arguments
    obj
    kind (1,1) string {mustBeMember(kind, ["bug", "feature"])}
end

[title, body] = obj.issueTemplate(kind);

body = review_report(obj, kind, body);

if ismissing(body)
    obj.setStatus("Issue report cancelled.");
    return
end

copied = copy_to_clipboard(body);

url = issue_url(title, body);

if strlength(url) > HistologyImageBrowser.MaxIssueUrlLength
    % Windows hands a URL to the browser through the shell, which truncates a
    % long one silently. Losing the body without saying so would be worse than
    % opening an empty form, so the form is opened empty and the clipboard is
    % named as the way the body gets there.
    url = issue_url(title, "");

    obj.openExternalLink(url, "the issue tracker");
    obj.setWarning("The report is too long for a link, so paste it from the clipboard into the issue.");

    return
end

if ~obj.openExternalLink(url, "the issue tracker")
    return
end

if copied
    obj.setSuccess("Opened a new %s issue. A copy of the report is on your clipboard.", kind);
    return
end

obj.setSuccess("Opened a new %s issue.", kind);

end

function body = review_report(obj, kind, body)
%REVIEW_REPORT Show what is about to be filled in, and let it be edited first.
% The bug body names the folders the user works in and the machine they work
% on, and the issue tracker is public, so the text is shown before the browser
% opens and anything unwanted can be deleted here. Returns a missing string
% when the user cancels.
%
% The dialog is a plain modal uifigure rather than a UICONFIRM because the body
% is long, has to scroll, and has to be editable, and UICONFIRM offers none of
% those.

body = string(body);

dlg = uifigure( ...
    Name = "New " + kind + " issue", ...
    Position = center_on(obj.Fig, [720 560]));

% A release that will not make a uifigure modal still shows the dialog; the
% wait below is what actually holds the caller either way.
try
    dlg.WindowStyle = "modal";
catch
end

grid = uigridlayout(dlg, [3 3]);
grid.RowHeight = {"fit", "1x", "fit"};
grid.ColumnWidth = {"1x", 120, 120};
grid.Padding = [10 10 10 10];

intro = uilabel(grid, Text = intro_text(kind), WordWrap = "on");
intro.Layout.Row = 1;
intro.Layout.Column = [1 3];

editor = uitextarea(grid, Value = splitlines(body));
editor.Layout.Row = 2;
editor.Layout.Column = [1 3];
editor.FontName = "Consolas";

% Cancel is what a closed window means, so the outcome is held here and the
% close request writes to it exactly as the button does.
outcome = struct(accepted = false, text = body);

cancelButton = uibutton(grid, "push", Text = "Cancel", ...
    ButtonPushedFcn = @(~,~) finish(false));
cancelButton.Layout.Row = 3;
cancelButton.Layout.Column = 2;

openButton = uibutton(grid, "push", Text = "Open Issue", ...
    ButtonPushedFcn = @(~,~) finish(true));
openButton.Layout.Row = 3;
openButton.Layout.Column = 3;

dlg.CloseRequestFcn = @(~,~) finish(false);

uiwait(dlg);

if ~outcome.accepted
    body = string(missing);
    return
end

body = outcome.text;

    function finish(accepted)
        %FINISH Record the choice and release the wait.

        outcome.accepted = accepted;

        if accepted
            outcome.text = strjoin(string(editor.Value(:)), newline);
        end

        delete(dlg);
    end

end

function text = intro_text(kind)
%INTRO_TEXT Say what the dialog is about to do, and what the body contains.

if kind == "bug"
    text = "This opens a new bug report on the histology_browser tracker, " + ...
        "prefilled with the text below. It describes your MATLAB " + ...
        "installation and the folders this session is working in. The " + ...
        "tracker is public, so edit anything out that should not be posted. " + ...
        "Nothing is submitted until you press the button on GitHub.";

    return
end

text = "This opens a new feature request on the histology_browser tracker, " + ...
    "prefilled with the text below. Nothing is submitted until you press " + ...
    "the button on GitHub.";

end

function position = center_on(parent, size)
%CENTER_ON Place a dialog over the window it belongs to.
% A dialog that opens on the primary monitor while the app sits on a second one
% is easy to miss entirely.

position = [100 100 size];

if isempty(parent) || ~isvalid(parent)
    return
end

anchor = parent.Position;
position(1:2) = anchor(1:2) + (anchor(3:4) - size) / 2;

end

function tf = copy_to_clipboard(text)
%COPY_TO_CLIPBOARD Put the report on the clipboard, reporting whether it stuck.
% The clipboard needs a desktop, which a session started with -nodisplay does
% not have, so failing to copy is an ordinary outcome rather than an error.

tf = false;

try
    clipboard("copy", char(text));
    tf = true;
catch
end

end

function url = issue_url(title, body)
%ISSUE_URL Build the new-issue link, with the fields GitHub prefills from.
% MATLAB.NET.URI is what escapes the body, so a report containing an ampersand
% or a newline cannot cut the link short.

base = HistologyImageBrowser.RepositoryURL + "/issues/new";

query = matlab.net.QueryParameter("title", title);

if strlength(body) > 0
    query(end + 1) = matlab.net.QueryParameter("body", body);
end

uri = matlab.net.URI(base);
uri.Query = query;

url = string(uri);

end
