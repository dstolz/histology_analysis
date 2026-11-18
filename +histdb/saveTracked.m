function file = saveTracked(file, name, value, opts)
%HISTDB.SAVETRACKED Save VALUE to a MAT file as variable NAME, and record the run that made it.
%   histdb.saveTracked("histology_ACxProfiles.mat", "histology", histology)
%   histdb.saveTracked(..., Pipeline = "histology_analysis/browser_export", ...
%       Inputs = paths, Parameters = s)
%
% The same file save(file, name) would write. Its provenance record
% (histdb.Run) names the file as the output and, as inputs, the files given
% in Inputs, or, for a sections table exported from the histology browser,
% the values, ROI and surface files its rows were read from
% (histdb.tableInputs).
%
% Returns the absolute path of the file written.
%
% See also HISTDB.RUN, HISTDB.TABLEINPUTS.

arguments
    file (1,1) string
    name (1,1) string
    value
    opts.Pipeline (1,1) string = "histology_analysis/browser_export"
    opts.Inputs string = string(missing)
    opts.Parameters = struct()
    opts.SubjectId (1,1) string = ""
end

file = absolutePath(file);
run = histdb.Run(opts.Pipeline, Parameters = opts.Parameters, SubjectId = opts.SubjectId);

if isscalar(opts.Inputs) && ismissing(opts.Inputs)
    inputs = strings(0, 1);
    if istable(value)
        inputs = histdb.tableInputs(value);
    end
else
    inputs = opts.Inputs;
end
run.input(inputs, Role = "derived", Kind = "histology_section_files");

S.(name) = value;
try
    save(file, "-struct", "S");
catch ME
    run.fail(ME);
    rethrow(ME);
end

run.output(file, Role = "derived", Kind = "mat");
run.finish();

end
