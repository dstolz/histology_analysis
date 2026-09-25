function lgd = legendFor(obj, ax, split, inScope, placement)
    %LEGENDFOR The key to one tile or to the whole layout, drawn from stand-ins.
    % The entries are stand-ins drawn at NaN rather than the curves
    % themselves. A curve belongs to one sub-group of one tile, so a
    % legend built from whatever sits under it would list a group once
    % per sub-group it was drawn in, in whichever line style the first
    % of them took; drawn at NaN the stand-ins change no limit, and
    % marked with their group they follow a color picked from a
    % right-click menu the way the curves do.
    %
    % INSCOPE says which columns the key stands for: one tile's, or
    % every drawn tile's. The groups those columns hold come first, each
    % in its color and in the plain marker and solid line, and under
    % them the values of the Marker by and Line style by fields they
    % hold, in gray -- no group's color -- and in the marker or line
    % style each value is drawn with, under a heading naming the field.
    % One field drawn by both gets one heading, and one entry per value
    % carrying its line style and its marker together.
    %
    % MATLAB places a legend outside a tiled layout by naming the side
    % it goes on, so the horizontal band lands between the layout title
    % and the top row of plots, and the column beside the right-hand
    % one. Either way the room every tile was spending on its own copy
    % of the key goes back to the plot.

    onPoints = ismember(string(obj.ShowDropDown.Value), ...
        ["peak summary", "metric summary"]);

    proxies = gobjects(1, 0);

    for k = 1:numel(split.Groups)
        held = inScope & split.GroupOf == split.Groups(k);

        if ~any(held)
            continue
        end

        groupKey = string(obj.styleKey(split.Field, split.Groups(k)));

        % The group's own line style and marker stand for it only while
        % no field is drawn by them: once one is, the group is keyed in
        % the plain style and the field's values are keyed below. A
        % curve carries no marker at all until a field puts one on it.
        keys = struct(Color = groupKey, LineStyle = groupKey, Marker = groupKey);

        if split.LineField ~= obj.NoField
            keys.LineStyle = "";
        end

        if split.MarkerField ~= obj.NoField || ~onPoints
            keys.Marker = "";
        end

        if onPoints
            marker = "o";
        else
            marker = "none";
        end

        series = proxy_series(split.Field, split.Groups(k), ...
            split.Colors(k, :), "-", marker, keys);
        label = obj.legendEntry(split.Groups(k), nnz(held));
        proxies(end+1) = obj.legendProxy(ax, series, label, onPoints); %#ok<AGROW>
    end

    sameField = split.MarkerField ~= obj.NoField && ...
        split.MarkerField == split.LineField;

    if split.MarkerField ~= obj.NoField
        proxies(end+1) = heading(ax, split.MarkerField);

        for k = 1:numel(split.Markers)
            if ~any(inScope & split.MarkerOf == split.Markers(k))
                continue
            end

            key = string(obj.styleKey(split.MarkerField, split.Markers(k)));
            lineStyle = "-";
            lineKey = "";

            if sameField
                lineStyle = split.LineStyles(k);
                lineKey = key;
            end

            keys = struct(Color = "", LineStyle = lineKey, Marker = key);
            series = proxy_series(split.MarkerField, split.Markers(k), ...
                obj.NeutralColor, lineStyle, split.MarkerStyles(k), keys);
            proxies(end+1) = obj.legendProxy(ax, series, split.Markers(k), onPoints); %#ok<AGROW>
        end
    end

    if split.LineField ~= obj.NoField && ~sameField
        proxies(end+1) = heading(ax, split.LineField);

        for k = 1:numel(split.Lines)
            if ~any(inScope & split.LineOf == split.Lines(k))
                continue
            end

            keys = struct(Color = "", Marker = "", ...
                LineStyle = string(obj.styleKey(split.LineField, split.Lines(k))));
            series = proxy_series(split.LineField, split.Lines(k), ...
                obj.NeutralColor, split.LineStyles(k), "none", keys);
            proxies(end+1) = obj.legendProxy(ax, series, split.Lines(k), false); %#ok<AGROW>
        end
    end

    % A band across the top is read along its rows, but MATLAB fills a
    % legend down its columns, so the entries are dealt out in the order
    % that puts them back in reading order -- a heading and then its
    % values to the right of it, rather than under it in a column that
    % may have wrapped. Wrapped at all so that a dozen groups stay inside
    % the figure instead of running off the edge of it.
    if placement == "one at top"
        [proxies, nCols] = row_major(proxies, 6);
    end

    lgd = legend(ax, proxies);
    lgd.Interpreter = "none";

    switch placement
        case "one at top"
            lgd.NumColumns = nCols;
            lgd.Layout.Tile = "north";

        case "one at right"
            lgd.Orientation = "vertical";
            lgd.Layout.Tile = "east";

        otherwise
            lgd.Location = "best";
    end

end

function series = proxy_series(field, group, color, lineStyle, marker, keys)
%PROXY_SERIES What a stand-in is marked with.
% The series a curve of the group would be, less the place on the axis
% a stand-in at NaN has no need of.

series = struct( ...
    Field = field, ...
    Group = group, ...
    Color = color, ...
    MarkerField = "", ...
    MarkerLevel = "", ...
    Marker = marker, ...
    LineField = "", ...
    LineLevel = "", ...
    LineStyle = lineStyle, ...
    Slot = NaN, ...
    Position = 1, ...
    NPositions = 1, ...
    Keys = keys);

end

function h = heading(ax, field)
%HEADING An entry with nothing drawn beside it, naming the field whose
% values the entries under it are.

h = line(ax, NaN, NaN, LineStyle = "none", Marker = "none", ...
    DisplayName = field + ":");

end

function [ordered, nCols] = row_major(wanted, maxCols)
%ROW_MAJOR Deal WANTED out so a legend of at most MAXCOLS columns reads across.
% A legend of N entries in NCOLS columns puts entry K in row
% mod(K-1, nRows)+1 of column floor((K-1)/nRows)+1. Reading those cells
% across the rows instead visits them in a different order, and the
% entries are put down in whichever cells that reading meets them in.

n = numel(wanted);
nRows = ceil(n / maxCols);
nCols = ceil(n / nRows);

k = 1:n;
row = mod(k - 1, nRows) + 1;
col = floor((k - 1) / nRows) + 1;

[~, order] = sort((row - 1) * nCols + col);

ordered = wanted;
ordered(order) = wanted;

end
