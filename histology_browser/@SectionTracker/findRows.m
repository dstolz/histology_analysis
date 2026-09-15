function idx = findRows(obj, criteria)
%FINDROWS Select rows of the last read by what they contain.
% This is the only way rows are identified anywhere in this class. Criteria are
% column name and value pairs, combined with AND:
%
%   idx = tracker.findRows({"Hemisphere", "L"})
%   idx = tracker.findRows({"Subject ID", "SUBJ-ID-896", "Content", "DAPI"})
%   idx = tracker.findRows({"Image Filename", ["stemA", "stemB"]})
%   idx = tracker.findRows({"Atlas Plate #", @(v) str2double(v) > 20})
%
% Text is compared after trimming and without regard to case, because the
% tracker is typed by hand and neither trailing spaces nor capitalization are
% ever meant as distinctions. A list of values matches any of them. A function
% handle is called with the whole column as a string array and returns a
% logical column, which covers the comparisons that are not equality.
%
% Parameters
%   criteria: Cell array of column name and value pairs. Empty selects nothing.
%
% Returns
%   idx: Row indices into obj.Table.
%
% See also SECTIONTRACKER/UPDATEROWS.

arguments
    obj (1,1) SectionTracker
    criteria cell
end

if height(obj.Table) == 0
    idx = zeros(0, 1);
    return
end

if isempty(criteria)
    % Selecting every row by asking for nothing is how a mistyped criteria list
    % would quietly turn into a write across the whole tracker.
    error("SectionTracker:NoCriteria", ...
        "No criteria were given. Pass at least one column and value pair.")
end

if mod(numel(criteria), 2) ~= 0
    error("SectionTracker:UnpairedCriteria", ...
        "Criteria must be column name and value pairs; %d values were given.", ...
        numel(criteria))
end

matches = true(height(obj.Table), 1);

for iPair = 1:2:numel(criteria)
    columnName = string(criteria{iPair});
    wanted = criteria{iPair + 1};

    if ~obj.hasColumn(columnName)
        error("SectionTracker:NoSuchColumn", ...
            "The '%s' tab has no column named '%s'. It has: %s.", ...
            obj.SheetName, columnName, strjoin(obj.ColumnNames, ", "))
    end

    matches = matches & match_column(obj.column(columnName), wanted, columnName);
end

idx = find(matches);

end

function tf = match_column(values, wanted, columnName)
%MATCH_COLUMN Test one column against one criterion.

values = strtrim(string(values));

if isa(wanted, "function_handle")
    tf = wanted(values);

    if ~islogical(tf) || numel(tf) ~= numel(values)
        error("SectionTracker:BadPredicate", ...
            "The predicate for '%s' must return one logical per row.", columnName)
    end

    tf = tf(:);
    return
end

wanted = strtrim(string(wanted));
wanted = wanted(:)';

if isempty(wanted)
    tf = false(numel(values), 1);
    return
end

tf = false(numel(values), 1);

for iWanted = 1:numel(wanted)
    tf = tf | strcmpi(values, wanted(iWanted));
end

end
