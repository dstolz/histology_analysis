function buildStatusBar(obj, parent)
%BUILDSTATUSBAR Build the message strip that runs along the bottom of the window.
% The bar is always visible so progress, warnings, and failures land in one
% predictable place instead of only in modal dialogs. Severity is carried by the
% lamp, the text color, and a tint on the bar itself; the tooltip keeps the last
% few messages so a status that scrolls past is still recoverable.

obj.StatusBar = uipanel(parent, BorderType = "line");
obj.StatusBar.Layout.Row = 2;

grid = uigridlayout(obj.StatusBar, [1 3]);
grid.RowHeight = {"fit"};
grid.ColumnWidth = {18, "1x", "fit"};
grid.Padding = [8 2 8 2];
grid.ColumnSpacing = 6;

obj.StatusLamp = uilabel(grid, Text = HistologyImageBrowser.StatusGlyphs(1));
obj.StatusLamp.Layout.Row = 1;
obj.StatusLamp.Layout.Column = 1;
obj.StatusLamp.FontSize = 13;
obj.StatusLamp.HorizontalAlignment = "center";

obj.StatusLabel = uilabel(grid, Text = "");
obj.StatusLabel.Layout.Row = 1;
obj.StatusLabel.Layout.Column = 2;

obj.StatusDetail = uilabel(grid, Text = "");
obj.StatusDetail.Layout.Row = 1;
obj.StatusDetail.Layout.Column = 3;
obj.StatusDetail.HorizontalAlignment = "right";
obj.StatusDetail.FontColor = [0.45 0.45 0.45];
obj.StatusDetail.Tooltip = "Time of the most recent status message.";

obj.setStatus("Idle. Choose Dataset > Root Folder, then Dataset > Load Dataset.");

end
