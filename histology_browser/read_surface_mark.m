function M = read_surface_mark(markPath)
% read_surface_mark
%   M = read_surface_mark(markPath)
%   M = read_surface_mark(surface_mark_path(roiPath))
%
% Read the brain surface mark stored beside a line ROI, the inverse of
% WRITE_SURFACE_MARK.
%
% The offset is the distance from the line's start point to the surface, in
% image pixels along the line. That is the invariant worth storing: dragging
% the far end of a line leaves the surface where it was, which a fraction of
% the line length would not. The endpoints the mark was made against are
% stored with it so a mark left behind by a line that has since moved can be
% recognized rather than silently believed.
%
% A file that is missing, unreadable, or not a surface mark comes back with
% isValid false and a message, never an error. These sit in a data folder
% beside files written by Fiji and by hand, and one section with a damaged
% sidecar must not stop a catalog of several hundred from being browsed.
%
% Parameters
%   markPath: Path to a *_surface.json sidecar.
%
% Returns
%   M: Struct with fields
%      - isValid: True when a surface offset was decoded.
%      - message: Empty on success, otherwise why nothing was read.
%      - markPath: Path that was read.
%      - offset: Distance from the line start to the surface, in pixels.
%      - x1, y1, x2, y2: Line the mark was made against, when recorded.
%      - source: How the mark was placed -- "auto", "manual", or "".
%      - version: Format version the file was written at.
%
% See also WRITE_SURFACE_MARK, SURFACE_MARK_PATH, DETECT_BRAIN_SURFACE.

arguments
    markPath (1,1) string
end

M = struct( ...
    "isValid", false, ...
    "message", "", ...
    "markPath", markPath, ...
    "offset", NaN, ...
    "x1", NaN, "y1", NaN, "x2", NaN, "y2", NaN, ...
    "source", "", ...
    "version", 0);

if markPath == "" || ~isfile(markPath)
    M.message = "No surface mark beside this ROI.";
    return
end

try
    text = fileread(markPath);
    S = jsondecode(text);
catch ME
    M.message = "Could not read the surface mark: " + string(ME.message);
    return
end

if ~isstruct(S) || ~isscalar(S) || ~isfield(S, "surfaceOffsetPx")
    M.message = "Not a surface mark: " + markPath;
    return
end

offset = double(S.surfaceOffsetPx);

if ~isscalar(offset) || ~isfinite(offset) || offset < 0
    M.message = "The surface mark holds no usable offset.";
    return
end

M.offset = offset;
M.x1 = read_number(S, "x1");
M.y1 = read_number(S, "y1");
M.x2 = read_number(S, "x2");
M.y2 = read_number(S, "y2");
M.source = read_text(S, "source");
M.version = read_number(S, "version");
M.isValid = true;

end

function value = read_number(S, name)
%READ_NUMBER Pull one numeric field out, or NaN when it is absent or unusable.

value = NaN;

if ~isfield(S, name)
    return
end

candidate = double(S.(name));

if isscalar(candidate) && isfinite(candidate)
    value = candidate;
end

end

function value = read_text(S, name)
%READ_TEXT Pull one string field out, or "" when it is absent or unusable.

value = "";

if ~isfield(S, name)
    return
end

candidate = S.(name);

if ischar(candidate) || (isstring(candidate) && isscalar(candidate))
    value = string(candidate);
end

end
