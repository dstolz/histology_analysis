function repaint(obj, h)
    %REPAINT One artist, in whatever its series is drawn in now.
    % A band and a scatter have no line style to take, the rules through
    % a metric summary's group have one but should not take it, and the
    % sections drawn faintly behind a mean carry their transparency in
    % the color itself, so each part of a group is put back its own way.
    % A curve takes a marker only if it was given one to begin with.

    mark = h.UserData;
    sty = obj.styleFor(mark);

    switch mark.Role
        case "line"
            h.Color = sty.Color;
            h.LineStyle = sty.LineStyle;

            if strlength(mark.Keys.Marker) > 0
                h.Marker = sty.Marker;
                h.MarkerFaceColor = sty.Color;
            end

        case "faint"
            h.Color = [sty.Color 0.25];
            h.LineStyle = sty.LineStyle;

        case "band"
            h.FaceColor = sty.Color;

        case "rule"
            % The mean and the interval through a metric summary's
            % group. Both are lines, but neither is the curve the line
            % style was chosen for -- a dashed mean would read as
            % another kind of average rather than as the same one in
            % another group's style -- so they take the color alone.
            h.Color = sty.Color;

        case "marker"
            h.CData = sty.Color;
            h.Marker = sty.Marker;
    end

end
