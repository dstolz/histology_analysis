function [firstRow, firstColumn] = rangeOrigin(range)
%RANGEORIGIN Sheet coordinates of the top-left cell of an A1 range.
% Where a block of values starts matters as much as what is in it: addressing a
% row for a later write means knowing which sheet row it came from. Google
% echoes the range it actually returned, so that is parsed rather than assuming
% every read begins at A1.
%
% A range with no cell reference, which is what a whole-tab request echoes back
% when the tab is empty, begins at A1.
%
% Parameters
%   range: Range in A1 notation, e.g. "Sections!B4:M120".
%
% Returns
%   firstRow, firstColumn: 1-based coordinates of the first cell.
%
% See also GSHEET.GETVALUES, GSHEET.A1RANGE.

arguments
    range (1,1) string
end

firstRow = 1;
firstColumn = 1;

if range == ""
    return
end

% A quoted tab name may itself contain an exclamation mark, so the split is
% taken at the last one rather than the first.
separator = max(strfind(range, "!"));

% With no separator there is no cell reference, only a tab name, and a tab name
% is made of the same letters a column reference is. Reading one as the other
% would put the origin thousands of columns to the right.
if isempty(separator)
    return
end

cellRef = extractAfter(range, separator);

if cellRef == ""
    return
end

cellRef = extractBefore(cellRef + ":", ":");

parts = regexp(cellRef, "^(?<column>[A-Za-z]*)(?<row>\d*)$", "names", "once");

if isempty(parts)
    return
end

if parts.row ~= ""
    firstRow = str2double(parts.row);
end

if parts.column ~= ""
    firstColumn = gsheet.columnNumber(parts.column);
end

end
