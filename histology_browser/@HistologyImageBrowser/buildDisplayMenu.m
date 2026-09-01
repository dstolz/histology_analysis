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
% All four have keys of their own, so the item runs the shortcut and picks up
% its status message as well as its toggle.
toggle(obj, obj.DisplayMenu, obj.ShowRoiCheck, "Line ROI", "toggleRoiOverlay", ...
    Separator = true);
toggle(obj, obj.DisplayMenu, obj.ShowBandCheck, "Sampling Band", "toggleBandOverlay");
toggle(obj, obj.DisplayMenu, obj.ColorByIntensityCheck, "Shade ROI by Intensity", ...
    "toggleIntensityShading");
toggle(obj, obj.DisplayMenu, obj.ShowSurfaceCheck, "Brain Surface Marks", ...
    "toggleSurfaceOverlay");

% -- Profile plot ---------------------------------------------------------
choice(obj, obj.DisplayMenu, obj.ProfileLayoutDropDown, "Profiles", Separator = true);
number(obj, obj.DisplayMenu, {obj.ProfileSizeField}, ...
    "Profile Size", "%g %%", Prompts = "Share of the split, in percent");

choice(obj, obj.DisplayMenu, obj.ProfileNormDropDown, "Normalize");
choice(obj, obj.DisplayMenu, obj.ProfileScopeDropDown, "Normalize Over");
choice(obj, obj.DisplayMenu, obj.ProfileDistanceDropDown, "Distance Axis");

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

toggle(obj, menu, obj.EditRoiButton, "Edit ROI", "toggleEditRoi");
action(obj, menu, "Draw Line", "drawRoi");
action(obj, menu, "Save ROI", "saveRoi", Mirror = obj.SaveRoiButton);
action(obj, menu, "Revert", "revertRoi", Mirror = obj.RevertRoiButton);

% The grid and the width are both properties of the band rather than actions
% taken on it, so they sit together below the separator. The grid has no key of
% its own, which is what the missing action name says.
toggle(obj, menu, obj.ShowBandGridCheck, "Band Grid", Separator = true);

number(obj, menu, {obj.RoiWidthField}, "Band Width", "%g px", ...
    Prompts = "Band width, in pixels");

% Where on the line the brain starts. Below the band, because a surface is a
% point on a line that has already been placed, and grouped rather than folded
% into the items above because all three are unavailable together: they need an
% edit session, which is exactly the Enable state their buttons carry.
action(obj, menu, "Detect Brain Surface", "detectSurface", ...
    Separator = true, Mirror = obj.DetectSurfaceButton);
action(obj, menu, "Mark Brain Surface", "markSurface", Mirror = obj.MarkSurfaceButton);

% No shortcut of its own, so the item presses the button rather than going
% through RUNSHORTCUT to an action KEYBINDINGS does not carry.
press(obj, menu, "Clear Brain Surface", obj.ClearSurfaceButton, ...
    @() obj.onClearSurface());

end

function press(obj, parent, text, control, callback)
%PRESS Mirror a button that has no keyboard shortcut behind it.
% ACTION goes through RUNSHORTCUT, which is right for anything KEYBINDINGS
% names and wrong for anything it does not: naming an action that is not in the
% table would send the item to nothing but a "no handler" message, and
% inventing a binding to avoid that would put a key on the menu that no key
% press answers. The item follows the button's Enable either way.

menu = uimenu(parent, ...
    Text = text, ...
    MenuSelectedFcn = @(~,~) callback());

record(obj, "enable", menu, {control}, text, "");

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
% An option with no key of its own is named without an action, and the item
% then writes its control and runs that control's callback through
% CHOOSEFROMMENU -- the same path a click takes, and the same path the tile
% context menu takes. Naming an action KEYBINDINGS does not carry would send
% the item through RUNSHORTCUT to nothing but a "no handler" message, and
% inventing a binding to avoid that would put a key on the menu that no key
% press answers.

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
