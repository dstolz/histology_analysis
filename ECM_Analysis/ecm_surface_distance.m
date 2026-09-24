function [surfaceDistance, hasMark] = ecm_surface_distance(offset, lineLength, d)
% ecm_surface_distance
%   [surfaceDistance, hasMark] = ecm_surface_distance(offset, lineLength, d)
%
% Put a brain surface mark from the histology browser onto a profile's
% distance axis.
%
% The browser stores the mark as an offset in pixels along the line from its
% start (SurfaceOffset), beside the line's length in pixels (RoiLength). The
% profile spans that line by construction, so the mark lands at the same
% fraction of the profile's span that it sits at along the line -- the
% conversion HistologyImageBrowser.readProfile uses to draw it -- whether or
% not the image carries a calibration.
%
% ecm_prepare_analysis_data and ecm_export_for_r both place the mark through
% this function, so the MATLAB analysis and the R analysis align every section
% on the same number.
%
% Parameters
%   offset: The mark's offset along the line, in pixels. NaN when the section
%       has no mark.
%   lineLength: The line's length in the unit of offset.
%   d: The profile's distances, finite and sorted ascending.
%
% Returns
%   surfaceDistance: The surface on the profile's distance axis, or NaN when
%       there is no mark or it cannot be placed.
%   hasMark: True when a mark was there, so a caller can tell a section with
%       no mark from one whose mark could not be placed (hasMark true,
%       surfaceDistance NaN).

surfaceDistance = NaN;
hasMark = isscalar(offset) && isfinite(offset);

if ~hasMark
    return
end

if isempty(d)
    return
end

span = d(end) - d(1);

if offset < 0 || ~isscalar(lineLength) || ~isfinite(lineLength) || lineLength <= 0 ...
        || ~isfinite(span) || span <= 0
    return
end

fraction = min(max(offset / lineLength, 0), 1);
surfaceDistance = d(1) + fraction * span;

end
