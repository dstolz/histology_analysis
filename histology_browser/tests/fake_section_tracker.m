function [tracker, state] = fake_section_tracker(options)
% fake_section_tracker
%   [tracker, state] = fake_section_tracker()
%   [tracker, state] = fake_section_tracker(columnCount = 8)
%
% A SECTIONTRACKER wired to a sheet held in memory, for tests. No credentials,
% no key file, and no network are involved, which is what makes the cases that
% matter testable at all: what a write does when somebody reorders the tab
% underneath it is not something to go and try against the real tracker.
%
% The fixture mirrors the real tab's shape rather than a tidy one: a title row
% and blank rows above the header, columns whose headers are blank but whose
% cells are not, and a blank row among the entries.
%
%   col 1  Subject ID        col 5  Hemisphere
%   col 2  (unnamed)         col 6  Notes
%   col 3  Content           col 7  Atlas Plate #
%   col 4  Image Filename    col 8  (unnamed)
%
% Row 4 is the header; rows 5, 6, 8 and 9 are entries and row 7 is blank.
%
% Parameters
%   options.columnCount: Width of the sheet's grid, as GRIDPROPERTIES reports
%     it. Set it to 8 to make the tab too narrow for the columns ENSURESCHEMA
%     adds, which is what a tab trimmed to the columns it uses looks like.
%
% Returns
%   tracker: The SectionTracker, with its Transport replaced.
%   state: CONTAINERS.MAP holding the sheet. Keys: grid, writes, appended,
%     columnCount, sabotage. It is a handle, so the transport closures mutate
%     the same sheet a test then inspects.
%
% See also SECTIONTRACKER, TEST_SECTION_TRACKER, TEST_HISTOLOGY_BROWSER.

arguments
    options.columnCount (1,1) double = 26
end

header = ["Subject ID", "", "Content", "Image Filename", "Hemisphere", "Notes", "Atlas Plate #", ""];

grid = [ ...
    "Section tracker", "",        "",            "",                                          "",   "", "",   ""; ...
    "",                "",        "",            "",                                          "",   "", "",   ""; ...
    "",                "",        "",            "",                                          "",   "", "",   ""; ...
    header; ...
    "SUBJ-ID-896",     "scratch", "DAPI",        "SUBJ-ID-896_2A_L_DAPI_Z1_250408_1",         "L",  "", "",   "keep"; ...
    "SUBJ-ID-896",     "scratch", "WFA-PV-DAPI", "SUBJ-ID-896_2A_R_WFA-PV-DAPI_Z3_250408_1",  "R",  "", "20", "keep"; ...
    "",                "",        "",            "",                                          "",   "", "",   ""; ...
    "SUBJ-ID-896",     "scratch", "dapi",        "SUBJ-ID-896_2B_LR_DAPI_Z1_250408_1",        "LR", "", "30", "keep"; ...
    "SUBJ-ID-896",     "scratch", "WFA-PV-DAPI", "SUBJ-ID-896_2C_R_WFA-PV-DAPI_Z3_250408_1",  "L",  "", "30", "keep"];

state = containers.Map("KeyType", "char", "ValueType", "any");
state("grid") = grid;
state("writes") = 0;
state("appended") = 0;
state("columnCount") = options.columnCount;
state("sabotage") = false;

tracker = SectionTracker("fake-spreadsheet", "fake-key.json", sheetName = "Sections");
tracker.Transport = fake_transport(state);

end

function transport = fake_transport(state)
%FAKE_TRANSPORT Sheets API entry points backed by a string grid in memory.

transport = struct( ...
    getValues = @(~) fake_get(state), ...
    updateValues = @(updates) fake_update(state, updates), ...
    sheetInfo = @() fake_info(state), ...
    appendColumns = @(~, n) fake_append(state, n));

end

function grid = fake_get(state)
%FAKE_GET Return the whole tab, as the real read does.

grid = struct( ...
    values = state("grid"), ...
    firstRow = 1, ...
    firstColumn = 1, ...
    range = "Sections!A1");

end

function info = fake_info(state)
%FAKE_INFO Report the tab's identity and grid size.

info = struct( ...
    sheetId = 1, ...
    title = "Sections", ...
    rowCount = size(state("grid"), 1), ...
    columnCount = state("columnCount"));

end

function fake_update(state, updates)
%FAKE_UPDATE Apply a batch to the grid, refusing to write past its edge.

grid = state("grid");

for iUpdate = 1:numel(updates)
    [row, column] = parse_range(updates(iUpdate).range);
    values = string(updates(iUpdate).values);

    if column + numel(values) - 1 > state("columnCount")
        error("fake:RangeExceedsGrid", ...
            "Wrote past the right edge of the tab, which Google refuses.")
    end

    if size(grid, 2) < column + numel(values) - 1
        grid = [grid, strings(size(grid, 1), ...
            column + numel(values) - 1 - size(grid, 2))]; %#ok<AGROW>
    end

    grid(row, column:column + numel(values) - 1) = values;
end

state("grid") = grid;
state("writes") = state("writes") + 1;

if state("sabotage")
    % Somebody sorts the tab in the instant between the write landing and the
    % check that follows it.
    state("sabotage") = false;
    entries = 5:size(grid, 1);
    grid(entries, :) = grid(fliplr(entries), :);
    state("grid") = grid;
end

end

function fake_append(state, n)
%FAKE_APPEND Widen the grid, as APPENDDIMENSION does.

state("appended") = state("appended") + n;
state("columnCount") = state("columnCount") + n;

end

function [row, column] = parse_range(range)
%PARSE_RANGE Recover the first cell of an A1 range.

cellRef = extractAfter(range, "!");
cellRef = extractBefore(cellRef + ":", ":");

parts = regexp(cellRef, "^(?<column>[A-Za-z]+)(?<row>\d+)$", "names");

row = str2double(parts.row);
column = gsheet.columnNumber(parts.column);

end
