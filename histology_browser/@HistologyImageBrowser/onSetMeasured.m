function onSetMeasured(obj, measured)
%ONSETMEASURED Record whether the selected sections have been measured.
% Two buttons rather than one checkbox, because the selection is often several
% sections at once and a checkbox has no honest way to show a mixed one. Each
% button says what it will do to every section selected, whatever state they
% are in now.
%
% Parameters
%   measured: True to mark the sections measured, false to clear the flag.
%
% See also HISTOLOGYIMAGEBROWSER/ONSETATLASPLATE, SECTIONTRACKER/ISMEASURED.

arguments
    obj (1,1) HistologyImageBrowser
    measured (1,1) logical
end

target = obj.reviewTarget();

if ~target.writable
    obj.setWarning("%s", target.reason);
    return
end

if measured
    description = "measured";
else
    description = "not measured";
end

obj.writeReview(target.uids, ...
    {SectionTracker.MeasuredColumn, SectionTracker.measuredText(measured)}, ...
    description);

obj.updateReviewControls();

end
