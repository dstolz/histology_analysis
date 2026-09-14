function onCatalogDisplayChanged(obj)
%ONCATALOGDISPLAYCHANGED Reorder obj.View to match a sort the user just made.
% Column sorting used to be switched off here, because obj.Selection holds
% indices into obj.View and a widget that quietly showed the rows in some other
% order would have made every one of those indices point at the wrong section.
% It is on now, and the invariant is kept a different way: the new order is
% taken from the widget and applied to obj.View itself, then the table is
% rewritten from the reordered view, so Data and DisplayData go back to holding
% the same rows in the same order and an index into either still names the same
% section. The question of whether Selection counts rows of Data or of
% DisplayData never has to be answered, because after this runs there is no
% difference between them.
%
% The order is read out of the widget rather than recomputed from the Sort by
% code, so this cannot disagree with the widget about how it orders strings,
% numbers, or blanks -- whatever it decided, obj.View is made to match.
%
% Which column was clicked is worked out by reproducing the order rather than
% by reading the interaction fields of the event, which do carry it. The
% reproduction is what makes the sort worth remembering: a column and direction
% are recorded only when CATALOGSORTORDER turns the previous order into the
% displayed one, which is exactly the condition for APPLYFILTERS being able to
% put that order back on the next session. A sort that cannot be reproduced is
% still applied; it is just not written down.
%
% Assigning Data drops the widget's own sort state, so the arrow leaves the
% header even though the rows stay in the order it put them in. That is
% accurate rather than unfortunate: the table is now showing Data in Data's own
% order, and the order is remembered here instead. It does mean the first
% repeat click on a header re-sorts ascending and changes nothing, with the
% click after it reaching descending.
%
% See also WRITECATALOGTABLE, CATALOGSORTORDER, APPLYFILTERS,
% BUILDCATALOGTABLE, SELECTEDROWS.

if obj.CatalogTableSyncing || height(obj.View) == 0
    return
end

key = HistologyImageBrowser.CatalogKeyColumn;

before = obj.CatalogTable.Data;
displayed = obj.CatalogTable.DisplayData;

if ~istable(displayed) || ~ismember(key, string(displayed.Properties.VariableNames))
    return
end

order = string(displayed.(key));
current = string(obj.View.Stem);

% Nothing moved. A repeat click on a column already in that order lands here,
% and returning without rewriting Data leaves the widget holding the sort state
% it just set, so the click after it toggles the direction as usual.
if numel(order) ~= numel(current) || isequal(order, current)
    return
end

[found, position] = ismember(order, current);

if ~all(found)
    % The widget is showing rows this view cannot account for, which means the
    % two have come apart rather than that the user sorted. Reordering the view
    % from it would put the mismatch into obj.View, so it is left alone.
    return
end

% Carried by stem rather than by row number, because the row numbers are about
% to mean something else.
selectedStems = string(obj.selectedRows().Stem);

obj.View = obj.View(position, :);

[obj.CatalogSortColumn, obj.CatalogSortDirection] = infer_sort(before, order);
obj.CatalogSortPreset = string(obj.SortDropDown.Value);

obj.writeCatalogTable();

restore_selection(obj, selectedStems);

obj.savePreferences();

announce(obj);

end

function [field, direction] = infer_sort(before, order)
%INFER_SORT Name the column sort that produced a display order, if one did.
% Every shown column is tried both ways and the first that reproduces the order
% wins. Two columns that happen to order the rows identically are
% interchangeable for the only purpose this answer serves -- putting the order
% back later -- so there is nothing to disambiguate between them.

field = "";
direction = "ascend";

% One row is in every order at once, so nothing can be told from it.
if height(before) < 2
    return
end

keys = string(before.(HistologyImageBrowser.CatalogKeyColumn));

headings = string(before.Properties.VariableNames);
headings = headings(headings ~= HistologyImageBrowser.CatalogKeyColumn);

directions = ["ascend", "descend"];

for iHeading = 1:numel(headings)
    spec = find(HistologyImageBrowser.CatalogColumnHeadings == headings(iHeading), 1);

    if isempty(spec)
        continue
    end

    for iDirection = 1:numel(directions)
        idx = HistologyImageBrowser.catalogSortOrder(before, headings(iHeading), ...
            directions(iDirection));

        if isequal(keys(idx), order)
            field = HistologyImageBrowser.CatalogColumnFields(spec);
            direction = directions(iDirection);

            return
        end
    end
end

end

function restore_selection(obj, stems)
%RESTORE_SELECTION Put the selection back on the sections it was on.
% Nothing is redrawn. The same sections are still selected, and the tiles are
% drawn from the sections rather than from where they sit in the table, so
% running the selection callback would rebuild a layout identical to the one
% already on screen -- and would end an ROI edit that has not moved.

if isempty(stems)
    obj.CatalogTable.Selection = [];
    obj.Selection = [];

    return
end

rows = find(ismember(string(obj.View.Stem), stems));

if isempty(rows)
    obj.CatalogTable.Selection = [];
    obj.Selection = [];

    return
end

% Row selections must be given as a row vector.
obj.CatalogTable.Selection = rows(:)';
obj.Selection = rows(:);

end

function announce(obj)
%ANNOUNCE Say what the table was sorted by, or that the order is not kept.
% The header arrow is gone by the time this runs, so the status bar is the only
% place left that says which column the rows are in the order of.

if obj.CatalogSortColumn == ""
    obj.setStatus("Sections reordered. This order cannot be restored, so it is not remembered.");
    return
end

spec = find(HistologyImageBrowser.CatalogColumnFields == obj.CatalogSortColumn, 1);

if obj.CatalogSortDirection == "descend"
    sense = "descending";
else
    sense = "ascending";
end

obj.setStatus("Sections sorted by %s, %s.", ...
    HistologyImageBrowser.CatalogColumnHeadings(spec), sense);

end
