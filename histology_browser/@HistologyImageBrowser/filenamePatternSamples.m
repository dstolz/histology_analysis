function [names, source] = filenamePatternSamples(obj)
%FILENAMEPATTERNSAMPLES Filenames the pattern preview is exercised against.
% A pattern is only worth anything against the names it will actually meet, so
% the preview runs on the loaded dataset. The names are recovered from the
% catalog's path columns rather than from its Stem column, because a stem has
% already had its variant markers taken off and previewing against stems would
% hide the one step that most often explains why a pattern does not match.
%
% With nothing loaded the preview falls back to worked examples instead of an
% empty table: an empty table looks like a pattern that matches nothing, which
% is the opposite of what it means. The examples deliberately include names in
% other conventions, so the fallback demonstrates the problem the pattern
% exists to solve rather than only the convention that already works.
%
% Returns
%   names: Filenames to preview against.
%   source: "dataset" or "examples", so a caller can say which it is showing.
%
% See also FILENAMEPATTERNPREVIEW, ONEDITFILENAMEPATTERN.

source = "examples";

names = [ ...
    "SUBJ-ID-1174IHC_ECM26A260608S1_1A_L_WFA-PV_Z3_260616_1.czi"; ...
    "SUBJ-ID-1174IHC_ECM26A260608S1_1A_L_WFA-PV_Z3_260616_1_proj.tif"; ...
    "SUBJ-ID-1174IHC_ECM26A260608S1_1A_L_WFA-PV_Z3_260616_1_proj_ACxvalues.csv"; ...
    "SUBJ-ID-2087IHC_ECM31C260702S2_3A_R_NeuN-DAPI_Z2_260714_2_composite.png"; ...
    "M12_slide3_CTX_DAPI_proj.tif"; ...
    "260616-M12-left-NeuN.tif"];

if isempty(obj.Catalog) || height(obj.Catalog) == 0
    return
end

source = "dataset";

C = obj.Catalog;

% The table is rebuilt on every keystroke, so a root folder holding thousands
% of sections would make the editor stutter. The head of the catalog is enough
% to see a pattern working, and the count is reported beside the table.
nRows = min(height(C), HistologyImageBrowser.MaxPatternPreviewNames);

names = strings(nRows, 1);

columns = ["ProjPath", "RawPath", "MidPath", "CompositePath", "RoiPath"];

for iRow = 1:nRows
    names(iRow) = row_name(C(iRow, :), columns);
end

end

function name = row_name(row, columns)
%ROW_NAME Recover the filename a catalog row was built from.
% Falls back to the stem when the row came from the tracker rather than from a
% file on disk, so an audit row still previews instead of leaving a blank.

for iColumn = 1:numel(columns)
    if ~ismember(columns(iColumn), string(row.Properties.VariableNames))
        continue
    end

    value = string(row.(columns(iColumn)));

    if value == ""
        continue
    end

    [~, base, ext] = fileparts(value);
    name = base + ext;

    return
end

name = string(row.Stem);

end
