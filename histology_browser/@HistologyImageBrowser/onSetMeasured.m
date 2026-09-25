function onSetMeasured(obj, measured)
%ONSETMEASURED Record whether the selected sections have been measured.
% Takes the direction rather than flipping each section, because the selection
% is often several sections at once and they need not agree. Whatever state
% they are in now, every section selected ends up in the one asked for; the
% keyboard toggle in RUNSHORTCUT decides which that is.
%
% Parameters
%   measured: True to mark the sections measured, false to clear the flag.
%
% See also HISTOLOGYIMAGEBROWSER/REVIEWTARGET, SECTIONTRACKER/ISMEASURED.

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

end
