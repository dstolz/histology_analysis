function applyCatalogColumns(obj, columns, options)
%APPLYCATALOGCOLUMNS Show these catalog columns in the Sections table, in this order.
% Kept apart from ONARRANGECOLUMNS so an arrangement can be validated and
% adopted without a dialog opening: the dialog is one caller, restoring the
% preference at startup is another, and a test that had to drive a modal window
% to check the wiring would be a test that hangs.
%
% Only the columns change here, never the rows, so the selection is left where
% it is and nothing is redrawn: the tiles are drawn from the selected sections
% rather than from what the table shows about them.
%
% Parameters
%   columns: Catalog variable names to show, in display order. Names the column
%       list does not know are dropped and repeats are collapsed, and an
%       arrangement left with nothing in it falls back to the default, so
%       neither a hand-edited preference nor one written by a release that
%       offered a column this one does not can produce an empty table.
%   options.persist: Write the arrangement to preferences and announce it.
%       False on the startup path, which is restoring a choice already made
%       rather than making one, so it neither writes back what it just read nor
%       puts a message on a status bar the user has not looked at yet.
%
% See also ONARRANGECOLUMNS, CATALOGDISPLAYTABLE, WRITECATALOGTABLE,
% LOADPREFERENCES, SAVEPREFERENCES.

arguments
    obj
    columns string = HistologyImageBrowser.DefaultCatalogColumns
    options.persist (1,1) logical = true
end

columns = string(columns(:))';
columns = columns(ismember(columns, HistologyImageBrowser.CatalogColumnFields));
columns = unique(columns, "stable");

if isempty(columns)
    columns = HistologyImageBrowser.DefaultCatalogColumns;
end

obj.CatalogColumns = columns;

% A sort on a column that is no longer shown has no header to toggle and
% nothing on screen to explain the order it puts the rows in, so it is dropped
% rather than left ordering sections by something the user cannot see.
if obj.CatalogSortColumn ~= "" && ~ismember(obj.CatalogSortColumn, columns)
    obj.CatalogSortColumn = "";
end

obj.writeCatalogTable();

if ~options.persist
    return
end

obj.savePreferences();

obj.setStatus("Sections table showing %d of %d columns.", ...
    numel(columns), numel(HistologyImageBrowser.CatalogColumnFields));

end
