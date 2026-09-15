function info = write_surface_mark(markPath, mark)
% write_surface_mark
%   info = write_surface_mark(markPath, mark)
%   info = write_surface_mark(surface_mark_path(roiPath), geometry)
%
% Write the brain surface mark that belongs to one line ROI, the inverse of
% READ_SURFACE_MARK.
%
% Clearing a mark is the same call with a surface of NaN, which deletes the
% sidecar rather than leaving one behind that says nothing. That is what keeps
% "no file" and "no surface" the same state on disk: a section either has a
% mark beside its ROI or it does not, and nothing has to distinguish an absent
% sidecar from an empty one.
%
% JSON rather than the values-CSV layout used elsewhere in this toolbox,
% because this is one record of a handful of named fields rather than a column
% of samples, and because the endpoints stored alongside the offset are there
% to be read by a person checking why a mark looks wrong.
%
% Parameters
%   markPath: Destination *_surface.json path.
%   mark: Struct with fields x1, y1, x2, y2 and surface, the last being the
%       distance from (x1,y1) to the surface in pixels along the line. An
%       optional surfaceSource field records how it was placed. The ROI edit
%       geometry the browser carries has exactly this shape, so it can be
%       handed over as it stands.
%
% Returns
%   info: Struct with fields markPath, written (false when the file was
%       removed instead), and offset.
%
% See also READ_SURFACE_MARK, SURFACE_MARK_PATH, DETECT_BRAIN_SURFACE.

arguments
    markPath (1,1) string
    mark (1,1) struct
end

info = struct("markPath", markPath, "written", false, "offset", NaN);

if markPath == ""
    error("write_surface_mark:NoPath", "No path to write the surface mark to.");
end

offset = surface_offset(mark);

if isnan(offset)
    if isfile(markPath)
        delete(markPath);
    end

    return
end

folder = fileparts(markPath);

if folder ~= "" && ~isfolder(folder)
    mkdir(folder);
end

S = struct( ...
    "version", 1, ...
    "surfaceOffsetPx", offset, ...
    "x1", endpoint(mark, "x1"), ...
    "y1", endpoint(mark, "y1"), ...
    "x2", endpoint(mark, "x2"), ...
    "y2", endpoint(mark, "y2"), ...
    "source", mark_source(mark), ...
    "written", string(datetime("now", Format = "yyyy-MM-dd HH:mm:ss")));

fid = fopen(markPath, "w");

if fid < 0
    error("write_surface_mark:CannotOpen", "Could not open %s for writing.", markPath);
end

cleanupFid = onCleanup(@() fclose(fid));

% Pretty printed because the file is small and is meant to be openable in a
% text editor by whoever is wondering where a marker on a tile came from.
fprintf(fid, "%s\n", jsonencode(S, PrettyPrint = true));

clear cleanupFid

info.written = true;
info.offset = offset;

end

function offset = surface_offset(mark)
%SURFACE_OFFSET Read the offset to store, or NaN when there is no mark.

offset = NaN;

if ~isfield(mark, "surface")
    return
end

candidate = double(mark.surface);

if isscalar(candidate) && isfinite(candidate) && candidate >= 0
    offset = candidate;
end

end

function value = endpoint(mark, name)
%ENDPOINT Read one line endpoint, or NaN when the caller did not supply it.

value = NaN;

if ~isfield(mark, name)
    return
end

candidate = double(mark.(name));

if isscalar(candidate) && isfinite(candidate)
    value = candidate;
end

end

function source = mark_source(mark)
%MARK_SOURCE Record how the mark was placed, defaulting to a manual one.

source = "manual";

if ~isfield(mark, "surfaceSource")
    return
end

candidate = string(mark.surfaceSource);

if isscalar(candidate) && ismember(candidate, ["auto", "manual"])
    source = candidate;
end

end
