function onExportView(obj)
%ONEXPORTVIEW Export the current view to an image or vector file.
% Whatever the layout is showing is what gets exported, so "Profiles only"
% writes the profile axes rather than an empty tile layout.

source = export_source(obj);

if isempty(source) || ~isvalid(source)
    obj.setWarning("Nothing to export: draw a selection first.");
    uialert(obj.Fig, "There is nothing to export yet.", "Nothing to Export");
    return
end

filters = { ...
    "*.png", "PNG image (*.png)"; ...
    "*.tif", "TIFF image (*.tif)"; ...
    "*.pdf", "PDF document (*.pdf)"};

[fileName, folderName] = uiputfile(filters, "Export current view", "histology_view.png");

if isequal(fileName, 0)
    return
end

target = fullfile(folderName, fileName);

obj.setBusy("Exporting view to %s ...", target);

try
    exportgraphics(source, target, Resolution = 300);
    obj.setSuccess("Exported view to %s", target);
catch ME
    obj.setError("Export failed: %s", ME.message);
    uialert(obj.Fig, ME.message, "Export Failed");
end

end

function source = export_source(obj)
%EXPORT_SOURCE Pick the graphics object the current layout is showing.

source = [];

if obj.showImages()
    source = obj.ImageLayout;
    return
end

if obj.showProfile()
    source = obj.ProfileAxes;
end

end
