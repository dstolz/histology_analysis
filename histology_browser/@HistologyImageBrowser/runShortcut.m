function runShortcut(obj, action)
%RUNSHORTCUT Carry out one named keyboard shortcut.
% Every arm goes through the same callback the button or menu uses, so a
% shortcut and a click cannot drift apart, and the guards those callbacks
% already carry -- nothing selected, nothing loaded, no toolbox -- report
% through the status bar as usual.
%
% Parameters
%   action: Action name from KEYBINDINGS.
%
% See also KEYBINDINGS, ONFIGUREKEYPRESS.

switch action
    case "nextSection"
        obj.onStepSelection(1);

    case "previousSection"
        obj.onStepSelection(-1);

    case "firstSection"
        select_row(obj, 1);

    case "lastSection"
        select_row(obj, height(obj.View));

    case "selectAll"
        obj.onSelectAll();

    case "focusSearch"
        focus_search(obj);

    case "resetFilters"
        obj.onResetFilters();

    case "loadDataset"
        obj.onLoadData();

    case "toggleEditRoi"
        % The state button carries the mode, so it is flipped first and the
        % callback then reads it exactly as it would after a click.
        obj.EditRoiButton.Value = ~obj.EditRoiButton.Value;
        obj.onToggleEditRoi();

    case "drawRoi"
        obj.onDrawRoi();

    case "saveRoi"
        press(obj, obj.SaveRoiButton, @obj.onSaveRoiEdits, ...
            "Nothing is being edited, so there is no ROI to save.");

    case "revertRoi"
        press(obj, obj.RevertRoiButton, @obj.onRevertRoiEdits, ...
            "The ROI has no unsaved changes to discard.");

    case "cancelRoiEdit"
        cancel_roi_edit(obj);

    case "toggleRoiOverlay"
        toggle_check(obj, obj.ShowRoiCheck, "Line ROI overlay");

    case "toggleBandOverlay"
        toggle_check(obj, obj.ShowBandCheck, "Sampling band");

    case "toggleIntensityShading"
        toggle_check(obj, obj.ColorByIntensityCheck, "Intensity shading");

    case "toggleDataColumn"
        obj.onToggleDataColumn();

    case "toggleDisplayRow"
        obj.onToggleDisplayRow();

    case "toggleAllPanels"
        obj.onToggleAllPanels();

    case "openInFigure"
        obj.onOpenInFigure();

    case "exportView"
        obj.onExportView();

    case "openFolder"
        obj.onOpenFolder();

    case "showShortcuts"
        obj.onShowShortcuts();

    otherwise
        % A binding naming an action with no arm here is a coding slip rather
        % than something the user did, so it is reported as one.
        obj.setError("No handler for the ""%s"" shortcut.", action);
end

end

function select_row(obj, rowIndex)
%SELECT_ROW Jump the selection to one row of the filtered view.

if height(obj.View) == 0
    return
end

rowIndex = min(max(rowIndex, 1), height(obj.View));

obj.CatalogTable.Selection = rowIndex;
obj.onSelectionChanged();

end

function focus_search(obj)
%FOCUS_SEARCH Put the caret in the search box, uncollapsing it if need be.
% FOCUS arrived in R2022a, and the shortcut is worth having on older releases
% too, so a release without it says where the box is instead of failing. It is
% a method of the component rather than a plain function, which EXIST cannot
% see, so the call itself is what reports whether the release has it.

if obj.DataColumnHidden
    obj.onToggleDataColumn();
end

try
    focus(obj.SearchField);
catch ME
    if ME.identifier == "MATLAB:UndefinedFunction"
        obj.setWarning("This MATLAB release cannot move focus; the search box is at the top left.");
        return
    end

    obj.setWarning("Could not move focus to the search box: %s", ME.message);
end

end

function press(obj, button, callback, disabledMessage)
%PRESS Run a button's callback only when the button itself would accept a click.
% Keeping the shortcut behind the same Enable state the button shows means the
% keyboard can never reach an action the window says is unavailable.

if isempty(button) || ~isvalid(button) || ~strcmp(string(button.Enable), "on")
    obj.setWarning("%s", disabledMessage);
    return
end

callback();

end

function cancel_roi_edit(obj)
%CANCEL_ROI_EDIT Leave ROI editing, or say there was nothing to leave.
% Unsaved work still gets its prompt: Escape asks to leave, it does not throw
% the edit away.

if obj.RoiEditStem == ""
    return
end

obj.EditRoiButton.Value = false;
obj.onToggleEditRoi();

end

function toggle_check(obj, check, name)
%TOGGLE_CHECK Flip an overlay checkbox and redraw, naming its new state.
% The checkbox is off screen whenever the configuration panels are hidden,
% which is exactly when these shortcuts matter most, so the status bar reports
% what the key did.

if isempty(check) || ~isvalid(check)
    return
end

check.Value = ~check.Value;
obj.onDisplayOptionChanged();

if check.Value
    obj.setStatus("%s on.", name);
else
    obj.setStatus("%s off.", name);
end

end
