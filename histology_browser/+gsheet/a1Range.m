function range = a1Range(sheetName, firstRow, firstColumn, lastRow, lastColumn)
%A1RANGE Build an A1 range that names its sheet.
%
%   gsheet.a1Range("Sections", 5, 14)        returns "Sections!N5"
%   gsheet.a1Range("Sections", 5, 14, 5, 15) returns "Sections!N5:O5"
%
% Parameters
%   sheetName: Tab name. Quoted automatically when it needs it.
%   firstRow, firstColumn: 1-based coordinates of the first cell.
%   lastRow, lastColumn: Optional coordinates of the last cell.
%
% Returns
%   range: Range in A1 notation.
%
% See also GSHEET.COLUMNLETTER.

arguments
    sheetName (1,1) string
    firstRow (1,1) double {mustBeInteger, mustBePositive}
    firstColumn (1,1) double {mustBeInteger, mustBePositive}
    lastRow (1,1) double {mustBeInteger, mustBePositive} = firstRow
    lastColumn (1,1) double {mustBeInteger, mustBePositive} = firstColumn
end

first = gsheet.columnLetter(firstColumn) + string(firstRow);
last = gsheet.columnLetter(lastColumn) + string(lastRow);

range = quote_sheet_name(sheetName) + "!" + first;

if last ~= first
    range = range + ":" + last;
end

end

function name = quote_sheet_name(name)
%QUOTE_SHEET_NAME Wrap a tab name in the quotes A1 notation needs.
% A bare name works only while it looks like an identifier. Anything else, a
% space or a hyphen most often, has to be quoted or the range parses as a cell
% reference on the default sheet.

if regexp(name, "^[A-Za-z_][A-Za-z0-9_]*$", "once")
    return
end

name = "'" + replace(name, "'", "''") + "'";

end
