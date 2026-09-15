function appendColumns(credentialsPath, spreadsheetId, sheetId, nColumns)
%APPENDCOLUMNS Widen a tab so cells can be written past its current edge.
% Called only when SHEETINFO says the tab is too narrow for the columns about
% to be written. Widening is additive and affects no existing cell, but it is
% still a change to the shared document, so it is never done speculatively.
%
% Parameters
%   credentialsPath: Path to the service account JSON key file.
%   spreadsheetId: Spreadsheet ID, not a full URL.
%   sheetId: Numeric tab identifier from GSHEET.SHEETINFO.
%   nColumns: How many columns to add on the right.
%
% See also GSHEET.SHEETINFO.

arguments
    credentialsPath (1,1) string
    spreadsheetId (1,1) string
    sheetId (1,1) double
    nColumns (1,1) double {mustBeInteger, mustBePositive}
end

token = gsheet.accessToken(credentialsPath);

body = struct(requests = {{struct(appendDimension = struct( ...
    sheetId = sheetId, ...
    dimension = "COLUMNS", ...
    length = nColumns))}});

url = "https://sheets.googleapis.com/v4/spreadsheets/" + spreadsheetId + ":batchUpdate";

gsheet.request("POST", url, token = token, body = string(jsonencode(body)));

end
