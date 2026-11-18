function tf = available(opts)
%HISTDB.AVAILABLE True when the lab database client (CarasLabDB's labclient package) can be used here.
%   tf = histdb.available()
%   tf = histdb.available(Refresh = true)   % look again (tests)
%
% histology_analysis records its work in the lab database through the client
% every lab toolbox on a computer shares: the +labclient package of a
% CarasLabDB checkout (one setup, one password, one outbox and one sender per
% computer). This package, histdb, is the only code here that uses it, and
% this function the only one that decides whether it can: everything else in
% histdb does nothing when it says false.
%
% The package is looked for once per MATLAB: already on the path; else in the
% folder the environment variable CARASLABDB_DIR names; else in a CarasLabDB
% folder beside this checkout (C:\src\histology_analysis -> C:\src\CarasLabDB).
% A folder holding +labclient is added to the path. The environment variable
% HISTDB_NO_CLIENT=1 makes the answer false whatever is installed
% (tools\Run-Tests.ps1 -WithoutClient), so a run can prove the analyses do not
% need the client.
%
% Never an error: a client that is missing, too old or broken is "false".
%
% Without the client nothing is lost: every analysis run still writes its
% provenance record beside its outputs (histdb.Run), and histdb.backfill
% puts those records in the outbox once the client is here.
%
% See also HISTDB.RUN, HISTDB.BACKFILL, HISTDB.CAPTURING.

arguments
    opts.Refresh (1,1) logical = false
end

persistent found

if opts.Refresh
    found = [];
end

if string(getenv("HISTDB_NO_CLIENT")) == "1"
    tf = false;
    return
end

if ~isempty(found)
    tf = found && exist("labclient.DB", "class") == 8;
    return
end

tf = false;

try
    if exist("labclient.DB", "class") == 8
        tf = true;
    else
        for c = histdb.clientCandidates()
            if strlength(c) > 0 && isfolder(fullfile(c, "+labclient"))
                addpath(char(c));
                if exist("labclient.DB", "class") == 8
                    tf = true;
                    break
                end
            end
        end
    end
catch
    tf = false;
end

found = tf;

end
