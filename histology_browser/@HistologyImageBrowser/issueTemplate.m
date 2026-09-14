function [title, body] = issueTemplate(obj, kind)
%ISSUETEMPLATE Compose the title and body of a new issue of one kind.
% Kept apart from ONREPORTISSUE so what the report says can be read, and
% tested, without a dialog opening. The headings match the ones already used on
% the tracker, and the title prefixes match the ones already in its list, so a
% report raised from the app files alongside the reports raised by hand.
%
% Only a bug carries the diagnostics block. A feature request is about what the
% app should do rather than about the machine it is running on, and a wall of
% environment detail on one would only bury the idea.
%
% Parameters
%   kind: "bug" or "feature".
%
% Returns
%   title: Prefilled issue title, ending in the space the user types after.
%   body: Prefilled issue body, in GitHub-flavored Markdown.
%
% See also ONREPORTISSUE, DIAGNOSTICSREPORT, BUILDHELPMENU.

arguments
    obj
    kind (1,1) string {mustBeMember(kind, ["bug", "feature"])}
end

if kind == "feature"
    title = "[feature] ";
    body = strjoin([ ...
        "### What should it do"; ""; ""; ...
        "### Why it would help"; ""; ""; ...
        "### How you work around it today"; ""; ""], newline);

    return
end

title = "[Bug] ";

body = strjoin([ ...
    "### What happened"; ""; ""; ...
    "### What you expected instead"; ""; ""; ...
    "### Steps to reproduce"; ""; ...
    "1. "; "2. "; "3. "; ""; ...
    "### Environment"; ""; ...
    "<details><summary>Collected automatically</summary>"; ""; ...
    "```text"; ...
    obj.diagnosticsReport(); ...
    "```"; ""; ...
    "</details>"; ""], newline);

end
