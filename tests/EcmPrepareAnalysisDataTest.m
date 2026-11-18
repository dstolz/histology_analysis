classdef EcmPrepareAnalysisDataTest < matlab.unittest.TestCase
    %ECMPREPAREANALYSISDATATEST ecm_prepare_analysis_data: a smoke test on the ECM fixture.

    properties
        Folder string
        Histology table
    end

    methods (TestMethodSetup)
        function makeFixture(testCase)
            testCase.Folder = string(tempname);
            [H, projectFile] = ecm_test_fixture(testCase.Folder);
            testCase.Histology = ecm_attach_project_info(H, projectFile);
            testCase.addTeardown(@() rmdir(testCase.Folder, "s"));
        end
    end

    methods (Test)
        function preparesEverySection(testCase)
            A = ecm_prepare_analysis_data(testCase.Histology, ...
                fileVar = "ImagePath", ...
                groupVars = ["SubjectID", "AtlasPlate", "Treatment"], ...
                smoothingWindow = 25, ...
                verbose = false);

            for f = ["aligned", "peaks", "grouped", "grid", "diagnostics", "vars", "options"]
                testCase.verifyTrue(isfield(A, f), "A has no field " + f);
            end
            testCase.verifyEqual(height(A.diagnostics), height(testCase.Histology));
            testCase.verifyEqual(height(A.peaks), height(testCase.Histology));
            testCase.verifyEqual(A.options.smoothingWindow, 25);
        end

        function marksAlignTheSurface(testCase)
            A = ecm_prepare_analysis_data(testCase.Histology, fileVar = "ImagePath", verbose = false);
            marked = isfinite(testCase.Histology.SurfaceOffset);
            methods = string(A.peaks.SurfaceMethod);
            testCase.verifyEqual(nnz(methods == "mark"), nnz(marked));
        end

        function isDeterministic(testCase)
            A1 = ecm_prepare_analysis_data(testCase.Histology, fileVar = "ImagePath", verbose = false);
            A2 = ecm_prepare_analysis_data(testCase.Histology, fileVar = "ImagePath", verbose = false);
            testCase.verifyTrue(isequaln(A1.aligned, A2.aligned));
            testCase.verifyTrue(isequaln(A1.grouped, A2.grouped));
        end
    end
end
