function grid = getValues(credentialsPath, spreadsheetId, range)
%GETVALUES Read a rectangle of cells as text.
% Cells come back formatted, that is, exactly as they read on screen, so the
% table this builds matches what someone editing the tracker sees. Numbers stay
% text here and are converted where they are used, which is what the CSV path
% did too.
%
% Parameters
%   credentialsPath: Path to the service account JSON key file.
%   spreadsheetId: Spreadsheet ID, not a full URL.
%   range: A1 notation, e.g. "Sections" for a whole tab or "Sections!A1:C9".
%
% Returns
%   grid: Struct with fields
%      - values: Padded string array of cell contents, rows by columns.
%      - firstRow: Sheet row number of values(1,:).
%      - firstColumn: Sheet column number of values(:,1).
%      - range: The range Google reported.
%
% See also GSHEET.UPDATEVALUES, GSHEET.VALUEGRID, GSHEET.RANGEORIGIN.

arguments
    credentialsPath (1,1) string
    spreadsheetId (1,1) string
    range (1,1) string
end

token = gsheet.accessToken(credentialsPath);

url = "https://sheets.googleapis.com/v4/spreadsheets/" + spreadsheetId ...
    + "/values/" + gsheet.encodeSegment(range) ...
    + "?majorDimension=ROWS&valueRenderOption=FORMATTED_VALUE";

payload = gsheet.request("GET", url, token = token);

grid = struct();
grid.range = "";

if isfield(payload, "range")
    grid.range = string(payload.range);
end

[grid.firstRow, grid.firstColumn] = gsheet.rangeOrigin(grid.range);

if isfield(payload, "values")
    grid.values = gsheet.valueGrid(payload.values);
else
    grid.values = strings(0, 0);
end

end
