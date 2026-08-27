function buildViewPanel(obj, parent)
%BUILDVIEWPANEL Build the image tile area and the linked profile axes.
% Both panels live in a 2x2 grid; APPLYVIEWLAYOUT decides which cells they
% occupy and how much room each one gets.

obj.ViewGrid = uigridlayout(parent, [2 2]);
obj.ViewGrid.Layout.Row = 2;
obj.ViewGrid.RowHeight = {"2x", "1x"};
obj.ViewGrid.ColumnWidth = {"1x", "1x"};
obj.ViewGrid.Padding = [0 0 0 0];
obj.ViewGrid.RowSpacing = 6;
obj.ViewGrid.ColumnSpacing = 6;

obj.ImagePanel = uipanel(obj.ViewGrid, Title = "Images");
obj.ProfilePanel = uipanel(obj.ViewGrid, Title = "Profiles");

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
