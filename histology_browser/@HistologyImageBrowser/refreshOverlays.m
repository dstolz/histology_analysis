function refreshOverlays(obj)
%REFRESHOVERLAYS Redraw the overlay of every tile on screen, in place.
% Switching the sampling band, the line, the intensity shading, or the band
% grid changes only the graphics drawn over each image; the pictures, their
% contrast, and the axes around them are all unchanged. Rebuilding the tiled
% layout for that would reread every image and restretch every pixel, so this
% replaces just the tagged overlay objects and leaves everything else standing.
%
% REFRESHROIOVERLAY already did this for the one tile being dragged, which is
% the same idea applied to one axes. Generalizing it here rather than calling
% it once per tile keeps the ROI editor out of the loop: it lives on at most
% one tile, and the other tiles must not be searched for a handle they cannot
% have.
%
% A layout that hides the image tiles has nothing to redraw, and neither has an
% empty selection; both leave the profile plot alone, because none of the four
% overlay options is drawn on it.
%
% See also REFRESHTILEOVERLAY, ONDISPLAYOPTIONCHANGED, DRAWROIOVERLAY.

if ~obj.showImages()
    return
end

if isempty(obj.ImageLayout) || ~isvalid(obj.ImageLayout)
    return
end

tiles = findobj(obj.ImageLayout, Type = "axes");

for iTile = 1:numel(tiles)
    obj.refreshTileOverlay(tiles(iTile));
end

end
