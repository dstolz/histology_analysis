function columnNumber = columnNumber(letter)
%COLUMNNUMBER Convert A1 column letters to a 1-based column number.
%
%   gsheet.columnNumber("A")  returns 1
%   gsheet.columnNumber("AA") returns 27
%
% Parameters
%   letter: Column letters, case insensitive.
%
% Returns
%   columnNumber: Column index, 1 for column A.
%
% See also GSHEET.COLUMNLETTER.

arguments
    letter (1,1) string
end

letters = upper(char(letter));

if isempty(letters) || any(letters < 'A' | letters > 'Z')
    error("gsheet:InvalidColumnLetter", ...
        "'%s' is not a spreadsheet column reference.", letter)
end

columnNumber = 0;

for iLetter = 1:numel(letters)
    columnNumber = columnNumber * 26 + (letters(iLetter) - 'A' + 1);
end

end
