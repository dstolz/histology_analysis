function uids = requireUids(obj, rows)
%REQUIREUIDS Identifiers of the given rows of the last read.
% Internal. Rows are turned into identifiers before anything is written, so
% that the write itself is expressed in terms of the one column that does not
% move. A row with no identifier cannot be written to safely and says so.

arguments
    obj (1,1) SectionTracker
    rows (:,1) double
end

if ~obj.hasColumn(obj.UidColumn)
    error("SectionTracker:NoUidColumn", ...
        "The '%s' tab has no '%s' column, so rows cannot be identified. " + ...
        "Run ENSURESCHEMA first.", obj.SheetName, obj.UidColumn)
end

uids = obj.column(obj.UidColumn);
uids = strtrim(uids(rows));

blank = uids == "";

if any(blank)
    keys = obj.column(obj.KeyColumn);
    named = keys(rows(blank));

    error("SectionTracker:MissingUid", ...
        "%d matching row(s) have no '%s' value, so they cannot be written " + ...
        "to. Run ENSURESCHEMA to fill them in. Affected: %s", ...
        sum(blank), obj.UidColumn, strjoin(named, ", "))
end

end
