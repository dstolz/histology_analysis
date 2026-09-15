function info = sheetInfo(credentialsPath, spreadsheetId, sheetName)
%SHEETINFO Look up one tab's identifier and grid size.
% Two things here cannot be learned from the cell values alone. Growing a tab
% needs its numeric sheetId, which is what SPREADSHEETS.BATCHUPDATE addresses
% rather than the tab name. And knowing the column count is what tells us
% whether a new column can be written at all: a tab trimmed to exactly the
% columns it uses, which is a normal thing to do, refuses a write one column
% past its right edge instead of growing to meet it.
%
% Parameters
%   credentialsPath: Path to the service account JSON key file.
%   spreadsheetId: Spreadsheet ID, not a full URL.
%   sheetName: Tab name to look up.
%
% Returns
%   info: Struct with fields sheetId, title, rowCount, columnCount.
%
% See also GSHEET.APPENDCOLUMNS.

arguments
    credentialsPath (1,1) string
    spreadsheetId (1,1) string
    sheetName (1,1) string
end

token = gsheet.accessToken(credentialsPath);

url = "https://sheets.googleapis.com/v4/spreadsheets/" + spreadsheetId ...
    + "?fields=" + gsheet.encodeSegment("sheets(properties(sheetId,title,gridProperties))");

payload = gsheet.request("GET", url, token = token);

if ~isfield(payload, "sheets") || isempty(payload.sheets)
    error("gsheet:NoSheets", ...
        "Spreadsheet %s reports no tabs. Check that the ID is correct.", spreadsheetId)
end

sheets = payload.sheets;

if ~iscell(sheets)
    sheets = num2cell(sheets);
end

titles = strings(numel(sheets), 1);

for iSheet = 1:numel(sheets)
    properties = sheets{iSheet}.properties;
    titles(iSheet) = string(properties.title);

    if titles(iSheet) ~= sheetName
        continue
    end

    info = struct( ...
        sheetId = double(properties.sheetId), ...
        title = titles(iSheet), ...
        rowCount = NaN, ...
        columnCount = NaN);

    if isfield(properties, "gridProperties")
        grid = properties.gridProperties;

        if isfield(grid, "rowCount")
            info.rowCount = double(grid.rowCount);
        end

        if isfield(grid, "columnCount")
            info.columnCount = double(grid.columnCount);
        end
    end

    return
end

error("gsheet:NoSuchSheet", ...
    "The spreadsheet has no tab named '%s'. It has: %s.", ...
    sheetName, strjoin(titles, ", "))

end
