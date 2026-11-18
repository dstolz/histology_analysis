function results = run_histology_tests(names, opts)
%RUN_HISTOLOGY_TESTS Run the histology_analysis test suites with matlab.unittest.
%   run_histology_tests            runs every suite: each matlab.unittest
%                                  test class in tests\ and each
%                                  function-style suite (test_histology_browser,
%                                  test_section_tracker) as one test of
%                                  HistologyLegacySuiteTest
%   run_histology_tests(NAMES)     runs only the named suites (string array or
%                                  cellstr): class names, or the names of the
%                                  function-style suites
%   run_histology_tests(Setup=true) only puts the repository on the path and
%                                  returns (tools\Run-Tests.ps1 -Command)
%
%   Options
%     DialogWatch   seconds a dialog may wait for an answer before the run says
%                   so (0 = never): one line in the output,
%                     [needs you] <dialog> "<window>" | asked by <fn> (<file>:<line>) | test <fn> (<file>:<line>)
%                   read by tools\Run-Tests.ps1. A dialog is waiting when the
%                   stack holds one of MATLAB's dialogs (questdlg, uiconfirm,
%                   uigetfile, ...) or uiwait / waitfor while a modal window is
%                   open.
%     ResultsCSV    file to write the results table to ("" = none)
%     Setup         only set up the path
%
%   The run raises an error at the end when any test failed, so it can drive
%   `matlab -batch` (exit 1). Run it through tools\Run-Tests.ps1, which starts
%   MATLAB on a desktop of its own so the windows the tests open never come
%   over yours:
%
%     tools\Run-Tests.ps1                         every suite
%     tools\Run-Tests.ps1 EcmAttachProjectInfoTest
%
%   Returns a table, one row per suite: Suite, Passed, Seconds, Tests, Failed,
%   Skipped, Message.
%
%   See also HistologyLegacySuiteTest.

arguments
    names (1,:) string = string.empty(1, 0)
    opts.DialogWatch (1,1) double {mustBeNonnegative} = 0
    opts.ResultsCSV (1,1) string = ""
    opts.Setup (1,1) logical = false
end

import matlab.unittest.TestSuite
import matlab.unittest.TestRunner

here = fileparts(mfilename("fullpath"));
repo = fileparts(here);
testsDir = fullfile(repo, "tests");

% Absolute paths: the user's startup.m changes the current folder, so nothing
% here may rely on it.
addpath(repo, ...
    fullfile(repo, "histology_browser"), ...
    fullfile(repo, "histology_browser", "tests"), ...
    fullfile(repo, "ECM_Analysis"), ...
    testsDir, here);

if opts.Setup
    results = table();
    return
end

suite = TestSuite.fromFolder(char(testsDir));
group = strings(1, numel(suite));
for k = 1:numel(suite)
    group(k) = suiteName(suite(k));
end

if ~isempty(names)
    unknown = names(~ismember(names, group));
    if ~isempty(unknown)
        error("run_histology_tests:UnknownSuite", "No suite named %s. Suites: %s.", ...
            strjoin(unknown, ", "), strjoin(unique(group), ", "));
    end
    keep = ismember(group, names);
    suite = suite(keep);
    group = group(keep);
end

if isempty(suite)
    error("run_histology_tests:NothingToRun", "No test matches the suites given.");
end

runner = TestRunner.withTextOutput;

stopWatch = startDialogWatch(opts.DialogWatch); %#ok<NASGU> (held until the clear below)
R = runner.run(suite);
clear stopWatch

suites = unique(group, "stable");
n = numel(suites);
passed = false(n, 1); seconds = zeros(n, 1); nTests = zeros(n, 1);
nFailed = zeros(n, 1); nSkipped = zeros(n, 1); message = strings(n, 1);
for k = 1:n
    r = R(group == suites(k));
    nTests(k) = numel(r);
    nFailed(k) = nnz([r.Failed]);
    nSkipped(k) = nnz([r.Incomplete] & ~[r.Failed]);
    seconds(k) = sum([r.Duration]);
    passed(k) = nFailed(k) == 0;
    if nFailed(k) > 0
        message(k) = sprintf("%d of %d test(s) failed", nFailed(k), nTests(k));
    end
end
results = table(suites(:), passed, seconds, nTests, nFailed, nSkipped, message, ...
    VariableNames = ["Suite", "Passed", "Seconds", "Tests", "Failed", "Skipped", "Message"]);

fprintf("\n######## Summary ########\n");
disp(results);
if opts.ResultsCSV ~= ""
    folder = fileparts(opts.ResultsCSV);
    if folder ~= "" && ~isfolder(folder); mkdir(folder); end
    writetable(results, opts.ResultsCSV);
    fprintf("Results: %s\n", opts.ResultsCSV);
end
if ~all(passed)
    error("run_histology_tests:Failures", "%d of %d suites failed.", nnz(~passed), n);
end
end


function name = suiteName(test)
%SUITENAME The suite a test belongs to: its class, or for HistologyLegacySuiteTest the
% function-style suite it runs.
name = string(test.TestClass);
if name == "HistologyLegacySuiteTest" && ~isempty(test.Parameterization)
    name = string(test.Parameterization(1).Value);
end
end


function stop = startDialogWatch(seconds)
%STARTDIALOGWATCH A timer that reports a dialog waiting SECONDS or more for an answer.
%   Timers run while uiwait / waitfor wait, so the timer sees the waiting frames
%   on the stack. A native dialog (uigetfile under -r) stops MATLAB's thread and
%   the timer with it: the runner finds that one by its window. STOP (an
%   onCleanup) deletes the timer; [] when SECONDS is 0.
stop = [];
if seconds <= 0; return; end
t = timer("Name", "run_histology_tests dialog watch", "Period", 5, "StartDelay", 5, ...
    "ExecutionMode", "fixedSpacing", "BusyMode", "drop", "ObjectVisibility", "off", ...
    "TimerFcn", @(tm, ~) lookForDialog(tm, seconds));
t.UserData = struct("Key", "", "Since", 0, "Told", false);
start(t);
stop = onCleanup(@() stopTimer(t));
end


function stopTimer(t)
if isvalid(t); stop(t); delete(t); end
end


function lookForDialog(tm, seconds)
%LOOKFORDIALOG The dialog watch's tick: one [needs you] line per dialog that has waited SECONDS.
s = dbstack("-completenames");
names = string({s.name});
dialogs = ["uiconfirm" "questdlg" "inputdlg" "listdlg" "msgbox" "errordlg" "warndlg" "helpdlg" ...
    "uigetfile" "uiputfile" "uigetdir" "uisetcolor" "uisetfont" "uialert"];
k = find(ismember(names, [dialogs "uiwait" "waitfor"]), 1, "last");
modal = findall(groot, "Type", "figure", "Visible", "on", "WindowStyle", "modal");
if isempty(k) || (~ismember(names(k), dialogs) && isempty(modal))
    tm.UserData = struct("Key", "", "Since", 0, "Told", false);
    return
end
caller = s(min(k + 1, numel(s)));
key = names(k) + "@" + caller.file + ":" + caller.line;
st = tm.UserData;
nowS = posixtime(datetime("now"));
if st.Key ~= key
    tm.UserData = struct("Key", key, "Since", nowS, "Told", false);
    return
end
if st.Told || nowS - st.Since < seconds; return; end
st.Told = true;
tm.UserData = st;
windows = "";
if ~isempty(modal); windows = " " + strjoin("""" + string({modal.Name}) + """", ", "); end
testPart = "";
files = string({s.file});
j = find(contains(files, filesep + "tests" + filesep), 1, "first");   % the test line nearest the dialog
if ~isempty(j); testPart = sprintf(" | test %s (%s:%d)", names(j), s(j).file, s(j).line); end
fprintf("\n[needs you] %s%s | asked by %s (%s:%d)%s\n", names(k), windows, caller.name, caller.file, caller.line, testPart);
end
