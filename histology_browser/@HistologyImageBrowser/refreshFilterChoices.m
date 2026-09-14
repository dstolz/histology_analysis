function refreshFilterChoices(obj)
%REFRESHFILTERCHOICES Repopulate the filter lists from the loaded catalog.
% Selections that still exist after a reload are preserved.

if height(obj.Catalog) == 0
    obj.SubjectList.Items = {};
    obj.HemisphereList.Items = {};
    obj.StainList.Items = {};
    obj.PlateList.Items = {};
    return
end

set_items(obj.SubjectList, unique_labels(obj.Catalog.SubjectID));
set_items(obj.HemisphereList, unique_labels(obj.Catalog.Hemisphere));
set_items(obj.StainList, unique_labels(obj.Catalog.Stain));
set_items(obj.PlateList, unique_plate_labels(obj.Catalog.AtlasPlate));

end

function labels = unique_labels(values)
%UNIQUE_LABELS Sorted, non-empty unique values as a cellstr.

values = string(values);
values = values(~ismissing(values) & values ~= "");
labels = cellstr(unique(values));

end

function labels = unique_plate_labels(plates)
%UNIQUE_PLATE_LABELS Sorted atlas plate numbers as a cellstr.

plates = plates(~isnan(plates));

if isempty(plates)
    labels = {};
    return
end

labels = cellstr(string(unique(plates)));

end

function set_items(list, labels)
%SET_ITEMS Replace list items while keeping any still-valid selection.

previous = string(list.Value);
list.Items = labels;

if isempty(labels)
    list.Value = {};
    return
end

kept = previous(ismember(previous, string(labels)));
list.Value = cellstr(kept);

end
