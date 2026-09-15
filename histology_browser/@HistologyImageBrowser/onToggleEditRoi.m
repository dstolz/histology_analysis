function onToggleEditRoi(obj, key)
%ONTOGGLEEDITROI Enter or leave line ROI editing for the targeted section.
% An edit session belongs to exactly one ROI of exactly one section: the line
% is dragged on the tile itself, so a drag has to belong to one image, and a
% section holding several lines has to say which of them the handles are on.
%
% It does not require exactly one section to be *selected*: with several on
% screen the tile ACTIVEROISTEM names takes the line, which is the tile marked
% "(ROI target)" and the section the hint under the buttons states, so the
% choice is settled and visible before this runs rather than being sprung by
% it. Refusing a multi-section selection outright meant the common way of
% browsing -- select a run of sections, look across them, fix the one that is
% wrong -- had to be undone before the ROI could be touched.
%
% Which of the drawn tiles that is, is the user's to say: clicking a tile or
% right-clicking one moves the target through SETROITARGET. Nothing about that
% choice is made here. Which of that section's ROIs is the key argument.
%
% Parameters
%   key: Which ROI to open. Defaults to the one the ROI dropdown is on, which
%       is what a click on the button or its shortcut means. ONADDROI names a
%       key the section does not have yet.
%
% See also ACTIVEROISTEM, SETROITARGET, ATTACHROIEDITOR, ONDRAWROI, ONADDROI,
% EXITROIEDIT.

arguments
    obj
    key (1,1) string = ""
end

if ~obj.EditRoiButton.Value
    % Captured before the session is cleared, because the tile that has to be
    % redrawn is the one the edit is being taken off, and by then nothing else
    % remembers which one that was.
    stem = obj.RoiEditStem;

    if obj.exitRoiEdit(true)
        obj.refreshRoiEdit(stem);
    end

    return
end

if exist("images.roi.Line", "class") ~= 8
    refuse(obj);
    obj.setError("Editing a line ROI needs the Image Processing Toolbox.");
    uialert(obj.Fig, ...
        "Editing a line ROI needs the Image Processing Toolbox, which is not installed.", ...
        "Toolbox Required");

    return
end

% The line is dragged on a tile, so a layout with no tiles has nothing to drag
% it on. Saying which control brings them back is more use than refusing.
if ~obj.showImages()
    refuse(obj);
    obj.setWarning("The ROI is dragged on the image, so set Profiles to a layout that shows the tiles.");

    return
end

% ACTIVEROISTEM comes back empty when nothing is selected, so the one lookup
% covers both "no section" and "a target that has left the view".
row = obj.rowForStem(obj.activeRoiStem());

if height(row) ~= 1
    refuse(obj);
    obj.setWarning("Select a section before editing its ROI.");

    return
end

if key == ""
    key = obj.activeRoiKey(row);
end

geometry = obj.initialRoiGeometry(row, key);

if isempty(geometry)
    refuse(obj);
    obj.setError("No readable image for %s, so there is nothing to draw an ROI over.", row.Stem);

    return
end

obj.RoiEditStem = string(row.Stem);
obj.RoiEditKey = key;
obj.ActiveRoiKey = key;
obj.RoiEditGeom = geometry;

% A line that was just invented has nothing on disk to match, so it counts as
% an unsaved change from the moment it appears.
obj.RoiEditDirty = geometry.isNew;
obj.RoiEditDragging = false;

% A confirmation left over from another ROI would read as though this one had
% just been written, so it is dropped when a new session opens.
if obj.RoiSavedStem ~= obj.RoiEditStem || obj.RoiSavedKey ~= key
    obj.RoiSavedStem = "";
    obj.RoiSavedKey = "";
end

obj.RoiPreview = struct();
obj.RoiWidthField.Value = geometry.strokeWidth;

% An untouched ROI already has its profile on disk, so reading the full
% resolution page waits until the line actually moves. A line with no file
% behind it has nothing to show until it is measured.
%
% A line that has just been invented has no brain surface either, so one is
% looked for as soon as there is a profile to look in. Quietly, because the
% message this function ends on is about the line -- and only for a new line: an
% existing ROI came off disk with whatever mark it has, and turning an edit
% session that has changed nothing into an unsaved one just by opening it would
% put an UNSAVED badge on a tile nobody has touched.
detected = false;

if geometry.isNew
    obj.updateRoiPreview();
    detected = obj.detectSurface(Announce = false, Overwrite = false);
end

obj.updateRoiEditControls();

% Only the one tile taking the line changes, so the rest of the grid keeps the
% pixels it already has rather than being read off disk again.
obj.refreshRoiEdit();

obj.setStatus("%s%s Drag its ends, then Save ROI.", ...
    opening_note(row, numel(obj.drawnStems()), obj.roiName(key), geometry.isNew), ...
    surface_note(obj, detected));

end

function note = surface_note(obj, detected)
%SURFACE_NOTE Mention a brain surface the detector found on the way in.
% Only when one was just placed. A line that came off disk with a mark already
% on it, and one that has none and could not be given one, both say nothing
% here: neither is news, and the ROI hint under the buttons states either.

note = "";

if ~detected
    return
end

note = " Marked the brain surface " + obj.describeSurface(obj.RoiEditGeom) + ".";

end

function note = opening_note(row, nDrawn, name, isNew)
%OPENING_NOTE Say which ROI of which section the line went to, and whether it
% is a new one.
% With one section on screen the section is obvious and naming it is enough.
% With several, which tile just became editable is the thing the button itself
% cannot say, so the count goes in the sentence and the tile it landed on is
% named. The tile is marked as well; this is the same fact said in words, for
% the moment attention is on the button rather than on the pictures. The ROI is
% named either way: a section can carry several, and which of them has the
% handles is no more visible from the button than which tile is.

if isNew
    verb = "Placed new ROI " + name + " on";
else
    verb = "Editing ROI " + name + " of";
end

if nDrawn <= 1
    note = sprintf("%s %s.", verb, row.Stem);
    return
end

note = sprintf("%s %s, the marked one of %d sections on screen.", verb, row.Stem, nDrawn);

end

function refuse(obj)
%REFUSE Put the button back up after declining to start an edit.
% The ROI controls, and the Display menu items mirroring them, follow the
% button, so they are told rather than left showing an edit that never began.

obj.EditRoiButton.Value = false;
obj.updateRoiEditControls();

end
