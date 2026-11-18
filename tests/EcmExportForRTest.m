classdef EcmExportForRTest < matlab.unittest.TestCase
    %ECMEXPORTFORRTEST ecm_export_for_r: the nested sections table flattened to two CSVs.

    properties
        Folder string
        MatFile string
        Histology table
    end

    methods (TestMethodSetup)
        function makeFixture(testCase)
            testCase.Folder = string(tempname);
            [H, projectFile] = ecm_test_fixture(testCase.Folder);
            testCase.MatFile = fullfile(testCase.Folder, "full.mat");
            testCase.Histology = ecm_attach_project_info(H, projectFile, SaveTo = testCase.MatFile);
            testCase.addTeardown(@() rmdir(testCase.Folder, "s"));
        end
    end

    methods (Test)
        function writesSectionsAndLongProfiles(testCase)
            out = testCase.Folder + filesep + "R";
            files = evalcQuiet(@() ecm_export_for_r(testCase.MatFile, out));
            testCase.verifyTrue(isfile(files.sections));
            testCase.verifyTrue(isfile(files.profiles));

            sections = readtable(files.sections, TextType = "string");
            profiles = readtable(files.profiles, TextType = "string");
            testCase.verifyEqual(height(sections), height(testCase.Histology));

            nSamples = sum(cellfun(@height, testCase.Histology.Profile));
            testCase.verifyEqual(height(profiles), nSamples);
            testCase.verifyTrue(all(ismember(["SampleIndex", "Distance", "Intensity", "SurfaceDistance"], ...
                string(profiles.Properties.VariableNames))));
        end

        function unmarkedSectionsHaveNoSurfaceDistance(testCase)
            files = evalcQuiet(@() ecm_export_for_r(testCase.MatFile, testCase.Folder));
            sections = readtable(files.sections, TextType = "string");
            marked = isfinite(testCase.Histology.SurfaceOffset);
            testCase.verifyTrue(all(isfinite(sections.SurfaceDistance(marked))));
            testCase.verifyTrue(all(isnan(sections.SurfaceDistance(~marked))));
        end

        function refusesATableWithoutSurfaceMarks(testCase)
            H = removevars(testCase.Histology, "SurfaceOffset");
            bad = fullfile(testCase.Folder, "nomarks.mat");
            histology = H; %#ok<NASGU> saved under the name the export reads
            save(bad, "histology");
            testCase.verifyError(@() ecm_export_for_r(bad, testCase.Folder), "ecm_export_for_r:noSurfaceMark");
        end
    end
end


function out = evalcQuiet(fcn)
%EVALCQUIET Call FCN for its output, keeping what it prints out of the test log.
out = [];
evalc("out = fcn();");
end
