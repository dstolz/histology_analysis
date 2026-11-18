function status = enqueue(file)
%HISTDB.ENQUEUE Put a run's provenance record in the lab database client's outbox, to be sent when it can be.
%   status = histdb.enqueue(file)         % the record file histdb.Run wrote
%
% The record becomes one analysis event (labclient.Bundles.event) whose id is
% the run's id: its inputs and outputs are the files the run read and wrote
% (with their SHA-256, so the database can tell copies and earlier versions
% apart), the subject is the run's one subject or none, and the code version,
% parameters and environment are the record's. The event is always built from
% the record file as written, so a record put in the outbox now and one put
% there later by histdb.backfill are the same bytes, and the database writes
% it once whichever arrives (it keeps the record's digest with the event).
%
% Returns
%   status: "off" when this computer keeps no records for the database
%       (histdb.capturing), else labclient.Outbox.put's answer: "added",
%       "unchanged" or "replaced". Errors from the client are raised; the
%       callers (histdb.Run, histdb.backfill) catch them.
%
% See also HISTDB.RUN, HISTDB.BACKFILL, LABCLIENT.BUNDLES.

arguments
    file (1,1) string
end

status = "off";
if ~histdb.capturing()
    return
end

% The file as written, never the struct the run still holds: the same text
% gives the same event, however often and from wherever it is enqueued.
rec = jsondecode(fileread(file));

inputs = labclient.Bundles.noItems();
for f = asList(rec.inputs)
    inputs(end + 1) = labclient.Bundles.item(string(f.path), Role = string(f.role), ...
        Kind = string(f.kind), Format = string(f.format), Sha256 = string(f.sha256), ...
        Snapshot = snapshotOf(f)); %#ok<AGROW>
end

outputs = labclient.Bundles.noItems();
for f = asList(rec.outputs)
    attributes = struct();
    if isfield(f, "replaces_sha256") && strlength(string(f.replaces_sha256)) > 0
        attributes.replaces_sha256 = string(f.replaces_sha256);
    end
    outputs(end + 1) = labclient.Bundles.item(string(f.path), Role = string(f.role), ...
        Kind = string(f.kind), Format = string(f.format), Sha256 = string(f.sha256), ...
        ArtifactId = string(f.artifact_id), Attributes = attributes, Snapshot = snapshotOf(f)); %#ok<AGROW>
end

environment = struct("app", string(rec.app), "code_text", string(rec.code_text), ...
    "matlab_release", string(rec.matlab_release), "host", string(rec.host), ...
    "os_user", string(rec.os_user), "metadata_source", rec.metadata_source);

detail = struct( ...
    "pipeline_name", string(rec.pipeline_name), ...
    "code_version", string(rec.code_version), ...
    "parameters_json", string(jsonencode(rec.parameters)), ...
    "environment_json", string(jsonencode(environment)), ...
    "started_at", string(rec.started_at), ...
    "finished_at", string(rec.finished_at), ...
    "status", string(rec.status));

attributes = struct("app", string(rec.app), "provenance_file", file);
if strlength(string(rec.error)) > 0
    attributes.error = string(rec.error);
end

b = labclient.Bundles.event( ...
    EventId = string(rec.run_id), ...
    EventType = "analysis", ...
    OccurredAt = string(rec.started_at), ...
    Detail = detail, ...
    Attributes = attributes, ...
    SubjectId = string(rec.subject_id), ...
    Inputs = inputs, ...
    Outputs = outputs, ...
    CapturedAt = string(rec.finished_at));   % the record's own time, so the bundle is the same bytes however often it is queued

b = labclient.Bundles.seal(b);
status = string(labclient.Outbox.put(b));
labclient.DB.outboxChanged();

end

function list = asList(x)
%ASLIST The decoded JSON list X as a row of structs (jsondecode gives a struct array or a cell).
if isempty(x)
    list = struct([]);
    list = reshape(list, 1, 0);
    return
end
if iscell(x)
    list = [x{:}];
else
    list = reshape(x, 1, []);
end
end

function s = snapshotOf(f)
bytes = f.bytes;
if isempty(bytes); bytes = NaN; end
s = struct("bytes", double(bytes), "mtime", string(f.mtime));
end
