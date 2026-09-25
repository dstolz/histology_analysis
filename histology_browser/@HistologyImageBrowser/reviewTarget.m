function target = reviewTarget(obj)
%REVIEWTARGET Work out which tracker rows a review write would reach.
% One function answers this for the write and for the warning given in its
% place, so what the status bar says is wrong and what a key press does cannot
% disagree.
%
% Returns
%   target: Struct with fields
%      - rows: Indices into obj.View of the selected sections.
%      - writableRows: Those of them a write would actually reach.
%      - uids: Tracker identifiers of the writable rows, in the same order.
%      - writable: True when a write could be made right now.
%      - reason: Why not, when writable is false; what will be skipped, when
%        it is true but not every selected section can be written to.
%
% Callers wanting to know the state of what they are about to change should
% read writableRows rather than rows. A section the tracker has no row for
% cannot be marked however often it is selected, so counting it would leave the
% keyboard toggle stuck trying to mark it.
%
% See also HISTOLOGYIMAGEBROWSER/ONSETMEASURED,
% HISTOLOGYIMAGEBROWSER/WRITEREVIEW.

target = struct( ...
    rows = zeros(0, 1), ...
    writableRows = zeros(0, 1), ...
    uids = strings(0, 1), ...
    writable = false, ...
    reason = "");

if obj.SheetUrl == ""
    target.reason = "Reviewing writes to the tracker's Google Sheet. " + ...
        "Set one under Dataset > Google Sheet Tracker.";
    return
end

if obj.SheetCredentials == ""
    target.reason = "Writing to the sheet needs a service account key file; " + ...
        "name one under Dataset > Google Sheet Tracker > Configure.";
    return
end

target.rows = selected_indices(obj);

if isempty(target.rows)
    target.reason = "Select one or more sections to review.";
    return
end

if ~ismember("TrackerUid", string(obj.View.Properties.VariableNames))
    target.reason = "This dataset was loaded before the tracker was read " + ...
        "from the sheet. Load it again to review it.";
    return
end

uids = strtrim(string(obj.View.TrackerUid(target.rows)));
identified = uids ~= "";

% A section with no identifier is one the tracker has no row for, or one whose
% row predates the identifier column. Neither can be written to, and the two
% have different fixes, so the count is reported rather than the write being
% attempted and refused row by row.
if ~any(identified)
    target.reason = describe_unidentified(obj, numel(uids));
    return
end

target.uids = uids(identified);
target.writableRows = target.rows(identified);
target.writable = true;

if ~all(identified)
    target.reason = sprintf("%d of %d selected section(s) have no tracker row " + ...
        "and will be skipped.", sum(~identified), numel(identified));
end

end

function rows = selected_indices(obj)
%SELECTED_INDICES Rows of obj.View the table has selected.
% SELECTEDROWS hands back the rows themselves, which is what every other caller
% wants; a write needs the indices, because it also has to put results back
% into the same positions afterwards.

rows = zeros(0, 1);

if height(obj.View) == 0 || isempty(obj.Selection)
    return
end

rows = obj.Selection(obj.Selection >= 1 & obj.Selection <= height(obj.View));
rows = rows(:);

end

function reason = describe_unidentified(obj, nSelected)
%DESCRIBE_UNIDENTIFIED Say why the selection cannot be written to.
% The two causes look identical from the browser but are fixed differently, so
% the tracker's own state is what decides which is named.

inTracker = false;

if ismember("InTracker", string(obj.View.Properties.VariableNames))
    inTracker = any(obj.View.InTracker(selected_indices(obj)));
end

if inTracker
    reason = "The tracker rows for these sections have no identifier yet. " + ...
        "Run Dataset > Google Sheet Tracker > Prepare Sheet for Writing.";
    return
end

if nSelected == 1
    reason = "This section has no row in the tracker, so there is nothing to write to.";
    return
end

reason = "None of the selected sections have a row in the tracker.";

end
