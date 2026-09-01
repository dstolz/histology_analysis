function buildUI(obj)
%BUILDUI Build the figure, the Dataset menu, the browse/view split, and the status bar.

obj.Fig = uifigure( ...
    Name = "Histology Image Browser", ...
    Position = [80 60 1500 880]);

obj.buildDatasetMenu();

% Menu accelerators do not fire in a uifigure, so every keyboard shortcut this
% window offers is bound on the figure itself. KEYBINDINGS holds the table and
% ONFIGUREKEYPRESS does the matching.
obj.Fig.WindowKeyPressFcn = @(~, evt) obj.onFigureKeyPress(evt);

% Closing is the one moment the window's own geometry is worth recording, and
% the only save the app would otherwise miss.
obj.Fig.CloseRequestFcn = @(~, ~) obj.onCloseRequest();

obj.MainGrid = uigridlayout(obj.Fig, [2 1]);
obj.MainGrid.RowHeight = {"1x", "fit"};
obj.MainGrid.ColumnWidth = {"1x"};
obj.MainGrid.Padding = [8 8 8 8];
obj.MainGrid.RowSpacing = 6;

obj.ContentGrid = uigridlayout(obj.MainGrid, [1 2]);
obj.ContentGrid.Layout.Row = 1;
obj.ContentGrid.ColumnWidth = {obj.BrowseColumnWidth, "1x"};
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

% Kept as a property rather than a local, because APPLYCONFIGVISIBILITY collapses
% its first row to hide the display controls.
obj.ViewColumnGrid = uigridlayout(obj.ContentGrid, [2 1]);
obj.ViewColumnGrid.Layout.Column = 2;
obj.ViewColumnGrid.RowHeight = {"fit", "1x"};
obj.ViewColumnGrid.ColumnWidth = {"1x"};
obj.ViewColumnGrid.Padding = [0 0 0 0];
obj.ViewColumnGrid.RowSpacing = 6;

obj.buildDisplayPanel(obj.ViewColumnGrid);
obj.buildViewPanel(obj.ViewColumnGrid);

% The Display menu mirrors the panel's controls, so it is built once they
% exist. It sits between Dataset and View, which is the order the menus were
% added in.
obj.buildDisplayMenu(obj.Fig);
obj.buildViewMenu();

% Help sits last on the bar, and its shortcut item is named through
% SHORTCUTHINT, so it is built once the bindings it reads from are reachable.
obj.buildHelpMenu();

% Built last so every panel exists before the first status message is written.
obj.buildStatusBar(obj.MainGrid);

% Nothing starts hidden, but the View menu's check marks say what is on screen,
% and only now do the grids they resize exist to be asked.
obj.applyPanelVisibility();

end
