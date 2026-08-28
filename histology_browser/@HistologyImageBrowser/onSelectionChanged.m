function onSelectionChanged(obj)
%ONSELECTIONCHANGED Record the selected rows, refresh channels, and redraw.

selection = obj.CatalogTable.Selection;

% With SelectionType "row" the table reports a plain vector of row indices,
% so flatten rather than indexing a column that does not exist.
if isempty(selection)
    obj.Selection = [];
else
    obj.Selection = unique(selection(:));
end

% The green "saved" mark is a confirmation of the write just made, not a
% property of the file, so it lasts only as long as the section it was made on
% is still on screen.
selectedStems = obj.selectedRows();

if obj.RoiSavedStem ~= "" && ~(height(selectedStems) > 0 ...
        && any(string(selectedStems.Stem) == obj.RoiSavedStem))
    obj.RoiSavedStem = "";
end

% An ROI edit belongs to one section, so moving off it ends the edit. The
% prompt comes before the redraw, so nothing is lost silently.
if obj.RoiEditStem ~= "" && ~obj.isEditingRow(obj.selectedRows())
    % The selection has already moved by this point, so a cancelled prompt
    % cannot put it back; the edit is dropped rather than left attached to a
    % section that is no longer on screen.
    if ~obj.exitRoiEdit(true)
        obj.exitRoiEdit(false);
    end
end

refresh_channel_choices(obj);

% The colormap that reads well for one stain rarely reads well for another,
% so the section now selected comes back in the map its stain was last shown
% in. Set before the redraw, so the tiles are drawn once.
obj.applyStainColormap();

% The review panel reads the selection's plate and measured state, so it is
% told before the redraw rather than left showing the section just left.
obj.updateReviewControls();

obj.renderSelection();

end

function refresh_channel_choices(obj)
%REFRESH_CHANNEL_CHOICES Offer only the channels the selected images contain.

rows = obj.selectedRows();

if isempty(rows) || height(rows) == 0
    return
end

nPages = 1;
channelNames = strings(0, 1);

for iRow = 1:height(rows)
    imagePath = obj.resolveImagePath(rows(iRow, :));

    if imagePath == "" || ~isfile(imagePath)
        continue
    end

    thisPages = count_pages(imagePath);
    nPages = max(nPages, thisPages);

    if isempty(channelNames)
        channelNames = channel_names_from_stain(rows.Stain(iRow), thisPages);
    end
end

items = strings(1, nPages);
itemsData = cell(1, nPages);

for iPage = 1:nPages
    if iPage <= numel(channelNames) && channelNames(iPage) ~= ""
        items(iPage) = sprintf("Ch %d (%s)", iPage, channelNames(iPage));
    else
        items(iPage) = sprintf("Channel %d", iPage);
    end

    itemsData{iPage} = iPage;
end

if nPages > 1
    items(end + 1) = "Merge (RGB)";
    itemsData{end + 1} = "merge";
end

previous = obj.ChannelDropDown.Value;

obj.ChannelDropDown.Items = items;
obj.ChannelDropDown.ItemsData = itemsData;

if is_selectable(previous, itemsData)
    obj.ChannelDropDown.Value = previous;
else
    obj.ChannelDropDown.Value = itemsData{1};
end

% The channel list is rebuilt for every selection, so the menu mirroring it has
% to be rebuilt with it.
obj.syncDisplayMenu();

end

function tf = is_selectable(value, itemsData)
%IS_SELECTABLE Test whether a previous channel choice still exists.

tf = false;

for iItem = 1:numel(itemsData)
    if isequal(itemsData{iItem}, value)
        tf = true;
        return
    end
end

end

function nPages = count_pages(imagePath)
%COUNT_PAGES Count the pages in an image file, defaulting to one.

nPages = 1;

[~, ~, ext] = fileparts(imagePath);

if ~ismember(lower(string(ext)), [".tif", ".tiff"])
    return
end

try
    nPages = numel(imfinfo(imagePath));
catch
    nPages = 1;
end

end

function names = channel_names_from_stain(stain, nPages)
%CHANNEL_NAMES_FROM_STAIN Split a stain label such as WFA-PV into channels.
% Only used when the split produces exactly one name per page, so an unrelated
% hyphenated label never mislabels a channel.

names = strings(0, 1);

stain = strtrim(string(stain));

if stain == ""
    return
end

parts = split(stain, "-");

if numel(parts) == nPages
    names = string(parts);
end

end
