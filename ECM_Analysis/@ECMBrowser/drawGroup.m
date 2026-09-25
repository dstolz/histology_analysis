function h = drawGroup(obj, ax, x, Y, idx, cols, series)
    %DRAWGROUP Draw one sub-group's sections into one tile.
    % SERIES says what they are drawn as and where -- see SERIESOF: the
    % group they belong to and its palette color, the marker and line
    % style their values of the Marker by and Line style by fields hand
    % them, and, for a metric summary, the group's slot on the axis and
    % which of the group's sub-groups this is, so that two hemispheres of
    % one subject sit side by side within its slot rather than on top of
    % one another.
    %
    % Nothing drawn here carries a legend entry: the legends are built
    % from stand-ins by LEGENDFOR, so a sub-group drawn dashed does not
    % put a dashed line beside its group's name, and a group is keyed
    % once however many sub-groups it was drawn in.
    %
    % Everything drawn is handed back marked with the series it belongs
    % to and the part it plays in it, which is what lets a color chosen
    % later find its way to every tile at once.

    sty = obj.styleFor(series);

    % A curve carries markers only when a field puts them on it; a point
    % is a marker whether or not one does.
    marked = series.MarkerField ~= obj.NoField;

    h = gobjects(1, 0);
    roles = strings(1, 0);

    switch string(obj.ShowDropDown.Value)

        case "peak summary"
            rows = idx(cols);
            h(end+1) = scatter(ax, obj.View.PeakX(rows), obj.View.PeakY(rows), 42, ...
                sty.Color, "filled", ...
                Marker = sty.Marker, ...
                MarkerFaceAlpha = 0.7, ...
                HandleVisibility = "off");
            roles(end+1) = "marker";

        case "metric summary"
            v = section_metrics(x, Y(:, cols), string(obj.MetricDropDown.Value));

            % One point per section at the sub-group's own place on the
            % axis, spread across it so that two sections of the same
            % value do not land on top of one another. Spread by position
            % in the sub-group rather than at random, so that a redraw
            % puts every point back where it was and a figure saved twice
            % is the same figure twice.
            [center, half] = obj.dodge(series);
            at = center + half * obj.MetricJitter * spread(numel(v));

            h(end+1) = scatter(ax, at, v, 42, ...
                sty.Color, "filled", ...
                Marker = sty.Marker, ...
                MarkerFaceAlpha = 0.7, ...
                HandleVisibility = "off");
            roles(end+1) = "marker";

            % The sub-group's mean ruled through its points, with whatever
            % the Error band control names drawn up and down from it.
            [m, lo, hi] = obj.metricBand(v);

            if isfinite(lo) && isfinite(hi)
                h(end+1) = line(ax, [center center], [lo hi], ...
                    Color = sty.Color, ...
                    LineWidth = 1.5, ...
                    HandleVisibility = "off");
                roles(end+1) = "rule";
            end

            if isfinite(m)
                h(end+1) = line(ax, center + half * [-1 1], [m m], ...
                    Color = sty.Color, ...
                    LineWidth = 2, ...
                    HandleVisibility = "off");
                roles(end+1) = "rule";
            end

        case "sections"
            for iCol = 1:numel(cols)
                y = Y(:, cols(iCol));

                h(end+1) = line(ax, x, y, ...
                    Color = sty.Color, ...
                    LineStyle = sty.LineStyle, ...
                    LineWidth = 1, ...
                    HandleVisibility = "off"); %#ok<AGROW>
                roles(end+1) = "line"; %#ok<AGROW>

                if marked
                    obj.markCurve(h(end), sty, y);
                end
            end

        case "group mean"
            if obj.SectionsCheckBox.Value
                for iCol = 1:numel(cols)
                    h(end+1) = line(ax, x, Y(:, cols(iCol)), ...
                        Color = [sty.Color 0.25], ...
                        LineStyle = sty.LineStyle, ...
                        LineWidth = 0.5, ...
                        HandleVisibility = "off"); %#ok<AGROW>
                    roles(end+1) = "faint"; %#ok<AGROW>
                end
            end

            M = Y(:, cols);
            n = sum(isfinite(M), 2);
            m = mean(M, 2, "omitnan");
            [lo, hi] = obj.bandOf(M, n, m);

            banded = n >= 2 & isfinite(m) & isfinite(lo) & isfinite(hi);

            if any(banded)
                xb = x(banded);
                lob = lo(banded);
                hib = hi(banded);

                h(end+1) = fill(ax, [xb; flipud(xb)], [lob; flipud(hib)], ...
                    sty.Color, ...
                    FaceAlpha = 0.2, ...
                    EdgeColor = "none", ...
                    HandleVisibility = "off");
                roles(end+1) = "band";
            end

            h(end+1) = line(ax, x(n >= 1), m(n >= 1), ...
                Color = sty.Color, ...
                LineStyle = sty.LineStyle, ...
                LineWidth = 2, ...
                HandleVisibility = "off");
            roles(end+1) = "line";

            if marked
                obj.markCurve(h(end), sty, m(n >= 1));
            end
    end

    obj.markStyled(h, roles, series);

end

function offsets = spread(n)
%SPREAD Where each of N points sits across the width of one sub-group's share.
% As a fraction of the half-width, so that one point sits on the
% sub-group's center and any more of them fill the share evenly out to
% its edges.

if n < 2
    offsets = 0;
    return
end

offsets = linspace(-1, 1, n).';

end
