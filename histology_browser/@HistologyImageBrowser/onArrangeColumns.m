function onArrangeColumns(obj)
%ONARRANGECOLUMNS Choose which Sections columns are shown, and in what order.
% A dialog rather than dragging the headers. uitable does have a
% RearrangeableColumns property, but it is hidden and undocumented, and a
% column order the user could only set by dragging would be an order this code
% could not read back reliably enough to save. Two lists and four buttons are
% duller and are the whole feature: what is shown, in what order, kept across
% sessions.
%
% The choice is handed to APPLYCATALOGCOLUMNS rather than applied here, so
% everything except the window itself is reachable without one -- which is what
% lets the arrangement be restored at startup and checked by a test that must
% never meet a UIWAIT.
%
% See also APPLYCATALOGCOLUMNS, CATALOGDISPLAYTABLE, BUILDCATALOGTABLE,
% ONREPORTISSUE.

fields = HistologyImageBrowser.CatalogColumnFields;
headings = HistologyImageBrowser.CatalogColumnHeadings;

shown = obj.CatalogColumns;
hidden = fields(~ismember(fields, shown));

dlg = uifigure( ...
    Name = "Sections Columns", ...
    Position = center_on(obj.Fig, [640 460]));

% A release that will not make a uifigure modal still shows the dialog; the
% wait below is what actually holds the caller either way.
try
    dlg.WindowStyle = "modal";
catch
end

grid = uigridlayout(dlg, [4 3]);
grid.RowHeight = {"fit", "fit", "1x", "fit"};
grid.ColumnWidth = {"1x", 120, "1x"};
grid.Padding = [10 10 10 10];

intro = uilabel(grid, WordWrap = "on", ...
    Text = "Choose the columns the Sections table shows and the order it shows " + ...
    "them in. The arrangement is remembered for the next session, and sorting " + ...
    "by clicking a heading keeps working whichever columns are on.");
intro.Layout.Row = 1;
intro.Layout.Column = [1 3];

shownLabel = uilabel(grid, Text = "Shown, left to right", FontWeight = "bold");
shownLabel.Layout.Row = 2;
shownLabel.Layout.Column = 1;

hiddenLabel = uilabel(grid, Text = "Available", FontWeight = "bold");
hiddenLabel.Layout.Row = 2;
hiddenLabel.Layout.Column = 3;

shownList = uilistbox(grid, Items = {});
shownList.Layout.Row = 3;
shownList.Layout.Column = 1;

hiddenList = uilistbox(grid, Items = {});
hiddenList.Layout.Row = 3;
hiddenList.Layout.Column = 3;

middle = uigridlayout(grid, [5 1]);
middle.Layout.Row = 3;
middle.Layout.Column = 2;
middle.RowHeight = {"fit", "fit", "fit", "fit", "1x"};
middle.Padding = [0 0 0 0];
middle.RowSpacing = 6;

upButton = uibutton(middle, "push", Text = "Move Up", ...
    ButtonPushedFcn = @(~,~) move(-1));
upButton.Layout.Row = 1;

downButton = uibutton(middle, "push", Text = "Move Down", ...
    ButtonPushedFcn = @(~,~) move(1));
downButton.Layout.Row = 2;

hideButton = uibutton(middle, "push", Text = "Hide >>", ...
    ButtonPushedFcn = @(~,~) hide_column());
hideButton.Layout.Row = 3;

showButton = uibutton(middle, "push", Text = "<< Show", ...
    ButtonPushedFcn = @(~,~) show_column());
showButton.Layout.Row = 4;

bottom = uigridlayout(grid, [1 4]);
bottom.Layout.Row = 4;
bottom.Layout.Column = [1 3];
bottom.ColumnWidth = {"fit", "1x", 100, 100};
bottom.Padding = [0 0 0 0];

defaultsButton = uibutton(bottom, "push", Text = "Restore Defaults", ...
    ButtonPushedFcn = @(~,~) restore_defaults());
defaultsButton.Layout.Column = 1;

cancelButton = uibutton(bottom, "push", Text = "Cancel", ...
    ButtonPushedFcn = @(~,~) finish(false));
cancelButton.Layout.Column = 3;

applyButton = uibutton(bottom, "push", Text = "Apply", ...
    ButtonPushedFcn = @(~,~) finish(true));
applyButton.Layout.Column = 4;

% Cancel is what a closed window means, so the outcome is held here and the
% close request writes to it exactly as the button does.
outcome = struct(accepted = false);

dlg.CloseRequestFcn = @(~,~) finish(false);

refresh("", "");

uiwait(dlg);

if ~outcome.accepted
    obj.setStatus("Column arrangement unchanged.");
    return
end

obj.applyCatalogColumns(shown);

    function refresh(shownPick, hiddenPick)
        %REFRESH Redraw both lists, keeping a named row selected in each.
        % The lists are rebuilt on every move rather than edited in place, so
        % there is one description of what each holds instead of two that have
        % to be kept agreeing.

        fill_list(shownList, shown, shownPick);
        fill_list(hiddenList, hidden, hiddenPick);

        % The table has to show something, so the last shown column cannot be
        % taken away.
        if numel(shown) > 1
            hideButton.Enable = "on";
        else
            hideButton.Enable = "off";
        end
    end

    function fill_list(list, columns, pick)
        %FILL_LIST Put one set of columns in a list box under their headings.
        % The data is emptied before the items are replaced, because a list box
        % refuses a set of items that its existing data no longer matches one
        % for one.

        list.ItemsData = {};

        if isempty(columns)
            list.Items = {};

            return
        end

        [~, at] = ismember(columns, fields);

        list.Items = headings(at);
        list.ItemsData = cellstr(columns);

        if pick ~= "" && ismember(pick, columns)
            list.Value = char(pick);
        end
    end

    function move(step)
        %MOVE Slide the picked column one place up or down the shown list.

        picked = picked_column(shownList);

        if picked == ""
            return
        end

        at = find(shown == picked, 1);
        to = at + step;

        if to < 1 || to > numel(shown)
            return
        end

        shown([at to]) = shown([to at]);

        refresh(picked, picked_column(hiddenList));
    end

    function hide_column()
        %HIDE_COLUMN Take the picked column out of the table.

        picked = picked_column(shownList);

        if picked == "" || numel(shown) < 2
            return
        end

        shown = shown(shown ~= picked);

        % Put back in the column list's own order rather than at the end, so
        % the available list reads the same however the user got there.
        hidden = fields(ismember(fields, [hidden, picked]));

        refresh("", picked);
    end

    function show_column()
        %SHOW_COLUMN Add the picked column to the right of the table.

        picked = picked_column(hiddenList);

        if picked == ""
            return
        end

        hidden = hidden(hidden ~= picked);
        shown = [shown, picked];

        refresh(picked, "");
    end

    function restore_defaults()
        %RESTORE_DEFAULTS Go back to the eight columns the table opens with.

        shown = HistologyImageBrowser.DefaultCatalogColumns;
        hidden = fields(~ismember(fields, shown));

        refresh("", "");
    end

    function finish(accepted)
        %FINISH Record the choice and release the wait.

        outcome.accepted = accepted;

        delete(dlg);
    end

end

function picked = picked_column(list)
%PICKED_COLUMN Catalog column a list box has selected, or "" for none.
% An empty list has no value at all, and a list box carrying ItemsData reports
% the data rather than the heading, so both are normalized here instead of at
% each of the four buttons.

picked = "";

if isempty(list.Items) || isempty(list.Value)
    return
end

picked = string(list.Value);

end

function position = center_on(parent, size)
%CENTER_ON Place a dialog over the window it belongs to.
% A dialog that opens on the primary monitor while the app sits on a second one
% is easy to miss entirely.

position = [100 100 size];

if isempty(parent) || ~isvalid(parent)
    return
end

anchor = parent.Position;
position(1:2) = anchor(1:2) + (anchor(3:4) - size) / 2;

end
