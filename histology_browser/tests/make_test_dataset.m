function [rootPath, metadataCSV] = make_test_dataset(targetFolder)
% make_test_dataset
%   rootPath = make_test_dataset(targetFolder)
%   [rootPath, metadataCSV] = make_test_dataset(targetFolder)
%
% Write a small synthetic histology dataset -- images, Fiji line ROIs, the
% *values.csv profiles measured through them, and a section tracker -- so the
% catalog, the combiner, and the browser can be exercised on a machine that has
% no real dataset mounted.
%
% What comes out is a miniature of what the Fiji batch line-measure workflow
% leaves on disk: two subjects, both hemispheres, two stains across a range of
% atlas plates, multi-page projections with their sidecars beside them, and one
% section written both inside its own folder and next to it. Three sections are
% deliberately incomplete -- one never measured, one neither measured nor
% assigned a plate, one missing from the tracker altogether -- because an
% unfinished section is the ordinary case the browser has to label rather than
% hide.
%
% Raw .czi renditions are left out. Only Bio-Formats can open one, so a stand-in
% file would leave the raw variant unreadable rather than tested.
%
% Everything is deterministic: the random stream is seeded and put back, so the
% same dataset comes out of every run and a failure is reproducible from the
% test alone.
%
% Parameters
%   targetFolder: Folder to write the dataset into. Created when it does not
%       exist, and defaults to a fresh folder under the system temp directory.
%
% Returns
%   rootPath: The dataset root, ready for BUILD_HISTOLOGY_IMAGE_CATALOG,
%       COMBINE_VALUES_CSV, or HISTOLOGYIMAGEBROWSER.
%   metadataCSV: The section tracker written at the root, for their
%       metadataCSV option.
%
% See also TEST_HISTOLOGY_BROWSER, BUILD_HISTOLOGY_IMAGE_CATALOG,
% COMBINE_VALUES_CSV, WRITE_IMAGEJ_ROI, WRITE_VALUES_CSV.

arguments
    targetFolder (1,1) string = string(tempname)
end

% The writers this fixture is built out of live in the repo root, one level up,
% so a caller can generate a dataset without having set the path up first.
addpath(fileparts(fileparts(mfilename("fullpath"))));

rootPath = string(targetFolder);

if ~isfolder(rootPath)
    mkdir(rootPath);
end

% Seeded so the fixture is reproducible, and put back so generating one does
% not shift the stream of whatever asked for it.
entryState = rng(20260831, "twister");
restoreRng = onCleanup(@() rng(entryState));

specs = section_specs();

for iSpec = 1:numel(specs)
    write_section(rootPath, specs(iSpec));
end

metadataCSV = write_tracker(rootPath, specs);

end

function specs = section_specs()
%SECTION_SPECS Describe every section the fixture writes.
% One list, so what the fixture covers can be read in one place: two subjects,
% both hemispheres, two stains, plates 28 through 46, both spellings of the
% macro's values suffix, and the three shapes of incomplete section the browser
% has to cope with -- plated but unmeasured, neither plated nor measured, and
% absent from the tracker altogether.

specs = [ ...
    make_spec("SUBJ-ID-1174", "IHC_ECM26A260608S1", "1A", "L", "WFA-PV", "Z3", "260616", "1", ...
        plate = 28, angle = -62, valuesSuffix = "_ACxvalues", ...
        mid = true, composite = true, duplicateProj = true), ...
    make_spec("SUBJ-ID-1174", "IHC_ECM26A260608S1", "1A", "R", "WFA-PV", "Z3", "260616", "2", ...
        plate = 28, angle = -118, valuesSuffix = "_ACx_values"), ...
    make_spec("SUBJ-ID-1174", "IHC_ECM26A260608S1", "2B", "L", "NeuN-DAPI", "Z2", "260616", "3", ...
        plate = 34, angle = -48, composite = true), ...
    make_spec("SUBJ-ID-1174", "IHC_ECM26A260608S1", "2B", "R", "NeuN-DAPI", "Z2", "260616", "4", ...
        plate = 34, hasProfile = false, sectionFolder = false, ...
        notes = "line not drawn yet"), ...
    make_spec("SUBJ-ID-2087", "IHC_ECM31C260702S2", "3A", "L", "WFA-PV", "Z3", "260714", "1", ...
        plate = 40, angle = -70, mid = true), ...
    make_spec("SUBJ-ID-2087", "IHC_ECM31C260702S2", "3A", "R", "WFA-PV", "Z4", "260714", "2", ...
        plate = 40, angle = -110, valuesSuffix = "_ACxvalues"), ...
    make_spec("SUBJ-ID-2087", "IHC_ECM31C260702S2", "4C", "L", "NeuN-DAPI", "Z2", "260714", "3", ...
        plate = 46, angle = -132), ...
    make_spec("SUBJ-ID-2087", "IHC_ECM31C260702S2", "4C", "R", "NeuN-DAPI", "Z2", "260714", "4", ...
        hasProfile = false, nChannels = 1, sectionFolder = false, ...
        notes = "plate not scored"), ...
    make_spec("SUBJ-ID-2087", "IHC_ECM31C260702S2", "5A", "L", "WFA-PV", "Z3", "260714", "5", ...
        hasProfile = false, nChannels = 1, sectionFolder = false, inTracker = false)];

end

function spec = make_spec(subject, sample, sectionID, hemisphere, stain, zPlane, dateCode, imageNumber, options)
%MAKE_SPEC Describe one section, defaulting to what most sections look like.
% The fields are assigned in a fixed order rather than copied out of OPTIONS,
% because struct arrays only concatenate when every element names its fields in
% the same order.

arguments
    subject (1,1) string
    sample (1,1) string
    sectionID (1,1) string
    hemisphere (1,1) string
    stain (1,1) string
    zPlane (1,1) string
    dateCode (1,1) string
    imageNumber (1,1) string
    options.plate (1,1) double = NaN
    options.nChannels (1,1) double = 2
    options.hasProfile (1,1) logical = true
    options.valuesSuffix (1,1) string = "_values"
    options.angle (1,1) double = -60
    options.mid (1,1) logical = false
    options.composite (1,1) logical = false
    options.sectionFolder (1,1) logical = true
    options.duplicateProj (1,1) logical = false
    options.inTracker (1,1) logical = true
    options.notes (1,1) string = ""
end

spec = struct( ...
    "subject", subject, ...
    "sample", sample, ...
    "sectionID", sectionID, ...
    "hemisphere", hemisphere, ...
    "stain", stain, ...
    "zPlane", zPlane, ...
    "dateCode", dateCode, ...
    "imageNumber", imageNumber, ...
    "plate", options.plate, ...
    "nChannels", options.nChannels, ...
    "hasProfile", options.hasProfile, ...
    "valuesSuffix", options.valuesSuffix, ...
    "angle", options.angle, ...
    "mid", options.mid, ...
    "composite", options.composite, ...
    "sectionFolder", options.sectionFolder, ...
    "duplicateProj", options.duplicateProj, ...
    "inTracker", options.inTracker, ...
    "notes", options.notes);

end

function stem = section_stem(spec)
%SECTION_STEM Build the filename stem PARSE_HISTOLOGY_FILENAME expects.
% The subject and the sample run together with no separator, which is what
% makes the parser read the name from the right.

stem = spec.subject + spec.sample + "_" + spec.sectionID + "_" + spec.hemisphere ...
    + "_" + spec.stain + "_" + spec.zPlane + "_" + spec.dateCode + "_" + spec.imageNumber;

end

function write_section(rootPath, spec)
%WRITE_SECTION Write every file one section contributes to the dataset.

stem = section_stem(spec);
subjectFolder = fullfile(rootPath, spec.subject);
folder = subjectFolder;

if spec.sectionFolder
    folder = fullfile(subjectFolder, stem);
end

if ~isfolder(folder)
    mkdir(folder);
end

D = image_geometry();

pages = cell(spec.nChannels, 1);

for iPage = 1:spec.nChannels
    pages{iPage} = synthesize_channel(D.nRows, D.nCols, iPage);
end

write_stack(fullfile(folder, stem + "_proj.tif"), pages);

% Renditions are commonly exported beside the section folder as well as into
% it, and the catalog is meant to prefer the copy sitting with the sidecars,
% so one section is written both ways.
if spec.sectionFolder && spec.duplicateProj
    write_stack(fullfile(subjectFolder, stem + "_proj.tif"), pages);
end

if spec.mid
    % The mid-plane export is a single focal plane rather than a maximum
    % projection, so it is the dimmer of the two renditions.
    write_stack(fullfile(folder, stem + "_mid.tif"), {uint16(0.7 * double(pages{1}))});
end

if spec.composite
    imwrite(composite_rgb(pages), fullfile(folder, stem + "_composite.png"));
end

if ~spec.hasProfile
    return
end

geometry = roi_geometry(D, spec.angle);

write_imagej_roi(string(fullfile(folder, stem + "_proj_roi.roi")), geometry, ...
    name = stem + "_proj_roi");

% The profile is measured through the line that was just written, from the
% projection it is stored beside, so the CSV holds what the pipeline would have
% written for that ROI rather than an invented curve.
P = measure_line_profile(pages{1}, geometry, pixelSize = D.pixelSize);

write_values_csv(string(fullfile(folder, stem + "_proj" + spec.valuesSuffix + ".csv")), ...
    P.distance, P.intensity);

end

function D = image_geometry()
%IMAGE_GEOMETRY Size and calibration every fixture image is written at.
% The macro's sampling band is specified in microns, so the pixel size is the
% one that keeps its 994 um band a legible 24 px on a grid this small. At 41
% um/px these 128x96 images stand for a section about 5.3 x 4.0 mm across,
% which is the scale they are pretending to be.

bandMicrons = 994;
bandPixels = 24;

D = struct( ...
    "nRows", 96, ...
    "nCols", 128, ...
    "bandPixels", bandPixels, ...
    "pixelSize", bandMicrons / bandPixels, ...
    "radiusX", 0.92, ...
    "radiusY", 0.78, ...
    "centerY", -0.12);

end

function img = synthesize_channel(nRows, nCols, iChannel)
%SYNTHESIZE_CHANNEL Build one channel of a synthetic coronal section.
% A flat field would reduce every line profile to a constant and hide any error
% in how the band is sampled, so the picture carries the structure the profiles
% are supposed to show: an elliptical section with a labelled ribbon just
% inside its edge, each channel peaking at a different depth the way two
% markers in one section do.

D = image_geometry();

[u, v] = meshgrid(linspace(-1, 1, nCols), linspace(-1, 1, nRows));

radius = hypot(u / D.radiusX, (v - D.centerY) / D.radiusY);

% A soft edge rather than a cut-out, so the display percentiles have a real
% background to stretch against.
tissue = 1 ./ (1 + exp((radius - 1) * 18));

depth = 1 - radius;
ribbon = exp(-((depth - (0.08 + 0.07 * (iChannel - 1))) / 0.06) .^ 2);

img = tissue .* (0.10 + 0.72 * ribbon + 0.30 * scattered_cells(u, v, 20)) + 0.015;
img = min(max(img, 0), 1);

% Twelve bits, which is what the cameras these projections come off deliver,
% and which still compresses down to a fixture worth checking in.
img = uint16(round(img * 4095) * 16);

end

function cells = scattered_cells(u, v, nCells)
%SCATTERED_CELLS Scatter labelled cell bodies through the ribbon.
% They sit in the band the line crosses, which is what gives the measured
% profile the bumpy shoulder a real one has instead of a clean Gaussian.

D = image_geometry();

cells = zeros(size(u));

for iCell = 1:nCells
    angle = 2 * pi * rand;
    radius = 0.80 + 0.18 * rand;

    centerU = D.radiusX * radius * cos(angle);
    centerV = D.centerY + D.radiusY * radius * sin(angle);
    width = 0.02 + 0.02 * rand;

    cells = cells + (0.5 + 0.5 * rand) ...
        * exp(-((u - centerU) .^ 2 + (v - centerV) .^ 2) / width ^ 2);
end

end

function write_stack(imagePath, pages)
%WRITE_STACK Write one or more pages as an ImageJ style calibrated TIFF.
% The unit in the description and the resolution tag are what
% IMAGEJ_PIXEL_SIZE reads, so a fixture image reports the micron calibration a
% Fiji export would and the profiles measured from it come out in microns.

D = image_geometry();

description = sprintf("ImageJ=1.54f\nimages=%d\nchannels=%d\nslices=1\nunit=um\n", ...
    numel(pages), numel(pages));

for iPage = 1:numel(pages)
    if iPage == 1
        mode = "overwrite";
    else
        mode = "append";
    end

    imwrite(pages{iPage}, imagePath, "tif", ...
        WriteMode = mode, ...
        Description = description, ...
        Resolution = 1 / D.pixelSize, ...
        Compression = "deflate");
end

end

function rgb = composite_rgb(pages)
%COMPOSITE_RGB Flatten the channels the way a Fiji composite export does.
% Green and magenta, the pairing the browser's own merge uses, so the composite
% and the merged view of the same section read alike.

colors = [0 1 0; 1 0 1; 0 1 1];

rgb = zeros([size(pages{1}), 3]);

for iPage = 1:min(numel(pages), size(colors, 1))
    rgb = rgb + reshape(colors(iPage, :), 1, 1, 3) .* rescale(double(pages{iPage}));
end

rgb = uint8(255 * min(rgb, 1));

end

function geometry = roi_geometry(D, angleDeg)
%ROI_GEOMETRY Place a line across the ribbon, where a user would draw one.
% It runs outward from the middle of the section so it crosses every layer,
% which is what makes the measured profile a cortical depth profile rather than
% a walk through background.

[x1, y1] = section_point(D, 0.15, angleDeg);
[x2, y2] = section_point(D, 1.05, angleDeg);

geometry = struct( ...
    "x1", round(x1), "y1", round(y1), ...
    "x2", round(x2), "y2", round(y2), ...
    "strokeWidth", D.bandPixels);

end

function [col, row] = section_point(D, radius, angleDeg)
%SECTION_POINT Map a polar point on the section ellipse to image pixels.
% Radius 1 is the edge of the tissue, so a line drawn between two radii lands
% on the same anatomy in every section however the ellipse is sized.

u = D.radiusX * radius * cosd(angleDeg);
v = D.centerY + D.radiusY * radius * sind(angleDeg);

col = 1 + (u + 1) / 2 * (D.nCols - 1);
row = 1 + (v + 1) / 2 * (D.nRows - 1);

end

function metadataCSV = write_tracker(rootPath, specs)
%WRITE_TRACKER Write the section tracker the catalog is joined against.
% Real trackers are sheet exports: a title row above the header, columns named
% for people rather than for code, and blanks where a section has not been
% scored yet. All three are reproduced, because COMBINE_VALUES_CSV searches for
% the header row rather than assuming it is the first one.

metadataCSV = string(fullfile(rootPath, "Trackers - Sections.csv"));

fid = fopen(metadataCSV, "w");

if fid < 0
    error("make_test_dataset:CannotOpen", "Could not open %s for writing.", metadataCSV);
end

cleanupFid = onCleanup(@() fclose(fid));

fprintf(fid, "Synthetic section tracker,,,,,,,,,\n");
fprintf(fid, "Slide #,Slice ID,Content,Hemisphere,Atlas Plate #,Image Filename,");
fprintf(fid, "Image Date,Laser power,Processing ID,Notes\n");

for iSpec = 1:numel(specs)
    spec = specs(iSpec);

    if ~spec.inTracker
        continue
    end

    fprintf(fid, "%d,%s,%s,%s,%s,%s,%s,%s,%s,%s\n", ...
        iSpec, ...
        extractAfter(spec.subject, "SUBJ-ID-") + "-" + spec.sectionID, ...
        "auditory cortex", ...
        spec.hemisphere, ...
        plate_text(spec.plate), ...
        section_stem(spec) + "_proj.tif", ...
        image_date(spec.dateCode), ...
        sprintf("%.1f", 3 + 0.4 * iSpec), ...
        "PROC-" + spec.dateCode + "-" + spec.imageNumber, ...
        spec.notes);
end

end

function text = plate_text(plate)
%PLATE_TEXT Write an atlas plate, leaving the cell blank when it has none.
% A blank is what an unscored section looks like in the sheet, and it is what
% the browser has to turn into "no atlas plate" rather than into a zero.

text = "";

if isfinite(plate)
    text = string(plate);
end

end

function text = image_date(dateCode)
%IMAGE_DATE Expand the YYMMDD code carried by the filename into a full date.

text = "20" + extractBetween(dateCode, 1, 2) + "-" ...
    + extractBetween(dateCode, 3, 4) + "-" + extractBetween(dateCode, 5, 6);

end
