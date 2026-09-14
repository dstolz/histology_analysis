function onShowShortcuts(obj)
%ONSHOWSHORTCUTS Show every keyboard shortcut in one dialog.
% Built from KEYBINDINGS rather than written out again, so the list cannot fall
% behind the keys that are actually bound.
%
% See also KEYBINDINGS, ONFIGUREKEYPRESS.

bindings = HistologyImageBrowser.keyBindings();

groups = unique(string({bindings.Group}), "stable");
lines = strings(0, 1);

for iGroup = 1:numel(groups)
    inGroup = bindings(string({bindings.Group}) == groups(iGroup));

    if iGroup > 1
        lines(end + 1, 1) = ""; %#ok<AGROW>
    end

    lines(end + 1, 1) = groups(iGroup); %#ok<AGROW>
    lines = [lines; group_lines(inGroup)]; %#ok<AGROW>
end

uialert(obj.Fig, strjoin(lines, newline), "Keyboard Shortcuts", Icon = "info");

end

function lines = group_lines(bindings)
%GROUP_LINES Render one heading's shortcuts, one action per line.
% Aliases share an action, so their keys are joined onto that action's single
% line instead of repeating what it does.

actions = unique(string({bindings.Action}), "stable");
lines = strings(numel(actions), 1);

% The keys column is padded to a common width so the descriptions line up in
% the dialog's proportional font about as well as they can.
keys = strings(numel(actions), 1);

for iAction = 1:numel(actions)
    forAction = bindings(string({bindings.Action}) == actions(iAction));
    keys(iAction) = strjoin(arrayfun(@HistologyImageBrowser.shortcutLabel, forAction), " or ");
end

width = max(strlength(keys));

for iAction = 1:numel(actions)
    forAction = bindings(string({bindings.Action}) == actions(iAction));
    lines(iAction) = "    " + pad(keys(iAction), width) + "    " + forAction(1).Label;
end

end
