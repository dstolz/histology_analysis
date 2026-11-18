classdef HistdbClientTest < matlab.unittest.TestCase
    %HISTDBCLIENTTEST histdb with the lab database client: records reach the outbox and are sent once.
    %
    %   Needs the labclient package (a CarasLabDB checkout with +labclient,
    %   found through CARASLABDB_DIR or beside this checkout); skipped without
    %   it. Everything runs against labclient.FakeBackend in a temporary
    %   preference store, a fake vault and a temporary client folder, so no
    %   server is needed and nothing of the user's is touched.

    properties
        Fake
        Restore = {}
        Top = ""
    end

    methods (TestClassSetup)
        function needTheClient(tc)
            old = string(getenv("HISTDB_NO_CLIENT"));
            setenv("HISTDB_NO_CLIENT", "");
            tc.addTeardown(@() setenv("HISTDB_NO_CLIENT", char(old)));
            tc.assumeTrue(histdb.available(Refresh = true), ...
                "The labclient package was not found: set CARASLABDB_DIR to a CarasLabDB checkout that has +labclient.");
        end
    end

    methods (TestMethodSetup)
        function isolate(tc)
            [tc.Fake, tc.Restore, tc.Top] = histdb_test_client();
            tc.addTeardown(@() tc.cleanUp());
        end
    end

    methods
        function cleanUp(tc)
            for k = numel(tc.Restore):-1:1
                tc.Restore{k} = [];
            end
            if isfolder(tc.Top); rmdir(tc.Top, "s"); end
        end

        function f = writeFile(tc, rel, text)
            f = string(fullfile(tc.Top, rel));
            if ~isfolder(fileparts(f)); mkdir(fileparts(f)); end
            fid = fopen(f, "w");
            fwrite(fid, uint8(char(text)));
            fclose(fid);
        end

        function run = oneRun(tc, opts)
            arguments
                tc
                opts.Subject (1,1) string = ""
            end
            in = tc.writeFile("SUBJ-1/s1/s1_values.csv", "1,2");
            out = tc.writeFile("analysis/out.csv", "x,y");
            run = histdb.Run("histology_analysis/test_step", Parameters = struct("a", 1), ...
                SubjectId = opts.Subject);
            run.input(in, Kind = "values");
            run.output(out, Kind = "test_output");
        end
    end

    methods (Test)
        function aRunIsQueuedAndSentOnce(tc)
            run = tc.oneRun();
            run.finish();
            tc.verifyEqual(labclient.Outbox.stateOf(run.RunId), "pending");
            [b, ~] = labclient.Outbox.read(run.RunId);
            tc.verifyTrue(labclient.Bundles.isSealed(b), "every file's SHA-256 is known: sealed");
            tc.verifyEqual(b.record.event.event_type, "analysis");
            tc.verifyEqual(string(b.record.event.detail.pipeline_name), "histology_analysis/test_step");

            labclient.Sync.flush(Budget = 10);
            tc.verifyEqual(labclient.Outbox.stateOf(run.RunId), "done");
            ids = string({tc.Fake.Events.event_id});
            tc.verifyEqual(nnz(ids == run.RunId), 1);
            tc.verifyTrue(any(tc.Fake.Artifacts.produced_by_event_id == run.RunId));
        end

        function aRecordForOneSubjectIsSentForIt(tc)
            run = tc.oneRun(Subject = "SUBJ-1");
            run.finish();
            labclient.Sync.flush(Budget = 10);
            tc.verifyEqual(labclient.Outbox.stateOf(run.RunId), "done");
            e = tc.Fake.Events(string({tc.Fake.Events.event_id}) == run.RunId);
            tc.verifyEqual(string(e.subject_id), "SUBJ-1");
        end

        function aSubjectTheDatabaseLacksHoldsTheRecord(tc)
            run = tc.oneRun(Subject = "SUBJ-ID-404");
            run.finish();
            labclient.Sync.flush(Budget = 10);
            tc.verifyEqual(labclient.Outbox.stateOf(run.RunId), "held");
        end

        function backfillQueuesWhatWasKeptWhileOffAndOnlyOnce(tc)
            s = labclient.Settings.load();
            s.Enabled = false;
            labclient.Settings.save(s);
            run = tc.oneRun();
            run.finish();
            tc.verifyEqual(labclient.Outbox.stateOf(run.RunId), "", "the database was off: kept on disk only");

            s.Enabled = true;
            labclient.Settings.save(s);
            r = histdb.backfill(tc.Top);
            tc.verifyEqual([r.found r.queued r.already r.failed], [1 1 0 0]);
            r = histdb.backfill(tc.Top);
            tc.verifyEqual([r.found r.queued r.already], [1 0 1]);

            labclient.Sync.flush(Budget = 10);
            tc.verifyEqual(labclient.Outbox.stateOf(run.RunId), "done");
        end

        function theSameRecordQueuedTwiceIsOneRecord(tc)
            run = tc.oneRun();
            file = run.finish();
            tc.verifyEqual(histdb.enqueue(file), "unchanged");
        end

        function anUnreachableServerLeavesItWaiting(tc)
            tc.Fake.Reachable = false;
            run = tc.oneRun();
            t = tic;
            run.finish();
            tc.verifyLessThan(toc(t), 3, "finishing a run never waits for the server");
            labclient.Sync.flush(Budget = 2);
            tc.verifyEqual(labclient.Outbox.stateOf(run.RunId), "pending");
        end
    end
end
