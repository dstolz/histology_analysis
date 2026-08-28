function updateReviewControls(obj)
%UPDATEREVIEWCONTROLS Match the review panel to what is selected.
% Called whenever the selection or the sheet configuration changes. The plate
% field shows the selection's own value, so a section's plate is visible where
% it would be edited, and a selection whose plates disagree shows nothing
% rather than one of them: a field showing 30 that would overwrite 28 on Enter
% is worse than a blank one.
%
% See also HISTOLOGYIMAGEBROWSER/REVIEWTARGET.

if isempty(obj.AtlasPlateField) || ~isvalid(obj.AtlasPlateField)
    return
end

target = obj.reviewTarget();

state = matlab.lang.OnOffSwitchState(target.writable);

obj.AtlasPlateField.Enable = state;
obj.SetAtlasPlateButton.Enable = state;
obj.MeasuredButton.Enable = state;
obj.ClearMeasuredButton.Enable = state;

if ~target.writable
    obj.AtlasPlateField.Value = "";
    obj.ReviewLabel.Text = target.reason;
    return
end

obj.AtlasPlateField.Value = char(shared_plate(obj, target.writableRows));
obj.ReviewLabel.Text = describe_selection(obj, target);

end

function text = shared_plate(obj, rows)
%SHARED_PLATE The plate number the selection agrees on, if it has one.

plates = obj.View.AtlasPlate(rows);
plates = plates(~isnan(plates));

if isempty(plates) || numel(unique(plates)) ~= 1 || numel(plates) ~= numel(rows)
    text = "";
    return
end

text = string(plates(1));

end

function text = describe_selection(obj, target)
%DESCRIBE_SELECTION Say what would be written to, and how much is done already.

nWritable = numel(target.uids);

if nWritable == 1
    text = "1 section in the tracker.";
else
    text = sprintf("%d sections in the tracker.", nWritable);
end

measured = obj.View.Measured(target.writableRows);
nMeasured = sum(measured);

if nMeasured == numel(measured)
    text = text + " All measured.";
elseif nMeasured > 0
    text = text + sprintf(" %d of %d measured.", nMeasured, numel(measured));
else
    text = text + " None measured.";
end

% Sections the tracker has no row for are skipped rather than refused, so the
% count of them belongs here where it can be seen before the button is pressed.
if target.reason ~= ""
    text = text + " " + target.reason;
end

end
