function targeted = setRoiTarget(obj, stem)
%SETROITARGET Point the ROI controls at one of the tiles on screen.
% With several sections drawn, Edit ROI, Draw Line and Open Containing Folder
% have to act on one of them, and until now that was always the first -- so
% editing the ninth section of a run meant narrowing the selection down to it
% first and losing the very comparison the run was selected for. This is how
% the choice is made instead: click a tile, or right-click one and pick from
% its menu, and the buttons follow.
%
% The one writer of ROITARGETSTEM. Everything that has to stay in step with it
% is done here rather than at each call site: leaving an edit that belongs to
% another section, moving the mark on the tiles, and rewording the panel hint
% that names the target beside the buttons.
%
% An edit already open is the case worth stating. The line being dragged
% belongs to one section, so a target somewhere else cannot coexist with it,
% and the edit is closed before the target moves -- through EXITROIEDIT, so
% unsaved work still gets its prompt and a cancelled prompt leaves both the
% edit and the target exactly as they were. The edit is not reopened on the
% new section: choosing which tile is next and starting to drag it are
% separate acts, and a click that silently began an edit somewhere else would
% be one the user could not undo by clicking back.
%
% Parameters
%   stem: Section to act on. Must be one RENDERSELECTION drew a tile for; a
%       stem outside the selection, or past the Max tiles cap, is declined
%       rather than quietly accepted and then ignored by ACTIVEROISTEM.
%
% Returns
%   targeted: True when the ROI controls now act on this section, including
%       when they already did and nothing had to move. False only when the
%       section could not be targeted at all -- it has no tile on screen, or
%       the user cancelled out of leaving an unsaved edit. Callers that go on
%       to act on the target, such as the menu items that edit or draw on the
%       clicked tile, check it first and do nothing rather than acting on
%       whichever section the controls were left pointing at.
%
% See also ACTIVEROISTEM, MARKROITARGET, EXITROIEDIT, ONTOGGLEEDITROI.

arguments
    obj
    stem (1,1) string
end

targeted = false;

if stem == ""
    return
end

if ~any(obj.drawnStems() == stem)
    return
end

% Already the target, whether because it was chosen before or because it is
% the first drawn tile and nobody has chosen at all. Nothing to redraw, and no
% status message: right-clicking the only section on screen is the common case
% and it should cost nothing and say nothing.
if obj.activeRoiStem() == stem
    obj.RoiTargetStem = stem;
    targeted = true;

    return
end

% Captured before the session is cleared, because the tile that has to be
% redrawn is the one the edit is being taken off, and by then nothing else
% remembers which one that was. Whether it had unsaved work is captured with
% it, because that decides who gets the last word on the status bar.
edited = obj.RoiEditStem;
wasDirty = obj.RoiEditDirty;

if edited ~= "" && ~obj.exitRoiEdit(true)
    return
end

obj.RoiTargetStem = stem;

% EXITROIEDIT leaves the tile it came off still drawn as the edited one -- its
% line stroked as an edit and its drag handle deleted -- so that tile is put
% back to how a section nobody is editing looks. After the target moves, so a
% redraw this falls back to already knows where the mark belongs.
if edited ~= ""
    obj.refreshRoiEdit(edited);
end

obj.markRoiTarget();

% The hint under the buttons names the target, so it is reworded with the mark
% rather than waiting for the next thing that happens to refresh it.
obj.updateRoiEditControls();

targeted = true;

report(obj, stem, edited, wasDirty);

end

function report(obj, stem, edited, wasDirty)
%REPORT Say on the status bar which section the buttons now act on.
% The tile and the hint both say it too, but neither is necessarily where the
% eye is at the moment a tile is clicked, and a click that appears to do
% nothing is a click the user repeats.
%
% An edit that was left with unsaved work in it is the one case this stays
% quiet for. EXITROIEDIT has just reported the save or the discard, which is
% the more important half of what happened and the half that cannot be read
% off the window afterwards; the target can, from the mark and the hint.

if edited ~= "" && wasDirty
    return
end

if edited ~= ""
    obj.setStatus("Closed the ROI edit on %s. Edit ROI and Draw Line now act on %s.", ...
        edited, stem);

    return
end

obj.setStatus("Edit ROI and Draw Line now act on %s.", stem);

end
