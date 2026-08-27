function buildUI(obj)
%BUILDUI Build the figure, the Dataset menu, the browse/view split, and the status bar.

obj.Fig = uifigure( ...
    Name = "Histology Image Browser", ...
    Position = [80 60 1500 880]);

obj.buildDatasetMenu();

obj.MainGrid = uigridlayout(obj.Fig, [2 1]);
obj.MainGrid.RowHeight = {"1x", "fit"};
obj.MainGrid.ColumnWidth = {"1x"};
obj.MainGrid.Padding = [8 8 8 8];
obj.MainGrid.RowSpacing = 6;

obj.ContentGrid = uigridlayout(obj.MainGrid, [1 2]);
obj.ContentGrid.Layout.Row = 1;
obj.ContentGrid.ColumnWidth = {460, "1x"};
obj.ContentGrid.RowHeight = {"1x"};
obj.ContentGrid.Padding = [0 0 0 0];
obj.ContentGrid.ColumnSpacing = 8;

obj.BrowseGrid = uigridlayout(obj.ContentGrid, [2 1]);
obj.BrowseGrid.Layout.Column = 1;
obj.BrowseGrid.RowHeight = {"fit", "1x"};
obj.BrowseGrid.ColumnWidth = {"1x"};
obj.BrowseGrid.Padding = [0 0 0 0];
obj.BrowseGrid.RowSpacing = 6;

obj.buildFilterPanel(obj.BrowseGrid);
obj.buildCatalogTable(obj.BrowseGrid);

viewColumn = uigridlayout(obj.ContentGrid, [2 1]);
viewColumn.Layout.Column = 2;
viewColumn.RowHeight = {"fit", "1x"};
viewColumn.ColumnWidth = {"1x"};
viewColumn.Padding = [0 0 0 0];
viewColumn.RowSpacing = 6;

obj.buildDisplayPanel(viewColumn);
obj.buildViewPanel(viewColumn);

% Built last so every panel exists before the first status message is written.
obj.buildStatusBar(obj.MainGrid);

end
