function pattern = tokenListPattern(delimiter, names)
%TOKENLISTPATTERN Compile a delimiter-and-field-names scheme into a pattern.
% The simpler of the two ways a naming scheme can be described: say what
% separates the fields, name them in order, and mark the ones to ignore. It
% earns its place beside the regular expression form because the people whose
% filenames this tool cannot read are microscopists, and telling them the fix
% is to write a regular expression is the same as telling them there is no fix.
%
% It compiles down to a named-capture pattern rather than being stored as a
% scheme of its own, so there is exactly one thing the parser, the catalog, and
% the preference file ever have to understand. The alternative -- a second
% persisted representation with its own validation and its own path through
% PARSE_HISTOLOGY_FILENAME -- would double that surface to save the dialog one
% call, and would still have to answer what a token list means for names that
% the delimiter does not divide evenly.
%
% Parameters
%   delimiter: Text between fields, one or more characters.
%   names: Field names in order, either as a string array or as one
%       comma-separated string. "-" or "" marks a field to parse past and
%       discard, which is how a field is ignored without naming it.
%
% Returns
%   pattern: Anchored named-capture pattern, or "" when no field was named.
%       "" is what the rest of the toolbox reads as the built-in convention,
%       so a half-typed list previews as the default rather than as an error.
%
% See also PARSE_HISTOLOGY_FILENAME, CHECKFILENAMEPATTERN,
% ONEDITFILENAMEPATTERN.

arguments
    delimiter (1,1) string = "_"
    names (1,:) string = strings(1, 0)
end

names = strtrim(names);

% One string holding a comma-separated list is how the dialog collects them and
% how they read in a call, so both spellings arrive at the same array.
if isscalar(names) && contains(names, ",")
    names = strtrim(split(names, ",")');
end

if isempty(names) || all(names == "" | names == "-") || delimiter == ""
    pattern = "";
    return
end

separator = regexptranslate("escape", delimiter);

% A single character delimiter gives a field the readable "anything but the
% separator" spelling, which matters because the compiled pattern is shown in
% the dialog and is meant to be edited from there. A longer delimiter has no
% character class, so the field becomes "characters that do not start one",
% which reproduces the same split without being pleasant to read.
if strlength(delimiter) == 1
    body = "[^" + separator + "]+";
else
    body = "(?:(?!" + separator + ").)+";
end

parts = strings(1, numel(names));

for iName = 1:numel(names)
    thisName = names(iName);

    if thisName == "" || thisName == "-"
        parts(iName) = "(?:" + body + ")";
        continue
    end

    % A name that is not a valid identifier cannot be a capture group name; it
    % is written out anyway so CHECKFILENAMEPATTERN rejects the result, rather
    % than being quietly renamed into something the user did not ask for and
    % will not find in the preview.
    parts(iName) = "(?<" + thisName + ">" + body + ")";
end

pattern = "^" + join(parts, separator) + "$";

end
