function report = updateByUid(obj, uids, updates, options)
%UPDATEBYUID Write values into the tracker rows carrying these identifiers.
% Use this when the rows were chosen earlier and the choice has to survive
% whatever happened to the tab since: a UID is the one thing about a row that
% no sort, filter, or edit to its other columns can change. UPDATEROWS is the
% better entry point when the rows can be described by their contents instead.
%
% Parameters
%   uids: Row identifiers, from the Row UID column.
%   updates: Cell array of column name and value pairs to write.
%   options.verify: Read the tab again afterwards and confirm the values landed
%     in the rows they were aimed at.
%
% Returns
%   report: Table of what was written, one row per tracker row touched.
%
% See also SECTIONTRACKER/UPDATEROWS.

arguments
    obj (1,1) SectionTracker
    uids (:,1) string
    updates cell
    options.verify (1,1) logical = true
end

obj.read();

report = obj.applyUpdates(uids, updates, verify = options.verify);

end
