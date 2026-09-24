function bindings = keyBindings()
%KEYBINDINGS Every keyboard shortcut the browser answers to.
% One place names the keys, says what they do, and supplies the text the
% shortcut list and the tooltips show, so a shortcut cannot be advertised in
% one spot and bound in another.
%
% Every binding carries a modifier. Bare letters were tried and dropped: a
% uifigure sends key presses to WINDOWKEYPRESSFCN whether or not an edit field
% has them, so typing "brain" into the search box would have fired five
% shortcuts. Keys that cannot be typed into a field -- Escape and F1 -- are the
% only ones bound on their own.
%
% Returns
%   bindings: Struct array, in the order the shortcut list presents them, with
%       fields Key, Modifier, Action, Group, Label, and SkipInTextEntry.
%
% Fields
%   Key:      The Key name a WindowKeyPress event reports, lowercase.
%   Modifier: Modifiers that must all be down, and no others.
%   Action:   Name RUNSHORTCUT switches on. Repeats are aliases for one action
%             and are listed together as "A or B".
%   Group:    Heading the shortcut list files it under.
%   Label:    What the shortcut does, in the shortcut list's words.
%   SkipInTextEntry: Leave the key to the text field when one was last clicked,
%             because the field already does something with it.
%
% See also ONFIGUREKEYPRESS, RUNSHORTCUT, ONSHOWSHORTCUTS.

bindings = struct( ...
    Key = {}, Modifier = {}, Action = {}, Group = {}, Label = {}, SkipInTextEntry = {});

% -- Sections ------------------------------------------------------------
bindings = add(bindings, "downarrow", "control", "nextSection", ...
    "Sections", "Next section");
bindings = add(bindings, "rightarrow", "control", "nextSection", ...
    "Sections", "Next section", SkipInTextEntry = true);
bindings = add(bindings, "uparrow", "control", "previousSection", ...
    "Sections", "Previous section");
bindings = add(bindings, "leftarrow", "control", "previousSection", ...
    "Sections", "Previous section", SkipInTextEntry = true);

% Ctrl+Home and Ctrl+End jump the caret inside a field, so they are handed
% over whenever one was clicked into.
bindings = add(bindings, "home", "control", "firstSection", ...
    "Sections", "First section", SkipInTextEntry = true);
bindings = add(bindings, "end", "control", "lastSection", ...
    "Sections", "Last section", SkipInTextEntry = true);

bindings = add(bindings, "a", "control", "selectAll", ...
    "Sections", "Select every section passing the filters", SkipInTextEntry = true);
bindings = add(bindings, "f", "control", "focusSearch", ...
    "Sections", "Jump to the search box");
bindings = add(bindings, "r", ["control", "shift"], "resetFilters", ...
    "Sections", "Clear every filter");
bindings = add(bindings, "l", "control", "loadDataset", ...
    "Sections", "Load the dataset");

% Ctrl+E already starts an ROI edit, so the export of the selected sections
% takes the shifted form of the same letter rather than a letter of its own.
bindings = add(bindings, "e", ["control", "shift"], "exportWorkspace", ...
    "Sections", "Export the selected sections to the workspace");

% -- Review --------------------------------------------------------------
bindings = add(bindings, "m", "control", "toggleMeasured", ...
    "Review", "Mark the selected sections measured, or clear them if all are");

% -- Line ROI ------------------------------------------------------------
bindings = add(bindings, "n", "control", "addRoi", ...
    "Line ROI", "Add another ROI to this section");

% Ctrl+Shift+N rather than the shifted Ctrl+E this was written as: that key
% already exports the selected sections, and ONFIGUREKEYPRESS takes the first
% binding that matches, so the second of the two would never have run. It sits
% beside Ctrl+N for adding one instead, which is the closer pairing anyway.
bindings = add(bindings, "n", ["control", "shift"], "nextRoi", ...
    "Line ROI", "Move to this section's next ROI");
bindings = add(bindings, "e", "control", "toggleEditRoi", ...
    "Line ROI", "Start or finish editing the chosen ROI of the marked section");
bindings = add(bindings, "d", "control", "drawRoi", ...
    "Line ROI", "Draw a new line over the marked section");
bindings = add(bindings, "s", "control", "saveRoi", ...
    "Line ROI", "Save the ROI and remeasure its profile");
bindings = add(bindings, "z", "control", "revertRoi", ...
    "Line ROI", "Discard unsaved ROI changes", SkipInTextEntry = true);
bindings = add(bindings, "escape", strings(1, 0), "cancelRoiEdit", ...
    "Line ROI", "Leave ROI editing");

% The two ways of putting a brain surface on the line being edited. They take
% the same letter because they answer the same question, one from the profile
% and one from a click, and the shifted form is the one that needs the mouse.
bindings = add(bindings, "b", "control", "detectSurface", ...
    "Line ROI", "Find the brain surface in the profile and mark it");
bindings = add(bindings, "b", ["control", "shift"], "markSurface", ...
    "Line ROI", "Click on the image to mark the brain surface");

% -- Display -------------------------------------------------------------
bindings = add(bindings, "1", "control", "toggleRoiOverlay", ...
    "Display", "Line ROI overlay on or off");
bindings = add(bindings, "2", "control", "toggleBandOverlay", ...
    "Display", "Sampling band on or off");
bindings = add(bindings, "3", "control", "toggleIntensityShading", ...
    "Display", "Shade the ROI by intensity, or not");
bindings = add(bindings, "4", "control", "toggleSurfaceOverlay", ...
    "Display", "Brain surface marks on or off");
bindings = add(bindings, "d", ["control", "shift"], "toggleDataColumn", ...
    "Display", "Hide or show the lookup and catalog column");
bindings = add(bindings, "p", ["control", "shift"], "toggleDisplayRow", ...
    "Display", "Hide or show the display controls above the tiles");
bindings = add(bindings, "h", "control", "toggleAllPanels", ...
    "Display", "Hide or show the data column and the display row together");
bindings = add(bindings, "o", "control", "openInFigure", ...
    "Display", "Redraw the view in a normal figure");
bindings = add(bindings, "o", ["control", "shift"], "openInFiji", ...
    "Display", "Open the marked section's image and ROIs in Fiji");
bindings = add(bindings, "p", "control", "exportView", ...
    "Display", "Export the view to an image file");
bindings = add(bindings, "f", ["control", "shift"], "openFolder", ...
    "Display", "Open the folder holding the marked section's image");

% -- Help ----------------------------------------------------------------
bindings = add(bindings, "f1", strings(1, 0), "showShortcuts", ...
    "Help", "Show this list");

end

function bindings = add(bindings, key, modifier, action, group, label, options)
%ADD Append one binding, defaulting the flag most bindings do not set.

arguments
    bindings struct
    key (1,1) string
    modifier (1,:) string
    action (1,1) string
    group (1,1) string
    label (1,1) string
    options.SkipInTextEntry (1,1) logical = false
end

bindings(end + 1, 1) = struct( ...
    Key = key, ...
    Modifier = sort(modifier), ...
    Action = action, ...
    Group = group, ...
    Label = label, ...
    SkipInTextEntry = options.SkipInTextEntry);

end
