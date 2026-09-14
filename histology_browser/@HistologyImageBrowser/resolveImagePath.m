function imagePath = resolveImagePath(obj, row)
%RESOLVEIMAGEPATH Resolve the path for the requested rendition of one section.
% Falls back to any other rendition that exists so a section is still viewable
% when the preferred one was never generated.

variant = string(obj.VariantDropDown.Value);

% Raw .czi files need Bio-Formats, so they are only ever used when asked for
% explicitly rather than as a silent fallback.
order = [variant, "proj", "mid", "composite"];
imagePath = "";

for iVariant = 1:numel(order)
    candidate = variant_path(row, order(iVariant));

    if candidate ~= "" && isfile(candidate)
        imagePath = candidate;
        return
    end
end

end

function p = variant_path(row, variant)
%VARIANT_PATH Read one rendition path from a catalog row.

switch variant
    case "proj"
        p = row.ProjPath;
    case "mid"
        p = row.MidPath;
    case "composite"
        p = row.CompositePath;
    case "raw"
        p = row.RawPath;
    otherwise
        p = "";
end

p = string(p);

if numel(p) ~= 1
    p = "";
end

end
