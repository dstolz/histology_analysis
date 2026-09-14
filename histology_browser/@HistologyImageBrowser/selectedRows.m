function rows = selectedRows(obj)
%SELECTEDROWS Return the catalog rows currently selected in the table.

rows = obj.View([], :);

if height(obj.View) == 0 || isempty(obj.Selection)
    return
end

idx = obj.Selection(obj.Selection >= 1 & obj.Selection <= height(obj.View));

if isempty(idx)
    return
end

rows = obj.View(idx, :);

end
