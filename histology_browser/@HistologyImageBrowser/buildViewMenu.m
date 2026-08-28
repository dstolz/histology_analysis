function buildViewMenu(obj)
%BUILDVIEWMENU Build the View menu on the figure menu bar.
% The lookup lists, the catalog, and the display options are set once and then
% mostly left alone, so they can be collapsed to give the image tiles the whole
% window. The data column and the display row collapse separately, because one
% sitting wants the filters out of the way and another wants the display
% options out of the way, and one item clears both at once. uifigure menus
% ignore the Accelerator property, so every shortcut is bound on the figure in
% ONFIGUREKEYPRESS and only named here, through SHORTCUTHINT so the label
% cannot disagree with the key.
%
% The check on each item follows what is on screen, so a mark means that part
% of the window is showing now. The marks are set by APPLYPANELVISIBILITY,
% which BUILDUI runs once the grids those items resize actually exist.
%
% See also APPLYPANELVISIBILITY, KEYBINDINGS.

obj.ViewMenu = uimenu(obj.Fig, Text = "View");

obj.DataColumnMenu = uimenu(obj.ViewMenu, ...
    Text = "Show/Hide Data Column" + obj.shortcutHint("toggleDataColumn"), ...
    MenuSelectedFcn = @(~,~) obj.onToggleDataColumn());

obj.DisplayRowMenu = uimenu(obj.ViewMenu, ...
    Text = "Show/Hide Display Row" + obj.shortcutHint("toggleDisplayRow"), ...
    MenuSelectedFcn = @(~,~) obj.onToggleDisplayRow());

obj.AllPanelsMenu = uimenu(obj.ViewMenu, ...
    Text = "Show/Hide All" + obj.shortcutHint("toggleAllPanels"), ...
    MenuSelectedFcn = @(~,~) obj.onToggleAllPanels());

obj.ShortcutsMenu = uimenu(obj.ViewMenu, ...
    Text = "Keyboard Shortcuts" + obj.shortcutHint("showShortcuts"), ...
    Separator = "on", ...
    MenuSelectedFcn = @(~,~) obj.onShowShortcuts());

end
