function rows = rowsForUids(obj, uids)
%ROWSFORUIDS Resolve row identifiers to rows of the last read.
% Internal. Every failure here means the write is about to be aimed at
% something other than what was asked for, so all of them stop it.
%
% A UID that has gone missing is the interesting case: it means the row was
% deleted, or its identifier was cleared, since whoever holds that UID last
% looked. Writing the value into whatever now sits nearby would be worse than
% refusing, so it refuses.

arguments
    obj (1,1) SectionTracker
    uids (:,1) string
end

if isempty(uids)
    error("SectionTracker:NoRows", "No rows were given to write to.")
end

if ~obj.hasColumn(obj.UidColumn)
    error("SectionTracker:NoUidColumn", ...
        "The '%s' tab has no '%s' column, so rows cannot be identified. " + ...
        "Run ENSURESCHEMA first.", obj.SheetName, obj.UidColumn)
end

if numel(unique(uids)) ~= numel(uids)
    error("SectionTracker:RepeatedUid", ...
        "The same row identifier was given more than once.")
end

present = obj.column(obj.UidColumn);
rows = zeros(numel(uids), 1);

for iUid = 1:numel(uids)
    match = find(strcmp(present, uids(iUid)));

    if isempty(match)
        error("SectionTracker:UnknownUid", ...
            "No row of the '%s' tab carries the identifier %s. The row may " + ...
            "have been deleted since it was read.", obj.SheetName, uids(iUid))
    end

    if numel(match) > 1
        error("SectionTracker:AmbiguousUid", ...
            "%d rows of the '%s' tab carry the identifier %s. Identifiers " + ...
            "are duplicated by copying a row; clear the copy's identifier " + ...
            "and run ENSURESCHEMA to give it one of its own.", ...
            numel(match), obj.SheetName, uids(iUid))
    end

    rows(iUid) = match;
end

end
