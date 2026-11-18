function histology = ecm_attach_project_info(histology, project, options)
%ECM_ATTACH_PROJECT_INFO Join the project sheet's per-hemisphere design onto the sections.
%   histology = ecm_attach_project_info(histology, projectFile)
%   histology = ecm_attach_project_info(histology, P)
%   histology = ecm_attach_project_info(..., SaveTo = "...full.mat")
%
% The project sheet ("ECM Projects - GM6001") has one row per subject and says
% which hemisphere received the drug and which the vehicle. The sections table
% exported from the histology browser has one row per section and hemisphere.
% This reshapes the sheet to one row per subject and hemisphere, so the drug
% and vehicle columns land on the hemisphere they were infused into, and joins
% it onto the sections:
%
%   Treatment    "GM6001" or "Vehicle" on an infused hemisphere; for a
%                control (no infused hemisphere) "Control L" / "Control R"
%   Infusion1h, Infusion3h   that hemisphere's infusion columns
%   CannulaDist  AtlasPlate minus that hemisphere's cannula plate (a control
%                is measured from ControlCannulaPlate)
%
% plus the subject-level columns Condition, LeftCannulaPlate,
% RightCannulaPlate, Sex, InfusionQuality, GM6001Molarity_uM_ and
% IncludeInAnalysis.
%
% Parameters
%   histology: Sections table (SubjectID, Hemisphere "L"/"R", AtlasPlate, ...).
%   project: The project sheet as a CSV path, or as a table read with
%       readtable(..., TextType = "string").
%   options.ControlCannulaPlate: Plate a control's CannulaDist is measured
%       from. Default 30.
%   options.SaveTo: When set, the joined table is saved there as the variable
%       "histology", and the run's provenance is recorded beside it
%       (histdb.Run, "histology_analysis/ecm_attach_project"; a .provenance
%       folder): the project sheet and InputFiles as inputs, the saved file
%       as the output, ControlCannulaPlate as the parameter. Recording never
%       changes the table or the file, and never stops the save.
%   options.InputFiles: Files the sections table was loaded from (e.g. the
%       browser export's .mat), named as inputs in the provenance record.
%
% Returns
%   histology: The joined table. The join is a left outer join on SubjectID and
%       Hemisphere with merged keys, so its rows come back sorted by those keys.
%
% See also ECM_EXPORT_FOR_R, ECM_PREPARE_ANALYSIS_DATA, S_ECMANALYSIS.

arguments
    histology table
    project
    options.ControlCannulaPlate (1,1) double = 30
    options.SaveTo (1,1) string = ""
    options.InputFiles string = strings(0, 1)
end

if istable(project)
    P = project;
else
    P = readtable(string(project), "TextType", "string");
end

% "Left"/"Right" in the project sheet -> "L"/"R" used in the image filenames
hemiCode = @(s) regexprep(strtrim(string(s)), "^(L|R).*$", "$1", "ignorecase");

P = P(P.SubjectID ~= "" & ~ismissing(P.SubjectID), :);
projVars = ["SubjectID", "Condition", "LeftCannulaPlate", "RightCannulaPlate", "Sex", ...
    "InfusionQuality", "GM6001Molarity_uM_", "IncludeInAnalysis"];

% reshape to one row per (subject, hemisphere) so the drug/vehicle columns
% land on the hemisphere they were actually infused into
Pveh = P(:, projVars);
Pveh.Hemisphere = hemiCode(P.VehicleInfusionHemisphere);
Pveh.Treatment  = repmat("Vehicle", height(P), 1);
Pveh.Infusion1h = P.VehicleInfusion1H;
Pveh.Infusion3h = P.VehicleInfusion3H;

Pdrug = P(:, projVars);
Pdrug.Hemisphere = hemiCode(P.GM6001InfusionHemisphere);
Pdrug.Treatment  = repmat("GM6001", height(P), 1);
Pdrug.Infusion1h = P.GM6001Infusion1H;
Pdrug.Infusion3h = P.GM6001Infusion3H;

% controls have no infused hemisphere; keep their subject-level info on both
isCtl = ~ismember(Pveh.Hemisphere, ["L", "R"]) & ~ismember(Pdrug.Hemisphere, ["L", "R"]);
Pctl = [Pveh(isCtl, :); Pdrug(isCtl, :)];
Pctl.Hemisphere = [repmat("L", sum(isCtl), 1); repmat("R", sum(isCtl), 1)];
Pctl.Treatment  = repmat("None", height(Pctl), 1);

Plong = [Pveh; Pdrug; Pctl];
Plong(~ismember(Plong.Hemisphere, ["L", "R"]), :) = [];   % drop uninfused/NA rows

histology = outerjoin(histology, Plong, ...
    Keys = ["SubjectID", "Hemisphere"], ...
    MergeKeys = true, ...
    Type = "left");

ind = histology.Treatment == "None";
histology.Treatment(ind) = "Control " + histology.Hemisphere(ind);

% cannula distance
d = nan(size(histology, 1), 1);
ind = histology.Hemisphere == "L";
d(ind) = histology.AtlasPlate(ind) - histology.LeftCannulaPlate(ind);
ind = histology.Hemisphere == "R";
d(ind) = histology.AtlasPlate(ind) - histology.RightCannulaPlate(ind);
ind = histology.Condition == "Control";
d(ind) = histology.AtlasPlate(ind) - options.ControlCannulaPlate;
histology.CannulaDist = d;

if options.SaveTo ~= ""
    run = histdb.Run("histology_analysis/ecm_attach_project", ...
        Parameters = struct("ControlCannulaPlate", options.ControlCannulaPlate));
    run.input(options.InputFiles, Kind = "histology_sections");
    if ~istable(project)
        run.input(string(project), Role = "other", Kind = "project_sheet");
    end
    run.willWrite(options.SaveTo);
    save(options.SaveTo, "histology");
    run.output(options.SaveTo, Kind = "ecm_sections");
    run.finish();
end

end
