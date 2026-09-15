function onEditRoiNames(obj)
%ONEDITROINAMES Name the ROI keys after the regions they measure.
%
% A section's ROIs are keyed A, B, C ... by the labels in their filenames, and
% those letters say only how many there are. Naming them says what they are:
% once A is ACx and B is S1, every overlay caption, legend entry, and catalog
% row reads in the study's own terms, on every section at once, without a
% single file on disk being renamed.
%
% The keys always offered are DEFAULTROIKEYS, plus any key the loaded dataset
% turns out to use and any that already has a name, so the regions a study
% measures can be named once at the start rather than one at a time as each is
% first drawn.
%
% See also ROINAME, SETROINAME, SAVEPREFERENCES.

keys = naming_keys(obj);

prompts = "ROI " + keys + " is called:";
defaults = arrayfun(@(k) obj.roiName(k), keys);

% Blank means "no name", so the key stands for itself; that is also how a name
% already set is cleared.
answer = inputdlg(cellstr(prompts), "ROI Names", [1 34], cellstr(defaults));

if isempty(answer)
    return
end

for iKey = 1:numel(keys)
    obj.setRoiName(keys(iKey), string(answer{iKey}));
end

obj.savePreferences();

% The names are on the tiles, in the legend, in the ROI dropdown, and in the
% catalog column, so all four are told rather than waiting for the next thing
% that happens to redraw them.
refresh_roi_column(obj);
obj.updateRoiEditControls();
obj.renderSelection();

named = sum(obj.RoiNameLabels ~= "");

if named == 0
    obj.setStatus("ROI names cleared; ROIs are shown by their keys.");
    return
end

obj.setSuccess("%d ROI name(s) set: %s.", named, describe_names(obj));

end

function keys = naming_keys(obj)
%NAMING_KEYS Every key worth offering a name for, in a stable order.

keys = string(HistologyImageBrowser.DefaultRoiKeys(:));
keys = unique([keys; obj.RoiNameKeys(:); catalog_keys(obj)], "stable");

end

function keys = catalog_keys(obj)
%CATALOG_KEYS Every ROI key the loaded dataset actually uses.

keys = strings(0, 1);

if height(obj.Catalog) == 0 ...
        || ~ismember("RoiKeys", string(obj.Catalog.Properties.VariableNames))
    return
end

for iRow = 1:height(obj.Catalog)
    keys = [keys; string(obj.Catalog.RoiKeys{iRow})]; %#ok<AGROW>
end

keys = unique(keys);

end

function refresh_roi_column(obj)
%REFRESH_ROI_COLUMN Rewrite the catalog table's ROI names in place.
% REFRESHCATALOGTABLE would reset the selection to the first row, and renaming
% a region is no reason to lose the section on screen.

if isempty(obj.CatalogTable) || ~isvalid(obj.CatalogTable)
    return
end

data = obj.CatalogTable.Data;

if ~istable(data) || height(data) == 0 || height(data) ~= height(obj.View)
    return
end

for iRow = 1:height(data)
    data.ROIs(iRow) = obj.describeRoiList(obj.View(iRow, :));
end

obj.CatalogTable.Data = data;

end

function text = describe_names(obj)
%DESCRIBE_NAMES Say which keys were named what, for the status bar.

named = obj.RoiNameLabels ~= "";
text = join(obj.RoiNameKeys(named) + " is " + obj.RoiNameLabels(named), ", ");

end
