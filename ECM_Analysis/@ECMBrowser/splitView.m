function split = splitView(obj, groupField, aesthetic, idx)
    %SPLITVIEW How the columns in view are told apart: by color, marker, and line style.
    % One field colors the groups, and up to two more put a marker or a
    % line style on the sections within them. Each is answered here for
    % every column at once -- which value it holds and what that value is
    % drawn as -- so the tiles, the legends, and the menus read one split
    % rather than each taking their own.
    %
    % Within a group the sections are divided again into sub-groups, one
    % per combination of marker value and line style value the group's
    % sections hold anywhere in the layout. A sub-group is what a mean is
    % taken over and what a metric summary sets side by side within the
    % group's slot, and it is listed for the whole layout rather than per
    % tile so that a hemisphere sits on the same side of its subject in
    % every tile, whether or not the other hemisphere reached that one.

    [groups, groupOf] = obj.splitBy(groupField, idx);

    colors = lines(max(numel(groups), 7));
    colors = colors(1:numel(groups), :);
    obj.rememberDefaults(groupField, groups, "Color", colors);

    [markers, markerOf] = obj.splitBy(aesthetic(1), idx);
    markerStyles = obj.styleRun(aesthetic(1), markers, "Marker");

    [lineLevels, lineOf] = obj.splitBy(aesthetic(2), idx);
    lineStyles = obj.styleRun(aesthetic(2), lineLevels, "LineStyle");

    % Which combination each column falls in, as one number that orders
    % the combinations by marker value first and line style value second
    % -- the order the legend lists the values in.
    [~, iMarker] = ismember(markerOf, markers);
    [~, iLine] = ismember(lineOf, lineLevels);
    subOf = (iMarker - 1) * numel(lineLevels) + iLine;

    subsOf = cell(1, numel(groups));

    for k = 1:numel(groups)
        subsOf{k} = reshape(unique(subOf(groupOf == groups(k))), 1, []);
    end

    split = struct( ...
        Field = groupField, ...
        Groups = groups, ...
        GroupOf = groupOf, ...
        Colors = colors, ...
        MarkerField = aesthetic(1), ...
        Markers = markers, ...
        MarkerOf = markerOf, ...
        MarkerStyles = markerStyles, ...
        LineField = aesthetic(2), ...
        Lines = lineLevels, ...
        LineOf = lineOf, ...
        LineStyles = lineStyles, ...
        SubOf = subOf, ...
        SubsOf = {subsOf});

end
