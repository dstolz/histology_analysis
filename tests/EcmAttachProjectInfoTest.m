classdef EcmAttachProjectInfoTest < matlab.unittest.TestCase
    %ECMATTACHPROJECTINFOTEST ecm_attach_project_info: the project join S_ECManalysis used to do inline.

    properties
        Folder string
        Histology table
        ProjectFile string
    end

    methods (TestMethodSetup)
        function makeFixture(testCase)
            testCase.Folder = string(tempname);
            [testCase.Histology, testCase.ProjectFile] = ecm_test_fixture(testCase.Folder);
            testCase.addTeardown(@() rmdir(testCase.Folder, "s"));
        end
    end

    methods (Test)
        function matchesTheScriptItReplaced(testCase)
            % The same table, row for row and column for column, as the
            % inline code S_ECManalysis ran before it was moved out.
            expected = scriptJoin(testCase.Histology, testCase.ProjectFile);
            actual = ecm_attach_project_info(testCase.Histology, testCase.ProjectFile);
            testCase.verifyTrue(isequaln(actual, expected), ...
                "The joined table differs from the one the script produced.");
        end

        function infusedHemispheresGetTheirTreatment(testCase)
            T = ecm_attach_project_info(testCase.Histology, testCase.ProjectFile);
            s1 = T(T.SubjectID == "SUBJ-ID-1", :);
            testCase.verifyEqual(unique(s1.Treatment(s1.Hemisphere == "L")), "Vehicle");
            testCase.verifyEqual(unique(s1.Treatment(s1.Hemisphere == "R")), "GM6001");
            testCase.verifyEqual(s1.CannulaDist(s1.Hemisphere == "L"), s1.AtlasPlate(s1.Hemisphere == "L") - 29);
            testCase.verifyEqual(s1.CannulaDist(s1.Hemisphere == "R"), s1.AtlasPlate(s1.Hemisphere == "R") - 31);
        end

        function controlsAreMeasuredFromTheControlPlate(testCase)
            T = ecm_attach_project_info(testCase.Histology, testCase.ProjectFile, ControlCannulaPlate = 28);
            s3 = T(T.SubjectID == "SUBJ-ID-3", :);
            testCase.verifyEqual(sort(unique(s3.Treatment)), ["Control L"; "Control R"]);
            testCase.verifyEqual(s3.CannulaDist, s3.AtlasPlate - 28);
        end

        function sectionsOutsideTheSheetAreKept(testCase)
            T = ecm_attach_project_info(testCase.Histology, testCase.ProjectFile);
            testCase.verifyEqual(height(T), height(testCase.Histology));
            s4 = T(T.SubjectID == "SUBJ-ID-4", :);
            testCase.verifyTrue(all(ismissing(s4.Treatment)));
            testCase.verifyTrue(all(isnan(s4.CannulaDist)));
        end

        function acceptsTheSheetAsATable(testCase)
            P = readtable(testCase.ProjectFile, TextType = "string");
            fromTable = ecm_attach_project_info(testCase.Histology, P);
            fromFile = ecm_attach_project_info(testCase.Histology, testCase.ProjectFile);
            testCase.verifyTrue(isequaln(fromTable, fromFile));
        end

        function savesWhenAsked(testCase)
            out = fullfile(testCase.Folder, "full.mat");
            T = ecm_attach_project_info(testCase.Histology, testCase.ProjectFile, SaveTo = out);
            testCase.verifyTrue(isfile(out));
            S = load(out);
            testCase.verifyEqual(fieldnames(S), {'histology'});
            testCase.verifyTrue(isequaln(S.histology, T));
        end
    end
end


function histology = scriptJoin(histology, projectFile)
%SCRIPTJOIN The code S_ECManalysis ran inline before ecm_attach_project_info, kept frozen.

P = readtable(projectFile,"TextType","string");

hemiCode = @(s) regexprep(strtrim(string(s)), "^(L|R).*$", "$1", "ignorecase");

P = P(P.SubjectID ~= "" & ~ismissing(P.SubjectID), :);
projVars = ["SubjectID", "Condition", "LeftCannulaPlate", "RightCannulaPlate", "Sex", "InfusionQuality", "GM6001Molarity_uM_","IncludeInAnalysis"];

Pveh = P(:,projVars);
Pveh.Hemisphere = hemiCode(P.VehicleInfusionHemisphere);
Pveh.Treatment  = repmat("Vehicle",height(P),1);
Pveh.Infusion1h = P.VehicleInfusion1H;
Pveh.Infusion3h = P.VehicleInfusion3H;

Pdrug = P(:,projVars);
Pdrug.Hemisphere = hemiCode(P.GM6001InfusionHemisphere);
Pdrug.Treatment  = repmat("GM6001",height(P),1);
Pdrug.Infusion1h = P.GM6001Infusion1H;
Pdrug.Infusion3h = P.GM6001Infusion3H;

isCtl = ~ismember(Pveh.Hemisphere,["L","R"]) & ~ismember(Pdrug.Hemisphere,["L","R"]);
Pctl = [Pveh(isCtl,:); Pdrug(isCtl,:)];
Pctl.Hemisphere = [repmat("L",sum(isCtl),1); repmat("R",sum(isCtl),1)];
Pctl.Treatment  = repmat("None",height(Pctl),1);

Plong = [Pveh; Pdrug; Pctl];
Plong(~ismember(Plong.Hemisphere,["L","R"]),:) = [];

histology = outerjoin(histology, Plong, ...
    Keys = ["SubjectID","Hemisphere"], ...
    MergeKeys = true, ...
    Type = "left");

ind = histology.Treatment == "None";
histology.Treatment(ind) = "Control " + histology.Hemisphere(ind);

d = nan(size(histology,1),1);
ind = histology.Hemisphere == "L";
d(ind) = histology.AtlasPlate(ind) - histology.LeftCannulaPlate(ind);
ind = histology.Hemisphere == "R";
d(ind) = histology.AtlasPlate(ind) - histology.RightCannulaPlate(ind);
ind = histology.Condition == "Control";
d(ind) = histology.AtlasPlate(ind) - 30;
histology.CannulaDist = d;
end
