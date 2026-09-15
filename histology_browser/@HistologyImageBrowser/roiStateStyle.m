function style = roiStateStyle(state, tileColor)
%ROISTATESTYLE Line aesthetics that say where an ROI stands against its file.
% Every state an ROI can be in gets its own color and stroke, so whether the
% line on screen is the one on disk is answerable from the picture alone
% rather than from the status bar or from memory.
%
% The two axes carry one meaning each, and they never contradict each other:
%
%   Stroke   solid means the geometry is on disk; dashed means it is not.
%   Color    tile color came from a file, gold is open for editing,
%            orange-red is unsaved, green was just written.
%
% Parameters
%   state: One of "file", "clean", "dirty", "new", or "saved".
%   tileColor: The tile's own color, used by the on-disk state so an
%       untouched ROI keeps reading as part of the tile it belongs to.
%
% Returns
%   style: Struct with fields Color, LineStyle, LineWidth, BandLineStyle,
%      BandLineWidth, Marker, MarkerSize, Badge, and BadgeTextColor.

arguments
    state (1,1) string
    tileColor (1,3) double = HistologyImageBrowser.tileColors(1)
end

style = struct( ...
    "Color", tileColor, ...
    "LineStyle", "-", ...
    "LineWidth", 1.25, ...
    "BandLineStyle", "-", ...
    "BandLineWidth", 1, ...
    "Marker", "o", ...
    "MarkerSize", 6, ...
    "Badge", "", ...
    "BadgeTextColor", [0.1 0.1 0.1]);

switch state
    case "file"
        % The quiet baseline: a thin solid line in the tile's own color is
        % what an ROI read straight off disk looks like, on every tile in a
        % grid, whether or not anything is being edited.
        return

    case "clean"
        % Editing has started but nothing has moved yet, so the line matches
        % the file. Gold says the handles are live; solid says disk agrees.
        style.Color = [1 0.85 0.10];
        style.LineWidth = 1.75;
        style.BandLineWidth = 1.25;
        style.Badge = "ROI FROM FILE";

    case {"dirty", "new"}
        % The one state that costs something to walk away from, so it is the
        % loudest: heavy dashed orange-red, on both the line and the band.
        style.Color = [1 0.35 0.10];
        style.LineStyle = "--";
        style.LineWidth = 3;
        style.BandLineStyle = "--";
        style.BandLineWidth = 2;
        style.Marker = "square";
        style.MarkerSize = 8;
        style.BadgeTextColor = [1 1 1];

        if state == "new"
            style.Badge = "UNSAVED - NEW ROI";
        else
            style.Badge = "UNSAVED EDITS";
        end

    case "saved"
        % Written in this session. Green and solid, and it stays that way
        % until the selection moves on, so a save is visible on the picture
        % rather than only in a status message that scrolls past.
        style.Color = [0.10 0.70 0.35];
        style.LineWidth = 2.25;
        style.BandLineWidth = 1.5;
        style.MarkerSize = 7;
        style.Badge = "SAVED TO DISK";
        style.BadgeTextColor = [1 1 1];
end

end
