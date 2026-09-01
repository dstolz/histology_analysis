function syncDisplayMenu(obj)
%SYNCDISPLAYMENU Make the Display menu agree with the Display panel.
% The panel holds the state and the menu only reflects it, so this runs
% wherever a display control settles: after an option changes, after the layout
% changes, after the background changes, after the ROI controls are re-enabled,
% and after preferences are restored.
%
% Choice submenus are rebuilt only when their choices actually changed. The
% channel list is rebuilt for every selection and the background list grows and
% shrinks a custom color, but the other three never change, and rebuilding all
% of them on every redraw would throw away and remake menu items for nothing.
%
% See also BUILDDISPLAYMENU, PROMPTDISPLAYNUMBER.

if isempty(obj.DisplayMirrors)
    return
end

for iMirror = 1:numel(obj.DisplayMirrors)
    M = obj.DisplayMirrors(iMirror);

    if ~isvalid(M.Menu)
        continue
    end

    switch M.Kind
        case "choice"
            sync_choice(obj, M);

        case "toggle"
            M.Menu.Checked = matlab.lang.OnOffSwitchState(logical(M.Controls{1}.Value));
            M.Menu.Enable = M.Controls{1}.Enable;

        case "number"
            M.Menu.Text = number_text(M);
            M.Menu.Enable = M.Controls{1}.Enable;

        case "enable"
            M.Menu.Enable = M.Controls{1}.Enable;
    end
end

end

function sync_choice(obj, M)
%SYNC_CHOICE Rebuild a submenu's items when they changed, then check the one
% in use.

control = M.Controls{1};
items = string(control.Items);

% A dropdown the panel has greyed out is one whose choices do not apply, and a
% menu that still offered them would be the one place in the window where a
% disabled setting could be changed.
M.Menu.Enable = control.Enable;

if ~isequal(M.Menu.UserData, items)
    rebuild_choice(obj, M.Menu, control, items);
end

children = M.Menu.Children;

for iChild = 1:numel(children)
    children(iChild).Checked = ...
        matlab.lang.OnOffSwitchState(isequal(children(iChild).UserData, control.Value));
end

end

function rebuild_choice(obj, menu, control, items)
%REBUILD_CHOICE Put one item on the submenu per choice the dropdown offers.
% Each item carries the value it stands for, which is what the check mark is
% decided by and what the callback writes back.

delete(menu.Children);

for iItem = 1:numel(items)
    % A dropdown given no ItemsData reports the item text as its value, so
    % that is what the item has to carry.
    if isempty(control.ItemsData)
        value = control.Items{iItem};
    else
        value = control.ItemsData{iItem};
    end

    child = uimenu(menu, Text = items(iItem));
    child.UserData = value;
    child.MenuSelectedFcn = @(~,~) obj.chooseFromMenu(control, value);
end

% uimenu adds children at the end but reports them newest first, so the
% snapshot is stored only once the list is whole.
menu.UserData = items;

end

function text = number_text(M)
%NUMBER_TEXT Label a prompting item with the value it would change.

values = cellfun(@(c) c.Value, M.Controls, UniformOutput = false);

text = M.Label + "...  " + sprintf(M.Format, values{:});

end
