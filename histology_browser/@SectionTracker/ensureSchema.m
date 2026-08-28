function report = ensureSchema(obj, options)
%ENSURESCHEMA Give the tracker tab the two columns this class needs.
% Adds a Row UID column and a Last Updated column if they are missing, then
% gives an identifier to every entry that lacks one. Both steps are idempotent:
% running this on a tab that already has them, and whose rows are all
% identified, writes nothing.
%
% This is the one place the class changes the shape of the tab rather than the
% contents of a row, so it is deliberately a separate call. It is also the only
% write that has to happen before any other can, since a row with no identifier
% cannot be addressed.
%
% Identifiers are handed out in one batch against a single read. A row that
% gains an identifier elsewhere in between would end up with two, so the write
% only ever fills cells that were empty when they were read, and the result is
% checked afterwards.
%
% Parameters
%   options.dryRun: Report what would change without writing anything.
%
% Returns
%   report: Struct with fields
%      - columnsAdded: Names of columns created on the tab.
%      - uidsAssigned: Number of rows given an identifier.
%      - rows: Table of the rows that were identified, empty when none were.
%
% See also SECTIONTRACKER/UPDATEROWS.

arguments
    obj (1,1) SectionTracker
    options.dryRun (1,1) logical = false
end

obj.read();

report = struct( ...
    columnsAdded = strings(0, 1), ...
    uidsAssigned = 0, ...
    rows = table());

missing = string.empty(1, 0);

for name = [obj.UidColumn, obj.UpdatedColumn]
    if ~obj.hasColumn(name)
        missing(end+1) = name; %#ok<AGROW>
    end
end

if ~isempty(missing)
    if options.dryRun
        report.columnsAdded = missing(:);
    else
        add_columns(obj, missing);
        report.columnsAdded = missing(:);
        obj.read();
    end
end

if options.dryRun && ~isempty(missing)
    % The identifiers cannot be counted until the column exists, and in a dry
    % run it does not, so every entry would need one.
    report.uidsAssigned = height(obj.Table);
    return
end

report.uidsAssigned = assign_uids(obj, options.dryRun);

if report.uidsAssigned > 0 && ~options.dryRun
    obj.read();
end

end

function add_columns(obj, names)
%ADD_COLUMNS Write new headers to the right of the existing ones.
% A tab trimmed to exactly the columns it uses has no room on its right, and
% writing past the edge of the grid is refused rather than growing it, so the
% width is checked and the tab widened first when it has to be.

info = obj.Transport.sheetInfo();

% Past everything the tab uses, not merely past the last named column. A
% column with a blank header is dropped from the table because nothing can
% refer to it, but it may still hold data that must not be written over.
firstNewColumn = max([obj.ColumnIndex(:); obj.LastColumn]) + 1;
lastNewColumn = firstNewColumn + numel(names) - 1;

if ~isnan(info.columnCount) && lastNewColumn > info.columnCount
    obj.Transport.appendColumns(info.sheetId, lastNewColumn - info.columnCount);
end

update = struct( ...
    range = gsheet.a1Range(obj.SheetName, obj.HeaderRow, firstNewColumn, ...
        obj.HeaderRow, lastNewColumn), ...
    values = string(names(:)'));

obj.Transport.updateValues(update);

end

function nAssigned = assign_uids(obj, dryRun)
%ASSIGN_UIDS Fill the identifier of every entry that has none.

existing = strtrim(obj.column(obj.UidColumn));
blank = find(existing == "");

nAssigned = numel(blank);

if nAssigned == 0 || dryRun
    return
end

uids = SectionTracker.newUid(nAssigned);

if numel(unique([uids; existing(existing ~= "")])) ~= nAssigned + sum(existing ~= "")
    error("SectionTracker:UidCollision", ...
        "A generated identifier collided with one already in the tab. " + ...
        "Run ENSURESCHEMA again.")
end

uidColumn = obj.columnNumber(obj.UidColumn);
sheetRows = obj.SheetRows(blank);

updates = struct(range = {}, values = {});

for iRow = 1:numel(blank)
    updates(end+1) = struct( ...
        range = gsheet.a1Range(obj.SheetName, sheetRows(iRow), uidColumn), ...
        values = uids(iRow)); %#ok<AGROW>
end

obj.Transport.updateValues(updates);

verify_uids(obj, sheetRows, uids);

end

function verify_uids(obj, sheetRows, uids)
%VERIFY_UIDS Confirm each identifier landed on the row it was meant for.
% Assigning identifiers is the one write that cannot be undone by writing again
% over the top, because after it the rows are no longer distinguishable from
% each other by anything else. So it is checked.

obj.read();

written = strtrim(obj.column(obj.UidColumn));
wrong = strings(0, 1);

for iRow = 1:numel(uids)
    row = find(obj.SheetRows == sheetRows(iRow), 1);

    if isempty(row) || ~strcmp(written(row), uids(iRow))
        wrong(end+1) = uids(iRow); %#ok<AGROW>
    end
end

if ~isempty(wrong)
    error("SectionTracker:UidWriteFailed", ...
        "%d identifier(s) did not land on the rows they were written to. " + ...
        "The tab was probably edited at the same time; check it before " + ...
        "running this again.", numel(wrong))
end

end
