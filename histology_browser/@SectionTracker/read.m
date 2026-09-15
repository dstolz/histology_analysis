function read(obj)
%READ Pull the tracker tab and rebuild the table from what is there now.
% The header is searched for rather than assumed to be row 1, because the tab
% carries blank and title rows above it, exactly as the exported CSV did. The
% sheet row each entry came from is recorded alongside it, which is what lets a
% later write name a rectangle; that mapping is only trustworthy until the tab
% changes, so nothing outside this class is given it to hold on to.
%
% See also SECTIONTRACKER/UPDATEROWS, SECTIONTRACKER/ENSURESCHEMA.

if ~obj.isConfigured()
    error("SectionTracker:NotConfigured", ...
        "Set the spreadsheet and the service account key file before reading.")
end

grid = obj.Transport.getValues(obj.SheetName);

values = string(grid.values);
values(ismissing(values)) = "";

if isempty(values)
    error("SectionTracker:EmptySheet", ...
        "The '%s' tab is empty.", obj.SheetName)
end

obj.Warnings = strings(0, 1);

headerIndex = find_header_row(values, obj.KeyColumn);

if isempty(headerIndex)
    error("SectionTracker:NoHeaderRow", ...
        "No row of the '%s' tab contains a '%s' column.", ...
        obj.SheetName, obj.KeyColumn)
end

obj.HeaderRow = grid.firstRow + headerIndex - 1;

[names, columnIndex, warnings] = read_header(values(headerIndex, :), grid.firstColumn);
obj.Warnings = [obj.Warnings; warnings];

if isempty(names)
    error("SectionTracker:NoNamedColumns", ...
        "The header row of the '%s' tab has no named columns.", obj.SheetName)
end

body = values(headerIndex + 1:end, :);
bodySheetRows = (grid.firstRow + headerIndex:grid.firstRow + size(values, 1) - 1)';

% Columns are pulled by position rather than sliced as a block, because the
% named columns need not be contiguous once blank headers are dropped.
localIndex = columnIndex - grid.firstColumn + 1;
cells = strings(size(body, 1), numel(names));

for iColumn = 1:numel(names)
    if localIndex(iColumn) <= size(body, 2)
        cells(:, iColumn) = strtrim(body(:, localIndex(iColumn)));
    end
end

% Spacer rows are part of how the tab is laid out, not entries in it. Dropping
% them here keeps them out of the table and, just as importantly, out of the
% row mapping, so nothing can later be written into one.
keep = any(cells ~= "", 2);

obj.Table = array2table(cells(keep, :), VariableNames = cellstr(names));
obj.SheetRows = bodySheetRows(keep);
obj.ColumnNames = names;
obj.ColumnIndex = columnIndex;
obj.LastColumn = grid.firstColumn + size(values, 2) - 1;
obj.FetchedAt = datetime("now", TimeZone = "UTC");

end

function headerIndex = find_header_row(values, keyColumn)
%FIND_HEADER_ROW Locate the header by the one column that must be present.

isKey = strcmpi(strtrim(values), keyColumn);
headerIndex = find(any(isKey, 2), 1, "first");

end

function [names, columnIndex, warnings] = read_header(headerRow, firstColumn)
%READ_HEADER Reduce the header row to addressable column names.
% Unnamed columns cannot be referred to and duplicated ones are ambiguous, so
% both are left out of the table. Neither is a reason to refuse the read, but
% both lose a column that somebody may be looking for, so both are reported.

headerRow = strtrim(headerRow);

names = strings(0, 1);
columnIndex = [];
warnings = strings(0, 1);

for iColumn = 1:numel(headerRow)
    name = headerRow(iColumn);

    if name == ""
        continue
    end

    if any(strcmpi(names, name))
        warnings(end+1) = "Column '" + name + "' appears more than once; " ...
            + "only the first was read."; %#ok<AGROW>
        continue
    end

    names(end+1) = name; %#ok<AGROW>
    columnIndex(end+1) = firstColumn + iColumn - 1; %#ok<AGROW>
end

columnIndex = columnIndex(:)';
names = names(:);
columnIndex = columnIndex(:);

end
