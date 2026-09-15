function test_section_tracker()
% test_section_tracker
%
% Checks for the Google Sheets tracker. Everything here runs against an
% in-memory sheet rather than the network, so no credentials, no key file, and
% no spreadsheet are needed, and the checks that matter most can be made at
% all: what happens to a write when somebody reorders the tab underneath it is
% not something to go and try against the real tracker.
%
% See also SECTIONTRACKER, GSHEET.GETVALUES, TEST_HISTOLOGY_BROWSER.

% The repo root holds the browser and its helpers; this folder holds the shared
% test fixtures. Both are added so the checks run from anywhere.
addpath(fileparts(fileparts(mfilename("fullpath"))));
addpath(fileparts(mfilename("fullpath")));

nFailed = 0;

nFailed = nFailed + run_case("A1 notation", @check_a1_notation);
nFailed = nFailed + run_case("decoded value grids", @check_value_grid);
nFailed = nFailed + run_case("service account key checks", @check_service_account);
nFailed = nFailed + run_case("signed assertion", @check_jwt_assertion);
nFailed = nFailed + run_case("header discovery", @check_header_discovery);
nFailed = nFailed + run_case("row lookup by criteria", @check_find_rows);
nFailed = nFailed + run_case("schema provisioning", @check_ensure_schema);
nFailed = nFailed + run_case("schema provisioning is idempotent", @check_schema_idempotent);
nFailed = nFailed + run_case("narrow tab is widened", @check_widen_tab);
nFailed = nFailed + run_case("write addresses rows by content", @check_write_after_sort);
nFailed = nFailed + run_case("write addresses rows by identifier", @check_write_by_uid);
nFailed = nFailed + run_case("write stamps the time", @check_timestamp_written);
nFailed = nFailed + run_case("write refuses a surprising match count", @check_expected_count);
nFailed = nFailed + run_case("maintained columns are protected", @check_protected_columns);
nFailed = nFailed + run_case("deleted row is not written over", @check_deleted_row);
nFailed = nFailed + run_case("a row moving mid-write is caught", @check_row_moved);
nFailed = nFailed + run_case("tracker feeds the catalog", @check_metadata_table);
nFailed = nFailed + run_case("measured flag round trip", @check_measured_flag);

if nFailed == 0
    fprintf("All checks passed.\n");
else
    fprintf(2, "%d check(s) failed.\n", nFailed);
end

end

function nFailed = run_case(name, fcn)
%RUN_CASE Run one check and report the outcome.

nFailed = 0;

try
    fcn();
    fprintf("PASS  %s\n", name);
catch ME
    nFailed = 1;
    fprintf(2, "FAIL  %s: %s\n", name, ME.message);
end

end

function check_a1_notation()
%CHECK_A1_NOTATION Column letters round trip, and tab names get quoted.

assert(gsheet.columnLetter(1) == "A", "Column 1 is not A");
assert(gsheet.columnLetter(26) == "Z", "Column 26 is not Z");
assert(gsheet.columnLetter(27) == "AA", "Column 27 is not AA");
assert(gsheet.columnLetter(703) == "AAA", "Column 703 is not AAA");

for column = [1 13 26 27 52 53 702 703]
    assert(gsheet.columnNumber(gsheet.columnLetter(column)) == column, ...
        "Column %d did not survive the round trip", column);
end

assert(gsheet.a1Range("Sections", 5, 14) == "Sections!N5", ...
    "A single cell range was built wrongly");
assert(gsheet.a1Range("Sections", 5, 14, 5, 15) == "Sections!N5:O5", ...
    "A multi-cell range was built wrongly");

% A tab name that is not an identifier has to be quoted, or the range parses as
% a cell reference on whichever sheet happens to come first.
assert(gsheet.a1Range("Section notes", 1, 1) == "'Section notes'!A1", ...
    "A tab name with a space was not quoted");

% The range travels in the URL path, where a space is not a plus sign.
assert(gsheet.encodeSegment("Section notes!A1") == "Section%20notes%21A1", ...
    "A range was encoded as though it were a query string");

assert(gsheet.spreadsheetId( ...
    "https://docs.google.com/spreadsheets/d/1yz6v2yP/edit?gid=108#gid=108") == "1yz6v2yP", ...
    "The spreadsheet ID was not recovered from a URL");
assert(gsheet.spreadsheetId("1yz6v2yP") == "1yz6v2yP", ...
    "A bare spreadsheet ID was not passed through");

end

function check_value_grid()
%CHECK_VALUE_GRID Every shape a values reply decodes to becomes one rectangle.
% Google omits the trailing empty cells of each row, so rows arrive at
% different lengths, and JSONDECODE renders that differently depending on
% whether the lengths happen to agree. The JSON here is written out as Google
% sends it and decoded for real, rather than the decoded shapes being guessed
% at and constructed by hand.

% Ragged: the usual case, where a short row is padded out on the right.
values = gsheet.valueGrid(jsondecode('[["a","b","c"],["d"],["e","f"]]'));
assert(isequal(size(values), [3 3]), ...
    "A ragged reply came out %s rather than 3 by 3", mat2str(size(values)));
assert(values(2, 1) == "d" && values(2, 2) == "" && values(2, 3) == "", ...
    "A short row was not padded with blanks");
assert(values(3, 2) == "f", "A padded row lost a value");

% Uniform: decodes to a cell matrix instead, and must come out the same way.
values = gsheet.valueGrid(jsondecode('[["a","b"],["c","d"]]'));
assert(isequal(values, ["a" "b"; "c" "d"]), ...
    "A reply whose rows are all one length was reshaped");

% A single row, and a single cell, are the degenerate shapes of the above.
values = gsheet.valueGrid(jsondecode('[["only","row"]]'));
assert(isequal(values, ["only" "row"]), "A single row was mangled");

values = gsheet.valueGrid(jsondecode('[["one"]]'));
assert(isequal(values, "one"), "A single cell was mangled");

% An empty tab has no values field at all, which reaches here as nothing.
assert(isempty(gsheet.valueGrid([])), "An empty reply did not come out empty");

% Cells read as formatted text, but a blank one decodes to an empty string and
% must not turn into a missing value that comparisons then propagate.
values = gsheet.valueGrid(jsondecode('[["a","","c"]]'));
assert(values(2) == "" && ~ismissing(values(2)), "A blank cell became missing");

% Ranges are echoed back by Google and say where the block starts, which is
% what makes a row addressable for a later write.
[row, column] = gsheet.rangeOrigin("Sections!A1:M1553");
assert(row == 1 && column == 1, "A range starting at A1 was misread");

[row, column] = gsheet.rangeOrigin("Sections!B4:N120");
assert(row == 4 && column == 2, "A range not starting at A1 was misread");

[row, column] = gsheet.rangeOrigin("'Section notes'!AA10");
assert(row == 10 && column == 27, "A quoted tab name confused the range parser");

[row, column] = gsheet.rangeOrigin("Sections");
assert(row == 1 && column == 1, "A range with no cell reference did not default to A1");

end

function check_service_account()
%CHECK_SERVICE_ACCOUNT A key file that will not work is rejected up front.
% Each of these decodes as valid JSON and would fail somewhere much later, with
% a message about Java key specifications or an HTTP 400, so the point is that
% they fail here instead, naming the file and what to do about it.

folder = string(tempname);
mkdir(folder);
cleanup = onCleanup(@() rmdir(folder, "s"));

assert_error(@() gsheet.serviceAccount(""), "gsheet:NoCredentials", ...
    "An empty credentials path was accepted");
assert_error(@() gsheet.serviceAccount(fullfile(folder, "absent.json")), ...
    "gsheet:MissingCredentials", "A missing key file was accepted");

notJson = fullfile(folder, "notjson.json");
writelines("this is not JSON", notJson);
assert_error(@() gsheet.serviceAccount(notJson), "gsheet:UnreadableCredentials", ...
    "A file that is not JSON was accepted");

% What someone gets by downloading the wrong thing from the Cloud console.
oauthClient = fullfile(folder, "oauth.json");
writelines(jsonencode(struct(type = "authorized_user", client_id = "x", ...
    client_email = "x@y", private_key = "z")), oauthClient);
assert_error(@() gsheet.serviceAccount(oauthClient), "gsheet:WrongCredentialType", ...
    "An OAuth client credential was accepted");

incomplete = fullfile(folder, "incomplete.json");
writelines(jsonencode(struct(type = "service_account", client_email = "x@y")), incomplete);
assert_error(@() gsheet.serviceAccount(incomplete), "gsheet:IncompleteCredentials", ...
    "A key file with no private key was accepted");

% Google omits token_uri from nothing it issues, but a hand-trimmed file is
% still usable and gets the documented default rather than an error.
minimal = fullfile(folder, "minimal.json");
writelines(jsonencode(struct(type = "service_account", ...
    client_email = "x@y", private_key = "z")), minimal);
credentials = gsheet.serviceAccount(minimal);
assert(credentials.token_uri == "https://oauth2.googleapis.com/token", ...
    "The default token endpoint was not filled in");

end

function check_jwt_assertion()
%CHECK_JWT_ASSERTION The assertion is a JWT that verifies against the key.
% Google will not say why an assertion was refused beyond "invalid_grant", so
% the signature is checked here against a key generated for the purpose. This
% is the one part of the auth path that cannot be exercised any other way
% without real credentials and a real spreadsheet.

if ~usejava("jvm")
    return
end

[privateKeyPem, publicKey] = generate_rsa_key();

folder = string(tempname);
mkdir(folder);
cleanup = onCleanup(@() rmdir(folder, "s"));

keyFile = fullfile(folder, "key.json");
writelines(jsonencode(struct( ...
    type = "service_account", ...
    private_key_id = "abc123", ...
    client_email = "histology@example.iam.gserviceaccount.com", ...
    token_uri = "https://oauth2.googleapis.com/token", ...
    private_key = privateKeyPem)), keyFile);

credentials = gsheet.serviceAccount(keyFile);

issuedAt = 1800000000;
assertion = gsheet.jwtAssertion(credentials, ...
    "https://www.googleapis.com/auth/spreadsheets", issuedAt);

parts = split(assertion, ".");
assert(numel(parts) == 3, "The assertion has %d parts rather than 3", numel(parts));

% The unpadded, URL-safe alphabet is what makes it safe to post as a form
% value: no plus signs to be read as spaces, no equals signs to end the field.
assert(~any(contains(parts, ["+", "/", "="])), ...
    "The assertion was encoded in the wrong base64 alphabet");

header = jsondecode(char(base64url_decode(parts(1))));
assert(string(header.alg) == "RS256", "The header names %s, not RS256", header.alg);
assert(string(header.typ) == "JWT", "The header does not declare a JWT");
assert(string(header.kid) == "abc123", "The key identifier was not carried over");

claims = jsondecode(char(base64url_decode(parts(2))));
assert(string(claims.iss) == credentials.client_email, "The issuer is wrong");
assert(string(claims.aud) == credentials.token_uri, "The audience is wrong");
assert(string(claims.scope) == "https://www.googleapis.com/auth/spreadsheets", ...
    "The scope is wrong");
assert(claims.iat == issuedAt, "The issued-at time is wrong");
assert(claims.exp == issuedAt + 3600, "The expiry is not an hour after issue");

% The part that matters: the signature is over the first two segments joined by
% a dot, and it verifies with the public half of the key that signed it.
verifier = java.security.Signature.getInstance("SHA256withRSA");
verifier.initVerify(publicKey);
verifier.update(typecast(unicode2native(parts(1) + "." + parts(2), "UTF-8"), "int8"));

assert(verifier.verify(typecast(base64url_decode(parts(3)), "int8")), ...
    "The assertion's signature does not verify against its own key");

% A key in the format OpenSSL writes by default is not what Google issues, and
% saying so beats a Java error about algorithm identifiers.
pkcs1 = credentials;
pkcs1.private_key = replace(privateKeyPem, "BEGIN PRIVATE KEY", "BEGIN RSA PRIVATE KEY");
assert_error(@() gsheet.jwtAssertion(pkcs1, "scope"), "gsheet:UnsupportedKeyFormat", ...
    "A PKCS#1 key was not recognized as the wrong format");

end

function [privateKeyPem, publicKey] = generate_rsa_key()
%GENERATE_RSA_KEY Make a throwaway RSA key in the PEM form Google issues.

generator = java.security.KeyPairGenerator.getInstance("RSA");
generator.initialize(2048);
pair = generator.generateKeyPair();

publicKey = pair.getPublic();

der = typecast(pair.getPrivate().getEncoded(), "uint8");
body = string(matlab.net.base64encode(der));

% PEM wraps at 64 characters. The decoder strips whitespace, but wrapping it
% the way a real key file is wrapped is what makes this a test of the real
% input rather than a tidier one.
wrapped = strings(0, 1);

for iChunk = 1:64:strlength(body)
    wrapped(end+1) = extractBetween(body, iChunk, ...
        min(iChunk + 63, strlength(body))); %#ok<AGROW>
end

privateKeyPem = "-----BEGIN PRIVATE KEY-----" + newline ...
    + strjoin(wrapped, newline) + newline ...
    + "-----END PRIVATE KEY-----" + newline;

end

function bytes = base64url_decode(text)
%BASE64URL_DECODE Undo the URL-safe, unpadded encoding a JWT uses.

text = replace(replace(string(text), "-", "+"), "_", "/");

% Padding is added as characters rather than as a repeated string, because
% repmat of a string zero times gives an empty array, and appending that to a
% scalar string empties it rather than leaving it alone.
padding = mod(4 - mod(strlength(text), 4), 4);
text = text + string(repmat('=', 1, padding));

bytes = matlab.net.base64decode(text);

end

function check_header_discovery()
%CHECK_HEADER_DISCOVERY The header is found below the rows above it.

tracker = fake_section_tracker();
tracker.read();

assert(tracker.HeaderRow == 4, ...
    "Header found on row %d rather than row 4", tracker.HeaderRow);
assert(height(tracker.Table) == 4, ...
    "Read %d entries rather than 4", height(tracker.Table));

% Row 7 of the fixture is blank: part of the tab's layout, not an entry. It has
% to be absent from the table and, more to the point, from the row mapping, or
% a later write could be aimed into it.
assert(~any(tracker.SheetRows == 7), "A blank spacer row was read as an entry");
assert(isequal(tracker.SheetRows(:)', [5 6 8 9]), ...
    "Entries were mapped to the wrong sheet rows: %s", mat2str(tracker.SheetRows(:)'));

assert(tracker.hasColumn("Image Filename"), "The key column was not found");
assert(tracker.columnNumber("Image Filename") == 4, ...
    "The key column was located in the wrong sheet column");

% A column with no header cannot be named, so it is left out rather than being
% given an invented name that nothing could match.
assert(~any(tracker.ColumnNames == ""), "An unnamed column was kept");

% The tab is wider than its last named column, which is what decides where a
% new column can safely go.
assert(tracker.LastColumn == 8, ...
    "The tab's width was recorded as %d rather than 8", tracker.LastColumn);
assert(max(tracker.ColumnIndex) == 7, ...
    "The last named column was located at %d rather than 7", max(tracker.ColumnIndex));

end

function check_find_rows()
%CHECK_FIND_ROWS Rows are selected by what they contain.

tracker = fake_section_tracker();
tracker.read();

idx = tracker.findRows({"Hemisphere", "L"});
assert(numel(idx) == 2, "Expected 2 left-hemisphere rows, found %d", numel(idx));

% Criteria combine with AND.
idx = tracker.findRows({"Hemisphere", "L", "Content", "DAPI"});
assert(numel(idx) == 1, "Two criteria did not narrow the match");

% Hand-typed cells carry stray case and spaces that are never meant as
% distinctions, so neither is one here.
idx = tracker.findRows({"Content", "  dapi  "});
assert(numel(idx) == 2, "Matching ignored neither case nor surrounding space");

idx = tracker.findRows({"Hemisphere", ["L", "R"]});
assert(numel(idx) == 3, "A list of values did not match any of them");

idx = tracker.findRows({"Atlas Plate #", @(v) str2double(v) > 25});
assert(numel(idx) == 2, "A predicate criterion did not select the right rows");

assert_error(@() tracker.findRows({}), "SectionTracker:NoCriteria", ...
    "Empty criteria were accepted");
assert_error(@() tracker.findRows({"Hemisphere"}), "SectionTracker:UnpairedCriteria", ...
    "An unpaired criterion was accepted");
assert_error(@() tracker.findRows({"Nonexistent", "x"}), "SectionTracker:NoSuchColumn", ...
    "A criterion on a missing column was accepted");

end

function check_ensure_schema()
%CHECK_ENSURE_SCHEMA The two maintained columns are created and filled.

[tracker, state] = fake_section_tracker();

report = tracker.ensureSchema();

assert(numel(report.columnsAdded) == 3, ...
    "Added %d columns rather than 3", numel(report.columnsAdded));
assert(report.uidsAssigned == 4, ...
    "Identified %d rows rather than 4", report.uidsAssigned);

grid = state("grid");

% Placed past everything the tab uses, not merely past its last named column.
% Column 8 has no header, so nothing can refer to it, but it holds data all the
% same and writing the new columns over it would destroy that.
assert(strtrim(grid(4, 9)) == "Row UID", "The identifier column header is wrong");
assert(strtrim(grid(4, 10)) == "Last Updated", "The timestamp column header is wrong");
assert(all(strtrim(grid([5 6 8 9], 8)) == "keep"), ...
    "An unnamed column to the right of the named ones was written over");

uids = strtrim(grid([5 6 8 9], 9));
assert(all(uids ~= ""), "Some entries were left without an identifier");
assert(numel(unique(uids)) == 4, "Identifiers were not unique");

% The spacer row is not an entry and must not be given an identity.
assert(strtrim(grid(7, 9)) == "", "A blank spacer row was given an identifier");

end

function check_schema_idempotent()
%CHECK_SCHEMA_IDEMPOTENT Running it again changes nothing.

[tracker, state] = fake_section_tracker();
tracker.ensureSchema();

before = state("grid");
writesBefore = state("writes");

report = tracker.ensureSchema();

assert(isempty(report.columnsAdded), "Columns were added a second time");
assert(report.uidsAssigned == 0, "Identifiers were reassigned");
assert(isequal(state("grid"), before), "The sheet changed on a second run");
assert(state("writes") == writesBefore, "A redundant write was sent");

end

function check_widen_tab()
%CHECK_WIDEN_TAB A tab with no spare columns is grown before it is written.
% Trimming a tab to exactly the columns it uses is an ordinary thing to do, and
% writing past the right edge of the grid is refused rather than growing it.

[tracker, state] = fake_section_tracker(columnCount = 8);

tracker.ensureSchema();

assert(state("appended") == 3, ...
    "Grew the tab by %d columns rather than 3", state("appended"));
assert(tracker.hasColumn("Row UID"), "The identifier column was not created");

end

function check_write_after_sort()
%CHECK_WRITE_AFTER_SORT A write lands by content after the tab is reordered.
% This is the failure the whole design exists to prevent. The row wanted is
% read at one position, the tab is then sorted so it sits somewhere else, and
% the value still has to reach that row and no other.

[tracker, state] = fake_section_tracker();
tracker.ensureSchema();

target = "SUBJ-ID-896_2C_R_WFA-PV-DAPI_Z3_250408_1";

% Read the row at its old position, exactly as a caller would before deciding
% to write to it.
tracker.read();
oldRow = tracker.SheetRows(tracker.findRows({"Image Filename", target}));

reverse_entries(state);

report = tracker.updateRows({"Image Filename", target}, {"Notes", "Remeasured"}, ...
    expected = 1);

assert(report.SheetRow ~= oldRow, ...
    "The fixture did not actually move the row, so nothing was tested");

grid = state("grid");
written = find(strtrim(grid(:, 4)) == target);

assert(strtrim(grid(written, 6)) == "Remeasured", ...
    "The value did not reach the row it was aimed at");
assert(report.SheetRow == written, ...
    "The report names row %d but the value landed on row %d", ...
    report.SheetRow, written);

% And nothing else was touched.
others = setdiff(find(strtrim(grid(:, 4)) ~= ""), [4; written]);
assert(all(strtrim(grid(others, 6)) ~= "Remeasured"), ...
    "The value was written into more rows than the one that matched");

end

function check_write_by_uid()
%CHECK_WRITE_BY_UID An identifier still finds its row after a reorder.

[tracker, state] = fake_section_tracker();
tracker.ensureSchema();

tracker.read();
row = tracker.findRows({"Image Filename", "SUBJ-ID-896_2A_L_DAPI_Z1_250408_1"});
uids = tracker.column("Row UID");
uid = uids(row);

reverse_entries(state);

tracker.updateByUid(uid, {"Notes", "By identifier"});

grid = state("grid");
written = find(strtrim(grid(:, 9)) == uid);

assert(strtrim(grid(written, 6)) == "By identifier", ...
    "The value did not follow its identifier to the row's new position");
assert(strtrim(grid(written, 4)) == "SUBJ-ID-896_2A_L_DAPI_Z1_250408_1", ...
    "The identifier resolved to the wrong entry");

end

function check_timestamp_written()
%CHECK_TIMESTAMP_WRITTEN Every write dates itself.

[tracker, state] = fake_section_tracker();
tracker.ensureSchema();

tracker.updateRows({"Hemisphere", "LR"}, {"Notes", "Both hemispheres"});

grid = state("grid");
rows = find(strtrim(grid(:, 5)) == "LR");
stamps = strtrim(grid(rows, 10));

assert(all(stamps ~= ""), "A row was written without being dated");

% Written in UTC so the text sorts as the instants do, whatever locale the
% spreadsheet or the machine that wrote it happens to carry.
parsed = datetime(stamps, InputFormat = "uuuu-MM-dd'T'HH:mm:ss'Z'", TimeZone = "UTC");
assert(all(~isnat(parsed)), "The timestamp was not written in the documented form");

untouched = strtrim(grid(strtrim(grid(:, 5)) == "L", 10));
assert(all(untouched == ""), "Rows that were not written were dated anyway");

end

function check_expected_count()
%CHECK_EXPECTED_COUNT A surprising number of matches stops the write.
% Criteria that were meant to name one row and name two are a mistake, and the
% point of catching it is that nothing is written while it is caught.

[tracker, state] = fake_section_tracker();
tracker.ensureSchema();

before = state("grid");

assert_error(@() tracker.updateRows({"Content", "DAPI"}, {"Notes", "x"}, expected = 1), ...
    "SectionTracker:UnexpectedMatchCount", "Two matches passed for one");

assert(isequal(state("grid"), before), "The refused write changed the sheet anyway");

assert_error(@() tracker.updateRows({"Hemisphere", "nowhere"}, {"Notes", "x"}), ...
    "SectionTracker:NoMatchingRows", "A write that matched nothing was not reported");

end

function check_protected_columns()
%CHECK_PROTECTED_COLUMNS The maintained columns cannot be set by hand.

[tracker, state] = fake_section_tracker();
tracker.ensureSchema();

before = state("grid");

assert_error(@() tracker.updateRows({"Hemisphere", "L"}, {"Row UID", "SEC-forged"}), ...
    "SectionTracker:ProtectedColumn", "A row identifier was allowed to be rewritten");

assert_error(@() tracker.updateRows({"Hemisphere", "L"}, {"Last Updated", "yesterday"}), ...
    "SectionTracker:ProtectedColumn", "A timestamp was allowed to be set by hand");

assert_error(@() tracker.updateRows({"Hemisphere", "L"}, {"Nonexistent", "x"}), ...
    "SectionTracker:NoSuchColumn", "A write to a missing column was accepted");

assert(isequal(state("grid"), before), "A refused write changed the sheet anyway");

end

function check_deleted_row()
%CHECK_DELETED_ROW An identifier whose row is gone stops the write.
% The row that was there has been removed, and whatever now occupies its
% position belongs to somebody else. Refusing is the only safe answer.

[tracker, state] = fake_section_tracker();
tracker.ensureSchema();

tracker.read();
uids = tracker.column("Row UID");
uid = uids(1);

grid = state("grid");
grid(5, :) = [];
state("grid") = grid;

assert_error(@() tracker.updateByUid(uid, {"Notes", "x"}), ...
    "SectionTracker:UnknownUid", "A write to a deleted row was accepted");

end

function check_row_moved()
%CHECK_ROW_MOVED A reorder during the write itself is caught afterwards.
% Nothing can prevent this: the Sheets API has no conditional write, so between
% resolving a row and writing to it there is a window. What can be done is to
% notice, so the write is reported rather than passing for a success.

[tracker, state] = fake_section_tracker();
tracker.ensureSchema();

% Reorder the tab the instant the write lands, which is the worst case the
% window allows for.
state("sabotage") = true;

assert_error(@() tracker.updateRows({"Hemisphere", "LR"}, {"Notes", "x"}), ...
    "SectionTracker:RowMovedDuringWrite", ...
    "A row that moved during the write was not noticed");

end

function check_metadata_table()
%CHECK_METADATA_TABLE The tracker joins onto the catalog like the CSV did.

tracker = fake_section_tracker();
T = tracker.metadataTable();

assert(ismember("Image Filename", string(T.Properties.VariableNames)), ...
    "The table is missing the column the catalog joins on");
assert(height(T) == 4, "The table has %d rows rather than 4", height(T));

% BUILD_HISTOLOGY_IMAGE_CATALOG reads Atlas Plate # as a number even though
% every cell arrives from the sheet as text.
plates = T.("Atlas Plate #");
assert(str2double(plates(3)) == 30, ...
    "A numeric tracker column did not survive as text that converts");

end

function check_measured_flag()
%CHECK_MEASURED_FLAG The review flag is provisioned, writable, and readable.
% Measured is created by ENSURESCHEMA like the bookkeeping columns, but it is
% not one of them: what goes in it is a judgement made during review, so unlike
% Row UID and Last Updated it has to be writable.

[tracker, state] = fake_section_tracker();

report = tracker.ensureSchema();

assert(numel(report.columnsAdded) == 3, ...
    "Added %d columns rather than 3", numel(report.columnsAdded));
assert(any(report.columnsAdded == "Measured"), "The Measured column was not added");

grid = state("grid");
assert(strtrim(grid(4, 11)) == "Measured", ...
    "The Measured header went to the wrong column: '%s'", strtrim(grid(4, 11)));

% Nobody has reviewed anything yet, so every cell is blank and every row reads
% as not measured. A blank default is what lets the flag be added to a tracker
% of existing rows without asserting anything about them.
assert(~any(SectionTracker.isMeasured(tracker.column("Measured"))), ...
    "Rows read as measured before anything was written");

tracker.updateRows({"Hemisphere", "LR"}, {"Measured", SectionTracker.measuredText(true)});

grid = state("grid");
row = find(strtrim(grid(:, 5)) == "LR");
assert(strtrim(grid(row, 11)) == "yes", "The flag was not written");
assert(strtrim(grid(row, 10)) ~= "", "Writing the flag did not stamp the time");

tracker.read();
assert(sum(SectionTracker.isMeasured(tracker.column("Measured"))) == 1, ...
    "Exactly one row should read as measured");

% Clearing empties the cell rather than writing "no", so a row that was
% reviewed and found wanting reads the same as one nobody has reached yet.
tracker.updateRows({"Hemisphere", "LR"}, {"Measured", SectionTracker.measuredText(false)});
grid = state("grid");
assert(strtrim(grid(row, 11)) == "", "Clearing the flag left something in the cell");

% The column is in a spreadsheet people type into, so the obvious other ways of
% saying yes count, and anything else does not.
assert(all(SectionTracker.isMeasured(["yes", "YES", " y ", "true", "1", "x", "done"])), ...
    "A reasonable way of typing yes was not accepted");
assert(~any(SectionTracker.isMeasured(["", "no", "n", "0", "maybe", "  "])), ...
    "Something that is not a yes was read as one");

end

function reverse_entries(state)
%REVERSE_ENTRIES Sort the fixture's entries into the opposite order.
% Standing in for someone sorting the tab in the browser, which is the ordinary
% event that invalidates every row number read before it.

grid = state("grid");
entries = 5:size(grid, 1);
grid(entries, :) = grid(fliplr(entries), :);
state("grid") = grid;

end

function assert_error(fcn, identifier, message)
%ASSERT_ERROR Check that a call fails, and fails for the stated reason.

try
    fcn();
catch ME
    assert(ME.identifier == string(identifier), ...
        "%s (failed with %s rather than %s)", message, ME.identifier, identifier);
    return
end

error("%s (the call succeeded)", message);

end
