function onPrepareSheet(obj)
%ONPREPARESHEET Add the columns that let the browser write to the tracker.
% This is the only action in the browser that changes the shape of a document
% other people maintain, so it says exactly what it will do and waits to be
% told to go ahead. What it does is additive: two columns on the right, and an
% identifier in each row that has none. No existing cell is touched.
%
% See also SECTIONTRACKER/ENSURESCHEMA, HISTOLOGYIMAGEBROWSER/ONCONFIGURESHEET.

tracker = obj.sheetTracker();

if isempty(tracker)
    obj.setWarning("No sheet is configured.");
    return
end

if obj.SheetCredentials == ""
    obj.setError("Writing to the sheet needs a service account key file.");
    uialert(obj.Fig, ...
        "Choose a service account key file under Dataset > Google Sheet " + ...
        "Tracker > Configure before preparing the sheet.", "No Key File");
    return
end

obj.setBusy("Checking the '%s' tab ...", obj.SheetTab);

try
    planned = tracker.ensureSchema(dryRun = true);
catch ME
    obj.setError("Could not read the sheet: %s", ME.message);
    uialert(obj.Fig, ME.message, "Sheet Not Read");
    return
end

if isempty(planned.columnsAdded) && planned.uidsAssigned == 0
    obj.setSuccess("The '%s' tab is already prepared; nothing to change.", obj.SheetTab);
    return
end

choice = uiconfirm(obj.Fig, describe_plan(obj.SheetTab, planned), ...
    "Prepare Sheet for Writing", ...
    Options = ["Prepare Sheet", "Cancel"], ...
    DefaultOption = "Cancel", ...
    CancelOption = "Cancel", ...
    Icon = "question");

if choice ~= "Prepare Sheet"
    obj.setStatus("The sheet was left as it was.");
    return
end

obj.setBusy("Preparing the '%s' tab ...", obj.SheetTab);

try
    report = tracker.ensureSchema();
catch ME
    obj.setError("Preparing the sheet failed: %s", ME.message);
    uialert(obj.Fig, ME.message, "Sheet Not Prepared");
    return
end

obj.refreshDatasetMenu();

obj.pushStatus("success", "%s", describe_result(obj.SheetTab, report));

end

function text = describe_plan(sheetTab, planned)
%DESCRIBE_PLAN Say what is about to change, before anything does.

parts = "The '" + sheetTab + "' tab will be changed:";

if ~isempty(planned.columnsAdded)
    parts(end+1) = "  - Add " + strjoin("'" + planned.columnsAdded(:)' + "'", " and ") ...
        + " as new columns on the right.";
end

if planned.uidsAssigned > 0
    parts(end+1) = "  - Give an identifier to " + planned.uidsAssigned + " row(s).";
end

parts(end+1) = "";
parts(end+1) = "No existing cell is changed. Google Sheets keeps version " + ...
    "history, so this can be undone from File > Version history.";

text = strjoin(parts, newline);

end

function text = describe_result(sheetTab, report)
%DESCRIBE_RESULT Say what actually changed.

parts = strings(1, 0);

if ~isempty(report.columnsAdded)
    parts(end+1) = "added " + strjoin(report.columnsAdded(:)', " and ");
end

if report.uidsAssigned > 0
    parts(end+1) = "identified " + report.uidsAssigned + " row(s)";
end

if isempty(parts)
    text = "The '" + sheetTab + "' tab needed no changes.";
    return
end

text = "Prepared the '" + sheetTab + "' tab: " + strjoin(parts, ", ") + ".";

end
