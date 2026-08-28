function buildFilterPanel(obj, parent)
%BUILDFILTERPANEL Build the search box and the multi-select filter lists.

panel = uipanel(parent, Title = "Look Up");
panel.Layout.Row = 1;

grid = uigridlayout(panel, [5 4]);
grid.RowHeight = {"fit", "fit", 132, "fit", "fit"};

% Subject IDs are long enough to clip at an even split, while hemisphere and
% plate labels never need more than a few characters, so the columns are
% weighted to match the widest label each list has to show.
grid.ColumnWidth = {"1.7x", "0.9x", "1.2x", "0.9x"};
grid.Padding = [10 10 10 10];
grid.RowSpacing = 6;
grid.ColumnSpacing = 8;

obj.SearchField = uieditfield(grid, "text", ...
    Placeholder = "Search subject, section, stain, notes...", ...
    ValueChangedFcn = @(~,~) obj.applyFilters());
obj.SearchField.Layout.Row = 1;
obj.SearchField.Layout.Column = [1 4];
obj.SearchField.Tooltip = "Space-separated terms; a row must match every term." ...
    + obj.shortcutHint("focusSearch");

headers = ["Subject", "Hemisphere", "Stain", "Atlas plate"];

for iHeader = 1:numel(headers)
    label = uilabel(grid, ...
        Text = headers(iHeader), ...
        FontWeight = "bold", ...
        HorizontalAlignment = "left");
    label.Layout.Row = 2;
    label.Layout.Column = iHeader;
end

obj.SubjectList = make_filter_list(obj, grid, 1);
obj.HemisphereList = make_filter_list(obj, grid, 2);
obj.StainList = make_filter_list(obj, grid, 3);
obj.PlateList = make_filter_list(obj, grid, 4);

obj.ProfileOnlyCheck = uicheckbox(grid, ...
    Text = "Only with profiles", ...
    ValueChangedFcn = @(~,~) obj.applyFilters());
obj.ProfileOnlyCheck.Layout.Row = 4;
obj.ProfileOnlyCheck.Layout.Column = [1 2];

label = uilabel(grid, Text = "Sort by", HorizontalAlignment = "right");
label.Layout.Row = 4;
label.Layout.Column = 3;

obj.SortDropDown = uidropdown(grid, ...
    Items = ["Subject, section", "Atlas plate", "Stain", "Status"], ...
    ItemsData = {"section", "plate", "stain", "status"}, ...
    Value = "section", ...
    ValueChangedFcn = @(~,~) obj.applyFilters());
obj.SortDropDown.Layout.Row = 4;
obj.SortDropDown.Layout.Column = 4;

obj.CountLabel = uilabel(grid, ...
    Text = "No dataset loaded.", ...
    VerticalAlignment = "center");
obj.CountLabel.Layout.Row = 5;
obj.CountLabel.Layout.Column = [1 3];

obj.ResetFiltersButton = uibutton(grid, "push", ...
    Text = "Reset", ...
    ButtonPushedFcn = @(~,~) obj.onResetFilters());
obj.ResetFiltersButton.Layout.Row = 5;
obj.ResetFiltersButton.Layout.Column = 4;
obj.ResetFiltersButton.Tooltip = "Clear every filter and show the whole catalog." ...
    + obj.shortcutHint("resetFilters");

end

function list = make_filter_list(obj, grid, column)
%MAKE_FILTER_LIST Create one multi-select filter list box.

list = uilistbox(grid, ...
    Items = {}, ...
    Multiselect = "on", ...
    ValueChangedFcn = @(~,~) obj.applyFilters());
list.Layout.Row = 3;
list.Layout.Column = column;
list.Tooltip = "Select none to include everything.";

end
