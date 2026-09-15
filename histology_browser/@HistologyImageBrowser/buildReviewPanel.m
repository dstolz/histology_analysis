function buildReviewPanel(obj, parent)
%BUILDREVIEWPANEL Build the controls that write review findings to the tracker.
% Sits under the catalog table because that is where the selection is made, and
% everything here acts on the selection. It is the only part of the window that
% changes a document other people are editing, so it says what it is going to
% touch and stays disabled until it can do so safely.
%
% See also HISTOLOGYIMAGEBROWSER/ONSETATLASPLATE,
% HISTOLOGYIMAGEBROWSER/ONSETMEASURED, SECTIONTRACKER.

panel = uipanel(parent, Title = "Review");
panel.Layout.Row = 3;

grid = uigridlayout(panel, [2 5]);
grid.RowHeight = {"fit", "fit"};
grid.ColumnWidth = {"fit", 60, 60, "1x", "fit"};
grid.Padding = [8 8 8 8];
grid.RowSpacing = 4;
grid.ColumnSpacing = 4;

place(uilabel(grid, Text = "Atlas plate"), 1, 1);

% A text field rather than a numeric one, because a plate number that turns out
% to be wrong has to be removable, and a numeric field has no way to say empty.
obj.AtlasPlateField = uieditfield(grid, "text", ...
    ValueChangedFcn = @(~,~) obj.onSetAtlasPlate());
place(obj.AtlasPlateField, 1, 2);
obj.AtlasPlateField.Tooltip = "Atlas plate number for the selected sections. " + ...
    "Press Enter or Set to write it to the tracker; clear it to empty the cell.";

obj.SetAtlasPlateButton = uibutton(grid, "push", ...
    Text = "Set", ...
    ButtonPushedFcn = @(~,~) obj.onSetAtlasPlate());
place(obj.SetAtlasPlateButton, 1, 3);
obj.SetAtlasPlateButton.Tooltip = "Write the plate number above to every selected section.";

obj.MeasuredButton = uibutton(grid, "push", ...
    Text = "Mark Measured", ...
    ButtonPushedFcn = @(~,~) obj.onSetMeasured(true));
place(obj.MeasuredButton, 1, 4);
obj.MeasuredButton.Tooltip = "Record that the selected sections have been measured." ...
    + obj.shortcutHint("toggleMeasured");

obj.ClearMeasuredButton = uibutton(grid, "push", ...
    Text = "Clear", ...
    ButtonPushedFcn = @(~,~) obj.onSetMeasured(false));
place(obj.ClearMeasuredButton, 1, 5);
obj.ClearMeasuredButton.Tooltip = "Empty the Measured cell of the selected sections.";

% Says which sections would be written to, and why the buttons are off when
% they are. Without it the panel would sit greyed out with no explanation, and
% the reasons are not guessable: no sheet, no key file, or a section the
% tracker has no row for.
obj.ReviewLabel = uilabel(grid, Text = "", WordWrap = "on");
place(obj.ReviewLabel, 2, [1 5]);
obj.ReviewLabel.FontColor = [0.35 0.35 0.35];

end

function place(component, row, column)
%PLACE Assign an explicit grid position to a component.

component.Layout.Row = row;
component.Layout.Column = column;

end
