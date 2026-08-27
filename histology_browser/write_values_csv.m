function info = write_values_csv(csvPath, distance, intensity)
% write_values_csv
%   info = write_values_csv(csvPath, distance, intensity)
%
% Write a line profile in the same layout MACRO_Batch_LineMeasure saves, so a
% profile remeasured in MATLAB drops straight into the existing analysis
% pipeline: a distance_pixel_index,intensity header followed by one row per
% sample.
%
% Distances are written with four decimals, as Fiji writes them. Intensities
% keep seven significant digits, which covers both the near-zero background
% and the bright end of a 32-bit projection without padding out the file.
%
% Parameters
%   csvPath: Destination CSV path.
%   distance: Distance of each sample from the start of the line.
%   intensity: Mean intensity at each sample.
%
% Returns
%   info: Struct with fields csvPath and nSamples.
%
% See also MEASURE_LINE_PROFILE, COMBINE_VALUES_CSV.

arguments
    csvPath (1,1) string
    distance (:,1) double
    intensity (:,1) double
end

if numel(distance) ~= numel(intensity)
    error("write_values_csv:LengthMismatch", ...
        "distance has %d samples but intensity has %d.", numel(distance), numel(intensity));
end

folder = fileparts(csvPath);

if folder ~= "" && ~isfolder(folder)
    mkdir(folder);
end

fid = fopen(csvPath, "w");

if fid < 0
    error("write_values_csv:CannotOpen", "Could not open %s for writing.", csvPath);
end

cleanupFid = onCleanup(@() fclose(fid));

fprintf(fid, "distance_pixel_index,intensity\n");
fprintf(fid, "%.4f,%.7g\n", [distance, intensity]');

info = struct("csvPath", csvPath, "nSamples", numel(distance));

end
