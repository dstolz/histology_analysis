function proceed = exitRoiEdit(obj, askWhenDirty)
%EXITROIEDIT Leave ROI editing, offering to keep anything unsaved.
% Callers redraw afterwards, so leaving an edit and moving to another section
% cost one redraw between them rather than two.
%
% Parameters
%   askWhenDirty: Prompt before discarding unsaved changes.
%
% Returns
%   proceed: False when the user cancelled and editing should continue.

arguments
    obj
    askWhenDirty (1,1) logical = true
end

proceed = true;

if obj.RoiEditStem == ""
    clear_state(obj);
    return
end

if askWhenDirty && obj.RoiEditDirty
    choice = uiconfirm(obj.Fig, ...
        "ROI " + obj.roiName(obj.RoiEditKey) + " of " + obj.RoiEditStem ...
            + " has unsaved changes.", ...
        "Unsaved ROI", ...
        Options = ["Save", "Discard", "Cancel"], ...
        DefaultOption = "Save", ...
        CancelOption = "Cancel");

    switch string(choice)
        case "Save"
            obj.onSaveRoiEdits();

            % A failed save leaves the edit dirty; staying in edit mode keeps
            % the work recoverable instead of throwing it away.
            if obj.RoiEditDirty
                obj.EditRoiButton.Value = true;
                proceed = false;
                return
            end

        case "Cancel"
            obj.EditRoiButton.Value = true;
            proceed = false;
            return

        otherwise
            obj.setWarning("Discarded unsaved changes to ROI %s of %s.", ...
                obj.roiName(obj.RoiEditKey), obj.RoiEditStem);
    end
end

clear_state(obj);

end

function clear_state(obj)
%CLEAR_STATE Drop the edit session and put the controls back to idle.

if ~isempty(obj.RoiEditor) && isvalid(obj.RoiEditor)
    delete(obj.RoiEditor);
end

if ~isempty(obj.SurfaceEditor) && isvalid(obj.SurfaceEditor)
    delete(obj.SurfaceEditor);
end

obj.RoiEditor = [];
obj.SurfaceEditor = [];
obj.SurfaceEditDragging = false;
obj.RoiEditStem = "";

% The active key outlives the session: it is which ROI the controls are
% pointed at, not which one has handles on it, and the next section stepped to
% should open on the same region.
obj.RoiEditKey = "";
obj.RoiEditGeom = struct();
obj.RoiEditDirty = false;
obj.RoiEditCreated = false;
obj.RoiEditDragging = false;
obj.RoiPreview = struct();

if ~isempty(obj.EditRoiButton) && isvalid(obj.EditRoiButton)
    obj.EditRoiButton.Value = false;
end

obj.updateRoiEditControls();

end
