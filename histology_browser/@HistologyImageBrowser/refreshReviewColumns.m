function refreshReviewColumns(obj)
%REFRESHREVIEWCOLUMNS Push changed review values into the table in place.
% REFRESHCATALOGTABLE rebuilds the whole table and then selects its first row,
% which is right after a load or a filter change and wrong after a review edit:
% someone working down a stack of sections would be thrown back to the top by
% every mark. Only the two columns that can change are rewritten here, and the
% selection is left alone.
%
% Which columns those are is read from the arrangement rather than named here,
% because the Sections table shows a chosen subset of the catalog: a review can
% be written while Plate or Meas is not on screen, and a heading is also
% something the column list is free to reword. A column the arrangement does
% not currently show is simply skipped -- the value behind it is already in
% obj.View, so it is drawn correctly the next time the table is rebuilt.
%
% The values are rendered through CATALOGDISPLAYTABLE, so a tick written after
% a review and a tick written by a full refresh cannot come out differently.
%
% See also HISTOLOGYIMAGEBROWSER/WRITEREVIEW, CATALOGDISPLAYTABLE,
% HISTOLOGYIMAGEBROWSER/REFRESHCATALOGTABLE.

if isempty(obj.CatalogTable) || ~isvalid(obj.CatalogTable)
    return
end

display = obj.CatalogTable.Data;

% WRITECATALOGTABLE keeps displayed row N as obj.View row N, so the two can be
% written across one for one. A table that has come out of step with the view
% is left for the next full rebuild rather than written into blind.
if ~istable(display) || height(display) ~= height(obj.View)
    return
end

[reviewed, replaced] = review_columns(obj, display);

if ~replaced
    return
end

% The assignment is what ONCATALOGDISPLAYCHANGED reacts to, and the rows have
% not moved, so it is fenced exactly as WRITECATALOGTABLE fences its own.
obj.CatalogTableSyncing = true;
releaseGuard = onCleanup(@() release_guard(obj));

selection = obj.CatalogTable.Selection;
obj.CatalogTable.Data = reviewed;
obj.CatalogTable.Selection = selection;

end

function [display, replaced] = review_columns(obj, display)
%REVIEW_COLUMNS Rewrite the shown review columns from the current view.

replaced = false;

fields = ["AtlasPlate", "Measured"];
present = string(obj.View.Properties.VariableNames);
headings = string(display.Properties.VariableNames);

for iField = 1:numel(fields)
    if ~ismember(fields(iField), present)
        continue
    end

    spec = find(HistologyImageBrowser.CatalogColumnFields == fields(iField), 1);
    heading = HistologyImageBrowser.CatalogColumnHeadings(spec);

    if ~ismember(heading, headings)
        continue
    end

    values = HistologyImageBrowser.catalogDisplayTable(obj.View, fields(iField));

    display.(heading) = values.(heading);
    replaced = true;
end

end

function release_guard(obj)
%RELEASE_GUARD Let the display-changed handler act again.

obj.CatalogTableSyncing = false;

end
