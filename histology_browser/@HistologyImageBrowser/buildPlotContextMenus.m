function buildPlotContextMenus(obj)
%BUILDPLOTCONTEXTMENUS Build the right-click menus the image tiles and the
%profile axes hand out.
%
% Two menus are built once and shared by every object drawn in a plot, rather
% than one menu per tile: a twelve tile view would otherwise build and throw
% away twelve copies of the same twenty items on every redraw, which is the
% exact cost REFRESHOVERLAYS exists to avoid. Sharing them means the items
% cannot capture which tile they belong to, so the tile under the pointer is
% recorded when the menu opens and the per-tile items read it back.
%
% Nothing here decides what an option means. Every item either writes the panel
% control it mirrors and runs that control's own callback through
% CHOOSEFROMMENU, or calls RUNSHORTCUT, so a right-click, a click on the panel,
% a pick from the Display menu, and a key press are one code path. The item
% builders below repeat the shape of the ones in BUILDDISPLAYMENU because local
% functions cannot be shared between files; what they must not repeat, and do
% not, is any knowledge of what the options do.
%
% Check marks and enable states are not maintained here either. Each mirrored
% item is recorded in DISPLAYMIRRORS, which is the list SYNCDISPLAYMENU already
% walks after every display change, so these menus follow the panel for free.
%
% Called lazily from ATTACHCONTEXTMENU rather than from BUILDUI, because
% BUILDDISPLAYMENU empties DISPLAYMIRRORS when it runs and it runs after the
% view panel is built; waiting until the first tile is drawn puts these
% registrations safely after it.
%
% See also ATTACHCONTEXTMENU, SYNCDISPLAYMENU, CHOOSEFROMMENU, RUNSHORTCUT.

obj.TileContextMenu = uicontextmenu(obj.Fig);
obj.TileContextMenu.ContextMenuOpeningFcn = @(src, evt) note_clicked_object(obj, src, evt);

% The section the items below will act on is not the one the panel is showing,
% so it is named at the top of the menu. Disabled, because it is a heading
% rather than something to pick.
uimenu(obj.TileContextMenu, ...
    Text = "Section", ...
    Enable = "off", ...
    Tag = "contextTileLabel");

% -- What this tile shows -------------------------------------------------
choice(obj, obj.TileContextMenu, obj.VariantDropDown, "Image", Separator = true);
choice(obj, obj.TileContextMenu, obj.ChannelDropDown, "Channel");
choice(obj, obj.TileContextMenu, obj.ColormapDropDown, "Colormap");
choice(obj, obj.TileContextMenu, obj.BackgroundDropDown, "Background");

% -- Overlays -------------------------------------------------------------
toggle(obj, obj.TileContextMenu, obj.ShowRoiCheck, "Line ROI", "toggleRoiOverlay", ...
    Separator = true);
toggle(obj, obj.TileContextMenu, obj.ShowBandCheck, "Sampling Band", "toggleBandOverlay");
toggle(obj, obj.TileContextMenu, obj.ColorByIntensityCheck, "Shade ROI by Intensity", ...
    "toggleIntensityShading");
toggle(obj, obj.TileContextMenu, obj.ShowBandGridCheck, "Band Grid");

% -- This tile's ROI ------------------------------------------------------
% These three are the reason the clicked tile is recorded at all: they are the
% items whose subject is the section under the pointer rather than the view.
tileToggle = toggle(obj, obj.TileContextMenu, obj.EditRoiButton, "Edit ROI", ...
    "toggleEditRoi", Separator = true);
tileToggle.MenuSelectedFcn = @(~,~) edit_clicked_roi(obj);

item(obj, obj.TileContextMenu, "Draw Line", "drawRoi", @() draw_clicked_roi(obj));
item(obj, obj.TileContextMenu, "Open Containing Folder", "openFolder", ...
    @() open_clicked_folder(obj));

% -- Output ---------------------------------------------------------------
item(obj, obj.TileContextMenu, "Open in Figure", "openInFigure", ...
    @() obj.runShortcut("openInFigure"), Separator = true);
item(obj, obj.TileContextMenu, "Export View", "exportView", ...
    @() obj.runShortcut("exportView"));

build_profile_menu(obj);

% The panel already holds the state these items mirror, so one sync fills the
% choice submenus in and sets every check mark before the menu is first opened.
obj.syncDisplayMenu();

end

function build_profile_menu(obj)
%BUILD_PROFILE_MENU Build the menu the profile axes and its traces raise.
% The overlay toggles and the colormap are left off it: neither is drawn on
% this plot, and a menu offering settings that visibly do nothing to the thing
% clicked is worse than a short one. Where the plot sits, how its axes are
% scaled, and how to get the view out of the window, are what is actually being
% asked here.

obj.ProfileContextMenu = uicontextmenu(obj.Fig);
obj.ProfileContextMenu.ContextMenuOpeningFcn = @(src, evt) note_clicked_object(obj, src, evt);

choice(obj, obj.ProfileContextMenu, obj.ProfileLayoutDropDown, "Profiles");

% The normalizations are the settings whose subject is this plot and nothing
% else, so unlike the overlay toggles and the colormap they belong on the menu
% the plot itself raises.
choice(obj, obj.ProfileContextMenu, obj.ProfileNormDropDown, "Normalize", ...
    Separator = true);
choice(obj, obj.ProfileContextMenu, obj.ProfileScopeDropDown, "Normalize Over");
choice(obj, obj.ProfileContextMenu, obj.ProfileDistanceDropDown, "Distance Axis");

item(obj, obj.ProfileContextMenu, "Open in Figure", "openInFigure", ...
    @() obj.runShortcut("openInFigure"), Separator = true);
item(obj, obj.ProfileContextMenu, "Export View", "exportView", ...
    @() obj.runShortcut("exportView"));

end

function menu = choice(obj, parent, control, text, options)
%CHOICE Mirror a dropdown as a submenu with one checked item per choice.
% Left empty here on purpose: SYNCDISPLAYMENU fills the items in and rebuilds
% them whenever the dropdown's own list changes, which the channel list and the
% background list both do while the window is open.

arguments
    obj
    parent
    control
    text (1,1) string
    options.Separator (1,1) logical = false
end

menu = uimenu(parent, ...
    Text = text, ...
    Separator = matlab.lang.OnOffSwitchState(options.Separator));

record(obj, "choice", menu, control, text);

end

function menu = toggle(obj, parent, control, text, action, options)
%TOGGLE Mirror a checkbox or state button as a checked menu item.
% An option that has a key of its own runs through RUNSHORTCUT, which picks up
% the status message the key press produces as well as the toggle. One without
% a key writes the control and runs that control's own callback instead, since
% naming an action KEYBINDINGS does not carry would reach nothing but a "no
% handler" message.

arguments
    obj
    parent
    control
    text (1,1) string
    action (1,1) string = ""
    options.Separator (1,1) logical = false
end

if action == ""
    selected = @(~,~) obj.chooseFromMenu(control, ~control.Value);
else
    selected = @(~,~) obj.runShortcut(action);
end

menu = uimenu(parent, ...
    Text = text + obj.shortcutHint(action), ...
    Separator = matlab.lang.OnOffSwitchState(options.Separator), ...
    MenuSelectedFcn = selected);

record(obj, "toggle", menu, control, text);

end

function menu = item(obj, parent, text, action, selected, options)
%ITEM Add a plain menu item that carries out one named action.
% The action name is passed even when the callback is not RUNSHORTCUT itself,
% because it is what SHORTCUTHINT reads to advertise the key, and a per-tile
% item must still name the same key the panel button does.

arguments
    obj
    parent
    text (1,1) string
    action (1,1) string
    selected function_handle
    options.Separator (1,1) logical = false
end

menu = uimenu(parent, ...
    Text = text + obj.shortcutHint(action), ...
    Separator = matlab.lang.OnOffSwitchState(options.Separator), ...
    MenuSelectedFcn = @(~,~) selected());

end

function record(obj, kind, menu, control, label)
%RECORD Add one item to the mirror list SYNCDISPLAYMENU walks.
% The struct has to match the one BUILDDISPLAYMENU builds field for field,
% because the two lists are the same list.

obj.DisplayMirrors(end + 1, 1) = struct( ...
    Kind = kind, ...
    Menu = menu, ...
    Controls = {{control}}, ...
    Label = label, ...
    Format = "");

end

function note_clicked_object(obj, src, evt)
%NOTE_CLICKED_OBJECT Record the tile the right-click landed on, and name it.
% Called as the menu opens, which is the only moment the object under the
% pointer is knowable: the items themselves are shared by every tile.

obj.ContextAxes = clicked_axes(obj, evt);

heading = findobj(src, Tag = "contextTileLabel");

if isempty(heading)
    return
end

stem = HistologyImageBrowser.tileStem(obj.ContextAxes);

if stem == ""
    heading.Text = "No section under the pointer";
    return
end

heading.Text = "Section:  " + stem;

end

function ax = clicked_axes(obj, evt)
%CLICKED_AXES Resolve the axes holding whatever was right-clicked.
% The opening event names the object the menu came up on, which is the reliable
% answer and the one used when it is there. CurrentObject is the fallback for a
% release whose event data does not carry it; it is what the figure last
% recorded a click on, which is the same object in every case that matters
% here.

ax = [];

target = [];

try
    target = evt.ContextObject;
catch
    % Event data without that field, including the plain struct a test hands
    % in; the figure is asked instead.
end

if isempty(target) || ~all(isgraphics(target))
    try
        target = obj.Fig.CurrentObject;
    catch
        target = [];
    end
end

if isempty(target) || ~all(isgraphics(target))
    return
end

found = ancestor(target(1), "axes");

if isempty(found)
    return
end

ax = found;

end

function edit_clicked_roi(obj)
%EDIT_CLICKED_ROI Start or finish editing the ROI of the tile under the pointer.

focus_clicked_tile(obj);
obj.runShortcut("toggleEditRoi");

end

function draw_clicked_roi(obj)
%DRAW_CLICKED_ROI Draw a new line on the tile under the pointer.

focus_clicked_tile(obj);
obj.runShortcut("drawRoi");

end

function open_clicked_folder(obj)
%OPEN_CLICKED_FOLDER Reveal the folder of the section under the pointer.

focus_clicked_tile(obj);
obj.runShortcut("openFolder");

end

function focus_clicked_tile(obj)
%FOCUS_CLICKED_TILE Make the right-clicked tile's section the one acted on.
% ONTOGGLEEDITROI, ONDRAWROI, and ONOPENFOLDER all work on the first selected
% row. Selecting the clicked section, through the catalog table and its own
% callback, is what makes "this tile" reach them without any of those files
% learning about the pointer. Reordering SELECTION so the clicked stem floated
% to the front was the alternative, and it was rejected because the tiles are
% drawn in that same order: editing an ROI from a tile would have silently
% rearranged the grid it was clicked on.
%
% A tile that is already the first selected row is left alone, so the common
% case of right-clicking the only section on screen costs no redraw at all.

stem = HistologyImageBrowser.tileStem(obj.ContextAxes);

if stem == ""
    return
end

rows = obj.selectedRows();

if height(rows) > 0 && string(rows.Stem(1)) == stem
    return
end

index = find(string(obj.View.Stem) == stem, 1);

if isempty(index)
    return
end

obj.CatalogTable.Selection = index;
obj.onSelectionChanged();

end
