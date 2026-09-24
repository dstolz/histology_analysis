# Section Tracker

The section tracker is a spreadsheet with one row per section image. It holds what the file name
can't: the atlas plate, slide, notes, laser power, and whether the section has been measured.
The browser joins it onto the catalog by file name.

## Three ways to connect it

| Source | Setup | Always current? | Can the browser write to it? | Launch option |
|---|---|---|---|---|
| **CSV export** | None | No, it's a snapshot | No | `metadataCSV = "path/to/Trackers - Sections.csv"` |
| **Published Google Sheet** | One click in Sheets | Yes (Google caches for a few minutes) | No | `publishedUrl = "https://docs.google.com/.../pub?gid=...&single=true&output=csv"` |
| **Google Sheets API** | Service account key | Yes | **Yes**: atlas plate and Measured | `sheetUrl = "...", sheetCredentials = "key.json"` |

When several are set, the browser uses the Sheets API first, then the published sheet, then the
CSV. The others stay configured as fallbacks. The status bar tells you which one a load used.

You can also set each source from the **Dataset** menu instead of the launch call.

## Columns the browser uses

The header row is **searched for**, so title or blank rows above it are fine.

| Tracker column | Catalog / export column |
|---|---|
| `Image Filename` | the join key; see below |
| `Atlas Plate #` | `AtlasPlate` (numeric) |
| `Content` | `Content` |
| `Slide #` | `Slide` |
| `Slice ID` | `SliceID` |
| `Image Date` | `ImageDate` |
| `Laser power` | `LaserPower` |
| `Processing ID` | `ProcessingID` |
| `Notes` | `Notes` (also searched by the Look Up box) |
| `Row UID`, `Last Updated`, `Measured` | added by **Prepare Sheet for Writing**; see below |

**How rows are matched.** The value in `Image Filename`, for example
`SUBJ-ID-1174IHC_ECM26A260608S1_1A_L_WFA-PV_Z3_260616_1_proj.tif`, is matched to the catalog by
filename stem. That is loose enough for reading, since a tracker entry may be a prefix of the
image name. Writing uses the stricter `Row UID`.

## Option A: CSV export

In Google Sheets: **File > Download > Comma-separated values**, on the tracker tab. Then:

```matlab
launch_histology_browser(root, metadataCSV = "D:/Data/Trackers - Sections.csv")
```

or use **Dataset > Tracker CSV:**. Export again whenever the sheet changes.

## Option B: Published sheet (read-only, no credentials)

1. In the sheet: **File > Share > Publish to web**.
2. Choose **the tracker tab** (not "Entire document") and **Comma-separated values (.csv)**.
   Click **Publish**.
3. Paste the link into **Dataset > Published Sheet**. The link is test-downloaded immediately,
   so a bad link is reported while the dialog is still open.

Keep **"Automatically republish when changes are made"** checked, which is the default.

> **Privacy.** Publishing exposes **that one tab** to anyone who has the link. The link isn't
> indexed or guessable, but it isn't access-controlled either. **Do not** set the whole file to
> "anyone with the link can view" instead: that would expose every tab, including subject
> records.

An ordinary `/edit` link is refused, and the browser says what to paste instead.

## Option C: Reading and writing over the Sheets API

Only this route lets the **Review** panel write the atlas plate and the Measured flag back.

> **Before starting.** This needs a Google Cloud **service account key**. Creating a Cloud
> project under a `umd.edu` account is blocked by organization policy. Unless that changes, or
> you get a key from a project outside that policy, use Option B.

### One-time setup

1. In the [Google Cloud console](https://console.cloud.google.com), create or pick a project and
   enable the **Google Sheets API**.
2. Go to **IAM & Admin > Service Accounts** and create a service account. It needs no project
   roles.
3. On that account, choose **Keys > Add key > Create new key > JSON**. Save the file **outside
   the repository**. Anyone holding it has the account's access.
4. **Share the spreadsheet** with the account's `client_email`: **Viewer** to read, **Editor**
   to write.
5. In the browser, open **Dataset > Google Sheet Tracker > Configure...** and enter the
   spreadsheet URL, the tab name (default `Sections`), and the key file. **Test Connection**
   confirms it works.

### Enabling write-back

Choose **Dataset > Google Sheet Tracker > Prepare Sheet for Writing...**. It tells you what it
will add and waits for your confirmation. It only **adds** columns and never changes existing
cells. You can undo it from the sheet's version history.

| Column | Purpose |
|---|---|
| `Row UID` | A stable ID for each row that survives sorting, filtering and edits. Managed by the browser; don't edit by hand. |
| `Last Updated` | UTC timestamp of the browser's last write to the row. Managed by the browser. |
| `Measured` | `yes` or blank. You set it from the Review panel. |

### How writes stay safe

- **Rows are found by `Row UID`, never by row number.** Row numbers change when someone sorts or
  inserts rows.
- **Every write re-reads the tab first**, then writes, then reads back to confirm the values
  landed in the intended rows. If a row moved in between, you get
  `SectionTracker:RowMovedDuringWrite` instead of a silent mis-write.
- **Writes stop, rather than guess,** when:
  - criteria match nothing, or the wrong number of rows;
  - a UID is missing or duplicated;
  - you try to write to `Row UID`, `Last Updated`, or a column that doesn't exist.
- **Sections the tracker has no row for are skipped.** The Review panel tells you how many before
  you press the button.

### From the command line

```matlab
tracker = SectionTracker(url, "C:/keys/histology-sheets.json");
tracker.ensureSchema();                                  % safe to run any time

idx = tracker.findRows({"Hemisphere", "L", "Content", "DAPI"});
disp(tracker.Table(idx, :))

tracker.updateRows( ...
    {"Image Filename", "SUBJ-ID-896_2A_L_DAPI_Z1_250408_1"}, ...
    {"Notes", "Profile remeasured"}, expected = 1);
```

`findRows` also accepts a function handle as the criterion:
`tracker.findRows({"Atlas Plate #", @(v) str2double(v) > 20})`.

### Notes

- **Tokens.** Access tokens last an hour and are cached in memory.
- **JVM.** Signing uses Java (`java.security`), so MATLAB must not be started with `-nojvm`. The
  GUI needs the JVM anyway.
- **Everything arrives as text.** Numeric columns are converted where they're used.
