function buildDisplayMenu(obj, parent)
%BUILDDISPLAYMENU Mirror the Display panel onto a menu.
% The display row can be collapsed to give the image tiles the whole window,
% and everything in it goes off screen when it is. This menu is the way back to
% those controls, so hiding the row costs reach rather than capability.
%
% The panel keeps the state. Every item here writes to the control it mirrors
% and then runs that control's own callback, so a menu choice and a click go
% down exactly the same path; nothing about what an option means is written
% twice. Anything that already has a keyboard shortcut goes through
% RUNSHORTCUT for the same reason.
%
% SYNCDISPLAYMENU pushes the panel's state back the other way, and finds what
% to update through the mirror list this function records in DISPLAYMIRRORS
% rather than through a handle per item.
%
% Parameters
%   parent: Figure the menu is added to.
%
% See also SYNCDISPLAYMENU, BUILDDISPLAYPANEL, RUNSHORTCUT.

obj.DisplayMenu = uimenu(parent, Text = "Display");
obj.DisplayMirrors = struct( ...
    Kind = {}, Menu = {}, Controls = {}, Label = {}, Format = {});

% -- What each tile shows -------------------------------------------------
choice(obj, obj.DisplayMenu, obj.VariantDropDown, "Image");
choice(obj, obj.DisplayMenu, obj.ChannelDropDown, "Channel");
choice(obj, obj.DisplayMenu, obj.ColormapDropDown, "Colormap");
choice(obj, obj.DisplayMenu, obj.BackgroundDropDown, "Background");

number(obj, obj.DisplayMenu, {obj.LowPercentileField, obj.HighPercentileField}, ...
    "Contrast Percentiles", "%g - %g %%", Separator = true, ...
    Prompts = ["Lower percentile", "Upper percentile"]);
number(obj, obj.DisplayMenu, {obj.MaxTilesField}, ...
    "Max Tiles", "%g", Prompts = "Images drawn at once");

% -- Overlays -------------------------------------------------------------
% These three have keys of their own, so the item runs the shortcut and picks
% up its status message as well as its toggle.
toggle(obj, obj.DisplayMenu, obj.ShowRoiCheck, "Line ROI", "toggleRoiOverlay", ...
    Separator = true);
toggle(obj, obj.DisplayMenu, obj.ShowBandCheck, "Sampling Band", "toggleBandOverlay");
toggle(obj, obj.DisplayMenu, obj.ColorByIntensityCheck, "Shade ROI by Intensity", ...
    "toggleIntensityShading");

% -- Profile plot ---------------------------------------------------------
choice(obj, obj.DisplayMenu, obj.ProfileLayoutDropDown, "Profiles", Separator = true);
number(obj, obj.DisplayMenu, {obj.ProfileSizeField}, ...
    "Profile Size", "%g %%", Prompts = "Share of the split, in percent");

build_roi_submenu(obj);

% -- Output ---------------------------------------------------------------
action(obj, obj.DisplayMenu, "Open in Figure", "openInFigure", Separator = true);
action(obj, obj.DisplayMenu, "Export View", "exportView");

% The panel is built before the menu is, so its state is already there to be
% read and the menu opens agreeing with it.
obj.syncDisplayMenu();

end

function build_roi_submenu(obj)
%BUILD_ROI_SUBMENU Mirror the ROI edit row, which the display row also hides.
% Save and Revert apply only part of the time, so their items follow the Enable
% state of the buttons they mirror rather than offering an action the window
% says is unavailable.

% Named for the editing rather than the ROI, because the overlay toggle just
% above is also called Line ROI and the two do quite different things.
menu = uimenu(obj.DisplayMenu, Text = "ROI Editing", Separator = "on");

% Which ROI the rest of this submenu acts on comes first, for the same reason
% it does in the panel.
choice(obj, menu, obj.RoiSelectDropDown, "ROI");
action(obj, menu, "Add ROI", "addRoi", Mirror = obj.AddRoiButton);
action(obj, menu, "Name ROIs...", "editRoiNames");

toggle(obj, menu, obj.EditRoiButton, "Edit ROI", "toggleEditRoi", Separator = true);
action(obj, menu, "Draw Line", "drawRoi");
action(obj, menu, "Save ROI", "saveRoi", Mirror = obj.SaveRoiButton);
action(obj, menu, "Revert", "revertRoi", Mirror = obj.RevertRoiButton);

number(obj, menu, {obj.RoiWidthField}, "Band Width", "%g px", ...
    Separator = true, Prompts = "Band width, in pixels");

end

function choice(obj, parent, control, text, options)
%CHOICE Mirror a dropdown as a submenu with one checked item per choice.
% The items are filled in by SYNCDISPLAYMENU rather than here, because the
% channel list and the background list both change while the window is open.

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

record(obj, "choice", menu, {control}, text, "");

end

function toggle(obj, parent, control, text, action, options)
%TOGGLE Mirror a checkbox or state button as a checked menu item.

arguments
    obj
    parent
    control
    text (1,1) string
    action (1,1) string
    options.Separator (1,1) logical = false
end

menu = uimenu(parent, ...
    Text = text + obj.shortcutHint(action), ...
    Separator = matlab.lang.OnOffSwitchState(options.Separator), ...
    MenuSelectedFcn = @(~,~) obj.runShortcut(action));

record(obj, "toggle", menu, {control}, text, "");

end

function action(obj, parent, text, name, options)
%ACTION Mirror a button as a plain menu item.
% A button whose Enable comes and goes is named in Mirror, and the item then
% follows it.

arguments
    obj
    parent
    text (1,1) string
    name (1,1) string
    options.Separator (1,1) logical = false
    options.Mirror = []
end

menu = uimenu(parent, ...
    Text = text + obj.shortcutHint(name), ...
    Separator = matlab.lang.OnOffSwitchState(options.Separator), ...
    MenuSelectedFcn = @(~,~) obj.runShortcut(name));

if isempty(options.Mirror)
    return
end

record(obj, "enable", menu, {options.Mirror}, text, "");

end

function number(obj, parent, controls, text, format, options)
%NUMBER Mirror one or two numeric fields as an item that prompts for them.
% The value goes in the item's own label, so the menu says what the setting is
% without being opened twice.

arguments
    obj
    parent
    controls cell
    text (1,1) string
    format (1,1) string
    options.Separator (1,1) logical = false
    options.Prompts (1,:) string = strings(1, 0)
end

index = numel(obj.DisplayMirrors) + 1;

menu = uimenu(parent, ...
    Text = text + "...", ...
    Separator = matlab.lang.OnOffSwitchState(options.Separator), ...
    MenuSelectedFcn = @(~,~) obj.promptDisplayNumber(index));

% The prompts ride along on the item, because they belong to it and nothing
% else ever needs them.
menu.UserData = options.Prompts;

record(obj, "number", menu, controls, text, format);

end

function record(obj, kind, menu, controls, label, format)
%RECORD Add one item to the mirror list SYNCDISPLAYMENU walks.

obj.DisplayMirrors(end + 1, 1) = struct( ...
    Kind = kind, ...
    Menu = menu, ...
    Controls = {controls}, ...
    Label = label, ...
    Format = format);

end
