function syncRoiSelector(obj)
%SYNCROISELECTOR Offer the ROIs the selected section holds, by name.
%
% The list is rebuilt whenever the selection or the ROI set changes, so it is
% written the way the channel list is: Items, ItemsData, and Value together,
% because the list length changes underneath them and any one of the three set
% on its own would disagree with the other two.
%
% The dropdown carries keys as its data and names as its text, so renaming A
% to ACx changes what the control says without changing which files an edit
% would write.
%
% See also UPDATEROIEDITCONTROLS, ONROISELECTIONCHANGED, ROINAME.

if isempty(obj.RoiSelectDropDown) || ~isvalid(obj.RoiSelectDropDown)
    return
end

rows = obj.selectedRows();

if height(rows) ~= 1
    % Nothing to choose between, but a dropdown cannot be empty, so it holds
    % the key the controls would act on if a section were selected.
    keys = obj.ActiveRoiKey;

    if keys == ""
        keys = "A";
    end
else
    keys = obj.roiKeysForRow(rows(1, :));

    if isempty(keys)
        % A section with no ROI yet still has to say which one Draw Line
        % would create.
        keys = obj.activeRoiKey(rows(1, :));
    end
end

keys = keys(:);
names = arrayfun(@(k) obj.roiName(k), keys);

% A name that is not the key is worth showing alongside it, because the key is
% what appears in the filenames on disk.
labels = names;
labels(names ~= keys) = names(names ~= keys) + "  (" + keys(names ~= keys) + ")";

value = keys(1);

if height(rows) == 1
    active = obj.activeRoiKey(rows(1, :));

    if ismember(active, keys)
        value = active;
    end
end

set(obj.RoiSelectDropDown, ...
    Items = labels, ...
    ItemsData = num2cell(keys), ...
    Value = value);

end
