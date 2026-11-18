function paths = tableInputs(T)
%HISTDB.TABLEINPUTS The files a sections table's rows were read from: values, ROI and surface files.
%   paths = histdb.tableInputs(T)
%
% A table the histology browser exported (onExportWorkspace) names, per row,
% its ROI file (RoiPath) and the values files of its profiles (ValuesPaths);
% the brain surface marked on an ROI is in the file surface_mark_path names.
% Those are what an analysis of the table read; the images are not (the
% profiles were measured from them before). Paths that do not exist are left
% out. The order is the table's, without repeats.
%
% See also HISTDB.SAVETRACKED, ONEXPORTWORKSPACE.

arguments
    T table
end

paths = strings(0, 1);
names = string(T.Properties.VariableNames);

if ismember("ValuesPaths", names)
    v = T.ValuesPaths;
    if iscell(v)
        for k = 1:numel(v)
            paths = [paths; reshape(string(v{k}), [], 1)]; %#ok<AGROW>
        end
    else
        paths = [paths; reshape(string(v), [], 1)];
    end
end

if ismember("RoiPath", names)
    roi = reshape(string(T.RoiPath), [], 1);
    paths = [paths; roi];
    for k = 1:numel(roi)
        if strlength(roi(k)) == 0 || ismissing(roi(k)); continue; end
        try
            paths(end + 1, 1) = string(surface_mark_path(roi(k))); %#ok<AGROW>
        catch
        end
    end
end

paths = paths(~ismissing(paths) & strlength(paths) > 0);
paths = unique(paths, "stable");
paths = paths(arrayfun(@isfile, paths));

end
