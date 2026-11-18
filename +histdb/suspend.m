function r = suspend()
%HISTDB.SUSPEND No sending to the lab database until R is cleared (a batch is running).
%   r = histdb.suspend();   % ... the batch ...;   clear r
%
% Sending a record takes the database's time and a little of MATLAB's; a long
% batch is better left alone until it is done. Without the client there is
% nothing to pause, and R is an object whose clearing does nothing.
%
% See also LABCLIENT.SYNC.

r = onCleanup(@() []);
try
    if histdb.available()
        r = labclient.Sync.suspend();
    end
catch
end
end
