function markRoiTarget(obj)
%MARKROITARGET Move the ROI target mark to the tile it now belongs on.
% Which section Edit ROI and Draw Line will act on is a thing the pictures do
% not say, and finding out by pressing the button and watching a line land on
% the wrong section is a poor way to be told. DRAWIMAGETILE marks it as each
% tile is drawn; this puts the mark somewhere else afterwards, when the target
% moves without a single pixel of any image changing -- a click on another
% tile, a right-click on one, an edit opening or ending.
%
% Cheap on purpose. It restyles a frame and a label per tile and reads nothing
% off disk, which is the same reason REFRESHTILEOVERLAY exists beside
% RENDERSELECTION: with a dozen sections on screen, rebuilding the layout to
% move one mark would reread and restretch a dozen images.
%
% The mark is only ever put on when more than one tile is drawn. On a single
% tile it would be on the only thing it could be on, which tells the reader
% nothing and costs the picture a strip of its top edge.
%
% See also MARKTILE, ACTIVEROISTEM, SETROITARGET, DRAWIMAGETILE.

if isempty(obj.ImageLayout) || ~isvalid(obj.ImageLayout)
    return
end

tiles = findobj(obj.ImageLayout, Type = "axes");

if numel(tiles) < 2
    % One tile, or none. A lone tile is still swept, because it may have been
    % drawn as the marked one and had the rest of the selection taken away
    % from beside it.
    for iTile = 1:numel(tiles)
        HistologyImageBrowser.markTile(tiles(iTile), false);
    end

    return
end

target = obj.activeRoiStem();

for iTile = 1:numel(tiles)
    ax = tiles(iTile);
    HistologyImageBrowser.markTile(ax, HistologyImageBrowser.tileStem(ax) == target);
end

end
