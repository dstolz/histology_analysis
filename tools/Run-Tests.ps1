<#
.SYNOPSIS
Run the histology_analysis test suites in a MATLAB on a desktop of its own, with a log and an exit code.

.DESCRIPTION
Starts MATLAB (R2025a when installed) with -logfile and
-batch "cd('<repo>\tools'); run_histology_tests({...}, DialogWatch=..., ResultsCSV=...)",
its preferences in a folder of this run's own under %LOCALAPPDATA%\histology_analysis\prefdir (never
yours), echoes the log as it grows, and exits with MATLAB's exit code: 0 = every test passed; 1 = a test
failed; 3 = a dialog waits for a person; 124 = killed at the timeout; 2 = usage.

Windows: MATLAB runs on a desktop that is never shown (Win32 CreateDesktop, "histology_analysis_tests"),
so the browsers and figures the tests open are drawn there and never come over your windows or take the
focus. -Visible runs it on your desktop instead, to watch.

Dialogs that wait for a person: nobody can answer one on the hidden desktop, so the run looks for them
(run_histology_tests DialogWatch=-DialogSec prints "[needs you]" lines, and the native dialog windows of
the run's processes are looked for every 10 s) and prints an "ACTION NEEDED" block naming the dialog, the
code that asked and the command to run it on your desktop with -Interactive. Without -Interactive the run
is then stopped (exit 3). Under -batch MATLAB refuses its own blocking dialogs (questdlg, uiconfirm,
uigetfile, ...); that prints the block too, and exits 3.

-WithoutClient sets HISTDB_NO_CLIENT=1 for the run, so the lab database client (CarasLabDB) is never
added to MATLAB's path: the run proves the analyses work with the client absent.

.PARAMETER Suites
Suite names: test classes under tests\ (EcmAttachProjectInfoTest) or the function-style suites
(test_histology_browser, test_section_tracker). None runs every suite.

.PARAMETER Command
Run this MATLAB expression instead of the suites (after the same path setup), for a one-off check
that must not come onto your desktop either.

.PARAMETER Visible
Run MATLAB on your desktop, so the windows the tests open can be watched.

.PARAMETER Interactive
Run MATLAB on your desktop with -r instead of -batch, so a dialog the tests open waits for your answer
(implies -Visible).

.PARAMETER WithoutClient
Run with the lab database client kept off the path (HISTDB_NO_CLIENT=1).

.PARAMETER DialogSec
Seconds a dialog may wait before it counts as waiting for a person (default 30).

.PARAMETER TimeoutMin
Minutes after which MATLAB is killed (exit 124). Default 30.

.PARAMETER DryRun
Print the MATLAB command and run nothing.

.EXAMPLE
tools\Run-Tests.ps1
tools\Run-Tests.ps1 EcmAttachProjectInfoTest test_section_tracker
tools\Run-Tests.ps1 -WithoutClient HistdbInvarianceTests
tools\Run-Tests.ps1 -Command "disp(histology_code_version())"
tools\Run-Tests.ps1 test_histology_browser -Interactive
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)] [string[]] $Suites = @(),
    [string] $Command = '',
    [switch] $Visible,
    [switch] $Interactive,
    [switch] $WithoutClient,
    [ValidateRange(5, 3600)] [int] $DialogSec = 30,
    [int] $TimeoutMin = 30,
    [string] $MatlabRoot = '',
    [string] $LogDir = '',
    [switch] $DryRun
)

$ErrorActionPreference = 'Stop'
if ($Interactive) { $Visible = [switch]::Present }

$pieces = @()
foreach ($s in $Suites) { foreach ($p in ($s -split '[\s,]+')) { if ($p) { $pieces += $p } } }
$Suites = $pieces

$repo = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$tools = Join-Path $repo 'tools'
$appData = Join-Path $env:LOCALAPPDATA 'histology_analysis'
if (-not $LogDir) { $LogDir = Join-Path $appData 'logs' }
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Force $LogDir | Out-Null }

function Find-MatlabRoot {
    $roots = @()
    if ($MatlabRoot) { $roots += $MatlabRoot }
    if ($env:HISTOLOGY_MATLAB_ROOT) { $roots += $env:HISTOLOGY_MATLAB_ROOT }
    $roots += (Join-Path $env:ProgramFiles 'MATLAB\R2025a')
    $all = Get-ChildItem (Join-Path $env:ProgramFiles 'MATLAB') -Directory -Filter 'R20*' -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending
    foreach ($r in $all) { $roots += $r.FullName }
    $cmd = Get-Command matlab -ErrorAction SilentlyContinue
    if ($cmd) { $roots += (Split-Path -Parent (Split-Path -Parent $cmd.Source)) }
    foreach ($r in $roots) {
        if ($r -and (Test-Path (Join-Path $r 'bin\win64\MATLAB.exe'))) { return $r }
    }
    throw "No MATLAB found (looked under -MatlabRoot, HISTOLOGY_MATLAB_ROOT, $env:ProgramFiles\MATLAB\R20*)."
}

# ---- the MATLAB command --------------------------------------------------------------------------

$root = Find-MatlabRoot
$exe = Join-Path $root 'bin\matlab.exe'
$release = Split-Path -Leaf $root
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$tag = 'all'
if ($Command) { $tag = 'command' } elseif ($Suites.Count -gt 0) { $tag = $Suites[0]; if ($Suites.Count -gt 1) { $tag += "_+$($Suites.Count - 1)" } }
if ($WithoutClient) { $tag += '_noclient' }
$log = Join-Path $LogDir "${stamp}_$tag.log"
$csv = Join-Path $LogDir "${stamp}_$tag.csv"

if ($Command) {
    # the expression may hold double quotes (MATLAB strings); the command line carries them doubled
    $cmd = "cd('$tools'); run_histology_tests(Setup=true); " + $Command
} else {
    $opts = @("DialogWatch=$DialogSec", "ResultsCSV='$csv'")
    if ($Suites.Count -gt 0) { $list = "{'" + ($Suites -join "','") + "'}"; $argList = $list + ', ' + ($opts -join ', ') }
    else { $argList = $opts -join ', ' }
    $cmd = "cd('$tools'); run_histology_tests($argList);"
}
$cmdLine = $cmd.Replace('"', '""')

function Get-MatlabArgs {
    if ($Interactive) {
        $rCmd = "try, $cmdLine; catch e, fprintf(2, '%s\n', getReport(e)); exit(1); end; exit(0)"
        return @('-wait', '-nodesktop', '-nosplash', '-minimize', '-logfile', "`"$log`"", '-r', "`"$rCmd`"")
    }
    return @('-wait', '-logfile', "`"$log`"", '-batch', "`"$cmdLine`"")
}

if ($DryRun) {
    Write-Host ("$exe " + ((Get-MatlabArgs) -join ' '))
    exit 0
}

# ---- the hidden desktop --------------------------------------------------------------------------

$HiddenDesktopSource = @'
using System;
using System.Runtime.InteropServices;
using System.Text;

// A process started on a desktop that is never shown: its windows (and its children's, which inherit
// the desktop) cannot come over the user's windows or take the focus. Id, HasExited and ExitCode
// as on System.Diagnostics.Process. DialogWindows finds the native dialogs (class #32770: file
// pickers, message boxes) that given processes show, on that desktop or on the user's.
public class HistologyTestDesktop {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct STARTUPINFO {
        public int cb; public string lpReserved; public string lpDesktop; public string lpTitle;
        public int dwX, dwY, dwXSize, dwYSize, dwXCountChars, dwYCountChars, dwFillAttribute, dwFlags;
        public short wShowWindow, cbReserved2;
        public IntPtr lpReserved2, hStdInput, hStdOutput, hStdError;
    }
    [StructLayout(LayoutKind.Sequential)]
    struct PROCESS_INFORMATION { public IntPtr hProcess, hThread; public int dwProcessId, dwThreadId; }

    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern IntPtr CreateDesktop(string name, IntPtr device, IntPtr devmode, int flags, uint access, IntPtr sa);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern bool CreateProcess(string app, StringBuilder cmd, IntPtr pa, IntPtr ta, bool inherit,
        uint flags, IntPtr env, string dir, ref STARTUPINFO si, out PROCESS_INFORMATION pi);
    [DllImport("kernel32.dll")] static extern uint WaitForSingleObject(IntPtr h, uint ms);
    [DllImport("kernel32.dll")] static extern bool GetExitCodeProcess(IntPtr h, out uint code);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
    delegate bool EnumWindowsProc(IntPtr hwnd, IntPtr lParam);
    [DllImport("user32.dll")] static extern bool EnumDesktopWindows(IntPtr desk, EnumWindowsProc fn, IntPtr lParam);
    [DllImport("user32.dll")] static extern IntPtr GetThreadDesktop(uint threadId);
    [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr hwnd);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr hwnd, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr hwnd, StringBuilder s, int n);

    const uint GENERIC_ALL = 0x10000000, CREATE_NEW_CONSOLE = 0x10;
    const int STARTF_USESHOWWINDOW = 1; const short SW_HIDE = 0;
    static IntPtr desktop = IntPtr.Zero;   // held open for the life of this PowerShell

    IntPtr handle;
    public int Id { get; private set; }

    public static HistologyTestDesktop Start(string desktopName, string commandLine) {
        if (desktop == IntPtr.Zero) {
            desktop = CreateDesktop(desktopName, IntPtr.Zero, IntPtr.Zero, 0, GENERIC_ALL, IntPtr.Zero);
            if (desktop == IntPtr.Zero) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
        }
        var si = new STARTUPINFO();
        si.cb = Marshal.SizeOf(typeof(STARTUPINFO));
        si.lpDesktop = @"WinSta0\" + desktopName;
        si.dwFlags = STARTF_USESHOWWINDOW; si.wShowWindow = SW_HIDE;
        PROCESS_INFORMATION pi;
        if (!CreateProcess(null, new StringBuilder(commandLine), IntPtr.Zero, IntPtr.Zero, false,
                CREATE_NEW_CONSOLE, IntPtr.Zero, null, ref si, out pi))
            throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
        CloseHandle(pi.hThread);
        var p = new HistologyTestDesktop();
        p.handle = pi.hProcess; p.Id = pi.dwProcessId;
        return p;
    }
    public bool HasExited { get { return WaitForSingleObject(handle, 0) == 0; } }
    public int ExitCode { get { uint c; GetExitCodeProcess(handle, out c); return unchecked((int)c); } }

    // the titles of the visible native dialogs of processes PIDS, on the hidden desktop or on the user's
    public static string[] DialogWindows(int[] pids, bool onHidden) {
        var found = new System.Collections.Generic.List<string>();
        IntPtr desk = onHidden ? desktop : GetThreadDesktop(GetCurrentThreadId());
        if (desk == IntPtr.Zero) return found.ToArray();
        var want = new System.Collections.Generic.HashSet<int>(pids);
        EnumDesktopWindows(desk, (hwnd, l) => {
            uint pid; GetWindowThreadProcessId(hwnd, out pid);
            if (!want.Contains((int)pid) || !IsWindowVisible(hwnd)) return true;
            var cls = new StringBuilder(64); GetClassName(hwnd, cls, cls.Capacity);
            if (cls.ToString() != "#32770") return true;
            var title = new StringBuilder(256); GetWindowText(hwnd, title, title.Capacity);
            found.Add(title.ToString());
            return true;
        }, IntPtr.Zero);
        return found.ToArray();
    }
}
'@

if (-not ('HistologyTestDesktop' -as [type])) { Add-Type -TypeDefinition $HiddenDesktopSource -Language CSharp }

function Start-Matlab($argList) {
    # MATLAB on the hidden desktop (default) or on the user's; the environment (MATLAB_PREFDIR,
    # HISTDB_NO_CLIENT) is this process's
    if ($Visible) { return Start-Process -FilePath $exe -ArgumentList $argList -PassThru -WindowStyle Hidden }
    return [HistologyTestDesktop]::Start('histology_analysis_tests', "`"$exe`" " + ($argList -join ' '))
}

function Get-ProcessTree($rootId) {
    $all = @(Get-CimInstance Win32_Process -Property ProcessId, ParentProcessId -ErrorAction SilentlyContinue)
    $ids = @([int]$rootId); $i = 0
    while ($i -lt $ids.Count) {
        foreach ($p in $all) { if ($p.ParentProcessId -eq $ids[$i] -and $ids -notcontains [int]$p.ProcessId) { $ids += [int]$p.ProcessId } }
        $i++
    }
    return [int[]]$ids
}

function Stop-MatlabTree($launcherId) {
    $ids = Get-ProcessTree $launcherId
    [array]::Reverse($ids)
    foreach ($id in $ids) { Stop-Process -Id $id -Force -ErrorAction SilentlyContinue }
}

$state = [pscustomobject]@{ Offset = 0; Tail = ''; Needs = $false; Told = @{}; NativeSince = @{}; LastNativeCheck = (Get-Date) }

function Show-ActionNeeded([string] $what, [string] $where, [string] $suite, [switch] $Refused) {
    $rerun = ($Suites | ForEach-Object { "'$_'" }) -join ' '
    if ($suite) { $rerun = "'$suite'" }
    $bar = '!' * 100
    Write-Host ''
    Write-Host $bar -ForegroundColor Yellow
    Write-Host '!!  ACTION NEEDED: a test is waiting for an answer from a person' -ForegroundColor Yellow
    Write-Host "!!  dialog:  $what" -ForegroundColor Yellow
    if ($where) { Write-Host "!!  where:   $where" -ForegroundColor Yellow }
    if ($Interactive) {
        Write-Host '!!  Answer it on your screen now (the window named above); the run goes on once you have.' -ForegroundColor Yellow
    } elseif ($Refused) {
        Write-Host '!!  Under -batch MATLAB cannot show it, so the test failed (exit 3). To answer it yourself:' -ForegroundColor Yellow
        Write-Host "!!    tools\Run-Tests.ps1 $rerun -Interactive" -ForegroundColor Yellow
    } else {
        Write-Host '!!  Nobody can answer it on the hidden desktop, so this run stops (exit 3). To answer it yourself:' -ForegroundColor Yellow
        Write-Host "!!    tools\Run-Tests.ps1 $rerun -Interactive" -ForegroundColor Yellow
    }
    Write-Host $bar -ForegroundColor Yellow
    $state.Needs = $true
}

function Find-WaitingDialogs($proc, [string] $txt) {
    $text = $state.Tail + $txt
    $lines = $text -split "`r?`n"
    $state.Tail = $lines[-1]
    $complete = @(); if ($lines.Count -gt 1) { $complete = $lines[0..($lines.Count - 2)] }
    foreach ($line in $complete) {
        if ($line -match '^\[needs you\] (.*)$') {
            $parts = $matches[1] -split ' \| '
            $suite = ''
            $t = $parts | Where-Object { $_ -like 'test *' } | Select-Object -First 1
            if ($t -and $t -match '^test ([A-Za-z0-9_]+)') { $suite = $matches[1] }
            $asked = ($parts | Where-Object { $_ -like 'asked by *' } | Select-Object -First 1)
            if (-not $state.Told.ContainsKey($line)) { $state.Told[$line] = $true; Show-ActionNeeded $parts[0] $asked $suite }
        }
        elseif ($line -match 'Creating dialog boxes that block execution is not supported' -and -not $state.Told.ContainsKey('refused')) {
            $state.Told['refused'] = $true
            Show-ActionNeeded 'one of MATLAB''s own dialogs (questdlg, uiconfirm, uigetfile, ...)' `
                'the failure report above (its stack names the code that asked and the test line)' '' -Refused
        }
    }
    if (((Get-Date) - $state.LastNativeCheck).TotalSeconds -ge 10) {
        $state.LastNativeCheck = Get-Date
        $titles = @([HistologyTestDesktop]::DialogWindows((Get-ProcessTree $proc.Id), -not $Visible))
        foreach ($k in @($state.NativeSince.Keys)) { if ($titles -notcontains $k) { $state.NativeSince.Remove($k) } }
        foreach ($t in $titles) {
            if (-not $state.NativeSince.ContainsKey($t)) { $state.NativeSince[$t] = Get-Date; continue }
            if (((Get-Date) - $state.NativeSince[$t]).TotalSeconds -ge $DialogSec -and -not $state.Told.ContainsKey("native:$t")) {
                $state.Told["native:$t"] = $true
                Show-ActionNeeded "a Windows dialog `"$t`" (a file picker or message box)" '' ''
            }
        }
    }
}

function Read-NewText($path) {
    if (-not (Test-Path $path)) { return '' }
    $fs = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    try {
        if ($fs.Length -le $state.Offset) { return '' }
        [void] $fs.Seek($state.Offset, [IO.SeekOrigin]::Begin)
        $buf = New-Object byte[] ($fs.Length - $state.Offset)
        $n = $fs.Read($buf, 0, $buf.Length)
        $state.Offset += $n
        return [Text.Encoding]::UTF8.GetString($buf, 0, $n)
    } finally { $fs.Dispose() }
}

# ---- run -----------------------------------------------------------------------------------------

# A preferences folder of this run's own: two runs never share matlabprefs.mat, and neither touches yours.
$prefDir = Join-Path $appData ("prefdir\{0}-{1}-{2}" -f $release, $stamp, $PID)
New-Item -ItemType Directory -Force $prefDir | Out-Null
$env:MATLAB_PREFDIR = $prefDir
if ($WithoutClient) { $env:HISTDB_NO_CLIENT = '1' } else { Remove-Item Env:\HISTDB_NO_CLIENT -ErrorAction SilentlyContinue }

Write-Host "MATLAB: $root"
Write-Host "command: $cmd"
Write-Host "log: $log"
$started = Get-Date
$exitCode = $null
$proc = $null
try {
    $proc = Start-Matlab (Get-MatlabArgs)
    if ($Interactive) {
        Write-Host "`n-Interactive: MATLAB runs on your desktop; a dialog a test opens waits for your answer. Watch this"
        Write-Host 'output for ACTION NEEDED: it names the window to answer.'
    }
    $deadline = $started.AddMinutes($TimeoutMin)
    while ($true) {
        $txt = Read-NewText $log
        if ($txt) { Write-Host -NoNewline $txt }
        Find-WaitingDialogs $proc $txt
        if ($proc.HasExited) {
            $exitCode = $proc.ExitCode
            $txt = Read-NewText $log
            if ($txt) { Write-Host -NoNewline $txt; Find-WaitingDialogs $proc ($txt + "`n") }
            break
        }
        if ($state.Needs -and -not $Interactive) {
            Write-Host "`nStopping MATLAB $($proc.Id): a dialog needs a person (see above)."
            Stop-MatlabTree $proc.Id
            $exitCode = 3
            break
        }
        if ((Get-Date) -gt $deadline) {
            Write-Host "`nTimeout after $TimeoutMin min: killing MATLAB $($proc.Id)."
            Stop-MatlabTree $proc.Id
            $exitCode = 124
            break
        }
        Start-Sleep -Seconds 2
    }
} finally {
    if ($null -ne $proc -and -not $proc.HasExited) { Stop-MatlabTree $proc.Id }
    Remove-Item -Recurse -Force $prefDir -ErrorAction SilentlyContinue
}

if ($state.Needs -and -not $Interactive -and $exitCode -ne 124) { $exitCode = 3 }
$elapsed = [math]::Round(((Get-Date) - $started).TotalSeconds)
$verdict = switch ($exitCode) { 0 { 'Passed' } 3 { 'ACTION NEEDED (a dialog waits for a person; see above)' } 124 { 'Timed out' } default { 'Failed' } }
Write-Host ("`n{0} in {1} s (exit {2}); log {3}" -f $verdict, $elapsed, $exitCode, $log)
exit $exitCode
