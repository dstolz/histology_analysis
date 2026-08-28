classdef SectionTracker < handle
    %SECTIONTRACKER Read and write the section tracker held in a Google Sheet.
    %
    %   tracker = SectionTracker(sheetUrl, credentialsPath)
    %   tracker = SectionTracker(sheetUrl, credentialsPath, sheetName = "Sections")
    %
    % The tracker is a tab in a spreadsheet several people edit by hand. That
    % single fact shapes everything here.
    %
    % Rows are addressed by what is in them, never by where they are. A sheet
    % row number is true only until somebody sorts the tab, deletes a filtered
    % row, or inserts above it, and none of those leave a trace this app could
    % notice. So a write is never aimed at a row index carried over from an
    % earlier read: UPDATEROWS re-reads the tab, resolves the criteria against
    % what is there now, writes, and then reads back the identifiers it wrote
    % to confirm they landed where it meant them to.
    %
    % Two columns exist to make that possible. Row UID gives every row a name
    % of its own that survives sorting, so a row stays findable even when the
    % human-meaningful columns are edited. Last Updated records when this code
    % last touched the row, so a value that changed on its own is visibly
    % distinct from one this app wrote. ENSURESCHEMA creates both and fills in
    % identifiers for rows that predate them.
    %
    % Reading needs only the Viewer role on the sheet. Writing needs Editor.
    %
    % Example
    %   tracker = SectionTracker(url, "C:\keys\histology-sheets.json");
    %   tracker.ensureSchema();
    %   idx = tracker.findRows({"Hemisphere", "L"});
    %   tracker.updateRows( ...
    %       {"Image Filename", "SUBJ-ID-896_2A_L_DAPI_Z1_250408_1"}, ...
    %       {"Notes", "Profile remeasured"});
    %
    % See also COMBINE_VALUES_CSV, HISTOLOGYIMAGEBROWSER, GSHEET.GETVALUES.

    properties
        SpreadsheetId string = ""   % Spreadsheet ID, never a full URL.
        SheetName string = "Sections"
        CredentialsPath string = "" % Service account JSON key file.

        Table table = table()       % Last read of the tab, one row per entry.
        SheetRows double = []       % Sheet row number of each Table row.
        ColumnNames string = strings(0, 1)
        ColumnIndex double = []     % Sheet column number of each named column.
        HeaderRow double = NaN      % Sheet row the header was found on.

        % Rightmost column the tab actually uses, named or not. New columns go
        % beyond this rather than beyond the last named one, because a column
        % whose header is blank still holds somebody's data.
        LastColumn double = NaN
        FetchedAt datetime = NaT

        % Header problems that do not stop a read but do lose information, so
        % they are carried out rather than warned about into an empty console.
        Warnings string = strings(0, 1)

        % Sheets API entry points, bound to this spreadsheet. Held as a struct
        % of handles so a test can drive the whole class against an in-memory
        % grid without a network or a key file.
        Transport struct = struct()
    end

    properties (Constant)
        % The column already used to join the tracker to images on disk.
        KeyColumn = "Image Filename"

        % Columns this class maintains. Named here rather than inline because
        % ENSURESCHEMA creates them, UPDATEROWS writes them, and READ has to
        % recognize them when they already exist.
        UidColumn = "Row UID"
        UpdatedColumn = "Last Updated"

        % Timestamps go in as text in UTC, which sorts correctly as text and
        % cannot be re-read as a different instant by a spreadsheet carrying a
        % different locale than the machine that wrote it.
        TimestampFormat = "uuuu-MM-dd'T'HH:mm:ss'Z'"
    end

    methods
        function obj = SectionTracker(sheetReference, credentialsPath, options)
            %SECTIONTRACKER Point the tracker at one tab of one spreadsheet.
            %
            % Parameters
            %   sheetReference: Spreadsheet URL or bare ID.
            %   credentialsPath: Path to the service account JSON key file.
            %   options.sheetName: Tab holding the tracker.

            arguments
                sheetReference (1,1) string = ""
                credentialsPath (1,1) string = ""
                options.sheetName (1,1) string = "Sections"
            end

            if sheetReference ~= ""
                obj.SpreadsheetId = gsheet.spreadsheetId(sheetReference);
            end

            obj.CredentialsPath = credentialsPath;
            obj.SheetName = options.sheetName;
            obj.Transport = obj.liveTransport();
        end

        function tf = isConfigured(obj)
            %ISCONFIGURED True when a read could be attempted.

            tf = obj.SpreadsheetId ~= "" && obj.CredentialsPath ~= "";
        end

        function tf = hasData(obj)
            %HASDATA True when a read has returned rows.

            tf = height(obj.Table) > 0;
        end

        function transport = liveTransport(obj)
            %LIVETRANSPORT Bind the Sheets API calls to this spreadsheet.
            % The spreadsheet and key file are captured here so the rest of the
            % class names ranges and nothing else.

            transport = struct( ...
                getValues = @(range) gsheet.getValues( ...
                    obj.CredentialsPath, obj.SpreadsheetId, range), ...
                updateValues = @(updates) gsheet.updateValues( ...
                    obj.CredentialsPath, obj.SpreadsheetId, updates), ...
                sheetInfo = @() gsheet.sheetInfo( ...
                    obj.CredentialsPath, obj.SpreadsheetId, obj.SheetName), ...
                appendColumns = @(sheetId, n) gsheet.appendColumns( ...
                    obj.CredentialsPath, obj.SpreadsheetId, sheetId, n));
        end

        function column = columnNumber(obj, columnName)
            %COLUMNNUMBER Sheet column holding one named tracker column.
            % Errors rather than returning empty, because every caller of this
            % is about to build a range and a silent miss would write into the
            % wrong column.

            match = find(strcmpi(obj.ColumnNames, columnName), 1);

            if isempty(match)
                error("SectionTracker:NoSuchColumn", ...
                    "The '%s' tab has no column named '%s'. It has: %s.", ...
                    obj.SheetName, columnName, strjoin(obj.ColumnNames, ", "))
            end

            column = obj.ColumnIndex(match);
        end

        function tf = hasColumn(obj, columnName)
            %HASCOLUMN True when the tab carries a column of that name.

            tf = any(strcmpi(obj.ColumnNames, columnName));
        end

        function values = column(obj, columnName)
            %COLUMN One column of the last read, as text.

            match = find(strcmpi(obj.ColumnNames, columnName), 1);

            if isempty(match)
                values = strings(height(obj.Table), 1);
                return
            end

            values = string(obj.Table.(char(obj.ColumnNames(match))));
        end

        function name = canonicalColumn(obj, columnName)
            %CANONICALCOLUMN The header's own spelling of a column name.
            % Callers name columns in whatever case reads well; the table is
            % indexed by the exact text in the header. This is where the two
            % meet, so nothing downstream has to search case-insensitively.

            match = find(strcmpi(obj.ColumnNames, columnName), 1);

            if isempty(match)
                error("SectionTracker:NoSuchColumn", ...
                    "The '%s' tab has no column named '%s'. It has: %s.", ...
                    obj.SheetName, columnName, strjoin(obj.ColumnNames, ", "))
            end

            name = obj.ColumnNames(match);
        end
    end

    methods (Access = private)
        % Defined in their own files. Private because each one is only correct
        % immediately after a read, and enforcing that is the whole reason the
        % public writes are the two that read first.
        report = applyUpdates(obj, uids, updates, options)
        rows = rowsForUids(obj, uids)
        uids = requireUids(obj, rows)
    end

    methods (Static)
        function uid = newUid(n)
            %NEWUID Mint row identifiers that no sort or edit can invalidate.
            % A timestamp prefix makes the order rows were first seen readable
            % at a glance in the sheet; the random tail is what actually keeps
            % them distinct, including across two machines writing at once.

            arguments
                n (1,1) double {mustBeInteger, mustBePositive} = 1
            end

            stamp = string(datetime("now", TimeZone = "UTC"), "uuuuMMdd");
            uid = strings(n, 1);

            for iUid = 1:n
                uid(iUid) = "SEC-" + stamp + "-" + string(dec2hex(randi([0 2^24 - 1]), 6)) ...
                    + string(dec2hex(randi([0 2^24 - 1]), 6));
            end
        end

        function stamp = timestamp()
            %TIMESTAMP The current instant in the form written to the sheet.

            stamp = string(datetime("now", TimeZone = "UTC"), ...
                SectionTracker.TimestampFormat);
        end
    end
end
