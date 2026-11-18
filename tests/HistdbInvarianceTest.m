classdef HistdbInvarianceTest < matlab.unittest.TestCase
    %HISTDBINVARIANCETEST The analyses give the same results whatever the state of the lab database.
    %
    %   The ECM pipeline on the fixture (ecm_attach_project_info with its save,
    %   ecm_export_for_r, ecm_prepare_analysis_data) is run once with no client
    %   at all, as the reference, and once in each state:
    %
    %     absent       no client (HISTDB_NO_CLIENT=1)
    %     disabled     the client here, the database turned off
    %     unreachable  turned on, the server not answering
    %     connected    turned on, the (fake) server answering
    %
    %   The saved table, the CSVs for R and the prepared analysis must be the
    %   same as the reference's; every run keeps its provenance record; and the
    %   outbox holds nothing (absent, disabled), waits (unreachable) or has sent
    %   everything (connected). The client states need the labclient package
    %   and are skipped without it.

    properties (TestParameter)
        State = {"absent", "disabled", "unreachable", "connected"}
    end

    properties
        OldNoClient string
        Restore = {}
        Folders = strings(0, 1)
    end

    methods (TestMethodSetup)
        function remember(tc)
            tc.OldNoClient = string(getenv("HISTDB_NO_CLIENT"));
            tc.addTeardown(@() tc.cleanUp());
        end
    end

    methods
        function cleanUp(tc)
            for k = numel(tc.Restore):-1:1
                tc.Restore{k} = [];
            end
            tc.Restore = {};
            setenv("HISTDB_NO_CLIENT", char(tc.OldNoClient));
            histdb.available(Refresh = true);
            for f = reshape(tc.Folders, 1, [])
                if isfolder(f); rmdir(f, "s"); end
            end
        end

        function [fake, top] = enter(tc, state)
            fake = [];
            if state == "absent"
                setenv("HISTDB_NO_CLIENT", "1");
                histdb.available(Refresh = true);
                top = string(tempname);
                mkdir(top);
                return
            end
            setenv("HISTDB_NO_CLIENT", "");
            tc.assumeTrue(histdb.available(Refresh = true), ...
                "The labclient package was not found: set CARASLABDB_DIR to a CarasLabDB checkout that has +labclient.");
            [fake, tc.Restore, top] = histdb_test_client(Enabled = state ~= "disabled");
            fake.Reachable = state ~= "unreachable";
        end

        function leave(tc)
            for k = numel(tc.Restore):-1:1
                tc.Restore{k} = [];
            end
            tc.Restore = {};
        end

        function R = pipeline(tc, top)
            tc.Folders(end + 1) = top;
            [H, projectFile] = ecm_test_fixture(fullfile(top, "project"));
            mat = fullfile(top, "analysis", "full.mat");
            if ~isfolder(fileparts(mat)); mkdir(fileparts(mat)); end
            R.joined = ecm_attach_project_info(H, projectFile, SaveTo = mat);
            S = load(mat);
            R.saved = S.histology;
            outDir = fullfile(top, "analysis", "R");
            files = [];
            evalc("files = ecm_export_for_r(mat, outDir);");
            R.profilesCsv = string(fileread(files.profiles));
            R.sectionsCsv = string(fileread(files.sections));
            A = ecm_prepare_analysis_data(R.joined, fileVar = "ImagePath", verbose = false, sourceFiles = mat);
            R.aligned = A.aligned;
            R.grouped = A.grouped;
            R.records = [dir(fullfile(top, "analysis", ".provenance", "*.json")); ...
                dir(fullfile(outDir, ".provenance", "*.json"))];
        end
    end

    methods (Test)
        function resultsDoNotDependOnTheDatabase(tc, State)
            tc.enter("absent");
            ref = tc.pipeline(string(tempname));

            [fake, top] = tc.enter(State);
            t = tic;
            got = tc.pipeline(top);
            elapsed = toc(t);

            tc.verifyTrue(isequaln(got.joined, ref.joined), "joined table");
            tc.verifyTrue(isequaln(got.saved, ref.saved), "saved table");
            tc.verifyEqual(got.profilesCsv, ref.profilesCsv, "profiles CSV, byte for byte");
            tc.verifyEqual(got.sectionsCsv, ref.sectionsCsv, "sections CSV, byte for byte");
            tc.verifyTrue(isequaln(got.aligned, ref.aligned), "aligned samples");
            tc.verifyTrue(isequaln(got.grouped, ref.grouped), "grouped summary");
            tc.verifyNumElements(got.records, 2, "a provenance record for each of the two runs that wrote files");

            switch State
                case "absent"
                    tc.verifyFalse(histdb.capturing());
                case "disabled"
                    c = labclient.Outbox.counts();
                    tc.verifyEqual(c.pending + c.held + c.failed + c.done, 0, "nothing kept for the database");
                case "unreachable"
                    tc.verifyLessThan(elapsed, 30, "the analyses never wait for the server");
                    labclient.Sync.flush(Budget = 2);
                    c = labclient.Outbox.counts();
                    tc.verifyEqual(c.pending, 2, "both runs wait in the outbox");
                case "connected"
                    labclient.Sync.flush(Budget = 20);
                    c = labclient.Outbox.counts();
                    tc.verifyEqual([c.done c.pending c.held c.failed], [2 0 0 0], "both runs sent");
                    tc.verifyNumElements(fake.Events, 2);
            end
            tc.leave();
        end
    end
end
