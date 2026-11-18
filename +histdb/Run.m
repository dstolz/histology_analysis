classdef Run < handle
    %HISTDB.RUN What one analysis run read and wrote, with which code and settings: its provenance record.
    %
    %   run = histdb.Run("histology_analysis/ecm_export_for_r", Parameters = opts);
    %   run.input(matFile, Role = "derived", Kind = "ecm_sections");
    %   ... the analysis writes its files ...
    %   run.output([profFile; sectFile], Role = "derived", Kind = "ecm_csv");
    %   run.finish();            % or run.fail(ME) when it did not
    %
    % FINISH writes the record beside the run's first output, in a .provenance
    % folder (<output folder>\.provenance\<time>_<step>_<id>.json, format
    % histology-provenance/1), whether or not the lab database is set up,
    % reachable or even installed: the record on disk is the run's provenance,
    % and the database is told of it from there. When this computer keeps
    % records for the database (histdb.capturing), the same record goes to the
    % lab database client's outbox (histdb.enqueue) and is sent when the server
    % answers; otherwise histdb.backfill sends it later.
    %
    % The record holds:
    %   run_id          a uuid, which becomes the event's id in the database
    %   pipeline_name   "histology_analysis/<step>"
    %   subject_id      the one subject the run is about ("" for several)
    %   code_version    the commit, "-dirty" with uncommitted changes
    %                   (histology_code_version); code_text, matlab_release
    %   host, os_user, started_at, finished_at, status, error
    %   parameters      the settings the run was made with (a JSON object)
    %   metadata_source where the sections' metadata came from (kind, as_of)
    %   inputs, outputs path, bytes, mtime, sha256, role, kind, format; an
    %                   output also has artifact_id (minted here, so the record
    %                   is the same however often it is sent) and
    %                   replaces_sha256 (the bytes it overwrote, willWrite)
    %
    % Nothing here may change what an analysis computes or writes, or stop it:
    % every method catches its own errors and warns (histdb:Provenance)
    % instead. A file larger than MaxHashMB is recorded without its SHA-256.
    %
    % See also HISTDB.ENQUEUE, HISTDB.BACKFILL, HISTOLOGY_CODE_VERSION.

    properties (Constant)
        Format = "histology-provenance/1"
        App = "histology_analysis"
        MaxHashMB = 512
    end

    properties (SetAccess = private)
        RunId (1,1) string = ""
        PipelineName (1,1) string = ""
        SubjectId (1,1) string = ""
        Parameters = struct()
        MetadataSource = struct()
        StartedAt (1,1) datetime = NaT("TimeZone", "local")
        Inputs struct = histdb.Run.noFiles()
        Outputs struct = histdb.Run.noFiles()
        SidecarFile (1,1) string = ""
        Finished (1,1) logical = false
    end

    properties (Access = private)
        Previous = []   % containers.Map path -> SHA-256 before the write (made in the constructor)
    end

    methods
        function obj = Run(pipelineName, opts)
            %RUN Start the record of a run of PIPELINENAME ("histology_analysis/<step>").
            arguments
                pipelineName (1,1) string
                opts.Parameters = struct()
                opts.SubjectId (1,1) string = ""
                opts.MetadataSource = struct()
            end
            obj.RunId = newId();
            obj.PipelineName = pipelineName;
            obj.SubjectId = strtrim(opts.SubjectId);
            obj.Parameters = opts.Parameters;
            obj.MetadataSource = opts.MetadataSource;
            obj.StartedAt = datetime("now", "TimeZone", "local");
            obj.Previous = containers.Map("KeyType", "char", "ValueType", "char");
        end

        function input(obj, paths, opts)
            %INPUT Note files the run read, as they are now (size, time, SHA-256).
            %   Hash=false records only the size and time: for a large file
            %   read where a person is waiting (an image behind an ROI save).
            arguments
                obj
                paths string
                opts.Role (1,1) string = "derived"
                opts.Kind (1,1) string = ""
                opts.Hash (1,1) logical = true
            end
            try
                paths = unique(paths(strlength(paths) > 0 & ~ismissing(paths)), "stable");
                for p = reshape(paths, 1, [])
                    p = absolutePath(p); %#ok<FXSET>
                    if any(string({obj.Inputs.path}) == p); continue; end
                    obj.Inputs(end + 1) = histdb.Run.describe(p, opts.Role, opts.Kind, "", opts.Hash);
                end
            catch ME
                histdb.Run.warn(ME);
            end
        end

        function willWrite(obj, paths)
            %WILLWRITE Before a file is overwritten in place, note the bytes it holds now (replaces_sha256).
            arguments
                obj
                paths string
            end
            try
                for p = reshape(paths, 1, [])
                    if strlength(p) == 0 || ismissing(p); continue; end
                    p = absolutePath(p); %#ok<FXSET>
                    if isKey(obj.Previous, char(p)) || ~isfile(p)
                        continue
                    end
                    d = dir(p);
                    if d.bytes <= histdb.Run.MaxHashMB * 2^20
                        obj.Previous(char(p)) = char(sha256File(p));
                    end
                end
            catch ME
                histdb.Run.warn(ME);
            end
        end

        function output(obj, paths, opts)
            %OUTPUT Note files the run wrote (described when the run finishes).
            arguments
                obj
                paths string
                opts.Role (1,1) string = "derived"
                opts.Kind (1,1) string = ""
            end
            try
                paths = unique(paths(strlength(paths) > 0 & ~ismissing(paths)), "stable");
                for p = reshape(paths, 1, [])
                    p = absolutePath(p); %#ok<FXSET>
                    if any(string({obj.Outputs.path}) == p); continue; end
                    f = histdb.Run.blank(p);
                    f.role = opts.Role;
                    f.kind = opts.Kind;
                    obj.Outputs(end + 1) = f;
                end
            catch ME
                histdb.Run.warn(ME);
            end
        end

        function file = finish(obj, opts)
            %FINISH Write the record (and put it in the outbox when the database is on here); its file.
            arguments
                obj
                opts.Status (1,1) string {mustBeMember(opts.Status, ["succeeded", "failed"])} = "succeeded"
                opts.Error (1,1) string = ""
            end
            file = "";
            if obj.Finished
                file = obj.SidecarFile;
                return
            end
            obj.Finished = true;
            try
                rec = obj.record(opts.Status, opts.Error);
                file = obj.writeRecord(rec);
                obj.SidecarFile = file;
            catch ME
                histdb.Run.warn(ME);
                return
            end
            try
                histdb.enqueue(file);
            catch ME
                histdb.Run.warn(ME);
            end
        end

        function file = fail(obj, ME)
            %FAIL Write the record of a run that stopped with error ME.
            file = obj.finish(Status = "failed", Error = string(ME.message));
        end
    end

    methods (Access = private)
        function rec = record(obj, status, err)
            outs = obj.Outputs;
            for k = 1:numel(outs)
                f = histdb.Run.describe(outs(k).path, outs(k).role, outs(k).kind, "", true);
                f.artifact_id = newId();
                if isKey(obj.Previous, char(outs(k).path))
                    before = string(obj.Previous(char(outs(k).path)));
                    if before ~= f.sha256
                        f.replaces_sha256 = before;
                    end
                end
                outs(k) = f;
            end
            code = histology_code_version();
            rec = struct( ...
                "format", histdb.Run.Format, ...
                "run_id", obj.RunId, ...
                "app", histdb.Run.App, ...
                "pipeline_name", obj.PipelineName, ...
                "subject_id", obj.SubjectId, ...
                "code_version", code.Version, ...
                "code_text", code.Text, ...
                "matlab_release", code.MatlabRelease, ...
                "host", histdb.Run.host(), ...
                "os_user", string(getenv("USERNAME")), ...
                "started_at", timeText(obj.StartedAt), ...
                "finished_at", timeText(datetime("now", "TimeZone", "local")), ...
                "status", status, ...
                "error", err, ...
                "parameters", histdb.Run.encodable(obj.Parameters), ...
                "metadata_source", histdb.Run.encodable(obj.MetadataSource), ...
                "inputs", {num2cell(obj.Inputs)}, ...
                "outputs", {num2cell(outs)});
        end

        function file = writeRecord(obj, rec)
            step = extractAfter(obj.PipelineName, "/");
            if ismissing(step) || step == ""; step = obj.PipelineName; end
            step = regexprep(step, "[^A-Za-z0-9_-]", "_");
            name = string(datetime("now", "Format", "yyyyMMdd'T'HHmmss")) + "_" + step + "_" + ...
                extractBefore(obj.RunId, 9) + ".json";
            text = string(jsonencode(rec, PrettyPrint = true));
            folders = strings(0, 1);
            if ~isempty(obj.Outputs)
                folders(end + 1) = fullfile(fileparts(obj.Outputs(1).path), ".provenance");
            end
            folders(end + 1) = histdb.Run.fallbackFolder();
            for f = reshape(folders, 1, [])
                candidate = string(fullfile(f, name));
                try
                    writeTextAtomic(candidate, text);
                    file = candidate;
                    return
                catch
                    % not writable: the next folder
                end
            end
            error("histdb:CannotWrite", "The provenance record of %s could not be written anywhere.", obj.PipelineName);
        end
    end

    methods (Static, Hidden)
        function f = noFiles()
            %NOFILES An empty list of file descriptions.
            f = struct("path", {}, "bytes", {}, "mtime", {}, "sha256", {}, "role", {}, ...
                "kind", {}, "format", {}, "artifact_id", {}, "replaces_sha256", {});
        end
    end

    methods (Static)
        function d = fallbackFolder()
            %FALLBACKFOLDER Where a record goes when its outputs' folder cannot take it.
            base = string(getenv("LOCALAPPDATA"));
            if base == ""; base = string(tempdir); end
            d = string(fullfile(base, "histology_analysis", "provenance"));
        end
    end

    methods (Static, Access = private)
        function f = blank(p)
            f = struct("path", string(p), "bytes", NaN, "mtime", "", "sha256", "", "role", "", ...
                "kind", "", "format", "", "artifact_id", "", "replaces_sha256", "");
        end

        function f = describe(p, role, kind, artifactId, hash)
            f = histdb.Run.blank(p);
            f.role = role;
            f.kind = kind;
            f.artifact_id = artifactId;
            [~, ~, ext] = fileparts(p);
            f.format = lower(erase(string(ext), "."));
            s = fileSnapshot(p);
            f.bytes = s.bytes;
            f.mtime = s.mtime;
            if hash && isfinite(s.bytes) && s.bytes <= histdb.Run.MaxHashMB * 2^20
                f.sha256 = sha256File(p);
            end
        end

        function v = encodable(v)
            %ENCODABLE V when jsonencode can write it; else a note saying what it was.
            try
                jsonencode(v);
            catch ME
                v = struct("not_recorded", "jsonencode could not write the " + class(v) + ...
                    ": " + string(ME.message));
            end
        end

        function h = host()
            h = string(getenv("COMPUTERNAME"));
            if h == ""; h = string(getenv("HOSTNAME")); end
        end

        function warn(ME)
            warning("histdb:Provenance", "The provenance record was not kept: %s", ME.message);
        end
    end
end
