function [img, imageSize, reason] = loadDisplayImage(obj, imagePath, page)
%LOADDISPLAYIMAGE Read one image page, downsampled for display, with caching.
%
% Returns the image as double in [0 1] before contrast stretching, plus the
% size of the full resolution image. Keeping the original size lets callers
% draw ROI coordinates in full resolution units regardless of downsampling.
%
% Returns an empty img when the file cannot be read, and REASON saying why so
% the tile can name the problem instead of only reporting that one exists.

arguments
    obj
    imagePath (1,1) string
    page (1,1) double = 1
end

img = [];
imageSize = [0 0];
reason = "";

key = char(imagePath + "|" + page);

if isKey(obj.ImageCache, key)
    cached = obj.ImageCache(key);
    img = cached.img;
    imageSize = cached.imageSize;
    return
end

try
    [raw, imageSize] = read_image_page(imagePath, page);
catch ME
    reason = string(ME.message);
    return
end

if isempty(raw)
    reason = "the file holds no pixels for this channel";
    return
end

img = downsample_for_display(raw, obj.MaxDisplayEdge);
img = double(img);

obj.ImageCache(key) = struct("img", img, "imageSize", imageSize);
obj.CacheOrder(end + 1) = string(key);

evict_stale_entries(obj);

end

function [raw, imageSize] = read_image_page(imagePath, page)
%READ_IMAGE_PAGE Read one page from a TIFF, PNG, or Bio-Formats file.

[~, ~, ext] = fileparts(imagePath);
ext = lower(string(ext));

if ext == ".czi"
    raw = read_with_bioformats(imagePath, page);
    imageSize = [size(raw, 1), size(raw, 2)];
    return
end

if ismember(ext, [".tif", ".tiff"])
    info = imfinfo(imagePath);
    page = min(max(round(page), 1), numel(info));
    raw = imread(imagePath, page);
else
    raw = imread(imagePath);
end

imageSize = [size(raw, 1), size(raw, 2)];

end

function raw = read_with_bioformats(imagePath, page)
%READ_WITH_BIOFORMATS Read one channel of a .czi through Bio-Formats.
% Only the requested plane is read. A .czi carries every focal plane, every
% channel, and the slide overview images, so pulling the whole file in to show
% one tile costs seconds and hundreds of megabytes for pixels nothing draws.

ensure_bioformats();

reader = bfGetReader(char(imagePath));
closeReader = onCleanup(@() reader.close());

channel = min(max(round(page), 1), reader.getSizeC());
plane = reader.getIndex(0, channel - 1, 0) + 1;

raw = bfGetPlane(reader, plane);

end

function ensure_bioformats()
%ENSURE_BIOFORMATS Put Bio-Formats on the path, looking in the usual places.
% The MATLAB path is easily lost — a startup.m calling RESTOREDEFAULTPATH is
% enough — and losing it turns every .czi that read yesterday into an
% unreadable file. So look beside this toolbox before giving up.
%
% The toolbox is a folder inside the histology_analysis checkout, so a bfmatlab
% checked out next to that repository sits two levels up rather than one.

if exist("bfGetReader", "file") == 2
    return
end

toolboxRoot = fileparts(fileparts(mfilename("fullpath")));
repositoryRoot = fileparts(toolboxRoot);

candidates = [ ...
    string(getenv("BFMATLAB_PATH")), ...
    string(fullfile(toolboxRoot, "bfmatlab")), ...
    string(fullfile(repositoryRoot, "bfmatlab")), ...
    string(fullfile(fileparts(repositoryRoot), "bfmatlab")), ...
    string(fullfile(userpath, "bfmatlab"))];

for iCandidate = 1:numel(candidates)
    candidate = candidates(iCandidate);

    if candidate ~= "" && isfile(fullfile(candidate, "bfGetReader.m"))
        addpath(char(candidate));
        return
    end
end

error("HistologyImageBrowser:BioFormatsMissing", ...
    "reading .czi needs the Bio-Formats bfmatlab folder on the MATLAB path. " + ...
    "Add it with addpath, put it beside this toolbox or the " + ...
    "histology_analysis checkout, or point the " + ...
    "BFMATLAB_PATH environment variable at it.")

end

function img = downsample_for_display(raw, maxEdge)
%DOWNSAMPLE_FOR_DISPLAY Shrink large images so many tiles stay responsive.

scale = maxEdge / max(size(raw, 1), size(raw, 2));

if scale >= 1
    img = raw;
    return
end

if exist("imresize", "file") == 2
    img = imresize(raw, scale);
    return
end

% Without Image Processing Toolbox, fall back to strided subsampling.
step = max(1, floor(1 / scale));
img = raw(1:step:end, 1:step:end, :);

end

function evict_stale_entries(obj)
%EVICT_STALE_ENTRIES Bound the cache by discarding the oldest entries.

while numel(obj.CacheOrder) > obj.MaxCachedImages
    oldest = char(obj.CacheOrder(1));
    obj.CacheOrder(1) = [];

    if isKey(obj.ImageCache, oldest)
        remove(obj.ImageCache, oldest);
    end
end

end
