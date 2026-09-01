function C = build_histology_image_catalog(rootPath, options)
% build_histology_image_catalog
%   C = build_histology_image_catalog(rootPath)
%   C = build_histology_image_catalog(rootPath, metadataTable = S.metadata.table)
%
% Build a one-row-per-section catalog of histology images found under a root
% folder. Each row collects every rendition of one acquisition (raw .czi,
% _proj, _mid, _composite), its Fiji line ROI sidecar, and any associated
% *values.csv profiles, then joins the section tracker metadata.
%
% Renditions are commonly written both beside the section folder and inside
% it. Both are discovered, and the copy stored in the section folder itself is
% preferred because that is where the ROI and values sidecars live.
%
% Parameters
%   rootPath: Root folder to scan recursively.
%   options.metadataTable: Section tracker table, e.g. S.metadata.table from
%     COMBINE_VALUES_CSV. Joined by image filename stem.
%   options.imageFilenameColumn: Tracker column holding image filenames.
%   options.includeMissing: Also emit a row for each tracker entry that has no
%     image on disk. Off by default because a shared tracker usually spans far
%     more subjects than any one root folder holds; turn it on to audit gaps.
%   options.filenamePattern: Named-capture regular expression PARSE_HISTOLOGY_
%     FILENAME uses in place of the built-in naming convention. Empty (the
%     default) keeps the convention, so an existing call is unchanged.
%
% Returns
%   C: Table with one row per image stem, sorted by subject and section.
%      Path columns are "" when that rendition is absent.
%      The columns are the same whatever the pattern: tokens it names beyond
%      the known components are parsed but not added as columns, because the
%      browser's filters, sort order, and table view all name their columns,
%      and a catalog whose shape changed with the pattern would break them.
%
% See also PARSE_HISTOLOGY_FILENAME, COMBINE_VALUES_CSV,
% HISTOLOGYIMAGEBROWSER.

arguments
    rootPath (1,1) string
    options.metadataTable table = table()
    options.imageFilenameColumn (1,1) string = "Image Filename"
    options.includeMissing (1,1) logical = false
    options.filenamePattern (1,1) string = ""
end

if ~isfolder(rootPath)
    error("build_histology_image_catalog:InvalidRootPath", ...
        "rootPath is not a valid folder: %s", rootPath)
end

F = scan_files(rootPath, options.filenamePattern);

if isempty(F)
    stems = strings(0, 1);
else
    stems = unique(F.Stem);
end

rows = build_rows(F, stems, options.filenamePattern);
rows = attach_metadata(rows, options.metadataTable, options.imageFilenameColumn, ...
    options.includeMissing, options.filenamePattern);

if isempty(rows)
    C = table();
    return
end

C = struct2table(rows, "AsArray", true);
C = sortrows(C, ["SubjectID", "SampleID", "SectionID", "Hemisphere", "Stain"]);

end

function F = scan_files(rootPath, filenamePattern)
%SCAN_FILES Discover images and sidecars, and parse each filename.

patterns = ["*.tif", "*.tiff", "*.png", "*.czi", "*.roi", "*values.csv"];
listing = [];

for iPattern = 1:numel(patterns)
    thisListing = dir(fullfile(rootPath, "**", patterns(iPattern)));

    if ~isempty(thisListing)
        listing = [listing; thisListing]; %#ok<AGROW>
    end
end

if isempty(listing)
    F = table();
    return
end

listing = listing(~[listing.isdir]);

nFiles = numel(listing);
folder = strings(nFiles, 1);
name = strings(nFiles, 1);
stem = strings(nFiles, 1);
variant = strings(nFiles, 1);
roiLabel = strings(nFiles, 1);
kind = strings(nFiles, 1);
nameParsed = false(nFiles, 1);

for iFile = 1:nFiles
    folder(iFile) = string(listing(iFile).folder);
    name(iFile) = string(listing(iFile).name);

    info = parse_histology_filename(name(iFile), pattern = filenamePattern);

    stem(iFile) = info.stem;
    variant(iFile) = info.variant;
    roiLabel(iFile) = info.roi;
    nameParsed(iFile) = info.isValid;
    kind(iFile) = classify_kind(name(iFile));
end

F = table(folder, name, stem, variant, roiLabel, kind, nameParsed, ...
    VariableNames = ["Folder", "Name", "Stem", "Variant", "RoiLabel", "Kind", "NameParsed"]);

% Overlapping scan patterns (*.tif and *.tiff on a case-insensitive
% filesystem) would otherwise double-count renditions.
[~, uniqueIdx] = unique(fullfile(F.Folder, F.Name));
F = F(sort(uniqueIdx), :);

end

function kind = classify_kind(name)
%CLASSIFY_KIND Sort a discovered file into image, roi, or values.

[~, ~, ext] = fileparts(name);
ext = lower(string(ext));

if ext == ".roi"
    kind = "roi";
elseif ext == ".csv"
    kind = "values";
else
    kind = "image";
end

end

function rows = build_rows(F, stems, filenamePattern)
%BUILD_ROWS Collapse discovered files into one row per stem.

rows = empty_row_struct();
rows(:) = [];

if isempty(stems)
    return
end

rows = repmat(empty_row_struct(), numel(stems), 1);

for iStem = 1:numel(stems)
    thisStem = stems(iStem);
    Fs = F(F.Stem == thisStem, :);

    info = parse_histology_filename(thisStem, pattern = filenamePattern);

    rows(iStem).Stem = thisStem;
    rows(iStem).SubjectID = info.SubjectID;
    rows(iStem).SampleID = info.SampleID;
    rows(iStem).SectionID = info.SectionID;
    rows(iStem).Hemisphere = info.Hemisphere;
    rows(iStem).Stain = info.Stain;
    rows(iStem).ZPlane = info.ZPlane;
    rows(iStem).DateCode = info.DateCode;
    rows(iStem).ImageNumber = info.ImageNumber;
    rows(iStem).Protocol = info.Protocol;
    rows(iStem).Series = info.Series;
    rows(iStem).NameParsed = info.isValid;

    images = Fs(Fs.Kind == "image", :);

    rows(iStem).ProjPath = pick_preferred(images(images.Variant == "proj", :), thisStem);
    rows(iStem).MidPath = pick_preferred(images(images.Variant == "mid", :), thisStem);
    rows(iStem).CompositePath = pick_preferred(images(images.Variant == "composite", :), thisStem);
    rows(iStem).RawPath = pick_preferred(images(images.Variant == "raw", :), thisStem);

    variants = ["proj", "mid", "composite", "raw"];
    present = [rows(iStem).ProjPath, rows(iStem).MidPath, ...
        rows(iStem).CompositePath, rows(iStem).RawPath] ~= "";
    rows(iStem).Variants = join_or_empty(variants(present));
    rows(iStem).NVariants = sum(present);

    rows(iStem).RoiPath = pick_preferred(Fs(Fs.Kind == "roi", :), thisStem);

    values = Fs(Fs.Kind == "values", :);
    valuePaths = fullfile(values.Folder, values.Name);
    rows(iStem).ValuesPaths = {string(valuePaths(:))};
    rows(iStem).ROILabels = {string(values.RoiLabel(:))};
    rows(iStem).NProfiles = height(values);
    rows(iStem).ROI = join_or_empty(unique(values.RoiLabel(values.RoiLabel ~= "")));

    rows(iStem).Folder = resolve_folder(rows(iStem), Fs);
    rows(iStem).Status = resolve_status(rows(iStem));
end

end

function row = empty_row_struct()
%EMPTY_ROW_STRUCT Build one blank catalog row.

row = struct( ...
    "Stem", "", "SubjectID", "", "SampleID", "", "SectionID", "", ...
    "Hemisphere", "", "Stain", "", "ZPlane", "", "DateCode", "", ...
    "ImageNumber", "", "Protocol", "", "Series", "", "NameParsed", false, ...
    "ProjPath", "", "MidPath", "", "CompositePath", "", "RawPath", "", ...
    "Variants", "", "NVariants", 0, "RoiPath", "", ...
    "ValuesPaths", {strings(0, 1)}, "ROILabels", {strings(0, 1)}, ...
    "NProfiles", 0, "ROI", "", "Folder", "", "Status", "no image", ...
    "InTracker", false, "AtlasPlate", NaN, "Content", "", "Slide", "", ...
    "SliceID", "", "ImageDate", "", "LaserPower", "", "Notes", "", ...
    "ProcessingID", "");

end

function selected = pick_preferred(candidates, stem)
%PICK_PREFERRED Choose one file, favoring the copy inside the section folder.

selected = "";

if isempty(candidates) || height(candidates) == 0
    return
end

paths = string(fullfile(candidates.Folder, candidates.Name));

[~, parentName] = fileparts(candidates.Folder);
inSectionFolder = string(parentName) == stem;

if any(inSectionFolder)
    paths = paths(inSectionFolder);
end

selected = paths(1);

end

function folder = resolve_folder(row, Fs)
%RESOLVE_FOLDER Choose the canonical folder for a stem.

candidates = [row.ProjPath, row.RoiPath, row.MidPath, row.CompositePath, row.RawPath];
candidates = candidates(candidates ~= "");

if ~isempty(candidates)
    folder = string(fileparts(candidates(1)));
    return
end

if height(Fs) > 0
    folder = Fs.Folder(1);
    return
end

folder = "";

end

function status = resolve_status(row)
%RESOLVE_STATUS Summarize what is available for a stem.

if row.NVariants == 0
    status = "no image";
elseif ~row.NameParsed
    status = "unparsed name";
elseif row.NProfiles > 0
    status = "image + profile";
else
    status = "image only";
end

end

function s = join_or_empty(values)
%JOIN_OR_EMPTY Join string values with commas, tolerating an empty input.

values = string(values(:))';

if isempty(values)
    s = "";
    return
end

s = join(values, ", ");

end

function rows = attach_metadata(rows, metadataTable, imageFilenameColumn, includeMissing, filenamePattern)
%ATTACH_METADATA Join tracker rows onto the catalog by filename stem.

if isempty(metadataTable) || width(metadataTable) == 0
    return
end

varNames = string(metadataTable.Properties.VariableNames);

if ~ismember(imageFilenameColumn, varNames)
    return
end

trackerStems = normalize_stems(metadataTable.(char(imageFilenameColumn)), filenamePattern);
matched = false(numel(trackerStems), 1);

for iRow = 1:numel(rows)
    idx = find_tracker_row(trackerStems, rows(iRow).Stem);

    if isempty(idx)
        continue
    end

    matched(idx) = true;
    rows(iRow) = copy_tracker_fields(rows(iRow), metadataTable, idx(1));
end

if ~includeMissing || all(matched)
    return
end

% Blank tracker rows carry no filename, so they describe no section at all.
missingIdx = find(~matched & trackerStems ~= "");

if isempty(missingIdx)
    return
end

extraRows = repmat(empty_row_struct(), numel(missingIdx), 1);

for iMissing = 1:numel(missingIdx)
    idx = missingIdx(iMissing);
    thisStem = trackerStems(idx);

    info = parse_histology_filename(thisStem, pattern = filenamePattern);

    extraRows(iMissing).Stem = thisStem;
    extraRows(iMissing).SubjectID = info.SubjectID;
    extraRows(iMissing).SampleID = info.SampleID;
    extraRows(iMissing).SectionID = info.SectionID;
    extraRows(iMissing).Hemisphere = info.Hemisphere;
    extraRows(iMissing).Stain = info.Stain;
    extraRows(iMissing).ZPlane = info.ZPlane;
    extraRows(iMissing).DateCode = info.DateCode;
    extraRows(iMissing).ImageNumber = info.ImageNumber;
    extraRows(iMissing).Protocol = info.Protocol;
    extraRows(iMissing).Series = info.Series;
    extraRows(iMissing).NameParsed = info.isValid;
    extraRows(iMissing) = copy_tracker_fields(extraRows(iMissing), metadataTable, idx);
end

rows = [rows; extraRows];

end

function idx = find_tracker_row(trackerStems, stem)
%FIND_TRACKER_ROW Match a catalog stem to a tracker row.

if stem == ""
    idx = [];
    return
end

idx = find(trackerStems == stem);

if ~isempty(idx)
    return
end

% Tracker entries are sometimes a true prefix of the acquired image name.
isPrefix = trackerStems ~= "" & startsWith(stem, trackerStems + "_");
idx = find(isPrefix);

end

function row = copy_tracker_fields(row, metadataTable, idx)
%COPY_TRACKER_FIELDS Copy the known tracker columns onto a catalog row.

row.InTracker = true;

row.AtlasPlate = tracker_number(metadataTable, idx, "Atlas Plate #");
row.Content = tracker_text(metadataTable, idx, "Content");
row.Slide = tracker_text(metadataTable, idx, "Slide #");
row.SliceID = tracker_text(metadataTable, idx, "Slice ID");
row.ImageDate = tracker_text(metadataTable, idx, "Image Date");
row.LaserPower = tracker_text(metadataTable, idx, "Laser power");
row.Notes = tracker_text(metadataTable, idx, "Notes");
row.ProcessingID = tracker_text(metadataTable, idx, "Processing ID");

if row.Hemisphere == ""
    row.Hemisphere = tracker_text(metadataTable, idx, "Hemisphere");
end

end

function value = tracker_text(metadataTable, idx, columnName)
%TRACKER_TEXT Read one tracker cell as text, tolerating absent columns.

value = "";

if ~ismember(columnName, string(metadataTable.Properties.VariableNames))
    return
end

raw = metadataTable.(char(columnName))(idx);

if iscell(raw)
    raw = raw{1};
end

if isempty(raw)
    return
end

if isnumeric(raw)
    if isnan(raw(1))
        return
    end

    value = string(num2str(raw(1)));
    return
end

if ismissing(raw)
    return
end

value = strtrim(string(raw));

end

function value = tracker_number(metadataTable, idx, columnName)
%TRACKER_NUMBER Read one tracker cell as a number, tolerating absent columns.

value = NaN;

if ~ismember(columnName, string(metadataTable.Properties.VariableNames))
    return
end

raw = metadataTable.(char(columnName))(idx);

if iscell(raw)
    raw = raw{1};
end

if isempty(raw)
    return
end

if isnumeric(raw)
    value = double(raw(1));
    return
end

value = str2double(string(raw));

end

function stems = normalize_stems(names, filenamePattern)
%NORMALIZE_STEMS Reduce tracker filenames to comparable stems.

names = string(names(:));
stems = strings(size(names));

for iName = 1:numel(names)
    if ismissing(names(iName)) || strtrim(names(iName)) == ""
        continue
    end

    info = parse_histology_filename(strtrim(names(iName)), pattern = filenamePattern);
    stems(iName) = info.stem;
end

end
