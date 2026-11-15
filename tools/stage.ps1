param(
    [Parameter(Mandatory = $true)][string]$FastbootPath,
    [Parameter(Mandatory = $true)][string]$FilePath,
    [Parameter(Mandatory = $true)][string]$Label
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $FilePath)) {
    Write-Host "[ERR] File not found: $FilePath"
    exit 1
}

$bytes = (Get-Item -LiteralPath $FilePath).Length
$mb = [Math]::Round($bytes / 1048576.0, 1)
$outFile = [System.IO.Path]::GetTempFileName()
$errFile = [System.IO.Path]::GetTempFileName()

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$quotedFile = '"' + $FilePath + '"'
$p = Start-Process -FilePath $FastbootPath `
    -ArgumentList @('stage', $quotedFile) `
    -WorkingDirectory (Get-Location).Path `
    -NoNewWindow -PassThru `
    -RedirectStandardOutput $outFile `
    -RedirectStandardError $errFile

$null = $p.Handle

$width = 16
$barW = 4
$pos = 0
$dir = 1
$cr = [char]13

try {
    while (-not $p.WaitForExit(150)) {
        $left = ' ' * $pos
        $right = ' ' * ($width - $barW - $pos)
        $bar = '[' + $left + '<==>' + $right + ']'
        $sec = [int][Math]::Floor($sw.Elapsed.TotalSeconds)
        $mm = [int][Math]::Floor($sec / 60)
        $ss = $sec % 60
        $line = ('    {0} ({1:N1} MB)  {2}  {3:00}:{4:00} elapsed' -f $Label, $mb, $bar, $mm, $ss)
        [Console]::Write($cr + $line.PadRight(68))
        $pos += $dir
        if ($pos -ge ($width - $barW) -or $pos -le 0) {
            $dir = -$dir
        }
    }
    $p.WaitForExit()
} finally {
    $sw.Stop()
    [Console]::Write($cr + (' ' * 70) + $cr)
}

$rc = $p.ExitCode
$secTotal = [Math]::Max(0.1, $sw.Elapsed.TotalSeconds)
$rate = [Math]::Round($mb / $secTotal, 1)

if ($rc -eq 0) {
    Write-Host ('[OK] {0} staged ({1:N1} MB in {2:N1}s @ {3:N1} MB/s)' -f $Label, $mb, $secTotal, $rate)
} else {
    Write-Host ('[ERR] Failed to stage {0} after {1:N1}s (exit code {2})' -f $Label, $secTotal, $rc)
    foreach ($tf in @($outFile, $errFile)) {
        if (Test-Path -LiteralPath $tf) {
            $txt = [System.IO.File]::ReadAllText($tf).Trim()
            if ($txt) { Write-Host $txt }
        }
    }
}

Remove-Item -Force -ErrorAction SilentlyContinue $outFile, $errFile
exit $rc
