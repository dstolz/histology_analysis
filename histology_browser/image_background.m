function level = image_background(img, options)
% image_background
%   level = image_background(img)
%   level = image_background(img, Fraction = 0.02, BlockSize = 16)
%
% The intensity of the empty slide around a section, read off the darkest part
% of the image, so DETECT_BRAIN_SURFACE has a background to measure a line
% profile against that does not come from the profile itself.
%
% A profile's own darkest samples are background only if the line happens to
% start off the section. One drawn entirely inside tissue has dim stretches too
% -- layer 1, white matter, a ventricle -- and nothing in the trace alone says
% they are not slide. The image does: whatever the stain and exposure, the
% darkest part of the page is the slide the section is lying on.
%
% Darkest regions rather than darkest pixels. The image is cut into square
% blocks and the blocks averaged, and the level is the median of the darkest
% few percent of them. The lowest pixels of a noisy background are its low
% tail, a couple of sigmas under its mean, and a profile averaged across a
% wide band sits at the mean. Averaging a block first takes the noise out
% before the darkest are picked, so the level lands where the band will. On
% a background-subtracted projection the slide is zero and so is this.
%
% Parameters
%   img: Pixel data, as MEASURE_LINE_PROFILE is given it. Colour planes are
%       averaged, as they are there.
%   options.Fraction: Share of the blocks, darkest first, the level is taken
%       from. Small enough that a section filling most of the frame still
%       leaves that much slide showing.
%   options.BlockSize: Side of the square blocks, in pixels.
%
% Returns
%   level: Background intensity, in the image's own units. NaN for an image
%       with no finite pixels.
%
% See also DETECT_BRAIN_SURFACE, MEASURE_LINE_PROFILE.

arguments
    img {mustBeNumericOrLogical}
    options.Fraction (1,1) double {mustBeInRange(options.Fraction, 0, 1, "exclude-lower")} = 0.02
    options.BlockSize (1,1) double {mustBeInteger, mustBePositive} = 16
end

img = double(img);

if ndims(img) == 3
    img = mean(img, 3);
end

blocks = block_means(img, options.BlockSize);
blocks = sort(blocks(isfinite(blocks)));

if isempty(blocks)
    level = NaN;
    return
end

nDarkest = max(1, ceil(options.Fraction * numel(blocks)));
level = median(blocks(1:nDarkest));

end

function means = block_means(img, blockSize)
%BLOCK_MEANS Average the image over square tiles, dropping the ragged edge.
% An image smaller than one block is averaged pixel by pixel instead, which is
% the same thing at a block size of one.

[nRows, nCols] = size(img);

if nRows < blockSize || nCols < blockSize
    blockSize = 1;
end

nBlockRows = floor(nRows / blockSize);
nBlockCols = floor(nCols / blockSize);

img = img(1:nBlockRows * blockSize, 1:nBlockCols * blockSize);

tiles = reshape(img, blockSize, nBlockRows, blockSize, nBlockCols);
means = mean(tiles, [1, 3], "omitnan");
means = means(:);

end
