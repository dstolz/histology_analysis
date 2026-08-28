function refreshReviewColumns(obj)
%REFRESHREVIEWCOLUMNS Push changed review values into the table in place.
% REFRESHCATALOGTABLE rebuilds the whole table and then selects its first row,
% which is right after a load or a filter change and wrong after a review edit:
% someone working down a stack of sections would be thrown back to the top by
% every mark. Only the two columns that can change are rewritten here, and the
% selection is left alone.
%
% See also HISTOLOGYIMAGEBROWSER/WRITEREVIEW,
% HISTOLOGYIMAGEBROWSER/REFRESHCATALOGTABLE.

if isempty(obj.CatalogTable) || ~isvalid(obj.CatalogTable)
    return
end

display = obj.CatalogTable.Data;

if ~istable(display) || height(display) ~= height(obj.View)
    return
end

if ismember("Plate", string(display.Properties.VariableNames))
    display.Plate = obj.View.AtlasPlate;
end

if ismember("Meas", string(display.Properties.VariableNames))
    marks = strings(height(obj.View), 1);
    marks(logical(obj.View.Measured)) = char(10003);
    display.Meas = marks;
end

selection = obj.CatalogTable.Selection;
obj.CatalogTable.Data = display;
obj.CatalogTable.Selection = selection;

end
