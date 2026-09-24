function found = detectSurface(obj, options)
%DETECTSURFACE Find the brain surface under the edited line and mark it.
% The profile under the line is what the surface is read off, so this runs
% after UPDATEROIPREVIEW rather than beside it: DETECT_BRAIN_SURFACE looks for
% the step from background into tissue in the measured trace, and there is
% nothing to look at until the trace exists. Background is the slide, read off
% the darkest part of the page the trace was measured from.
%
% Called from two places with two different tempers. Creating a line -- drawing
% one, or having one placed across the middle of a section that never had one
% -- asks quietly, because a guess offered unbidden should not push a message
% the user was reading off the status bar, and should not overwrite a mark that
% is already there. The Detect button asks loudly and overwrites, because
% pressing it is a request for exactly that.
%
% Nothing is written to disk here. The mark lands on the edit geometry like any
% other change, turns the ROI dirty, and goes out with Save ROI, so a surface
% the detector got wrong costs a drag rather than a file.
%
% Parameters
%   options.Announce: Report the outcome on the status bar. Off for the
%       automatic pass, which has a message of its own to leave standing.
%   options.Overwrite: Replace a mark that is already on the line. Off for the
%       automatic pass, which is offering a starting point rather than an
%       opinion about one the user has already placed.
%
% Returns
%   found: True when a surface was located and marked.
%
% See also DETECT_BRAIN_SURFACE, ONDETECTSURFACE, ONDRAWROI, ONTOGGLEEDITROI.

arguments
    obj
    options.Announce (1,1) logical = true
    options.Overwrite (1,1) logical = true
end

found = false;

if obj.RoiEditStem == ""
    if options.Announce
        obj.setWarning("Edit a line ROI before detecting its brain surface.");
    end

    return
end

geometry = obj.RoiEditGeom;

if ~options.Overwrite && isfield(geometry, "surface") && isfinite(geometry.surface)
    return
end

% The ROI being edited, named rather than left to the default: the mark this
% finds is written into RoiEditGeom, so reading any other ROI's profile would
% put a depth measured on one line onto another.
P = obj.readProfile(obj.editedRow(), obj.RoiEditKey);

if ~P.hasData
    if options.Announce
        obj.setWarning("No profile under the line for %s, so its surface cannot be found.", ...
            obj.RoiEditStem);
    end

    return
end

S = detect_brain_surface(P.distance, P.intensity, Background = measure_background(obj));

if ~S.found
    if options.Announce
        obj.setWarning("Could not find a brain surface for %s: %s", obj.RoiEditStem, S.message);
    end

    return
end

% The detector answers in the profile's own distance units, which are microns
% wherever the page carries a calibration. The mark is stored in pixels along
% the line, so it is converted through the fraction of the trace the crossing
% sits at rather than by dividing out a pixel size that may not exist.
lineLength = hypot(geometry.x2 - geometry.x1, geometry.y2 - geometry.y1);

geometry.surface = S.fraction * lineLength;
geometry.surfaceSource = "auto";

obj.RoiEditGeom = geometry;
obj.RoiEditDirty = true;
obj.RoiSavedStem = "";

found = true;

if options.Announce
    obj.setStatus("Marked the brain surface for %s %s. %s", ...
        obj.RoiEditStem, obj.describeSurface(geometry), confidence_note(S));
end

end

function level = measure_background(obj)
%MEASURE_BACKGROUND The slide level of the page the profile was measured from.
% The darkest part of that page, so the step is measured against the slide the
% section lies on rather than against the dimmest stretch of the trace, which
% for a line drawn inside tissue is only dim tissue. The page is the one the
% preview was just measured from and is already in memory. Without one, NaN
% hands the choice back to DETECT_BRAIN_SURFACE, which reads the background off
% the trace instead.

level = NaN;

M = obj.loadMeasureImage(obj.editedRow());

if M.hasImage
    level = image_background(M.img);
end

end

function note = confidence_note(S)
%CONFIDENCE_NOTE Say how much the step it found is worth trusting.
% A weak edge is still marked -- the marker is there to be dragged -- but it is
% said out loud, because a mark placed on a trace with barely an edge in it
% looks exactly like one placed on an obvious one.

if S.confidence == "high"
    note = "Drag its marker to correct it.";
    return
end

note = S.message + " Check it before saving.";

end
