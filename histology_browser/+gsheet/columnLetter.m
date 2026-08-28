function letter = columnLetter(columnNumber)
%COLUMNLETTER Convert a 1-based column number to its A1 letters.
%
%   gsheet.columnLetter(1)  returns "A"
%   gsheet.columnLetter(27) returns "AA"
%
% The tracker already runs past column M, and adding columns to it pushes
% further right, so the two-letter case is reached in ordinary use rather than
% being a theoretical edge.
%
% Parameters
%   columnNumber: Column index, 1 for column A.
%
% Returns
%   letter: Column letters in A1 notation.
%
% See also GSHEET.COLUMNNUMBER, GSHEET.A1RANGE.

arguments
    columnNumber (1,1) double {mustBeInteger, mustBePositive}
end

letter = "";
remaining = columnNumber;

% Spreadsheet columns are bijective base 26: there is no zero digit, so each
% step takes one off before dividing and the remainder maps A through Z.
while remaining > 0
    digit = mod(remaining - 1, 26);
    letter = string(char('A' + digit)) + letter;
    remaining = floor((remaining - 1) / 26);
end

end
