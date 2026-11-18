function record_export(obj, pipeline, file, role)
%RECORD_EXPORT Keep the provenance of a plot or data file saved from the browser.
% The view as commands would rebuild it (captureSettings), the analysis
% settings the sections were prepared with, and the files they came from
% (ecm_prepare_analysis_data's sourceFiles), beside the file written
% (histdb.Run). Keeping it never changes the file or stops the save.

try
    settings = obj.captureSettings();
catch
    settings = struct();
end

analysis = struct();
sources = strings(0, 1);

if isstruct(obj.Data) && isfield(obj.Data, "options") && isstruct(obj.Data.options)
    analysis = obj.Data.options;

    if isfield(analysis, "sourceFiles")
        sources = string(analysis.sourceFiles);
    end

    try
        jsonencode(analysis);
    catch
        analysis = "not recorded: the analysis settings could not be written as JSON";
    end
end

try
    jsonencode(settings);
catch
    settings = "not recorded: the view settings could not be written as JSON";
end

run = histdb.Run(pipeline, Parameters = struct("View", settings, "Analysis", analysis));
run.input(sources, Kind = "ecm_sections");
run.output(file, Role = role, Kind = "ecm_browser_export");
run.finish();

end
