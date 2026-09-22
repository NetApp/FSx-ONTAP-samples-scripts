<#
.SYNOPSIS
    Reads every file in a CIFS/SMB share to force promotion of capacity-tier
    (cold/tiered) data back to the performance tier on an FSx for ONTAP volume.

.DESCRIPTION
    ONTAP's tiering scanner intentionally avoids promoting data when it detects
    a sequential, backup-like read pattern (to avoid backup/AV jobs needlessly
    re-filling the performance tier). This script defeats that detection by
    reading each file's blocks in reverse order (or random order) instead of
    front-to-back, so the read pattern looks like real client access rather
    than a scan.

    This is a native Windows/PowerShell port of NetApp's warm_performance_tier
    bash script (NFS-only) for environments with no Linux available.

.PARAMETER Path
    UNC path or mapped drive letter to the share/volume root, e.g. \\fsx-server\myshare

.PARAMETER ThreadCount
    Number of files to read in parallel. Default 8.

.PARAMETER BlockSizeMB
    Block size in MB used for the out-of-order reads. Default 2 (matches the
    original script's default of 2MB).

.PARAMETER ReadMethod
    'Reverse' (read blocks back-to-front) or 'Random' (shuffle block order).
    Default 'Reverse'.

.PARAMETER BatchSize
    How many files to queue at once before waiting for that batch to finish.
    Bounds memory usage on volumes with very large file counts. Default is
    ThreadCount * 4.

.PARAMETER Help
    Print invocation usage and exit.

.NOTES
    Promotion observed on FSx for ONTAP has been gradual rather than
    immediate - a single pass over a volume may only promote a small
    fraction of the read data back to the performance tier, with the rest
    following over subsequent passes. Expect to run this multiple times
    (or in a loop until volume footprint stabilizes) rather than a single
    one-shot sweep for full promotion.

.EXAMPLE
    .\WarmPerformanceTier.ps1 -Path \\fsx-server\myshare -ThreadCount 12

.EXAMPLE
    .\WarmPerformanceTier.ps1 -Path Z:\ -ReadMethod Random -BlockSizeMB 4

.EXAMPLE
    .\WarmPerformanceTier.ps1 -Help
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "")] # Since the GitHub PS Lint thinks $VerboseProgress is unused.

[CmdletBinding(DefaultParameterSetName = 'Run')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'Run', Position = 0)]
    [string]$Path,

    [Parameter(ParameterSetName = 'Run')]
    [ValidateRange(1, 1024)]
    [int]$ThreadCount = 8,

    [Parameter(ParameterSetName = 'Run')]
    [ValidateScript({ $_ -gt 0 -and ([int64]$_ * 1MB) -le [int]::MaxValue })]
    [int]$BlockSizeMB = 2,

    [Parameter(ParameterSetName = 'Run')]
    [ValidateSet('Reverse', 'Random')]
    [string]$ReadMethod = 'Reverse',

    [Parameter(ParameterSetName = 'Run')]
    [int]$BatchSize = 0,

    [Parameter(ParameterSetName = 'Run')]
    [switch]$VerboseProgress,

    [Parameter(ParameterSetName = 'Help')]
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Host @"
Usage: .\WarmPerformanceTier.ps1 -Path <unc_or_drive> [-ThreadCount n] [-BlockSizeMB n] [-ReadMethod Reverse|Random] [-BatchSize n] [-VerboseProgress] [-Help]

Where:
  -Path            UNC path or mapped drive to the share/volume root (required).
                   Example: \\fsx-server\myshare  or  Z:\
  -ThreadCount     Number of files to read in parallel. Default: 8
  -BlockSizeMB     Block size in MB for out-of-order reads. Default: 2
  -ReadMethod      Reverse (back-to-front) or Random. Default: Reverse
  -BatchSize       Files to queue before waiting. Default: ThreadCount * 4
  -VerboseProgress Print extra progress lines in addition to the progress bar
  -Help            Print this help and exit

Examples:
  .\WarmPerformanceTier.ps1 -Path \\fsx-server\myshare -ThreadCount 12
  .\WarmPerformanceTier.ps1 -Path Z:\ -ReadMethod Random -BlockSizeMB 4
"@
    return
}

if ($BatchSize -le 0) {
    $BatchSize = $ThreadCount * 4
}

if (-not (Test-Path -LiteralPath $Path)) {
    throw "Path '$Path' does not exist or is not accessible."
}

Write-Host "Streaming files under '$Path' and reading with $ThreadCount parallel workers (method: $ReadMethod, block size: ${BlockSizeMB}MB, batch size: $BatchSize)..."

$blockSize = [int64]$BlockSizeMB * 1MB

# Script block executed inside each runspace. Reads the file's blocks out of
# sequential order and discards the contents - the goal is purely to trigger
# ONTAP's read-driven promotion, not to use the data.
$readScriptBlock = {
    param($filePath, $blockSize, $readMethod)

    try {
        $fs = [System.IO.File]::Open(
            $filePath,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::ReadWrite
        )
        try {
            $length = $fs.Length
            if ($length -eq 0) {
                return [PSCustomObject]@{ Path = $filePath; Success = $true; Bytes = 0 }
            }

            $buffer = New-Object byte[] $blockSize
            $totalBlocks = [math]::Ceiling($length / $blockSize)

            if ($readMethod -eq 'Reverse') {
                $blockOrder = ($totalBlocks - 1)..0
            }
            else {
                $blockOrder = 0..($totalBlocks - 1) | Get-Random -Count $totalBlocks
            }

            foreach ($i in $blockOrder) {
                $offset = [int64]$i * $blockSize
                $toRead = [Math]::Min($blockSize, $length - $offset)
                if ($toRead -le 0) { continue }
                [void]$fs.Seek($offset, [System.IO.SeekOrigin]::Begin)
                $remaining = [int]$toRead
                while ($remaining -gt 0) {
                    $bytesRead = $fs.Read($buffer, 0, $remaining)
                    if ($bytesRead -eq 0) {
                        throw "Unexpected end of file while reading '$filePath'."
                    }
                    $remaining -= $bytesRead
                 }
            }
            return [PSCustomObject]@{ Path = $filePath; Success = $true; Bytes = $length }
        }
        finally {
            $fs.Dispose()
        }
    }
    catch {
        return [PSCustomObject]@{ Path = $filePath; Success = $false; Error = $_.Exception.Message }
    }
}

$sessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
$pool = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool(1, $ThreadCount, $sessionState, $Host)
$pool.Open()

$startTime = Get-Date
$doneCount = 0
$errorCount = 0
$errorList = New-Object System.Collections.Generic.List[string]

function Wait-AndCollect($jobs) {
    foreach ($job in $jobs) {
        $result = $job.Pipeline.EndInvoke($job.Handle)
        $job.Pipeline.Dispose()
        $script:doneCount++
        if ($result.Success -eq $false) {
            $script:errorCount++
            $script:errorList.Add("$($result.Path): $($result.Error)")
        }
    }
}

$batch = New-Object System.Collections.Generic.List[object]
$queuedCount = 0
$enumerationErrors = @()

# Get-ChildItem streams FileInfo objects one at a time as it walks the tree,
# and piping straight into ForEach-Object dispatches each file to the worker
# queue as soon as it is discovered - the full listing is never held in
# memory, so this scales to directories with very large file counts.
Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction SilentlyContinue -ErrorVariable enumerationErrors |
    ForEach-Object {
        $file = $_
        $queuedCount++

        $ps = [System.Management.Automation.PowerShell]::Create()
        $ps.RunspacePool = $pool
        [void]$ps.AddScript($readScriptBlock).AddArgument($file.FullName).AddArgument($blockSize).AddArgument($ReadMethod)
        $handle = $ps.BeginInvoke()
        $batch.Add([PSCustomObject]@{ Pipeline = $ps; Handle = $handle; File = $file.FullName })

        if ($batch.Count -ge $BatchSize) {
            Wait-AndCollect $batch
            $batch.Clear()

            $elapsed = (Get-Date) - $startTime
            Write-Progress -Activity "Warming performance tier" -Status "$doneCount processed, $queuedCount queued so far ($errorCount errors)"
            if ($VerboseProgress) {
                Write-Host ("[{0:hh\:mm\:ss}] {1} processed, {2} queued so far, {3} errors" -f $elapsed, $doneCount, $queuedCount, $errorCount)
            }
        }
    }

# Drain the final partial batch.
if ($batch.Count -gt 0) {
    Wait-AndCollect $batch
}

$pool.Close()
$pool.Dispose()

$elapsed = (Get-Date) - $startTime
Write-Progress -Activity "Warming performance tier" -Completed

if ($enumerationErrors.Count -gt 0) {
    Write-Warning "Encountered $($enumerationErrors.Count) errors while enumerating files. Some files may be skipped."
}

if ($queuedCount -eq 0) {
    Write-Host "No files found under '$Path'. Nothing to do."
    return
}

Write-Host ""
Write-Host "Done in $($elapsed.ToString('hh\:mm\:ss')). Processed $doneCount files, $errorCount errors."
if ($errorCount -gt 0) {
    Write-Host "Errors:"
    $errorList | ForEach-Object { Write-Host "  $_" }
    exit 1
}
