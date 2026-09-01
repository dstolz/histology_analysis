function onToggleEditRoi(obj)
%ONTOGGLEEDITROI Enter or leave line ROI editing for the selected section.
% A drag happens on one tile, so an edit session still belongs to exactly one
% section. It no longer requires exactly one section to be *selected*: with
% several on screen the first drawn tile takes the line, and the status bar
% names the section it went to so the choice is never a surprise. Refusing a
% multi-section selection outright meant the common way of browsing -- select a
% run of sections, look across them, fix the one that is wrong -- had to be
% undone before the ROI could be touched.
%
% See also ATTACHROIEDITOR, ONDRAWROI, EXITROIEDIT.

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

rows = obj.selectedRows();

if height(rows) == 0
    refuse(obj);
    obj.setWarning("Select a section before editing its ROI.");

    return
end

% The line is dragged on a tile, so a layout with no tiles has nothing to drag
% it on. Saying which control brings them back is more use than refusing.
if ~obj.showImages()
    refuse(obj);
    obj.setWarning("The ROI is dragged on the image, so set Profiles to a layout that shows the tiles.");

    return
end

row = rows(1, :);
geometry = obj.initialRoiGeometry(row);

if isempty(geometry)
    refuse(obj);
    obj.setError("No readable image for %s, so there is nothing to draw an ROI over.", row.Stem);

    return
end

obj.RoiEditStem = string(row.Stem);
obj.RoiEditGeom = geometry;

% A line that was just invented has nothing on disk to match, so it counts as
% an unsaved change from the moment it appears.
obj.RoiEditDirty = geometry.isNew;
obj.RoiEditDragging = false;

% A confirmation left over from another section would read as though this one
% had just been written, so it is dropped when a new session opens.
if obj.RoiSavedStem ~= obj.RoiEditStem
    obj.RoiSavedStem = "";
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
    opening_note(row, height(rows), geometry.isNew), surface_note(obj, detected));

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

function note = opening_note(row, nSelected, isNew)
%OPENING_NOTE Say which section the line went to, and whether it is a new one.
% With one section selected the section is obvious and naming it is enough.
% With several, which tile just became editable is the thing the user cannot
% see from the button, so the count goes in the sentence.

if isNew
    verb = "Placed a new ROI on";
else
    verb = "Editing the ROI for";
end

if nSelected == 1
    note = sprintf("%s %s.", verb, row.Stem);
    return
end

note = sprintf("%s %s, the first of %d selected sections.", verb, row.Stem, nSelected);

end

function refuse(obj)
%REFUSE Put the button back up after declining to start an edit.
% The ROI controls, and the Display menu items mirroring them, follow the
% button, so they are told rather than left showing an edit that never began.

obj.EditRoiButton.Value = false;
obj.updateRoiEditControls();

end
