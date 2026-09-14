function idx = catalogSortOrder(display, heading, direction)
%CATALOGSORTORDER Row order one column sort of the Sections table produces.
% The single definition of what "sorted by this column" means here, used both
% to recognize the sort the user just made in ONCATALOGDISPLAYCHANGED and to
% put that sort back in APPLYFILTERS. Sharing it is the whole point: a sort is
% only remembered when this function reproduces the order the widget showed, so
% whatever comes back on the next session is guaranteed to be the order the
% user was looking at when they left.
%
% Blanks are treated as missing and missing values are placed last whichever
% way the column runs. A descending sort with MATLAB's own default would open
% on a screenful of rows that have nothing in the column being sorted, which is
% the one ordering that tells the user nothing; the cost is that a widget sort
% which puts them elsewhere is not recognized, and so is applied but not
% remembered.
%
% Parameters
%   display: Table built by CATALOGDISPLAYTABLE.
%   heading: Variable of that table to sort on.
%   direction: "ascend" or "descend".
%
% Returns
%   idx: Row indices of display, in sorted order. Stable, so rows that tie
%       stay in the order they came in and the Sort by preset survives as the
%       tie-break underneath a column sort.
%
% See also ONCATALOGDISPLAYCHANGED, APPLYFILTERS, CATALOGDISPLAYTABLE.

arguments
    display table
    heading (1,1) string
    direction (1,1) string {mustBeMember(direction, ["ascend", "descend"])} = "ascend"
end

idx = (1:height(display))';

if ~ismember(heading, string(display.Properties.VariableNames))
    return
end

key = display.(heading);

if isstring(key)
    key(key == "") = missing;
end

% Sorted through a one-variable table rather than through SORT so the ordering
% is documented as stable and MissingPlacement is available for every type the
% catalog holds.
[~, idx] = sortrows(table(key), 1, direction, MissingPlacement = "last");

end
