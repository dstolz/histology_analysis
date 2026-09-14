function promptDisplayNumber(obj, index)
%PROMPTDISPLAYNUMBER Ask for the numbers behind one Display menu item.
% A menu cannot hold an edit field, so the numeric display settings are reached
% through a prompt instead. The value is put through the same limits and
% rounding the field itself enforces, so the menu cannot set something the
% panel would have refused, and the field's own callback runs afterwards
% exactly as it would have on a typed edit.
%
% Parameters
%   index: Position in DISPLAYMIRRORS of the item that was chosen.
%
% See also BUILDDISPLAYMENU, SYNCDISPLAYMENU.

M = obj.DisplayMirrors(index);
prompts = string(M.Menu.UserData);

current = cellfun(@(c) string(num2str(c.Value)), M.Controls);

answer = inputdlg(cellstr(prompts), char(M.Label), [1 40], cellstr(current));

if isempty(answer)
    return
end

values = str2double(answer);

if any(isnan(values))
    obj.setWarning("%s needs a number; nothing was changed.", M.Label);
    return
end

% Every field is written before any callback runs, because the contrast
% percentiles are read as a pair and a redraw between the two would be drawn
% from half of the new setting.
for iControl = 1:numel(M.Controls)
    M.Controls{iControl}.Value = clamp(M.Controls{iControl}, values(iControl));
end

fire(M.Controls{1});

end

function value = clamp(control, value)
%CLAMP Bring a typed number inside what the field itself would accept.

if strcmp(string(control.RoundFractionalValues), "on")
    value = round(value);
end

limits = control.Limits;

value = min(max(value, limits(1)), limits(2));

end

function fire(control)
%FIRE Run the field's own callback, which is what a typed edit would have done.
% The controls behind one item share a callback, so it is run once rather than
% once per field.

callback = control.ValueChangedFcn;

if isempty(callback)
    return
end

callback(control, []);

end
