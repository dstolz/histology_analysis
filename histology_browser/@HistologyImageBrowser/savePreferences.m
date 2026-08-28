function savePreferences(obj)
%SAVEPREFERENCES Persist paths and display settings for the next session.

group = char(obj.PrefGroup);

setpref(group, "LastRootPath", obj.RootPath);
setpref(group, "LastMetadataPath", obj.MetadataPath);

% Where the tracker is, not what is in it. The key file is named rather than
% read, so nothing secret is written to the preference store.
setpref(group, "SheetUrl", obj.SheetUrl);
setpref(group, "SheetTab", obj.SheetTab);
setpref(group, "SheetCredentials", obj.SheetCredentials);
setpref(group, "Variant", obj.VariantDropDown.Value);
setpref(group, "Colormap", obj.ColormapDropDown.Value);
setpref(group, "LowPercentile", obj.LowPercentileField.Value);
setpref(group, "HighPercentile", obj.HighPercentileField.Value);
setpref(group, "MaxTiles", obj.MaxTilesField.Value);
setpref(group, "ShowRoi", obj.ShowRoiCheck.Value);
setpref(group, "ShowBand", obj.ShowBandCheck.Value);
setpref(group, "ColorByIntensity", obj.ColorByIntensityCheck.Value);
setpref(group, "ProfileLayout", obj.ProfileLayoutDropDown.Value);
setpref(group, "ProfileSize", obj.ProfileSizeField.Value);
setpref(group, "ImageBackground", obj.ImageBackground);

% The band width is a property of how the study samples cortex, not of one
% sitting with the browser, so it carries over to the next session.
setpref(group, "RoiWidth", obj.RoiWidthField.Value);

% Which colormap reads best is a property of the stain rather than of one
% sitting, so the per-stain choices carry over too. They are written as two
% string arrays rather than a map, so what prefs hold stays a plain value.
setpref(group, "ColormapStains", obj.ColormapStains);
setpref(group, "ColormapChoices", obj.ColormapChoices);

save_figure_geometry(obj, group);

end

function save_figure_geometry(obj, group)
%SAVE_FIGURE_GEOMETRY Record where the window sits and how it is shown.
% A maximized window reports its maximized bounds as its position, so that
% geometry is left as it was and only the state is written. The window then
% reopens maximized, and restores down to wherever it sat before.

if isempty(obj.Fig) || ~isvalid(obj.Fig)
    return
end

state = string(obj.Fig.WindowState);

if state == "normal"
    setpref(group, "FigurePosition", obj.Fig.Position);
end

% Minimized is a passing state rather than a way to open, so it is recorded
% as the ordinary window it would restore to.
if state == "minimized"
    state = "normal";
end

setpref(group, "FigureWindowState", state);

end
