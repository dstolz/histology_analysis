classdef HistologyCodeVersionTest < matlab.unittest.TestCase
    %HISTOLOGYCODEVERSIONTEST histology_code_version: which code is running.

    methods (Test)
        function namesTheCheckout(testCase)
            info = histology_code_version(Refresh = true);
            testCase.assumeNotEqual(info.Commit, "", "Not a git checkout, or no git on this machine.");
            testCase.verifyMatches(info.Commit, "^[0-9a-f]{7,}$");
            testCase.verifyTrue(startsWith(info.Version, info.Commit));
            testCase.verifyEqual(endsWith(info.Version, "-dirty"), info.Dirty);
            testCase.verifyEqual(contains(info.Text, "(with uncommitted changes)"), info.Dirty);
            testCase.verifyTrue(isfolder(info.Root));
        end

        function browserScopeIsTheBrowserFolder(testCase)
            repo = histology_code_version(Scope = "repo");
            browser = histology_code_version(Scope = "browser");
            testCase.verifyEqual(browser.Root, fullfile(repo.Root, "histology_browser"));
            testCase.verifyEqual(browser.Scope, "browser");
        end

        function namesTheMatlabRelease(testCase)
            info = histology_code_version();
            testCase.verifyTrue(startsWith(info.MatlabRelease, "R20") || info.MatlabRelease ~= "");
        end

        function answersFromTheCacheWithinAMinute(testCase)
            histology_code_version(Refresh = true);
            t = tic;
            histology_code_version();
            testCase.verifyLessThan(toc(t), 0.05, "A second call within a minute should not ask git again.");
        end
    end
end
