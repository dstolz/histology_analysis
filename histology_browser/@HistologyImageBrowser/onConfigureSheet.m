function onConfigureSheet(obj)
%ONCONFIGURESHEET Point the browser at the Google Sheet holding the tracker.
% Three things have to be named and none of them can be guessed, so they are
% asked for together rather than one prompt at a time. The dialog also offers
% to try the connection, because everything that can go wrong here, a key file
% for the wrong project, a sheet nobody shared with the service account, a tab
% renamed since last time, goes wrong identically from the outside: the read
% simply fails. Finding that out on the spot beats finding it out during a load.
%
% See also SECTIONTRACKER, HISTOLOGYIMAGEBROWSER/ONPREPARESHEET.

dialog = uifigure( ...
    Name = "Google Sheet Tracker", ...
    Position = center_on(obj.Fig, 560, 320), ...
    WindowStyle = "modal", ...
    Resize = "off");

layout = uigridlayout(dialog, [6 3], ...
    RowHeight = {22, 22, 22, "1x", 30, 30}, ...
    ColumnWidth = {150, "1x", 90}, ...
    Padding = [16 16 16 12]);

uilabel(layout, Text = "Spreadsheet URL or ID:", HorizontalAlignment = "right");
urlField = uieditfield(layout, "text", Value = obj.SheetUrl);
urlField.Layout.Column = [2 3];

uilabel(layout, Text = "Tab name:", HorizontalAlignment = "right");
tabField = uieditfield(layout, "text", Value = obj.SheetTab);
tabField.Layout.Column = [2 3];

uilabel(layout, Text = "Service account key:", HorizontalAlignment = "right");
keyField = uieditfield(layout, "text", Value = obj.SheetCredentials);
uibutton(layout, Text = "Browse...", ...
    ButtonPushedFcn = @(~,~) browse_for_key(dialog, keyField));

status = uilabel(layout, ...
    Text = help_text(), ...
    VerticalAlignment = "top", ...
    WordWrap = "on");
status.Layout.Row = 4;
status.Layout.Column = [1 3];

testButton = uibutton(layout, Text = "Test Connection");
testButton.Layout.Row = 5;
testButton.Layout.Column = 1;

% The callback is attached afterwards because it disables the button while the
% read is in flight, and an anonymous function captures what it names at the
% moment it is built, not the moment it runs.
testButton.ButtonPushedFcn = ...
    @(~,~) test_connection(urlField, tabField, keyField, status, testButton);

buttons = uigridlayout(layout, [1 3], ...
    ColumnWidth = {"1x", 90, 90}, ...
    Padding = [0 0 0 0]);
buttons.Layout.Row = 6;
buttons.Layout.Column = [1 3];

uilabel(buttons, Text = "");

accepted = false;

uibutton(buttons, Text = "Cancel", ButtonPushedFcn = @(~,~) close(dialog));
uibutton(buttons, Text = "OK", ButtonPushedFcn = @(~,~) accept());

uiwait(dialog);

if ~accepted
    return
end

obj.refreshDatasetMenu();
obj.savePreferences();

if obj.SheetUrl == ""
    obj.setStatus("No sheet configured. The tracker CSV will be used instead.");
else
    obj.setStatus("Sheet tracker set to tab '%s'. Load again to apply it.", obj.SheetTab);
end

    function accept()
        %ACCEPT Take the values from the dialog, once they make sense together.

        url = strtrim(urlField.Value);
        tab = strtrim(tabField.Value);
        key = strtrim(keyField.Value);

        if url ~= ""
            try
                gsheet.spreadsheetId(url);
            catch ME
                status.Text = ME.message;
                return
            end

            if tab == ""
                status.Text = "Name the tab the tracker is on, for example Sections.";
                return
            end

            if key ~= "" && ~isfile(key)
                status.Text = "The key file does not exist: " + key;
                return
            end
        end

        obj.SheetUrl = url;
        obj.SheetTab = tab;
        obj.SheetCredentials = key;

        % The old tracker was built against whatever was configured before, so
        % it is dropped rather than reused under the new settings.
        obj.Tracker = [];

        accepted = true;
        close(dialog);
    end

end

function text = help_text()
%HELP_TEXT What has to be true before any of this can work.

text = "The sheet must be shared with the service account's client_email " + ...
    "address: Viewer to read it, Editor to write back to it. " + ...
    "See README.md, 'Reading the tracker from Google Sheets', for how to " + ...
    "create the service account and download its key." + newline + newline + ...
    "Leave the spreadsheet blank to go back to using a tracker CSV.";

end

function browse_for_key(dialog, keyField)
%BROWSE_FOR_KEY Pick the service account JSON key file.

[f, p] = uigetfile("*.json", "Select service account key file");

% The dialog is modal, and MATLAB drops that behind the main window while a
% file chooser is open, so it is brought back to the front afterwards.
figure(dialog);

if isequal(f, 0)
    return
end

keyField.Value = char(fullfile(p, f));

end

function test_connection(urlField, tabField, keyField, status, testButton)
%TEST_CONNECTION Read the tab and report what came back, or why nothing did.

url = strtrim(urlField.Value);
tab = strtrim(tabField.Value);
key = strtrim(keyField.Value);

if url == "" || key == ""
    status.Text = "Give both a spreadsheet and a key file before testing.";
    return
end

testButton.Enable = "off";
status.Text = "Reading " + tab + "...";
drawnow;

restore = onCleanup(@() set(testButton, Enable = "on"));

try
    tracker = SectionTracker(url, key, sheetName = tab);
    tracker.read();
catch ME
    status.Text = "Could not read the sheet: " + ME.message;
    return
end

text = sprintf("Read %d entries from '%s'. Header on row %d.", ...
    height(tracker.Table), tab, tracker.HeaderRow);

if tracker.hasColumn(tracker.UidColumn)
    identified = sum(strtrim(tracker.column(tracker.UidColumn)) ~= "");
    text = text + sprintf(" %d of them are identified for writing.", identified);
else
    text = text + " Writing needs the two maintained columns; " + ...
        "use Prepare Sheet for Writing to add them.";
end

if ~isempty(tracker.Warnings)
    text = text + newline + strjoin(tracker.Warnings, " ");
end

status.Text = text;

end

function position = center_on(parent, width, height)
%CENTER_ON Place a dialog over the middle of the window that opened it.

position = [0 0 width height];

if isempty(parent) || ~isvalid(parent)
    position(1:2) = [100 100];
    return
end

parentPosition = parent.Position;
position(1) = parentPosition(1) + (parentPosition(3) - width) / 2;
position(2) = parentPosition(2) + (parentPosition(4) - height) / 2;

end
