function [display, widths] = catalogDisplayTable(rows, columns)
%CATALOGDISPLAYTABLE Build the table the Sections widget shows for some rows.
% The one place a catalog turns into what the Sections table draws, so that
% WRITECATALOGTABLE and the sort APPLYFILTERS restores cannot disagree about
% which values a column holds. Restoring a sort means reproducing an ordering
% of the drawn values, and a second construction of "the display table" living
% beside this one is exactly how the two would drift apart.
%
% Static, and taking the rows rather than reading obj.View, because
% APPLYFILTERS has to build it for a candidate view it has not adopted yet.
%
% Every arrangement carries CATALOGKEYCOLUMN as its last variable, drawn at
% zero width. That is the column a displayed row is mapped back through after
% the user sorts, and it is present whether or not the visible Stem column is,
% because an arrangement showing neither the stem nor anything else unique
% would otherwise leave a sorted row unidentifiable.
%
% Parameters
%   rows: Catalog rows to draw, in the order they are to be drawn in.
%   columns: Catalog variable names to show, in display order. Names this
%       catalog does not carry are dropped rather than thrown on, so a catalog
%       built by an older release cannot leave the table empty.
%
% Returns
%   display: One variable per shown column, named for its heading, plus the
%       key column last.
%   widths: Value for the widget's ColumnWidth, matching display.
%
% See also WRITECATALOGTABLE, APPLYCATALOGCOLUMNS, CATALOGSORTORDER,
% REFRESHCATALOGTABLE.

arguments
    rows table
    columns string = HistologyImageBrowser.DefaultCatalogColumns
end

display = table();
widths = "auto";

present = string(rows.Properties.VariableNames);

% Without the stem there is nothing to key the rows by, so nothing is drawn
% rather than a table whose rows cannot be mapped back after a sort.
if ~ismember("Stem", present)
    return
end

fields = HistologyImageBrowser.CatalogColumnFields;

columns = string(columns(:))';
columns = columns(ismember(columns, fields) & ismember(columns, present));

if isempty(columns)
    columns = HistologyImageBrowser.DefaultCatalogColumns;
    columns = columns(ismember(columns, present));
end

widths = cell(1, numel(columns) + 1);

for iColumn = 1:numel(columns)
    spec = find(fields == columns(iColumn), 1);

    display.(HistologyImageBrowser.CatalogColumnHeadings(spec)) = ...
        display_values(rows, columns(iColumn));

    widths{iColumn} = width_value(HistologyImageBrowser.CatalogColumnWidths(spec));
end

display.(HistologyImageBrowser.CatalogKeyColumn) = string(rows.Stem);
widths{end} = 0;

end

function values = display_values(rows, field)
%DISPLAY_VALUES Take one catalog column, shortened where the heading is narrow.
% Only the subject is touched. Every subject in a dataset carries the same
% SUBJ-ID- prefix, so the prefix distinguishes nothing and costs the column
% eight characters it does not have.

values = rows.(field);

if field == "SubjectID"
    values = replace(string(values), "SUBJ-ID-", "");
end

end

function width = width_value(spec)
%WIDTH_VALUE Turn a width from the column list into what ColumnWidth takes.

if spec == "auto"
    width = "auto";
    return
end

width = str2double(spec);

end
