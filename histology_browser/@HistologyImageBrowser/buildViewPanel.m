function buildViewPanel(obj, parent)
%BUILDVIEWPANEL Build the image tile area and the linked profile axes.
% Both panels live in a 2x2 grid; APPLYVIEWLAYOUT decides which cells they
% occupy and how much room each one gets.
%
% The right-click menus these plots hand out are not built here, even though
% this is where the plots are made. They mirror the Display panel through the
% same list the Display menu registers with, and BUILDDISPLAYMENU empties that
% list when it runs, which is after this function; BUILDPLOTCONTEXTMENUS is
% therefore built on demand when the first tile is drawn instead.
%
% See also APPLYVIEWLAYOUT, BUILDPLOTCONTEXTMENUS, RENDERSELECTION.

obj.ViewGrid = uigridlayout(parent, [2 2]);
obj.ViewGrid.Layout.Row = 2;
obj.ViewGrid.RowHeight = {"2x", "1x"};
obj.ViewGrid.ColumnWidth = {"1x", "1x"};
obj.ViewGrid.Padding = [0 0 0 0];
obj.ViewGrid.RowSpacing = 6;
obj.ViewGrid.ColumnSpacing = 6;

obj.ImagePanel = uipanel(obj.ViewGrid, Title = "Images");
obj.ProfilePanel = uipanel(obj.ViewGrid, Title = "Profiles");

% The panel's own default is taken as the starting background so the app opens
% looking as it did before the color could be chosen; LOADPREFERENCES replaces
% it when an earlier session picked something else.
obj.ImageBackground = obj.ImagePanel.BackgroundColor;
obj.applyImageBackground();

profileGrid = uigridlayout(obj.ProfilePanel, [1 1]);
profileGrid.Padding = [4 4 4 4];

obj.ProfileAxes = uiaxes(profileGrid);
obj.ProfileAxes.Layout.Row = 1;
obj.ProfileAxes.Layout.Column = 1;
xlabel(obj.ProfileAxes, "distance along line (\mum)");
ylabel(obj.ProfileAxes, "intensity");
grid(obj.ProfileAxes, "on");
box(obj.ProfileAxes, "on");

obj.applyViewLayout();

end
