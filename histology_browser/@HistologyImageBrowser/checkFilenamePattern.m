function [tf, message] = checkFilenamePattern(pattern)
%CHECKFILENAMEPATTERN Report whether a filename pattern is usable, and why not.
% The one place a candidate pattern is judged, so the dialog that offers it,
% the method that adopts it, and the preference load that restores it all agree
% on what "usable" means. A pattern is text a user wrote, and there are two
% ways for it to be text that cannot do the job: it can be malformed, and it
% can be well formed while naming no tokens, which matches filenames without
% extracting anything. Both are caught here rather than where they would
% otherwise be noticed, which is a catalog full of blank columns.
%
% MATLAB is remarkably forgiving about malformed patterns: REGEXP does not
% raise on an unclosed group, it quietly stops reading the pattern where it
% went wrong and reports no match forever after. Waiting for an error would
% therefore catch almost nothing, so the pattern is instead run once and asked
% which tokens MATLAB actually took from it. A pattern that declares a token
% REGEXP did not read is malformed, whatever REGEXP was willing to say about
% it. Anything past that, such as a group that is well formed but can never
% match, is left to the preview table, which is what showing the parse against
% real names is for.
%
% Parameters
%   pattern: Candidate pattern. Empty means the built-in convention, which is
%       always usable.
%
% Returns
%   tf: True when the pattern can be handed to PARSE_HISTOLOGY_FILENAME.
%   message: Empty when tf is true, otherwise what is wrong with it, phrased
%       for a status bar.
%
% See also PARSE_HISTOLOGY_FILENAME, APPLYFILENAMEPATTERN,
% ONEDITFILENAMEPATTERN, TOKENLISTPATTERN.

arguments
    pattern (1,1) string = ""
end

tf = false;
message = "";

pattern = strtrim(pattern);

if pattern == ""
    tf = true;
    return
end

% Lookbehind assertions open with "(?<" too, so a token name is required to
% start with a letter, which "=" and "!" cannot.
declared = regexp(pattern, "\(\?<([A-Za-z]\w*)>", "tokens");

if isempty(declared)
    message = "the pattern names no tokens; write at least one (?<Name>...) group";
    return
end

% One group means one token per match, and a string subject gives string
% tokens, so the nested cells flatten straight into a list of names.
declared = [declared{:}];

try
    probe = regexp("SUBJ-ID-1174IHC_ECM26A260608S1_1A_L_WFA-PV_Z3_260616_1", ...
        pattern, "names", "once");
catch ME
    message = "the pattern is not a valid regular expression (" + string(ME.message) + ")";
    return
end

% The probe carries its token names whether or not the sample matched, so the
% names MATLAB read out of the pattern can be compared against the names the
% pattern appears to declare without needing a sample that matches.
if isstruct(probe)
    parsed = string(fieldnames(probe));
else
    parsed = strings(0, 1);
end

missing = setdiff(declared, parsed, "stable");

if ~isempty(missing)
    message = "the pattern is malformed: MATLAB read no token named """ + missing(1) + ...
        """ out of it, so check the brackets and parentheses around it";
    return
end

tf = true;

end
