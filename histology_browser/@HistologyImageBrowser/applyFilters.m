function applyFilters(obj)
%APPLYFILTERS Reduce the catalog to the rows passing every active filter.
% An empty list box means "no constraint" rather than "match nothing".
%
% Also where the two ways of ordering the rows are reconciled. The Sort by
% preset and a click on a column heading both end as an order of obj.View, and
% the last one the user reached for wins: moving the preset clears the column
% sort, and a column sort otherwise leads with the preset left underneath it as
% the tie-break. That keeps a sort alive across a refilter, which is what a
% user who sorted by plate and then narrowed to one stain expects.
%
% The preset moving is noticed by comparing it against the one recorded when
% the column sort was made, rather than by giving the dropdown a callback of
% its own: BUILDFILTERPANEL owns that control and points it straight at this
% function, so this is the only place both orderings pass through.

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

preset = string(obj.SortDropDown.Value);

if preset ~= obj.CatalogSortPreset
    obj.CatalogSortColumn = "";
    obj.CatalogSortPreset = preset;
end

V = sort_view(C(keep, :), preset);

obj.View = sort_by_column(obj, V);
obj.refreshCatalogTable();

end

function V = sort_view(V, sortMode)
%SORT_VIEW Order the filtered rows for display.
% The presets are multi-key orderings with no heading to click, so they stay
% here rather than being expressed as column sorts.

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

function V = sort_by_column(obj, V)
%SORT_BY_COLUMN Put back the column sort the user last made, if there is one.
% Applied to the values the table draws rather than to the catalog values
% behind them, by sorting a display table built for these rows and carrying the
% resulting order back. Those are not always the same ordering -- the Subject
% column drops a prefix on its way to the screen -- and the sort being restored
% is the one the user made on a heading, so it is the drawn values it has to be
% made from.
%
% A column that is no longer shown orders nothing: it would leave the rows in
% an order with nothing on screen to explain it. APPLYCATALOGCOLUMNS already
% drops the sort when its column is hidden, and this is the second half of that
% agreement, for a saved sort read back beside a saved arrangement.

if height(V) == 0 || obj.CatalogSortColumn == ""
    return
end

spec = find(HistologyImageBrowser.CatalogColumnFields == obj.CatalogSortColumn, 1);

if isempty(spec)
    return
end

heading = HistologyImageBrowser.CatalogColumnHeadings(spec);

display = HistologyImageBrowser.catalogDisplayTable(V, obj.CatalogColumns);

% Asked of the table that was actually built rather than of the arrangement,
% because CATALOGDISPLAYTABLE drops any column this catalog does not carry and
% falls back to the default when that leaves nothing.
if ~ismember(heading, string(display.Properties.VariableNames))
    return
end

V = V(HistologyImageBrowser.catalogSortOrder(display, heading, obj.CatalogSortDirection), :);

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
