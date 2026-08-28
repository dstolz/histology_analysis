function report = updateRows(obj, criteria, updates, options)
%UPDATEROWS Write values into the tracker rows that match some criteria.
% The tab is re-read first, every time, and the criteria are resolved against
% that read rather than against anything held from before. Between a read and
% the write that follows it there is still a window in which somebody could
% reorder the tab, and the Sheets API offers nothing to close it: there is no
% conditional write. What can be done is to keep the window to one round trip
% and to check afterwards, which is what VERIFY does.
%
% Nothing is written unless the criteria match. A write aimed at rows that are
% no longer there is a mistake worth hearing about, not a no-op to pass over.
%
% Parameters
%   criteria: Cell array of column name and value pairs. See FINDROWS.
%   updates: Cell array of column name and value pairs to write.
%   options.expected: Number of rows the caller expects to match. A different
%     count refuses the write. Use it whenever the count is known in advance.
%   options.verify: Read the tab again afterwards and confirm the values
%     landed in the rows they were aimed at.
%
% Returns
%   report: Table of what was written, one row per tracker row touched.
%
% Example
%   tracker.updateRows( ...
%       {"Image Filename", stem}, ...
%       {"Notes", "Profile remeasured"}, expected = 1);
%
% See also SECTIONTRACKER/UPDATEBYUID, SECTIONTRACKER/FINDROWS.

arguments
    obj (1,1) SectionTracker
    criteria cell
    updates cell
    options.expected (1,1) double = NaN
    options.verify (1,1) logical = true
end

obj.read();

idx = obj.findRows(criteria);

if isempty(idx)
    error("SectionTracker:NoMatchingRows", ...
        "No row of the '%s' tab matches %s.", ...
        obj.SheetName, describe_criteria(criteria))
end

if ~isnan(options.expected) && numel(idx) ~= options.expected
    error("SectionTracker:UnexpectedMatchCount", ...
        "%s matches %d row(s) of the '%s' tab, but %d were expected. " + ...
        "Nothing was written.", ...
        describe_criteria(criteria), numel(idx), obj.SheetName, options.expected)
end

uids = obj.requireUids(idx);

report = obj.applyUpdates(uids, updates, verify = options.verify);

end

function text = describe_criteria(criteria)
%DESCRIBE_CRITERIA Render a criteria list for an error message.

parts = strings(1, 0);

for iPair = 1:2:numel(criteria) - 1
    value = criteria{iPair + 1};

    if isa(value, "function_handle")
        value = "<predicate>";
    end

    parts(end+1) = string(criteria{iPair}) + "=" ...
        + strjoin(string(value), "|"); %#ok<AGROW>
end

text = strjoin(parts, ", ");

end
