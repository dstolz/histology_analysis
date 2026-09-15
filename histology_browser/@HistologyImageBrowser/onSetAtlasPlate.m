function onSetAtlasPlate(obj)
%ONSETATLASPLATE Write the plate number in the field to the selected sections.
% Reached from the field's Enter key and from the Set button, which is why the
% field's value is read here rather than passed in: the two have to mean the
% same thing.
%
% An empty field empties the cell. That is a real thing to want -- a plate
% number assigned in error has to be removable -- so it is allowed, but it is
% confirmed first, because pressing Enter in an empty field is also how someone
% would find out what the field does.
%
% See also HISTOLOGYIMAGEBROWSER/ONSETMEASURED,
% HISTOLOGYIMAGEBROWSER/REVIEWTARGET.

target = obj.reviewTarget();

if ~target.writable
    obj.setWarning("%s", target.reason);
    return
end

text = strtrim(string(obj.AtlasPlateField.Value));

if text == ""
    if ~confirm_clear(obj, numel(target.uids))
        obj.updateReviewControls();
        return
    end
else
    plate = str2double(text);

    % Plates are numbered, and a cell holding something else would break the
    % filters and the sort that read this column as a number.
    if isnan(plate) || plate < 0 || plate ~= floor(plate)
        obj.setError("'%s' is not a plate number.", text);
        obj.updateReviewControls();
        return
    end

    text = string(plate);
end

description = "atlas plate " + describe_value(text);

if obj.writeReview(target.uids, {"Atlas Plate #", text}, description)
    obj.AtlasPlateField.Value = char(text);
end

obj.updateReviewControls();

end

function tf = confirm_clear(obj, nRows)
%CONFIRM_CLEAR Check that emptying the plate cell is what was meant.

choice = uiconfirm(obj.Fig, ...
    sprintf("Empty the Atlas Plate # cell of %d tracker row(s)?", nRows), ...
    "Clear Atlas Plate", ...
    Options = ["Clear It", "Cancel"], ...
    DefaultOption = "Cancel", ...
    CancelOption = "Cancel", ...
    Icon = "question");

tf = choice == "Clear It";

end

function text = describe_value(value)
%DESCRIBE_VALUE Name the written value for the status bar.

if value == ""
    text = "(empty)";
    return
end

text = value;

end
