function openWindow(opts)
%HISTDB.OPENWINDOW The lab database's Database window, or why there is none here.
%   histdb.openWindow(Parent = fig)
%
% With the client here, the Database window every lab toolbox shares
% (labclient.Panel): the server, your login and password, the storage roots
% mapped on this computer, and the outbox. Without it, a message saying how to
% get it; the analyses work the same either way.
%
% See also HISTDB.ADDLAMP, LABCLIENT.PANEL.

arguments
    opts.Parent = []
end

if histdb.available()
    labclient.Panel.open(Parent = opts.Parent);
    return
end

text = "The lab database client is not installed on this computer, so nothing is sent to " + ...
    "the lab database. The analyses work the same without it, and each run keeps its " + ...
    "provenance record beside its outputs (a .provenance folder)." + newline + newline + ...
    "To use the database: clone https://github.com/dstolz/CarasLabDB beside this " + ...
    "checkout (or set CARASLABDB_DIR to a checkout of it) and restart. " + ...
    "Then histdb.backfill(<data folder>) puts the records kept so far in the outbox.";

if ~isempty(opts.Parent) && isvalid(opts.Parent)
    uialert(opts.Parent, text, "Lab Database", Icon = "info");
else
    fprintf("%s\n", text);
end

end
