function nUpdated = updateValues(credentialsPath, spreadsheetId, updates)
%UPDATEVALUES Write several disjoint rectangles of cells in one request.
% Batching matters for more than speed. A tracker row gets its data columns and
% its timestamp in the same call, so the sheet never shows a value that has
% been changed without the stamp that says when, and a row cannot be left half
% written by a connection that drops between two requests.
%
% Values are sent RAW: Google stores exactly the text given, without guessing
% at dates or numbers. A row identifier must survive the round trip character
% for character, and a timestamp written as an ISO string should not be
% reinterpreted according to whatever locale the spreadsheet happens to carry.
%
% Parameters
%   credentialsPath: Path to the service account JSON key file.
%   spreadsheetId: Spreadsheet ID, not a full URL.
%   updates: Struct array with fields
%      - range: A1 notation for one rectangle, sheet name included.
%      - values: String array of the text to write into it.
%
% Returns
%   nUpdated: Number of cells Google reported as written.
%
% See also GSHEET.GETVALUES, GSHEET.A1RANGE.

arguments
    credentialsPath (1,1) string
    spreadsheetId (1,1) string
    updates struct
end

if isempty(updates)
    nUpdated = 0;
    return
end

token = gsheet.accessToken(credentialsPath);

data = cell(numel(updates), 1);

for iUpdate = 1:numel(updates)
    data{iUpdate} = struct( ...
        range = string(updates(iUpdate).range), ...
        majorDimension = "ROWS", ...
        values = to_json_rows(updates(iUpdate).values));
end

body = struct(valueInputOption = "RAW", data = {data});

url = "https://sheets.googleapis.com/v4/spreadsheets/" + spreadsheetId ...
    + "/values:batchUpdate";

payload = gsheet.request("POST", url, token = token, body = string(jsonencode(body)));

nUpdated = 0;

if isfield(payload, "totalUpdatedCells")
    nUpdated = double(payload.totalUpdatedCells);
end

end

function rows = to_json_rows(values)
%TO_JSON_ROWS Shape a string block so JSONENCODE writes it as an array of rows.
% A cell of cells is used rather than a string matrix because JSONENCODE
% flattens a 1-by-N string array into a bare array of strings, which the API
% reads as one row of a different rectangle than the one intended.

values = string(values);

if isempty(values)
    rows = {{}};
    return
end

rows = cell(size(values, 1), 1);

for iRow = 1:size(values, 1)
    row = values(iRow, :);
    row(ismissing(row)) = "";

    rows{iRow} = num2cell(row);
end

end
