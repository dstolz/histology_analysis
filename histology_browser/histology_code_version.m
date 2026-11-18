function info = histology_code_version(options)
%HISTOLOGY_CODE_VERSION Which code is running: the commit, its state, and MATLAB.
%   info = histology_code_version()
%   info = histology_code_version(Scope = "browser")
%   info = histology_code_version(Refresh = true)
%
% A result is only as reproducible as the code that made it is identifiable,
% and nobody types a commit hash from memory. This names the checked out
% commit, the branch, and whether the working tree has been edited since, for
% a bug report (diagnosticsReport) and for the provenance record an analysis
% run writes beside its outputs.
%
% Everything is gathered defensively: a missing git or a source tree that is
% not a repository gives a version of "unknown", never an error.
%
% Answers are kept for 60 seconds, because asking git costs a few hundred
% milliseconds and a save from the browser can happen many times a minute.
%
% Parameters
%   options.Scope: "repo" (default) counts edits anywhere in the repository as
%       uncommitted changes; "browser" counts only edits to histology_browser,
%       which is what a bug report about the browser cares about.
%   options.Refresh: Ask git again even when a recent answer is kept.
%
% Returns
%   info: Struct with fields
%       Commit        short hash, or "" when unknown
%       Branch        branch name, or "" (detached, or unknown)
%       Dirty         true when the scope has uncommitted changes
%       Version       Commit, with "-dirty" appended when Dirty; "unknown"
%                     when there is no commit
%       Text          the commit described for a person, e.g.
%                     "4301a33 on main (with uncommitted changes)"
%       MatlabRelease e.g. "R2025a Update 3"
%       Root          the folder git was asked about
%       Scope         the scope asked for
%
% See also DIAGNOSTICSREPORT.

arguments
    options.Scope (1,1) string {mustBeMember(options.Scope, ["repo", "browser"])} = "repo"
    options.Refresh (1,1) logical = false
end

persistent cache

if isempty(cache)
    cache = struct("repo", [], "browser", []);
end

kept = cache.(options.Scope);

if ~options.Refresh && ~isempty(kept) && seconds(datetime("now") - kept.At) < 60
    info = kept.Info;
    return
end

browserRoot = string(fileparts(mfilename("fullpath")));

if options.Scope == "browser"
    root = browserRoot;
else
    root = string(fileparts(browserRoot));
end

info = struct( ...
    "Commit", "", ...
    "Branch", "", ...
    "Dirty", false, ...
    "Version", "unknown", ...
    "Text", "unknown (not a git checkout, or git is not installed)", ...
    "MatlabRelease", matlab_release(), ...
    "Root", root, ...
    "Scope", options.Scope);

hash = git_output(root, "rev-parse --short HEAD");

if hash ~= ""
    info.Commit = hash;
    info.Text = hash;

    branch = git_output(root, "rev-parse --abbrev-ref HEAD");

    if branch ~= "" && branch ~= "HEAD"
        info.Branch = branch;
        info.Text = info.Text + " on " + branch;
    end

    % A hash alone would be misleading on a working tree with uncommitted
    % changes, which is exactly the state a bug is most likely to be found in
    % and the state most exploratory analyses are run from. "-- ." limits the
    % question to the scope's folder.
    info.Dirty = git_output(root, "status --porcelain -- .") ~= "";

    info.Version = hash;

    if info.Dirty
        info.Version = hash + "-dirty";
        info.Text = info.Text + " (with uncommitted changes)";
    end
end

cache.(options.Scope) = struct("At", datetime("now"), "Info", info);

end

function out = git_output(root, arguments)
%GIT_OUTPUT Run one git command in the source tree, or return "" on any failure.

out = "";

try
    [status, raw] = system(sprintf('git -C "%s" %s', root, arguments));
catch
    return
end

if status ~= 0
    return
end

out = strtrim(string(raw));

end

function text = matlab_release()
%MATLAB_RELEASE Name the release, falling back to the version string.

try
    R = matlabRelease;
    text = string(R.Release) + " " + string(R.Update);
catch
    text = string(version);
end

end
