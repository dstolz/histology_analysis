function buildCatalogTable(obj, parent)
%BUILDCATALOGTABLE Build the results table and its navigation buttons.

panel = uipanel(parent, Title = "Sections");
panel.Layout.Row = 2;

grid = uigridlayout(panel, [2 4]);
grid.RowHeight = {"1x", "fit"};
grid.ColumnWidth = {"1x", "1x", "1x", "1x"};
grid.Padding = [8 8 8 8];
grid.RowSpacing = 4;

% Column sorting is left off deliberately: the row order shown must stay
% identical to the row order of obj.View so a selection index always maps back
% to the right section. Ordering is offered through the Sort by control, which
% sorts obj.View itself.
obj.CatalogTable = uitable(grid, ...
    Data = table(), ...
    ColumnSortable = false, ...
    RowName = [], ...
    SelectionType = "row", ...
    Multiselect = "on", ...
    SelectionChangedFcn = @(~,~) obj.onSelectionChanged());
obj.CatalogTable.Layout.Row = 1;
obj.CatalogTable.Layout.Column = [1 4];

obj.PreviousButton = uibutton(grid, "push", ...
    Text = "< Prev", ...
    ButtonPushedFcn = @(~,~) obj.onStepSelection(-1));
obj.PreviousButton.Layout.Row = 2;
obj.PreviousButton.Layout.Column = 1;

obj.NextButton = uibutton(grid, "push", ...
    Text = "Next >", ...
    ButtonPushedFcn = @(~,~) obj.onStepSelection(1));
obj.NextButton.Layout.Row = 2;
obj.NextButton.Layout.Column = 2;

obj.SelectAllButton = uibutton(grid, "push", ...
    Text = "Select All", ...
    ButtonPushedFcn = @(~,~) obj.onSelectAll());
obj.SelectAllButton.Layout.Row = 2;
obj.SelectAllButton.Layout.Column = 3;

obj.OpenFolderButton = uibutton(grid, "push", ...
    Text = "Open Folder", ...
    ButtonPushedFcn = @(~,~) obj.onOpenFolder());
obj.OpenFolderButton.Layout.Row = 2;
obj.OpenFolderButton.Layout.Column = 4;

end
