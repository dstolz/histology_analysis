function buildCatalogTable(obj, parent)
%BUILDCATALOGTABLE Build the results table and its navigation buttons.

panel = uipanel(parent, Title = "Sections");
panel.Layout.Row = 2;

grid = uigridlayout(panel, [2 5]);
grid.RowHeight = {"1x", "fit"};
grid.ColumnWidth = {"1x", "1x", "1x", "1x", "1x"};
grid.Padding = [8 8 8 8];
grid.RowSpacing = 4;
grid.ColumnSpacing = 4;

% Column sorting is on, and the invariant it used to be off to protect is kept
% a different way. obj.Selection holds indices into obj.View, so a widget
% showing the rows in some order of its own would make every one of those
% indices name the wrong section. ONCATALOGDISPLAYCHANGED stops that happening
% by taking the order the user sorted into and applying it to obj.View itself,
% then rewriting the table from the reordered view: Data and DisplayData always
% hold the same rows in the same order, so an index into either names the same
% section and nothing downstream has to know a sort happened.
%
% Ordering is still offered through the Sort by control as well, which sorts
% obj.View directly. The two are the same mechanism seen from two ends -- both
% end as an order of obj.View -- and APPLYFILTERS decides between them: the
% preset moving clears the column sort, and otherwise the column sort leads
% with the preset breaking its ties.
obj.CatalogTable = uitable(grid, ...
    Data = table(), ...
    ColumnSortable = true, ...
    RowName = [], ...
    SelectionType = "row", ...
    Multiselect = "on", ...
    SelectionChangedFcn = @(~,~) obj.onSelectionChanged(), ...
    DisplayDataChangedFcn = @(~,~) obj.onCatalogDisplayChanged());
obj.CatalogTable.Layout.Row = 1;
obj.CatalogTable.Layout.Column = [1 5];

obj.PreviousButton = uibutton(grid, "push", ...
    Text = "< Prev", ...
    ButtonPushedFcn = @(~,~) obj.onStepSelection(-1));
obj.PreviousButton.Layout.Row = 2;
obj.PreviousButton.Layout.Column = 1;
obj.PreviousButton.Tooltip = "Move the selection up one section." ...
    + obj.shortcutHint("previousSection");

obj.NextButton = uibutton(grid, "push", ...
    Text = "Next >", ...
    ButtonPushedFcn = @(~,~) obj.onStepSelection(1));
obj.NextButton.Layout.Row = 2;
obj.NextButton.Layout.Column = 2;
obj.NextButton.Tooltip = "Move the selection down one section." ...
    + obj.shortcutHint("nextSection");

obj.SelectAllButton = uibutton(grid, "push", ...
    Text = "Select All", ...
    ButtonPushedFcn = @(~,~) obj.onSelectAll());
obj.SelectAllButton.Layout.Row = 2;
obj.SelectAllButton.Layout.Column = 3;
obj.SelectAllButton.Tooltip = "Select every section passing the filters." ...
    + obj.shortcutHint("selectAll");

obj.OpenFolderButton = uibutton(grid, "push", ...
    Text = "Open Folder", ...
    ButtonPushedFcn = @(~,~) obj.onOpenFolder());
obj.OpenFolderButton.Layout.Row = 2;
obj.OpenFolderButton.Layout.Column = 4;
obj.OpenFolderButton.Tooltip = "Reveal the folder holding the marked section's image." ...
    + obj.shortcutHint("openFolder");

% Sat beside the table rather than on a menu because it acts on this table and
% nothing else, and because the headings it rearranges are the thing a user is
% looking at when they decide they want it.
obj.ArrangeColumnsButton = uibutton(grid, "push", ...
    Text = "Columns...", ...
    ButtonPushedFcn = @(~,~) obj.onArrangeColumns());
obj.ArrangeColumnsButton.Layout.Row = 2;
obj.ArrangeColumnsButton.Layout.Column = 5;
obj.ArrangeColumnsButton.Tooltip = "Choose which columns this table shows, and in what order.";

end
