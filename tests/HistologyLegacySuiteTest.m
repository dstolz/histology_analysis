classdef HistologyLegacySuiteTest < matlab.unittest.TestCase
    %HISTOLOGYLEGACYSUITETEST The function-style suites, each run as one test.
    %   test_histology_browser and test_section_tracker are plain functions
    %   that print PASS / FAIL per check and return normally either way. Here
    %   each runs as one test that fails when any of its checks did, so
    %   run_histology_tests (and tools\Run-Tests.ps1) can report it.
    %
    %   A suite that returns its count of failed checks (nFailed =
    %   test_section_tracker()) is asked for it. One that returns nothing is
    %   run under a diary, and its "FAIL  " lines are counted.
    %
    %   See also RUN_HISTOLOGY_TESTS.

    properties (TestParameter)
        Suite = struct( ...
            "test_histology_browser", "test_histology_browser", ...
            "test_section_tracker", "test_section_tracker")
    end

    methods (Test)
        function suitePasses(testCase, Suite)
            [nFailed, failures] = HistologyLegacySuiteTest.runSuite(Suite);
            testCase.verifyEqual(nFailed, 0, sprintf("%s: %d check(s) failed:\n%s", ...
                Suite, nFailed, strjoin(failures, newline)));
        end
    end

    methods (Static)
        function [nFailed, failures] = runSuite(name)
            %RUNSUITE Run function-style suite NAME; the count and lines of its failed checks.
            name = string(name);
            logFile = string(tempname) + ".log";
            cleanLog = onCleanup(@() HistologyLegacySuiteTest.dropFile(logFile));

            diary(char(logFile));
            stopDiary = onCleanup(@() diary("off"));
            if nargout(char(name)) ~= 0
                nFailed = feval(char(name));
            else
                feval(char(name));
                nFailed = NaN;
            end
            clear stopDiary

            text = "";
            if isfile(logFile)
                text = string(fileread(logFile));
            end
            lines = splitlines(text);
            failures = strtrim(lines(startsWith(lines, "FAIL  ")));
            if isnan(nFailed)
                nFailed = numel(failures);
            end
        end

        function dropFile(file)
            if isfile(file)
                delete(file);
            end
        end
    end
end
