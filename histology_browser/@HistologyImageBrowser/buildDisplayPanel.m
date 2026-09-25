function buildDisplayPanel(obj, parent)
%BUILDDISPLAYPANEL Build the rendition, overlay, profile, and ROI controls.
% The controls are grouped the way the Display menu and the tile's right-click
% menu group them -- Image, Overlays, Profiles, then the ROI and brain surface
% editing that writes to disk -- one group to a row, named in a column of
% headings down the left edge, so the panel, the menu, and the context menu
% read as the same list.
%
% Each row is a grid of its own rather than a slice of one grid the whole panel
% shares. A group sizes its own controls, and a control added to one row cannot
% move anything in another. Text that changes with the selection sits in a
% "1x" column, never a "fit" one: a "fit" column grows with its text, and a
% long section stem in one used to push the right end of the panel off the
% edge of the window.
%
% See also BUILDDISPLAYMENU, BUILDPLOTCONTEXTMENUS, UPDATEROIEDITCONTROLS.

panel = uipanel(parent, Title = "Display");
panel.Layout.Row = 1;

grid = uigridlayout(panel, [6 2]);
grid.RowHeight = repmat({"fit"}, 1, 6);
grid.ColumnWidth = {"fit", "1x"};
grid.Padding = [8 6 8 6];
grid.RowSpacing = 4;
grid.ColumnSpacing = 10;

build_image_row(obj, group(grid, 1, "Image"));
build_overlay_row(obj, group(grid, 2, "Overlays"));
build_profile_row(obj, group(grid, 3, "Profiles"));
build_roi_rows(obj, group(grid, 4, "ROI"), group(grid, 5, ""));
build_surface_row(obj, group(grid, 6, "Surface"));

end

function build_image_row(obj, row)
%BUILD_IMAGE_ROW Build the controls that decide the pixels in each tile.
% Everything here rebuilds the tiles when it changes, which is what sets it
% apart from the overlay switches on the row below.

row.ColumnWidth = {100, "fit", 110, "fit", 85, "fit", 50, 50, "fit", 100, "fit", 45, "1x"};

% First in the row and unlabelled, because the heading beside it already says
% what it chooses.
obj.VariantDropDown = uidropdown(row, ...
    Items = ["Projection", "Mid plane", "Composite", "Raw"], ...
    ItemsData = {"proj", "mid", "composite", "raw"}, ...
    Value = "proj", ...
    ValueChangedFcn = @(~,~) obj.onDisplayOptionChanged());
place(obj.VariantDropDown, 1, 1);
obj.VariantDropDown.Tooltip = "Which rendition of each section to display.";

place(uilabel(row, Text = "Channel"), 1, 2);

obj.ChannelDropDown = uidropdown(row, ...
    Items = "Channel 1", ...
    ItemsData = {1}, ...
    ValueChangedFcn = @(~,~) obj.onDisplayOptionChanged());
place(obj.ChannelDropDown, 1, 3);
obj.ChannelDropDown.Tooltip = "Page of a multi-channel TIFF, or an RGB merge of the first channels.";

place(uilabel(row, Text = "Colormap"), 1, 4);

obj.ColormapDropDown = uidropdown(row, ...
    Items = ["gray", "bone", "hot", "parula", "turbo", "green", "magenta"], ...
    Value = "gray", ...
    ValueChangedFcn = @(~,~) obj.onColormapChanged());
place(obj.ColormapDropDown, 1, 5);
obj.ColormapDropDown.Tooltip = "Colormap for single channel images. " + ...
    "The choice is remembered for the stain on screen and comes back with it.";

place(uilabel(row, Text = "Contrast %"), 1, 6);

obj.LowPercentileField = uieditfield(row, "numeric", ...
    Value = 0.5, ...
    Limits = [0 100], ...
    ValueChangedFcn = @(~,~) obj.onDisplayOptionChanged());
place(obj.LowPercentileField, 1, 7);
obj.LowPercentileField.Tooltip = "Lower display percentile.";

obj.HighPercentileField = uieditfield(row, "numeric", ...
    Value = 99.7, ...
    Limits = [0 100], ...
    ValueChangedFcn = @(~,~) obj.onDisplayOptionChanged());
place(obj.HighPercentileField, 1, 8);
obj.HighPercentileField.Tooltip = "Upper display percentile.";

% A section on a dark ground reads very differently from the same section on a
% white one, so the backdrop the tiles sit on is a display choice like the
% colormap rather than a fixed part of the window.
place(uilabel(row, Text = "Background"), 1, 9);

% The list itself is filled with the color in use, so it doubles as the swatch.
% SYNCBACKGROUNDCONTROLS owns Items, ItemsData, and Value from here on.
obj.BackgroundDropDown = uidropdown(row, ...
    Items = obj.BackgroundNames, ...
    ItemsData = num2cell(obj.BackgroundCodes), ...
    Value = "lightgray", ...
    ValueChangedFcn = @(~,~) obj.onImageBackgroundChanged());
place(obj.BackgroundDropDown, 1, 10);
obj.BackgroundDropDown.Tooltip = "Color behind the image tiles.";

place(uilabel(row, Text = "Max tiles"), 1, 11);

obj.MaxTilesField = uieditfield(row, "numeric", ...
    Value = 12, ...
    Limits = [1 64], ...
    RoundFractionalValues = "on", ...
    ValueChangedFcn = @(~,~) obj.onDisplayOptionChanged());
place(obj.MaxTilesField, 1, 12);
obj.MaxTilesField.Tooltip = "Upper bound on images drawn at once; extra selections are reported, not drawn.";

end

function build_overlay_row(obj, row)
%BUILD_OVERLAY_ROW Build the overlay switches, and the ways out of the window.
% The switches are in the order the tile's right-click menu lists them. The
% three buttons at the right end take the view somewhere else -- a figure, an
% image file, Fiji -- and sit here because this is the row with room for them:
% five checkboxes leave half of it free, and a row of their own would cost the
% tiles its height.

row.ColumnWidth = {"fit", "fit", "fit", "fit", "fit", "1x", 105, 90, 90};
row.ColumnSpacing = 12;

obj.ShowRoiCheck = uicheckbox(row, ...
    Text = "Line ROI", ...
    Value = true, ...
    ValueChangedFcn = @(~,~) obj.onDisplayOptionChanged());
place(obj.ShowRoiCheck, 1, 1);
obj.ShowRoiCheck.Tooltip = "Draw the Fiji line ROI used to sample the profile." ...
    + obj.shortcutHint("toggleRoiOverlay");

obj.ShowBandCheck = uicheckbox(row, ...
    Text = "Sampling band", ...
    Value = true, ...
    ValueChangedFcn = @(~,~) obj.onDisplayOptionChanged());
place(obj.ShowBandCheck, 1, 2);
obj.ShowBandCheck.Tooltip = "Outline the full line width the profile averages over." ...
    + obj.shortcutHint("toggleBandOverlay");

obj.ColorByIntensityCheck = uicheckbox(row, ...
    Text = "Shade ROI by intensity", ...
    Value = true, ...
    ValueChangedFcn = @(~,~) obj.onDisplayOptionChanged());
place(obj.ColorByIntensityCheck, 1, 3);
obj.ColorByIntensityCheck.Tooltip = "Color the ROI using the matching *values.csv intensities." ...
    + obj.shortcutHint("toggleIntensityShading");

% The grid rules the band in the band's own frame, for any ROI on the view
% rather than only the one being edited, so it is an overlay switch like the
% others even though it is mostly wanted while a line is being placed.
obj.ShowBandGridCheck = uicheckbox(row, ...
    Text = "Band grid", ...
    Value = false, ...
    ValueChangedFcn = @(~,~) obj.onDisplayOptionChanged());
place(obj.ShowBandGridCheck, 1, 4);
obj.ShowBandGridCheck.Tooltip = "Rule the sampling band parallel and square to the line, " + ...
    "to check it against a layer boundary. Needs the band itself shown.";

% The one overlay switch with a callback of its own, because it is the one
% drawn on the profile plot as well as on the tiles.
obj.ShowSurfaceCheck = uicheckbox(row, ...
    Text = "Brain surface", ...
    Value = true, ...
    ValueChangedFcn = @(~,~) obj.onSurfaceOverlayChanged());
place(obj.ShowSurfaceCheck, 1, 5);
obj.ShowSurfaceCheck.Tooltip = "Tick each line where its brain surface was marked, " + ...
    "and rule the profile plot at the same depth." ...
    + obj.shortcutHint("toggleSurfaceOverlay");

obj.NewFigureButton = uibutton(row, "push", ...
    Text = "Open in Figure", ...
    ButtonPushedFcn = @(~,~) obj.onOpenInFigure());
place(obj.NewFigureButton, 1, 7);
obj.NewFigureButton.Tooltip = "Redraw the current view in a normal figure." ...
    + obj.shortcutHint("openInFigure");

obj.ExportButton = uibutton(row, "push", ...
    Text = "Export View", ...
    ButtonPushedFcn = @(~,~) obj.onExportView());
place(obj.ExportButton, 1, 8);
obj.ExportButton.Tooltip = "Save the current view to an image file." ...
    + obj.shortcutHint("exportView");

% It acts on the marked section alone, as Open Folder does, because Fiji opens
% images one window each and a selection of twelve would be twelve.
obj.FijiButton = uibutton(row, "push", ...
    Text = "Open in Fiji", ...
    ButtonPushedFcn = @(~,~) obj.onOpenInFiji());
place(obj.FijiButton, 1, 9);
obj.FijiButton.Tooltip = "Open the marked section's image in Fiji, " ...
    + "with its saved line ROIs as an overlay." + obj.shortcutHint("openInFiji");

end

function build_profile_row(obj, row)
%BUILD_PROFILE_ROW Build the controls that place and rescale the profile plot.
% Where the plot sits comes first, then the two settings that change the
% numbers on its axes rather than the pixels in a tile. Those read left to right
% as the sentence they are: normalize <this> over <that>, distance <this>.

row.ColumnWidth = {"fit", 125, "fit", 45, 8, "fit", 145, "fit", 95, 8, "fit", 135, "1x"};

place(uilabel(row, Text = "Position"), 1, 1);

obj.ProfileLayoutDropDown = uidropdown(row, ...
    Items = obj.ProfileLayoutNames, ...
    ItemsData = num2cell(obj.ProfileLayoutCodes), ...
    Value = "bottom", ...
    ValueChangedFcn = @(~,~) obj.onLayoutOptionChanged());
place(obj.ProfileLayoutDropDown, 1, 2);
obj.ProfileLayoutDropDown.Tooltip = "Where the profile plot sits relative to the image tiles.";

place(uilabel(row, Text = "Size %"), 1, 3);

obj.ProfileSizeField = uieditfield(row, "numeric", ...
    Value = 33, ...
    Limits = [5 95], ...
    RoundFractionalValues = "on", ...
    ValueChangedFcn = @(~,~) obj.onLayoutOptionChanged());
place(obj.ProfileSizeField, 1, 4);
obj.ProfileSizeField.Tooltip = "Share of the split the profile plot takes, in percent.";

place(uilabel(row, Text = "Normalize"), 1, 6);

obj.ProfileNormDropDown = uidropdown(row, ...
    Items = obj.ProfileNormNames, ...
    ItemsData = num2cell(obj.ProfileNormCodes), ...
    Value = "none", ...
    ValueChangedFcn = @(~,~) obj.onProfileOptionChanged());
place(obj.ProfileNormDropDown, 1, 7);
obj.ProfileNormDropDown.Tooltip = "Rescale the intensity axis of the profile plot. " + ...
    "The plot only; the values files and everything exported from the app " + ...
    "stay in the units they were measured in.";

place(uilabel(row, Text = "over"), 1, 8);

obj.ProfileScopeDropDown = uidropdown(row, ...
    Items = obj.ProfileScopeNames, ...
    ItemsData = num2cell(obj.ProfileScopeCodes), ...
    Value = "each", ...
    ValueChangedFcn = @(~,~) obj.onProfileOptionChanged());
place(obj.ProfileScopeDropDown, 1, 9);
obj.ProfileScopeDropDown.Tooltip = "Whether each trace is scaled by its own numbers, " + ...
    "which hides how bright one section was against another, or every trace " + ...
    "by one set taken over the whole plot, which keeps that difference.";

place(uilabel(row, Text = "Distance"), 1, 11);

obj.ProfileDistanceDropDown = uidropdown(row, ...
    Items = obj.ProfileDistanceNames, ...
    ItemsData = num2cell(obj.ProfileDistanceCodes), ...
    Value = "none", ...
    ValueChangedFcn = @(~,~) obj.onProfileOptionChanged());
place(obj.ProfileDistanceDropDown, 1, 12);
obj.ProfileDistanceDropDown.Tooltip = "Rescale the distance axis, to line the traces up " + ...
    "at their starts or to read them as a percentage of each line's own length.";

end

function build_roi_rows(obj, row, hintRow)
%BUILD_ROI_ROWS Build the controls that pick, move, and save a line ROI.
% Editing writes over the .roi file and the values.csv beside it, so the
% controls that do it sit together under their own heading rather than among
% the display options, and the line under them says what Save will touch.
%
% A section may carry several ROIs, and every one of these controls acts on
% exactly one of them, so which one comes first: the dropdown that picks it
% leads the row, ahead of the buttons that edit it.

row.ColumnWidth = {110, 70, 90, 6, 75, "fit", 55, 80, 75, 65, "1x"};

% Keyed by letter, shown by name. SYNCROISELECTOR owns Items, ItemsData, and
% Value, because the list changes with every selection.
obj.RoiSelectDropDown = uidropdown(row, ...
    Items = "A", ...
    ItemsData = {"A"}, ...
    Value = "A", ...
    ValueChangedFcn = @(~,~) obj.onRoiSelectionChanged());
place(obj.RoiSelectDropDown, 1, 1);
obj.RoiSelectDropDown.Tooltip = "Which of this section's line ROIs " + ...
    "the ROI and surface controls act on.";

obj.AddRoiButton = uibutton(row, "push", ...
    Text = "Add ROI", ...
    ButtonPushedFcn = @(~,~) obj.onAddRoi());
place(obj.AddRoiButton, 1, 2);
obj.AddRoiButton.Tooltip = "Start another line ROI on this section, under the next free letter." ...
    + obj.shortcutHint("addRoi");

obj.RoiNamesButton = uibutton(row, "push", ...
    Text = "Name ROIs...", ...
    ButtonPushedFcn = @(~,~) obj.onEditRoiNames());
place(obj.RoiNamesButton, 1, 3);
obj.RoiNamesButton.Tooltip = "Call the ROI keys after the regions they measure, " + ...
    "for example A is ACx and B is S1. The names are kept between sessions.";

% Column 4 is an empty gutter between choosing an ROI and changing it.

obj.EditRoiButton = uibutton(row, "state", ...
    Text = "Edit ROI", ...
    ValueChangedFcn = @(~,~) obj.onToggleEditRoi());
place(obj.EditRoiButton, 1, 5);
obj.EditRoiButton.Tooltip = "Drag the chosen line ROI of the marked section. " ...
    + "With several on screen, click a tile to move the mark to it." ...
    + obj.shortcutHint("toggleEditRoi");

place(uilabel(row, Text = "Width px"), 1, 6);

% The width applies to whatever line is drawn next, so it stays editable even
% when nothing is being edited, and it is remembered between sessions.
obj.RoiWidthField = uieditfield(row, "numeric", ...
    Value = obj.DefaultRoiWidth, ...
    Limits = [1 20000], ...
    RoundFractionalValues = "on", ...
    ValueChangedFcn = @(~,~) obj.onRoiWidthChanged());
place(obj.RoiWidthField, 1, 7);
obj.RoiWidthField.Tooltip = "Width of the band the profile averages over, in pixels. " + ...
    "The Fiji macro's band is 994 um, which is about 600 px on these projections.";

obj.DrawRoiButton = uibutton(row, "push", ...
    Text = "Draw Line", ...
    ButtonPushedFcn = @(~,~) obj.onDrawRoi());
place(obj.DrawRoiButton, 1, 8);
obj.DrawRoiButton.Tooltip = "Drag on the marked section to replace the chosen ROI " ...
    + "at the width to the left." + obj.shortcutHint("drawRoi");

obj.SaveRoiButton = uibutton(row, "push", ...
    Text = "Save ROI", ...
    Enable = "off", ...
    ButtonPushedFcn = @(~,~) obj.onSaveRoiEdits());
place(obj.SaveRoiButton, 1, 9);
obj.SaveRoiButton.Tooltip = "Overwrite this ROI's .roi file and remeasure its values.csv." ...
    + obj.shortcutHint("saveRoi");

obj.RevertRoiButton = uibutton(row, "push", ...
    Text = "Revert", ...
    Enable = "off", ...
    ButtonPushedFcn = @(~,~) obj.onRevertRoiEdits());
place(obj.RevertRoiButton, 1, 10);
obj.RevertRoiButton.Tooltip = "Discard unsaved changes and reload this ROI from disk." ...
    + obj.shortcutHint("revertRoi");

% The line under the buttons is two sentences: which ROIs the section has, and
% what the buttons would do to the one chosen. The first is short and bounded
% by the number of keys, so it is sized to its text; the second names a section
% stem and takes whatever is left.
hintRow.ColumnWidth = {"fit", "1x"};
hintRow.ColumnSpacing = 12;

obj.RoiListLabel = uilabel(hintRow, Text = "");
place(obj.RoiListLabel, 1, 1);
obj.RoiListLabel.FontColor = [0.35 0.35 0.35];

obj.RoiEditLabel = uilabel(hintRow, Text = "");
place(obj.RoiEditLabel, 1, 2);
obj.RoiEditLabel.FontColor = [0.35 0.35 0.35];

end

function build_surface_row(obj, row)
%BUILD_SURFACE_ROW Build the controls that mark the brain surface on a line.
% A row of its own under the ROI rows it belongs to, because these three are
% one question -- where on this line does the brain start -- rather than three
% settings that happen to be adjacent. They read left to right as the order
% they are used in: let the profile place a mark, place one by hand, take one
% off. The switch that shows the marks is with the other overlays.
%
% All three change a line, and a line is only changeable inside an edit
% session, so UPDATEROIEDITCONTROLS greys them the way it greys Save and Revert.

row.ColumnWidth = {75, 100, 65, "1x"};

obj.DetectSurfaceButton = uibutton(row, "push", ...
    Text = "Detect", ...
    Enable = "off", ...
    ButtonPushedFcn = @(~,~) obj.onDetectSurface());
place(obj.DetectSurfaceButton, 1, 1);
obj.DetectSurfaceButton.Tooltip = "Find the brain surface in the profile under the line, " + ...
    "where it steps up out of the background." ...
    + obj.shortcutHint("detectSurface");

obj.MarkSurfaceButton = uibutton(row, "push", ...
    Text = "Mark Surface", ...
    Enable = "off", ...
    ButtonPushedFcn = @(~,~) obj.onMarkSurface());
place(obj.MarkSurfaceButton, 1, 2);
obj.MarkSurfaceButton.Tooltip = "Click on the image to place the brain surface; " + ...
    "the point is taken onto the line." + obj.shortcutHint("markSurface");

obj.ClearSurfaceButton = uibutton(row, "push", ...
    Text = "Clear", ...
    Enable = "off", ...
    ButtonPushedFcn = @(~,~) obj.onClearSurface());
place(obj.ClearSurfaceButton, 1, 3);
obj.ClearSurfaceButton.Tooltip = "Take the brain surface mark off this line. " + ...
    "Save ROI then removes it from disk.";

obj.SurfaceLabel = uilabel(row, Text = "");
place(obj.SurfaceLabel, 1, 4);
obj.SurfaceLabel.FontColor = [0.35 0.35 0.35];

end

function row = group(grid, index, heading)
%GROUP Name one row of the panel and hand back the grid its controls go in.
% The heading column is sized to the longest heading, so every group's controls
% start at the same place however its own row is laid out.

label = uilabel(grid, Text = heading, FontWeight = "bold");
place(label, index, 1);

row = uigridlayout(grid, [1 1]);
row.RowHeight = {"fit"};
row.Padding = [0 0 0 0];
row.ColumnSpacing = 6;
place(row, index, 2);

end

function place(component, row, column)
%PLACE Assign an explicit grid position to a component.

component.Layout.Row = row;
component.Layout.Column = column;

end
