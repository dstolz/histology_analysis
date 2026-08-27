function savePreferences(obj)
%SAVEPREFERENCES Persist paths and display settings for the next session.

group = char(obj.PrefGroup);

setpref(group, "LastRootPath", obj.RootPath);
setpref(group, "LastMetadataPath", obj.MetadataPath);
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

% The band width is a property of how the study samples cortex, not of one
% sitting with the browser, so it carries over to the next session.
setpref(group, "RoiWidth", obj.RoiWidthField.Value);

% Which colormap reads best is a property of the stain rather than of one
% sitting, so the per-stain choices carry over too. They are written as two
% string arrays rather than a map, so what prefs hold stays a plain value.
setpref(group, "ColormapStains", obj.ColormapStains);
setpref(group, "ColormapChoices", obj.ColormapChoices);

end
