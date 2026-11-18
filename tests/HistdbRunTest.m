classdef HistdbRunTest < matlab.unittest.TestCase
    %HISTDBRUNTEST histdb.Run and the runs that keep their provenance, with no lab database client.
    %
    %   Every test runs with HISTDB_NO_CLIENT=1, as on a computer without the
    %   CarasLabDB checkout: the provenance record is still written beside the
    %   outputs, and nothing else happens. (HistdbClientTest covers the outbox.)

    properties
        Folder string
        OldNoClient string
    end

    methods (TestMethodSetup)
        function withoutClient(tc)
            tc.Folder = string(tempname);
            mkdir(tc.Folder);
            tc.OldNoClient = string(getenv("HISTDB_NO_CLIENT"));
            setenv("HISTDB_NO_CLIENT", "1");
            histdb.available(Refresh = true);
            tc.addTeardown(@() tc.restore());
        end
    end

    methods
        function restore(tc)
            setenv("HISTDB_NO_CLIENT", char(tc.OldNoClient));
            histdb.available(Refresh = true);
            if isfolder(tc.Folder)
                rmdir(tc.Folder, "s");
            end
        end

        function f = writeFile(tc, rel, text)
            f = string(fullfile(tc.Folder, rel));
            if ~isfolder(fileparts(f)); mkdir(fileparts(f)); end
            fid = fopen(f, "w");
            fwrite(fid, uint8(char(text)));
            fclose(fid);
        end

        function rec = onlyRecord(tc, folder)
            d = dir(fullfile(folder, ".provenance", "*.json"));
            tc.assertNumElements(d, 1, "Expected one provenance record in " + folder);
            rec = jsondecode(fileread(fullfile(d.folder, d.name)));
        end
    end

    methods (Test)
        function theRecordIsKeptBesideTheFirstOutput(tc)
            in = tc.writeFile("in.txt", "abc");
            out = tc.writeFile("out/out.csv", "x,y");
            run = histdb.Run("histology_analysis/test_step", ...
                Parameters = struct("a", 1), SubjectId = "SUBJ-ID-1");
            run.input(in, Kind = "test_input");
            run.output(out, Kind = "test_output");
            file = run.finish();

            tc.verifyTrue(startsWith(file, fullfile(tc.Folder, "out", ".provenance")));
            rec = jsondecode(fileread(file));
            tc.verifyEqual(string(rec.format), "histology-provenance/1");
            tc.verifyEqual(string(rec.pipeline_name), "histology_analysis/test_step");
            tc.verifyEqual(string(rec.subject_id), "SUBJ-ID-1");
            tc.verifyEqual(string(rec.status), "succeeded");
            tc.verifyEqual(rec.parameters.a, 1);
            tc.verifyNotEmpty(rec.code_version);
            tc.verifyEqual(string(rec.inputs(1).sha256), ...
                "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
            tc.verifyEqual(rec.inputs(1).bytes, 3);
            tc.verifyMatches(string(rec.outputs(1).artifact_id), "^[0-9a-f]{8}-[0-9a-f]{4}-4");
            tc.verifyEqual(string(rec.outputs(1).format), "csv");
        end

        function overwrittenBytesAreNamed(tc)
            out = tc.writeFile("o.txt", "old");
            run = histdb.Run("histology_analysis/test_step");
            run.willWrite(out);
            tc.writeFile("o.txt", "new");
            run.output(out);
            rec = jsondecode(fileread(run.finish()));
            tc.verifyEqual(string(rec.outputs(1).replaces_sha256), sha256Text("old"));
            tc.verifyEqual(string(rec.outputs(1).sha256), sha256Text("new"));
        end

        function unchangedBytesReplaceNothing(tc)
            out = tc.writeFile("same.txt", "same");
            run = histdb.Run("histology_analysis/test_step");
            run.willWrite(out);
            tc.writeFile("same.txt", "same");
            run.output(out);
            rec = jsondecode(fileread(run.finish()));
            tc.verifyEqual(string(rec.outputs(1).replaces_sha256), "");
        end

        function aFailedRunIsRecorded(tc)
            out = tc.writeFile("f.txt", "partial");
            run = histdb.Run("histology_analysis/test_step");
            run.output(out);
            rec = jsondecode(fileread(run.fail(MException("test:boom", "boom"))));
            tc.verifyEqual(string(rec.status), "failed");
            tc.verifyEqual(string(rec.error), "boom");
        end

        function parametersJsonCannotWriteAreNoted(tc)
            out = tc.writeFile("p.txt", "p");
            run = histdb.Run("histology_analysis/test_step", Parameters = struct("f", @sin));
            run.output(out);
            rec = jsondecode(fileread(run.finish()));
            tc.verifyTrue(isfield(rec.parameters, "not_recorded"));
        end

        function finishingTwiceWritesOnce(tc)
            out = tc.writeFile("t.txt", "t");
            run = histdb.Run("histology_analysis/test_step");
            run.output(out);
            first = run.finish();
            tc.verifyEqual(run.finish(), first);
            tc.verifyNumElements(dir(fullfile(tc.Folder, ".provenance", "*.json")), 1);
        end

        function aRunWithNoOutputsUsesTheFallbackFolder(tc)
            run = histdb.Run("histology_analysis/test_nothing_written");
            file = run.finish();
            tc.addTeardown(@() delete(file));
            tc.verifyTrue(startsWith(file, histdb.Run.fallbackFolder()));
            tc.verifyTrue(isfile(file));
        end

        function withoutTheClientNothingIsQueued(tc)
            tc.verifyFalse(histdb.available());
            tc.verifyFalse(histdb.capturing());
            r = histdb.backfill(tc.Folder);
            tc.verifyEqual(r.queued, 0);
            tc.verifySubstring(r.message, "nothing was queued");
            tc.verifyEqual(histdb.enqueue("no such file.json"), "off");
            q = histdb.suspend(); %#ok<NASGU> clearing it must do nothing
            clear q
        end

        function attachProjectInfoKeepsItsProvenance(tc)
            [H, projectFile] = ecm_test_fixture(tc.Folder);
            out = fullfile(tc.Folder, "full.mat");
            joined = ecm_attach_project_info(H, projectFile, SaveTo = out);
            tc.verifyTrue(isequaln(joined, ecm_attach_project_info(H, projectFile)), ...
                "Saving and recording must not change the table.");
            rec = tc.onlyRecord(tc.Folder);
            tc.verifyEqual(string(rec.pipeline_name), "histology_analysis/ecm_attach_project");
            tc.verifyEqual(string(rec.outputs(1).path), string(out));
            tc.verifyTrue(any(string({rec.inputs.path}) == string(projectFile)));
            tc.verifyEqual(rec.parameters.ControlCannulaPlate, 30);
        end

        function exportForRKeepsItsProvenance(tc)
            [H, projectFile] = ecm_test_fixture(tc.Folder);
            mat = fullfile(tc.Folder, "full.mat");
            ecm_attach_project_info(H, projectFile, SaveTo = mat);
            outDir = fullfile(tc.Folder, "R");
            evalc("ecm_export_for_r(mat, outDir);");
            rec = tc.onlyRecord(outDir);
            tc.verifyEqual(string(rec.pipeline_name), "histology_analysis/ecm_export_for_r");
            tc.verifyNumElements(rec.outputs, 2);
            tc.verifyEqual(string(rec.inputs(1).path), string(mat));
            tc.verifyEqual(string(rec.inputs(1).sha256), sha256File(mat));
        end

        function saveTrackedWritesWhatSaveWrites(tc)
            T = table(["a"; "b"], [1; 2], VariableNames = ["Name", "Value"]);
            file = histdb.saveTracked(fullfile(tc.Folder, "t.mat"), "histology", T);
            S = load(file);
            tc.verifyEqual(fieldnames(S), {'histology'});
            tc.verifyEqual(S.histology, T);
            rec = tc.onlyRecord(tc.Folder);
            tc.verifyEqual(string(rec.pipeline_name), "histology_analysis/browser_export");
        end

        function tableInputsAreTheFilesTheRowsCameFrom(tc)
            v1 = tc.writeFile("s1/a_values.csv", "1");
            v2 = tc.writeFile("s1/b_values.csv", "2");
            roi = tc.writeFile("s1/a_roi.roi", "r");
            T = table({[v1; v2]; v1}, [roi; ""], VariableNames = ["ValuesPaths", "RoiPath"]);
            p = histdb.tableInputs(T);
            tc.verifyEqual(p, [v1; v2; roi]);
        end
    end
end


function h = sha256Text(text)
md = java.security.MessageDigest.getInstance("SHA-256");
md.update(uint8(char(text)));
h = string(lower(reshape(dec2hex(typecast(md.digest(), "uint8"), 2)', 1, [])));
end

function h = sha256File(file)
fid = fopen(file, "r");
assert(fid > 0, "Cannot open " + file);
data = fread(fid, Inf, "*uint8");
fclose(fid);
md = java.security.MessageDigest.getInstance("SHA-256");
md.update(data);
h = string(lower(reshape(dec2hex(typecast(md.digest(), "uint8"), 2)', 1, [])));
end
