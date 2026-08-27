function applyFilters(obj)
%APPLYFILTERS Reduce the catalog to the rows passing every active filter.
% An empty list box means "no constraint" rather than "match nothing".

if height(obj.Catalog) == 0
    obj.View = obj.Catalog;
    obj.refreshCatalogTable();
    return
end

C = obj.Catalog;
keep = true(height(C), 1);

keep = keep & match_list(obj.SubjectList, C.SubjectID);
keep = keep & match_list(obj.HemisphereList, C.Hemisphere);
keep = keep & match_list(obj.StainList, C.Stain);
keep = keep & match_plates(obj.PlateList, C.AtlasPlate);

if obj.ProfileOnlyCheck.Value
    keep = keep & C.NProfiles > 0;
end

keep = keep & match_search(obj.SearchField.Value, C);

obj.View = sort_view(C(keep, :), string(obj.SortDropDown.Value));
obj.refreshCatalogTable();

end

function V = sort_view(V, sortMode)
%SORT_VIEW Order the filtered rows for display.
% Sorting happens here rather than through ColumnSortable so that a table
% selection index always refers to the same row of obj.View.

if height(V) == 0
    return
end

switch sortMode
    case "plate"
        V = sortrows(V, ["AtlasPlate", "SubjectID", "SectionID", "Hemisphere"]);
    case "stain"
        V = sortrows(V, ["Stain", "SubjectID", "SectionID", "Hemisphere"]);
    case "status"
        V = sortrows(V, ["Status", "SubjectID", "SectionID", "Hemisphere"]);
    otherwise
        V = sortrows(V, ["SubjectID", "SampleID", "SectionID", "Hemisphere", "Stain"]);
end

end

function keep = match_list(list, values)
%MATCH_LIST Keep rows whose value is among the selected list entries.

selected = string(list.Value);

if isempty(selected)
    keep = true(numel(values), 1);
    return
end

keep = ismember(string(values), selected);

end

function keep = match_plates(list, plates)
%MATCH_PLATES Keep rows whose atlas plate is among the selected entries.

selected = string(list.Value);

if isempty(selected)
    keep = true(numel(plates), 1);
    return
end

keep = ismember(string(plates), selected);

end

function keep = match_search(searchText, C)
%MATCH_SEARCH Keep rows matching every whitespace-separated search term.

searchText = strtrim(string(searchText));

if searchText == ""
    keep = true(height(C), 1);
    return
end

terms = split(searchText);
terms = terms(terms ~= "");

haystack = lower(join([ ...
    C.Stem, C.SubjectID, C.SectionID, C.Hemisphere, C.Stain, ...
    C.Content, C.ROI, C.Notes, C.ProcessingID, C.Status, ...
    string(C.AtlasPlate)], " ", 2));

keep = true(height(C), 1);

for iTerm = 1:numel(terms)
    keep = keep & contains(haystack, lower(terms(iTerm)));
end

end
