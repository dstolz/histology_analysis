function attachContextMenu(obj, ax, kind)
%ATTACHCONTEXTMENU Make an axes and everything drawn in it answer the pointer
%alike -- one right-click menu, and on a tile, one left-click.
%
% A context menu is raised by the object the pointer is actually over, not by
% the axes behind it, so a menu hung on the bare axes disappears the moment the
% pointer crosses the sampling band, a badge, or a profile trace. Rather than
% remembering to assign it at each of the dozen places a graphic is created,
% this walks the axes and hands the menu to every child and decoration at once,
% which also means an overlay object added later is covered without this file
% changing.
%
% The left-click a tile answers to rides on that same walk, for the same reason
% and at no extra cost: clicking a tile is how the user says which of several
% sections Edit ROI, Draw Line and Open Containing Folder should act on, and a
% click that worked on the picture but not on the band drawn over it would be a
% click the user learns not to trust. The profile axes takes no click handler,
% because it shows every trace at once and no one section of it is "this one".
%
% The image is a special case worth stating: DRAWIMAGETILE sets its
% PickableParts to "none" so hovering the section raises no data tip, which
% means the image can never be the hit object and the click lands on the axes
% underneath it instead. It is still given the menu, because the menu that then
% comes up has to be the same one either way, and because a later release or a
% later change of that property must not silently take the menu away.
%
% The two draggable ROI handles -- the line, and the brain surface mark on it --
% are deliberately skipped. Each carries a context menu of its own with the
% ROI's own commands on it, and replacing that would cost more than it adds
% while a line is being placed.
%
% Parameters
%   ax: Axes whose contents should raise the menu.
%   kind: "tile" for an image tile, "profile" for the profile axes.
%
% See also BUILDPLOTCONTEXTMENUS, DRAWIMAGETILE, DRAWROIOVERLAY, RENDERPROFILEPLOT.

arguments
    obj
    ax
    kind (1,1) string {mustBeMember(kind, ["tile", "profile"])}
end

if isempty(ax) || ~isvalid(ax)
    return
end

% A context menu belongs to one figure and cannot be shared with another, and
% ONOPENINFIGURE draws these same tiles into a plain figure of its own. Those
% tiles simply go without: a normal figure already carries the toolbar and menu
% bar this menu exists to substitute for.
if ~isequal(ancestor(ax, "figure"), obj.Fig)
    return
end

if isempty(obj.TileContextMenu) || ~isvalid(obj.TileContextMenu)
    obj.buildPlotContextMenus();
end

if kind == "tile"
    menu = obj.TileContextMenu;
else
    menu = obj.ProfileContextMenu;
end

if isempty(menu) || ~isvalid(menu)
    return
end

if kind == "tile"
    clicked = @(src, ~) click_tile(obj, src);
else
    clicked = function_handle.empty;
end

% Title and axis labels are decorations rather than children, so they have to
% be named; everything else drawn on the tile is a child.
targets = [ax; ax.Title; ax.XLabel; ax.YLabel; ax.Children];

for iTarget = 1:numel(targets)
    assign(targets(iTarget), menu, clicked);
end

end

function assign(target, menu, clicked)
%ASSIGN Give one object the menu and the click, if it is the sort that takes them.
% Written as guarded assignments rather than a list of types this file trusts,
% because the overlay is free to grow new kinds of graphic and none of them
% should have to be added here to become clickable.

if isempty(target) || ~isvalid(target) || ~isprop(target, "ContextMenu")
    return
end

% ATTACHROIEDITOR and ATTACHSURFACEEDITOR tag their handles, which is how each
% is left holding the ROI commands it comes with instead of these -- and, for
% the click, how dragging a line end stays a drag rather than also counting as
% a pick of the tile it is on.
if isprop(target, "Tag") && ismember(string(target.Tag), ["roiEditor", "surfaceEditor"])
    return
end

target.ContextMenu = menu;

if isempty(clicked) || ~isprop(target, "ButtonDownFcn")
    return
end

target.ButtonDownFcn = clicked;

end

function click_tile(obj, src)
%CLICK_TILE Point the ROI controls at the tile a left-click landed on.
% The click may have landed on the axes, on the band drawn over it, or on the
% label in its corner, so the tile is found by walking up from whatever was hit
% rather than by assuming it was the axes.
%
% Ignored while DRAWLINE or DRAWPOINT has the mouse. Those calls are waiting
% for a click of their own on one particular tile, and a click that wandered
% onto another one must not be allowed to close the very edit they are placing
% a line or a mark into -- least of all by raising an unsaved-changes dialog
% underneath one.

if obj.RoiPlacing
    return
end

obj.setRoiTarget(HistologyImageBrowser.tileStem(ancestor(src, "axes")));

end
