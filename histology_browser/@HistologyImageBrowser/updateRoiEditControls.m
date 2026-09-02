function updateRoiEditControls(obj)
%UPDATEROIEDITCONTROLS Enable the ROI controls that make sense right now, and
% say what the band width currently is. The width governs every line drawn
% from here on, so it is stated whether or not an edit is under way.
%
% The brain surface controls below them follow the same rule and are stated the
% same way: the three that change a line are live only inside an edit session,
% and the label beside them says where the mark sits -- for the line being
% edited, or for the section the buttons would act on if one were.

if isempty(obj.EditRoiButton) || ~isvalid(obj.EditRoiButton)
    return
end

editing = obj.RoiEditStem ~= "";

% Saving an unchanged ROI is still worth allowing: it is how a section that
% has a line but no profile beside it gets one.
obj.SaveRoiButton.Enable = on_off(editing);
obj.RevertRoiButton.Enable = on_off(editing && obj.RoiEditDirty);

obj.RoiEditLabel.Text = hint(obj, editing);

% Detect and Mark place a point on the line being edited, so neither has a line
% to place it on until there is one. Clear needs a mark as well as a line,
% because a button that says it will remove something when there is nothing to
% remove is worse than one that is grey.
obj.DetectSurfaceButton.Enable = on_off(editing);
obj.MarkSurfaceButton.Enable = on_off(editing);
obj.ClearSurfaceButton.Enable = on_off(editing && has_mark(obj.RoiEditGeom));

obj.SurfaceLabel.Text = surface_hint(obj, editing);

% The ROI items on the Display menu follow these same Enable states, and this
% is the one place they are decided.
obj.syncDisplayMenu();

end

function text = hint(obj, editing)
%HINT Say what the ROI controls will do, and how wide the band is.
% The wording tracks the same states the overlay is stroked from, so the panel
% and the tile never disagree about whether the line is on disk.

width = obj.describeRoiWidth(obj.RoiWidthField.Value);

if ~editing
    % With several sections on screen, which one the buttons act on is the
    % thing the panel cannot be read without. It is the same section the tile
    % marks, so the two say it at once rather than either being the only place
    % to look -- and when there is more than one to choose from, the hint says
    % how to choose, because a tile being clickable is not something a picture
    % of a brain looks like.
    target = obj.activeRoiStem();

    if target == ""
        text = "Band " + width + ". Select a section, then Edit ROI or Draw Line.";
        return
    end

    text = "Band " + width + ". Edit ROI and Draw Line act on " + target + ".";

    if numel(obj.drawnStems()) > 1
        text = text + " Click another tile to move the target.";
    end

    return
end

if obj.RoiEditDirty
    text = "Band " + width + ", UNSAVED. Save ROI rewrites the .roi and values.csv.";
    return
end

if obj.RoiSavedStem == obj.RoiEditStem
    text = "Band " + width + ". Saved to disk; the line matches its .roi file.";
    return
end

text = "Band " + width + ", from file. Drag the line ends, or Draw Line to replace it.";

end

function tf = has_mark(geometry)
%HAS_MARK True when a geometry carries a brain surface mark.

tf = isfield(geometry, "surface") && isscalar(geometry.surface) ...
    && isfinite(geometry.surface);

end

function text = surface_hint(obj, editing)
%SURFACE_HINT Say where the brain surface sits, and what would place one.
% With an edit open it describes the line being edited. Without one it
% describes the section the buttons would act on if it were opened, which is
% the same section the ROI hint above names and the same one the tile marks --
% so a run of sections can be walked through to find the unmarked ones without
% entering an edit on each in turn.

if editing
    if has_mark(obj.RoiEditGeom)
        text = "Brain surface " + obj.describeSurface(obj.RoiEditGeom) + ...
            ". Drag its marker, or Clear to remove it.";
        return
    end

    text = "No brain surface on this line. Detect reads one off the profile; " + ...
        "Mark Surface takes one from a click.";
    return
end

stem = obj.activeRoiStem();

if stem == ""
    text = "Brain surface: select a section to mark one on.";
    return
end

row = obj.rowForStem(stem);

if height(row) ~= 1
    text = "Brain surface: select a section to mark one on.";
    return
end

R = obj.roiForRow(row);

if ~R.isValid || ~R.isLine
    text = stem + " has no line ROI to mark a brain surface on.";
    return
end

if ~isfinite(R.surface)
    text = stem + " has no brain surface marked. Edit ROI, then Detect or Mark Surface.";
    return
end

text = stem + " brain surface " + obj.describeSurface(R) + ".";

end

function state = on_off(tf)
%ON_OFF Convert a logical to the matlab.lang.OnOffSwitchState text.

if tf
    state = "on";
else
    state = "off";
end

end
