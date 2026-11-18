function tf = capturing()
%HISTDB.CAPTURING True when this computer keeps records for the lab database (client here, turned on).
%   The client's own answer (labclient.Sync.enabled: the setting Enabled,
%   and the CarasLabDB class usable). False, never an error, without the
%   client.
%
% See also HISTDB.AVAILABLE, HISTDB.ENQUEUE.

tf = false;
if ~histdb.available()
    return
end
try
    tf = labclient.Sync.enabled();
catch
    tf = false;
end
end
