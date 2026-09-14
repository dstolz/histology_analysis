function onFigureKeyPress(obj, evt)
%ONFIGUREKEYPRESS Run the shortcut a key press names, if it names one.
% uifigure menus ignore the Accelerator property, so every shortcut this window
% offers is bound here and the menus and tooltips only name them. KEYBINDINGS
% holds the table; this function does the matching and RUNSHORTCUT does the
% work.
%
% Parameters
%   evt: The WindowKeyPress event, whose Key and Modifier settle the match.
%
% See also KEYBINDINGS, RUNSHORTCUT, ONSHOWSHORTCUTS.

key = lower(string(evt.Key));
modifier = sort(lower(string(evt.Modifier(:)')));

if isempty(modifier)
    modifier = strings(1, 0);
end

bindings = HistologyImageBrowser.keyBindings();

% A text field was clicked into is a real possibility for every press, and
% asking once is cheaper than asking per candidate binding.
inTextEntry = obj.keyTargetIsTextEntry();

for iBind = 1:numel(bindings)
    B = bindings(iBind);

    if B.Key ~= key || ~isequal(B.Modifier, modifier)
        continue
    end

    if inTextEntry && B.SkipInTextEntry
        return
    end

    obj.runShortcut(B.Action);

    return
end

end
