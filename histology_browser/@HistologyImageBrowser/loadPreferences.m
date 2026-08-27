function loadPreferences(obj)
%LOADPREFERENCES Restore saved paths and display settings.
% Every value is validated before use so a stale preference cannot leave a
% control in an invalid state.

group = char(obj.PrefGroup);

rootPath = read_pref(group, "LastRootPath", "");

if rootPath ~= "" && isfolder(rootPath)
    obj.RootPath = rootPath;
end

metadataPath = read_pref(group, "LastMetadataPath", "");

if metadataPath ~= "" && isfile(metadataPath)
    obj.MetadataPath = metadataPath;
end

apply_dropdown(obj.VariantDropDown, read_pref(group, "Variant", ""));
apply_dropdown(obj.ColormapDropDown, read_pref(group, "Colormap", ""));
apply_stain_colormaps(obj, group);

apply_numeric(obj.LowPercentileField, read_pref(group, "LowPercentile", []));
apply_numeric(obj.HighPercentileField, read_pref(group, "HighPercentile", []));
apply_numeric(obj.MaxTilesField, read_pref(group, "MaxTiles", []));

apply_checkbox(obj.ShowRoiCheck, read_pref(group, "ShowRoi", []));
apply_checkbox(obj.ShowBandCheck, read_pref(group, "ShowBand", []));
apply_checkbox(obj.ColorByIntensityCheck, read_pref(group, "ColorByIntensity", []));
apply_dropdown(obj.ProfileLayoutDropDown, profile_layout_pref(group));
apply_numeric(obj.ProfileSizeField, read_pref(group, "ProfileSize", []));
apply_numeric(obj.RoiWidthField, read_pref(group, "RoiWidth", []));

% The restored paths are only visible on the Dataset menu and in the title bar.
obj.refreshDatasetMenu();

obj.applyViewLayout();

end

function code = profile_layout_pref(group)
%PROFILE_LAYOUT_PREF Read the saved layout, honoring the older on/off flag.

code = read_pref(group, "ProfileLayout", "");

if code ~= ""
    return
end

% Sessions saved before the layout choice existed recorded only whether the
% profile plot was shown at all.
wasShown = read_pref(group, "ShowProfile", []);

if ~isempty(wasShown) && (islogical(wasShown) || isnumeric(wasShown)) && ~logical(wasShown(1))
    code = "hidden";
end

end

function apply_stain_colormaps(obj, group)
%APPLY_STAIN_COLORMAPS Restore the colormap remembered for each stain.
% The pairs are dropped rather than trusted when the two saved lists disagree
% in length, or when a saved colormap is no longer offered, so a stale
% preference cannot name a colormap the dropdown does not have.

stains = string(read_pref(group, "ColormapStains", strings(0, 1)));
choices = string(read_pref(group, "ColormapChoices", strings(0, 1)));

stains = stains(:);
choices = choices(:);

if isempty(stains) || numel(stains) ~= numel(choices)
    return
end

keep = stains ~= "" & ismember(choices, string(obj.ColormapDropDown.Items));

obj.ColormapStains = stains(keep);
obj.ColormapChoices = choices(keep);

end

function value = read_pref(group, name, defaultValue)
%READ_PREF Read one preference, falling back to a default.

value = defaultValue;

if ~ispref(group, char(name))
    return
end

try
    value = getpref(group, char(name));
catch
    value = defaultValue;
end

if ischar(value)
    value = string(value);
end

end

function apply_dropdown(control, value)
%APPLY_DROPDOWN Apply a saved dropdown choice when it is still offered.

if isempty(value) || (isstring(value) && value == "")
    return
end

if isempty(control.ItemsData)
    if ismember(value, string(control.Items))
        control.Value = value;
    end

    return
end

for iItem = 1:numel(control.ItemsData)
    if isequal(string(control.ItemsData{iItem}), string(value))
        control.Value = control.ItemsData{iItem};
        return
    end
end

end

function apply_numeric(control, value)
%APPLY_NUMERIC Apply a saved numeric value when it is inside the limits.

if isempty(value) || ~isnumeric(value) || ~isscalar(value) || ~isfinite(value)
    return
end

if value < control.Limits(1) || value > control.Limits(2)
    return
end

control.Value = value;

end

function apply_checkbox(control, value)
%APPLY_CHECKBOX Apply a saved checkbox state.

if isempty(value) || ~(islogical(value) || isnumeric(value)) || ~isscalar(value)
    return
end

control.Value = logical(value);

end
