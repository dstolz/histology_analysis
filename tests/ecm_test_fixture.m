function [histology, projectFile] = ecm_test_fixture(folder)
%ECM_TEST_FIXTURE A small sections table and project sheet for the ECM tests.
%   [histology, projectFile] = ecm_test_fixture(folder)
%
% HISTOLOGY has the shape the histology browser exports (one row per section
% and hemisphere, the profile nested in a cell), and PROJECTFILE is a CSV in
% FOLDER shaped like "ECM Projects - GM6001.csv":
%
%   SUBJ-ID-1  Trained, vehicle left,  drug right, cannulas at plates 29 / 31
%   SUBJ-ID-2  Trained, vehicle right, drug left,  cannulas at plates 30 / 30
%   SUBJ-ID-3  Control, no infusion
%   SUBJ-ID-4  sections only: not in the project sheet
%
% plus a project row with a blank SubjectID, which is dropped. Everything is
% computed, nothing random, so every call gives the same bytes.
%
% See also ECM_ATTACH_PROJECT_INFO, ECM_EXPORT_FOR_R.

arguments
    folder (1,1) string
end

if ~isfolder(folder)
    mkdir(folder);
end

subjects = ["SUBJ-ID-1"; "SUBJ-ID-2"; "SUBJ-ID-3"; "SUBJ-ID-4"];
hemis = ["L"; "R"];
plates = [29; 31];

rows = cell(0, 1);
k = 0;

for iSubject = 1:numel(subjects)
    for iHemi = 1:numel(hemis)
        for iPlate = 1:numel(plates)
            k = k + 1;
            distance = (0:2:998)';
            depth = distance - 100;
            intensity = zeros(size(distance));
            inTissue = depth >= 0;
            intensity(inTissue) = 20 + 60 * exp(-((depth(inTissue) - 150 - 10 * k) / 120) .^ 2);

            stem = sprintf("%sIHC_ECM26A260608S1_%d_%s_WFA_Z1_260610_%d", ...
                subjects(iSubject), iPlate, hemis(iHemi), k);

            % Every third section has no surface mark, so both the marked and
            % the detected paths are exercised.
            surfaceOffset = 100;
            if mod(k, 3) == 0
                surfaceOffset = NaN;
            end

            rows{end + 1, 1} = { ...
                subjects(iSubject), hemis(iHemi), plates(iPlate), ...
                "C:/data/" + subjects(iSubject) + "/" + stem + "_proj.tif", ...
                {table(distance, intensity, VariableNames = ["Distance", "Intensity"])}, ...
                surfaceOffset, 998}; %#ok<AGROW>
        end
    end
end

data = vertcat(rows{:});
histology = cell2table(data, VariableNames = ...
    ["SubjectID", "Hemisphere", "AtlasPlate", "ImagePath", "Profile", "SurfaceOffset", "RoiLength"]);
histology.SubjectID = string(histology.SubjectID);
histology.Hemisphere = string(histology.Hemisphere);
histology.ImagePath = string(histology.ImagePath);

projectFile = fullfile(folder, "ECM Projects - fixture.csv");

lines = [ ...
    "SubjectID,Condition,LeftCannulaPlate,RightCannulaPlate,Sex,InfusionQuality,GM6001Molarity_uM_,IncludeInAnalysis,VehicleInfusionHemisphere,GM6001InfusionHemisphere,VehicleInfusion1H,VehicleInfusion3H,GM6001Infusion1H,GM6001Infusion3H"
    "SUBJ-ID-1,Trained,29,31,M,good,100,TRUE,Left,Right,yes,yes,yes,no"
    "SUBJ-ID-2,Trained,30,30,F,fair,100,TRUE,Right,Left,yes,no,yes,yes"
    "SUBJ-ID-3,Control,,,F,,,TRUE,NA,NA,,,,"
    ",Trained,30,30,M,,,FALSE,Left,Right,,,,"];

writelines(lines, projectFile);

end
