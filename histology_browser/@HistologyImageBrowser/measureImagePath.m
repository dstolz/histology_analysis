function imagePath = measureImagePath(obj, row)
%MEASUREIMAGEPATH Resolve the image a profile is measured from.
% Profiles always come from the projection, the rendition the Fiji line-measure
% macro profiled, whatever rendition is on screen. Anything else the section
% has is only a fallback, so a section without a projection is still workable.

imagePath = string(row.ProjPath);

if imagePath ~= "" && isfile(imagePath)
    return
end

imagePath = obj.resolveImagePath(row);

if imagePath == "" || ~isfile(imagePath)
    imagePath = "";
end

end
