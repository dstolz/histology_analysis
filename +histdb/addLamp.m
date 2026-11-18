function lamp = addLamp(grid, opts)
%HISTDB.ADDLAMP The lab database's lamp in an app's status bar (or a note that the client is not installed).
%   lamp = histdb.addLamp(grid, Row = 1, Column = 4, Parent = fig)
%
% With the lab database client here (histdb.available), the client's own
% lamp (labclient.Lamp): the database's state and what waits in the outbox,
% the Database window on a click, and the sending started when the database
% is turned on. Without it, a grey button saying so, whose click says how to
% install it. Never an error: a lamp that cannot be made is [].
%
% See also HISTDB.OPENWINDOW, LABCLIENT.LAMP.

arguments
    grid
    opts.Row (1,1) double = 1
    opts.Column (1,1) double = 1
    opts.Parent = []
end

try
    if histdb.available()
        lamp = labclient.Lamp(grid, Row = opts.Row, Column = opts.Column, Parent = opts.Parent);
        return
    end
    lamp = uibutton(grid, "Text", "Database: not installed", "FontSize", 11, ...
        "FontColor", [0.45 0.45 0.45], "Tag", "LabClientLamp", ...
        "Tooltip", "The lab database client (CarasLabDB) is not on this computer. " + ...
        "Analyses work the same without it; each run's provenance is kept beside its outputs.", ...
        "ButtonPushedFcn", @(~, ~) histdb.openWindow(Parent = opts.Parent));
    lamp.Layout.Row = opts.Row;
    lamp.Layout.Column = opts.Column;
catch ME
    warning("histdb:Lamp", "No lab database lamp: %s", ME.message);
    lamp = [];
end

end
