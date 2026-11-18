# Lab Database and Provenance

Every analysis run keeps a record of what it read, what it wrote, and the code and settings
that produced it. This record is the run's **provenance**. It is saved as a small file next to
the run's outputs, so it is there whether or not the lab database is set up, reachable, or even
installed. When it is, the same record also goes to the lab database
([CarasLabDB](https://github.com/dstolz/CarasLabDB)), the lab's shared log of what happened
to every animal and file.

**Nothing an analysis computes or writes depends on the database.** Results are the same
whatever the database's state. A database that is off, unreachable or missing never slows
an analysis down or stops it. The tests check this (see [Testing](#testing) below).

## What is recorded

These runs keep a provenance record:

| Run | Recorded as | Inputs | Outputs |
|---|---|---|---|
| `histdb.saveTracked` (used by `S_ECManalysis` to save the browser export) | `histology_analysis/browser_export` | the values, ROI and surface files of the table's rows | the `.mat` |
| `ecm_attach_project_info(..., SaveTo=)` | `histology_analysis/ecm_attach_project` | the project sheet CSV, `InputFiles` | the saved `full.mat` |
| `ecm_export_for_r` | `histology_analysis/ecm_export_for_r` | the `full.mat` | the profiles and sections CSVs |
| `batch_detect_brain_surface` | `histology_analysis/batch_detect_brain_surface` | the ROI files and images | the surface marks it wrote, the report CSV |
| Saving an ROI edit in the browser | `histology_analysis/roi_edit` | the image measured | the `.roi`, values and surface files |
| ECM Browser **Save plot** / **Save data** | `histology_analysis/ecm_browser_plot` / `_data` | `sourceFiles` of the analysis | the file saved |

Each record is a JSON file in a `.provenance` folder next to the run's first output:
`<folder>\.provenance\<time>_<step>_<id>.json`. Its format is `histology-provenance/1`. A
run with no outputs, or whose output folder can't be written, keeps its record in
`%LOCALAPPDATA%\histology_analysis\provenance`.

A record holds:

- `run_id`: becomes the event's id in the database.
- `pipeline_name` and `subject_id`: the subject is set when the run is about one subject.
- `code_version`: the commit, with `-dirty` when there are uncommitted changes.
- `matlab_release`, `host`, `os_user`.
- `started_at`, `finished_at`, `status` and `error`.
- `parameters`: the settings the run used. For an ECM Browser export, these are the view, as
  **Copy code** would write it.
- `inputs` and `outputs`: each file's path, size, time and SHA-256. An output that
  overwrote a file also has `replaces_sha256`, the hash of the bytes it replaced.

## Sending records to the lab database

The `histdb` package is the only code that talks to the database. It uses the client every lab
toolbox on a computer shares: the `+labclient` package of a CarasLabDB checkout. All toolboxes
on a computer share one setup, one password, one outbox and one sender.

- **Finding the client.** The client is looked for in the folder `CARASLABDB_DIR` names, then
  in a `CarasLabDB` folder next to this checkout (`C:\src\CarasLabDB`).
  `histdb.available()` says whether it was found.
- **Turning it on.** Set up the database in the shared Database window, `histdb.openWindow()`,
  where you enter the server, your login and the storage roots. From then on, each run's
  record also goes to the outbox and is sent when the server answers.
- **Runs made before that.** Records kept while the database was off, or before the client
  was installed, are still on disk. `histdb.backfill("D:/GM6001_HISTOLOGY")` puts every one
  the outbox doesn't hold yet into it. Running it twice is harmless: the database writes a
  record once.
- **Storage roots.** A file is registered in the database by its path below a storage root
  (the lab NAS). A record whose files are under no root mapped on this computer waits in the
  outbox until you map the root in the Database window.

## Testing

`tools\Run-Tests.ps1` runs the test suites in a MATLAB on a hidden desktop, so test windows
never come over yours. Add `-Visible` to watch a run. It exits with 0 when everything passes
and 1 when something fails.

```powershell
tools\Run-Tests.ps1                         # every suite
tools\Run-Tests.ps1 HistdbRunTest           # one suite
tools\Run-Tests.ps1 -WithoutClient          # as on a computer without CarasLabDB
$env:CARASLABDB_DIR = 'D:\code\CarasLabDB'; tools\Run-Tests.ps1 HistdbInvarianceTest
```

`HistdbInvarianceTest` runs the ECM pipeline with no client, with the database off, with the
server unreachable and with it answering. It checks that the tables, the CSVs for R and the
prepared analysis are the same every time. `HistdbClientTest` checks that records reach the
outbox and are sent once. Both use the client's fake server, so no database is needed.
