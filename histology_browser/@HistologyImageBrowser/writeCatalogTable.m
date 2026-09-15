function writeCatalogTable(obj)
%WRITECATALOGTABLE Put obj.View into the Sections table, row for row.
% The one place the widget's Data is assigned, so the invariant the rest of the
% browser depends on -- displayed row N is obj.View row N -- has one place it
% can be broken and one place it is kept.
%
% The assignment is what ONCATALOGDISPLAYCHANGED reacts to, so it is fenced
% with CatalogTableSyncing. R2025a happens not to fire the callback for a
% programmatic write, but a guard that costs a boolean is cheaper than a
% behavior that has to be true of every release.
%
% Nothing about the selection is decided here beyond keeping it pointing at the
% same row numbers it already pointed at, which is what a column arrangement
% change wants: the rows have not moved, only the columns beside them.
% REFRESHCATALOGTABLE and ONCATALOGDISPLAYCHANGED each set the selection
% themselves afterwards, because each has its own idea of where it should land.
%
% See also CATALOGDISPLAYTABLE, ONCATALOGDISPLAYCHANGED, REFRESHCATALOGTABLE,
% APPLYCATALOGCOLUMNS.

if isempty(obj.CatalogTable) || ~isvalid(obj.CatalogTable)
    return
end

previous = obj.CatalogTable.Selection;

obj.CatalogTableSyncing = true;
% Held in a variable so the guard lives until this function returns.
releaseGuard = onCleanup(@() release_guard(obj));

[display, widths] = HistologyImageBrowser.catalogDisplayTable(obj.View, obj.CatalogColumns, ...
    roiText = obj.roiListText(obj.View));

obj.CatalogTable.Data = display;
obj.CatalogTable.ColumnWidth = widths;

if isempty(previous) || height(display) == 0
    return
end

% A write that shortened the table would leave the old selection pointing past
% its end, which the widget refuses rather than trims.
previous = previous(previous >= 1 & previous <= height(display));

if isempty(previous)
    obj.CatalogTable.Selection = [];
    return
end

obj.CatalogTable.Selection = previous;

end

function release_guard(obj)
%RELEASE_GUARD Let the display-changed handler act again.
% Run through ONCLEANUP so a write that throws cannot leave the handler deaf to
% every sort the user makes for the rest of the session.

obj.CatalogTableSyncing = false;

end
