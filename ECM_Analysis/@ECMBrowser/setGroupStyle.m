function setGroupStyle(obj, field, level, opts)
    %SETGROUPSTYLE Draw one group in a color, line style, or marker of your own.
    %   B.setGroupStyle("Treatment", "GM6001", Color = [0.85 0.33 0.10])
    %   B.setGroupStyle("Treatment", "GM6001", LineStyle = "--")
    %   B.setGroupStyle("Hemisphere", "Right", Marker = "s")
    %
    % What the right-click menu does, reachable from a script. FIELD is
    % the field the group came from -- whatever Color by is set to, or
    % Marker by or Line style by for the marker or line style of one of
    % that field's values -- and LEVEL one of its values. Any option can
    % be given on its own, and the others are left as they were.
    %
    % The change reaches every plot already on screen without a redraw,
    % so nothing loses the zoom it was left at, and it is kept until
    % RESETGROUPSTYLES takes it back.

    arguments
        obj
        field (1,1) string
        level (1,1) string
        opts.Color (1,:) double = []
        opts.LineStyle (1,1) string = ""
        opts.Marker (1,1) string = ""
    end

    key = obj.styleKey(field, level);

    if isKey(obj.Styles, key)
        chosen = obj.Styles(key);
    else
        chosen = obj.noStyle();
    end

    if ~isempty(opts.Color)
        if numel(opts.Color) ~= 3 || any(opts.Color < 0 | opts.Color > 1)
            error("ECMBrowser:BadColor", ...
                "Color must be an RGB triplet with each part between 0 and 1.")
        end

        chosen.Color = opts.Color;
    end

    if opts.LineStyle ~= ""
        mustBeMember(opts.LineStyle, obj.LineStyleValues)
        chosen.LineStyle = opts.LineStyle;
    end

    if opts.Marker ~= ""
        mustBeMember(opts.Marker, obj.MarkerValues)
        chosen.Marker = opts.Marker;
    end

    obj.Styles(key) = chosen;
    obj.applyStyles();

end
