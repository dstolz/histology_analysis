function T = filenamePatternPreview(names, pattern)
%FILENAMEPATTERNPREVIEW Tabulate what one pattern extracts from a list of names.
% What the pattern dialog shows under the editor, kept out of it so the preview
% can be checked without a window opening, and so it is literally the parse the
% catalog will run rather than a second implementation that agrees with it
% until it does not.
%
% The Stem column is carried even though the pattern never sees the rest of the
% name, because the markers stripped ahead of the pattern are the first thing
% that confuses someone whose pattern will not match: they write one that ends
% in _proj and cannot see why nothing matches. Columns that are empty for every
% name are dropped, so a pattern's own tokens are what the table is made of.
%
% Parameters
%   names: Filenames to parse, with or without paths and extensions.
%   pattern: Named-capture pattern, or "" for the built-in convention. It must
%       already have passed CHECKFILENAMEPATTERN; an uncompilable one raises
%       here exactly as it would during a catalog build.
%
% Returns
%   T: One row per name. Name, Match, and Stem, then one column per token the
%      pattern filled for at least one name.
%
% See also PARSE_HISTOLOGY_FILENAME, CHECKFILENAMEPATTERN,
% ONEDITFILENAMEPATTERN, FILENAMEPATTERNSAMPLES.

arguments
    names (:,1) string
    pattern (1,1) string = ""
end

nNames = numel(names);

matched = strings(nNames, 1);
stems = strings(nNames, 1);

infos = cell(nNames, 1);
tokenNames = strings(0, 1);

for iName = 1:nNames
    info = parse_histology_filename(names(iName), pattern = pattern);

    infos{iName} = info;
    stems(iName) = info.stem;

    if info.isValid
        matched(iName) = "yes";
    else
        matched(iName) = "no";
    end

    fields = string(fieldnames(info));
    fields = fields(~ismember(fields, ["isValid", "stem", "variant", "roi"]));
    tokenNames = [tokenNames; setdiff(fields, tokenNames, "stable")]; %#ok<AGROW>
end

T = table(names, matched, stems, VariableNames = ["Name", "Match", "Stem"]);

T = append_column(T, "Variant", collect(infos, "variant"), "raw");
T = append_column(T, "ROI", collect(infos, "roi"), "");

for iToken = 1:numel(tokenNames)
    T = append_column(T, tokenNames(iToken), collect(infos, tokenNames(iToken)), "");
end

end

function values = collect(infos, field)
%COLLECT Read one field from every parse, tolerating a name that lacks it.
% Only the tokens the pattern filled for a given name are fields of that name's
% result, so a token that appears in one alternative branch and not another is
% absent rather than empty on the names it did not match.

values = strings(numel(infos), 1);

for iInfo = 1:numel(infos)
    if isfield(infos{iInfo}, field)
        values(iInfo) = string(infos{iInfo}.(field));
    end
end

end

function T = append_column(T, name, values, uninformative)
%APPEND_COLUMN Add one preview column, unless it would say nothing.
% A column every row agrees on carries no information about the pattern and
% only narrows the ones that do, so it is left off.

if all(values == uninformative)
    return
end

% A pattern is free to name a token Stem or Match; the base columns keep their
% names and the token takes a suffixed one rather than overwriting them.
name = string(matlab.lang.makeUniqueStrings(name, string(T.Properties.VariableNames)));

T.(name) = values;

end
