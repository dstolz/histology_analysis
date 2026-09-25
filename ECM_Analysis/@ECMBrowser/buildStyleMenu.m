function cm = buildStyleMenu(obj, fig, split, clicked)
    %BUILDSTYLEMENU The menu behind one right-click.
    % A curve's menu leads with its own group, because that is the one
    % the click was about, and keeps the rest a level down so that a
    % click landing on the wrong curve is still one menu away from the
    % right group. Under the groups come the values of whichever fields
    % the markers and line styles are drawn by, so which hemisphere is
    % the dashed one is still a choice.

    cm = uicontextmenu(fig, Tag = char(obj.MenuTag), ...
        ContextMenuOpeningFcn = @(src, ~) obj.syncStyleMenu(src));

    groups = split.Groups;
    others = groups;

    if clicked ~= ""
        obj.addStyleItems(cm, split.Field, clicked, clicked + ": ");
        others = groups(groups ~= clicked);
    end

    if ~isempty(others)
        parent = cm;

        if clicked ~= ""
            parent = uimenu(cm, Text = "Other groups", Separator = "on");
        end

        for k = 1:numel(others)
            obj.addStyleItems(uimenu(parent, Text = others(k)), ...
                split.Field, others(k), "");
        end
    end

    obj.addRunItems(cm, split.MarkerField, split.Markers, "Marker");
    obj.addRunItems(cm, split.LineField, split.Lines, "LineStyle");

    uimenu(cm, Text = "Reset all groups", Separator = "on", ...
        MenuSelectedFcn = @(~, ~) obj.resetViewStyles(split));

end
