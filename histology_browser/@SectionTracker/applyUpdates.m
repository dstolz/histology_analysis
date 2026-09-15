function report = applyUpdates(obj, uids, updates, options)
%APPLYUPDATES Write one batch of cells against the read now in hand.
% Internal. Callers reach this through UPDATEROWS or UPDATEBYUID, both of which
% read the tab immediately beforehand, because the sheet rows this resolves are
% only true for as long as nothing else has moved them.
%
% The whole batch, values and timestamps together, goes out as a single request
% so a row can never be left carrying a new value under an old stamp.

arguments
    obj (1,1) SectionTracker
    uids (:,1) string
    updates cell
    options.verify (1,1) logical = true
end

pairs = validate_updates(obj, updates);

rows = obj.rowsForUids(uids);
sheetRows = obj.SheetRows(rows);

stamp = SectionTracker.timestamp();

writeColumns = [pairs.column, obj.canonicalColumn(obj.UpdatedColumn)];
writeValues = [pairs.value, stamp];
writeSheetColumns = zeros(1, numel(writeColumns));

for iColumn = 1:numel(writeColumns)
    writeSheetColumns(iColumn) = obj.columnNumber(writeColumns(iColumn));
end

batch = build_batch(obj.SheetName, sheetRows, writeSheetColumns, writeValues);

obj.Transport.updateValues(batch);

report = table( ...
    uids(:), sheetRows(:), ...
    repmat(strjoin(writeColumns, ", "), numel(rows), 1), ...
    repmat(stamp, numel(rows), 1), ...
    VariableNames = ["Uid", "SheetRow", "Columns", "UpdatedAt"]);

if obj.hasColumn(obj.KeyColumn)
    keys = obj.column(obj.KeyColumn);
    report.ImageFilename = keys(rows);
end

if options.verify
    verify_write(obj, uids, sheetRows, writeColumns, writeValues);
end

end

function pairs = validate_updates(obj, updates)
%VALIDATE_UPDATES Check the requested writes before any of them is sent.
% Everything that can be known to be wrong is caught here, so a batch is either
% sent whole or not at all rather than failing partway through the sheet.

if isempty(updates)
    error("SectionTracker:NoUpdates", ...
        "No columns to write were given.")
end

if mod(numel(updates), 2) ~= 0
    error("SectionTracker:UnpairedUpdates", ...
        "Updates must be column name and value pairs; %d values were given.", ...
        numel(updates))
end

pairs = struct(column = strings(1, 0), value = strings(1, 0));

for iPair = 1:2:numel(updates)
    columnName = string(updates{iPair});
    value = updates{iPair + 1};

    if ~(isstring(value) || ischar(value) || isnumeric(value)) || ~isscalar(string(value))
        error("SectionTracker:BadUpdateValue", ...
            "The value for '%s' must be a single piece of text or one number.", ...
            columnName)
    end

    if strcmpi(columnName, obj.UidColumn)
        error("SectionTracker:ProtectedColumn", ...
            "'%s' identifies the row and is never rewritten. " + ...
            "Use ENSURESCHEMA to give a row an identifier it lacks.", obj.UidColumn)
    end

    if strcmpi(columnName, obj.UpdatedColumn)
        error("SectionTracker:ProtectedColumn", ...
            "'%s' is stamped automatically on every write and cannot be set.", ...
            obj.UpdatedColumn)
    end

    if ~obj.hasColumn(columnName)
        error("SectionTracker:NoSuchColumn", ...
            "The '%s' tab has no column named '%s'. It has: %s.", ...
            obj.SheetName, columnName, strjoin(obj.ColumnNames, ", "))
    end

    if any(strcmpi(pairs.column, columnName))
        error("SectionTracker:DuplicateUpdate", ...
            "Column '%s' was given a value twice.", columnName)
    end

    % Stored under the header's own spelling, because the table is indexed by
    % exact name later even though callers may name a column in any case.
    pairs.column(end+1) = obj.canonicalColumn(columnName);
    pairs.value(end+1) = string(value);
end

if ~obj.hasColumn(obj.UpdatedColumn)
    error("SectionTracker:NoTimestampColumn", ...
        "The '%s' tab has no '%s' column, so a write could not be dated. " + ...
        "Run ENSURESCHEMA first.", obj.SheetName, obj.UpdatedColumn)
end

end

function batch = build_batch(sheetName, sheetRows, sheetColumns, values)
%BUILD_BATCH Turn per-row cell writes into as few rectangles as possible.
% Columns that happen to sit next to each other go out as one range. That is
% worth doing because the two columns this class maintains are appended
% together and so are always adjacent, which halves the request for the common
% case of stamping a value and its timestamp.

[sheetColumns, order] = sort(sheetColumns);
values = values(order);

runStart = [1, find(diff(sheetColumns) ~= 1) + 1];
runEnd = [runStart(2:end) - 1, numel(sheetColumns)];

batch = struct(range = {}, values = {});

for iRow = 1:numel(sheetRows)
    for iRun = 1:numel(runStart)
        span = runStart(iRun):runEnd(iRun);

        batch(end+1) = struct( ...
            range = gsheet.a1Range(sheetName, sheetRows(iRow), sheetColumns(span(1)), ...
                sheetRows(iRow), sheetColumns(span(end))), ...
            values = values(span)); %#ok<AGROW>
    end
end

end

function verify_write(obj, uids, sheetRows, writeColumns, writeValues)
%VERIFY_WRITE Confirm the cells landed in the rows they were aimed at.
% This is the answer to the gap the Sheets API leaves open. It cannot prevent a
% row moving between the read and the write, but it does mean such a write is
% reported rather than passing for a success, which is the difference between a
% problem someone can go and fix and one nobody knows about.

obj.read();

moved = strings(0, 1);
unexpected = strings(0, 1);

for iUid = 1:numel(uids)
    row = find(strcmp(obj.column(obj.UidColumn), uids(iUid)), 1);

    if isempty(row) || obj.SheetRows(row) ~= sheetRows(iUid)
        moved(end+1) = uids(iUid); %#ok<AGROW>
        continue
    end

    for iColumn = 1:numel(writeColumns)
        actual = strtrim(obj.Table.(char(writeColumns(iColumn)))(row));

        if ~strcmpi(actual, strtrim(writeValues(iColumn)))
            unexpected(end+1) = uids(iUid) + " (" + writeColumns(iColumn) ...
                + ": wrote '" + writeValues(iColumn) + "', reads '" + actual + "')"; %#ok<AGROW>
        end
    end
end

if ~isempty(moved)
    error("SectionTracker:RowMovedDuringWrite", ...
        "The tab changed while it was being written. These rows are no " + ...
        "longer where the values were sent, so the wrong rows may now hold " + ...
        "them; check the sheet's version history: %s", strjoin(moved, ", "))
end

% A value that reads back differently is usually the cell's own formatting
% rather than a lost write, so it is carried out as a warning rather than
% raised as an error over what may be a display difference.
if ~isempty(unexpected)
    obj.Warnings = [obj.Warnings; ...
        "Written values read back differently: " + strjoin(unexpected, "; ")];
end

end
