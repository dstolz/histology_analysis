function summary = missingMetadata(row)
%MISSINGMETADATA Name the annotations one catalog row is lacking.
% Missing atlas plate or profile data never hides an image, so the browser
% labels what is absent instead. Returns "" when nothing is missing.

parts = strings(0, 1);

if isnan(row.AtlasPlate)
    parts(end + 1) = "no atlas plate";
end

if row.NProfiles == 0
    parts(end + 1) = "no profile";
end

if isempty(parts)
    summary = "";
    return
end

summary = join(parts, ", ");

end
