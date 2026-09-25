function ok = writeReview(obj, uids, updates, description)
%WRITEREVIEW Send one review edit to the tracker and show the result.
% The write puts its result back into the catalog in memory as well as into
% the sheet. Without that the sheet and the table would disagree until the next
% load, and the table is what someone is reading while they work.
%
% Parameters
%   uids: Tracker identifiers of the rows to write.
%   updates: Column and value pairs, as SECTIONTRACKER/UPDATEBYUID takes them.
%   description: What was written, for the status bar.
%
% Returns
%   ok: True when the write went through.
%
% See also SECTIONTRACKER/UPDATEBYUID, HISTOLOGYIMAGEBROWSER/REVIEWTARGET.

ok = false;

tracker = obj.sheetTracker();

if isempty(tracker)
    obj.setError("No sheet is configured.");
    return
end

obj.setBusy("Writing %s to %d tracker row(s) ...", description, numel(uids));

try
    tracker.updateByUid(uids, updates);
catch ME
    obj.setError("The tracker was not changed: %s", ME.message);
    uialert(obj.Fig, ME.message, "Tracker Not Updated");
    return
end

apply_locally(obj, uids, updates);

for iWarning = 1:numel(tracker.Warnings)
    obj.pushStatus("warning", "%s", tracker.Warnings(iWarning));
end

obj.pushStatus("success", "Set %s on %d tracker row(s).", description, numel(uids));

ok = true;

end

function apply_locally(obj, uids, updates)
%APPLY_LOCALLY Mirror a successful write onto the catalog already in memory.
% Only the columns just written are touched, and the table is patched in place
% rather than rebuilt, so the selection someone is working through does not
% jump back to the top under them.

for iPair = 1:2:numel(updates)
    columnName = string(updates{iPair});
    value = string(updates{iPair + 1});

    if columnName == SectionTracker.MeasuredColumn
        assign(obj, uids, "Measured", SectionTracker.isMeasured(value));
    end
end

obj.refreshReviewColumns();

end

function assign(obj, uids, columnName, value)
%ASSIGN Write one value into every catalog and view row carrying these UIDs.

obj.Catalog = assign_in(obj.Catalog, uids, columnName, value);
obj.View = assign_in(obj.View, uids, columnName, value);

end

function T = assign_in(T, uids, columnName, value)
%ASSIGN_IN Set one column of whichever rows carry these identifiers.

if height(T) == 0 || ~ismember("TrackerUid", string(T.Properties.VariableNames))
    return
end

rows = ismember(strtrim(string(T.TrackerUid)), uids);

if ~any(rows)
    return
end

T.(char(columnName))(rows) = value;

end
