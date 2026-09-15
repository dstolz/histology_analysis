function values = valueGrid(raw)
%VALUEGRID Pad the ragged array Google returns into a rectangle of text.
% Trailing empty cells are omitted from every row, so rows arrive at different
% lengths, and JSONDECODE renders that in one of three ways depending on what
% it was given: a cell of cells when the rows differ in length, a plain cell
% matrix when they happen not to, and a bare array when there is a single row.
% All three become one string array here so nothing downstream has to know
% which it got.
%
% Parameters
%   raw: The decoded "values" field of a Sheets values.get reply.
%
% Returns
%   values: String array of cell contents, rows by columns, blank-padded.
%
% See also GSHEET.GETVALUES.

if isempty(raw)
    values = strings(0, 0);
    return
end

if ~iscell(raw)
    values = string(raw);
    return
end

% A response whose rows are all the same length decodes straight to a cell
% matrix, one cell per value, and needs no padding.
if size(raw, 2) > 1
    values = string(cellfun(@cell_text, raw, UniformOutput = false));
    return
end

rows = raw(:);
nColumns = 0;

for iRow = 1:numel(rows)
    nColumns = max(nColumns, numel(row_cells(rows{iRow})));
end

values = strings(numel(rows), nColumns);

for iRow = 1:numel(rows)
    cells = row_cells(rows{iRow});

    for iColumn = 1:numel(cells)
        values(iRow, iColumn) = cell_text(cells{iColumn});
    end
end

end

function cells = row_cells(row)
%ROW_CELLS Present one decoded row as a cell array of values.

if iscell(row)
    cells = row(:)';
    return
end

if isempty(row)
    cells = {};
    return
end

if isstring(row) || ischar(row)
    cells = cellstr(string(row(:)'));
    return
end

cells = num2cell(row(:)');

end

function text = cell_text(value)
%CELL_TEXT Render one cell as text, whatever JSONDECODE made of it.

if iscell(value)
    if isempty(value)
        text = "";
        return
    end

    value = value{1};
end

if isempty(value)
    text = "";
    return
end

if isnumeric(value) || islogical(value)
    text = string(value(1));
    return
end

text = string(value);

if ~isscalar(text)
    text = text(1);
end

if ismissing(text)
    text = "";
end

end
