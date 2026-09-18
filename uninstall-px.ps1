# uninstall-px.ps1 - remove the px loader and fallback copy from every profile.
# ASCII only. Does NOT delete the px.ps1 in this folder (the source of truth).
# Usage: pwsh.exe -File uninstall-px.ps1

$marker = '# px - single-command proxy prefix'
$log    = Join-Path $PSScriptRoot '_uninstall.log'
$lines  = @()

$profiles = @(
    (Join-Path $env:USERPROFILE 'Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1'),
    (Join-Path $env:USERPROFILE 'Documents\PowerShell\Microsoft.PowerShell_profile.ps1')
)

foreach ($p in $profiles) {
    $dir = Split-Path $p -Parent

    # remove the fallback copy, but only if it really is ours
    $copy = Join-Path $dir 'px.ps1'
    if ((Test-Path $copy) -and ((Get-Content $copy -Raw) -match 'function px')) {
        Remove-Item $copy -Force
        $lines += "OK   removed fallback copy: $copy"
    }

    if (-not (Test-Path $p)) { $lines += "SKIP (no profile): $p"; continue }

    # Same filter as install-px.ps1: the loader is two lines (marker line +
    # the 'if (Test-Path "<...>\px.ps1") { . "<...>\px.ps1" }' line), and only
    # the second one mentions px.ps1. Dropping just the marker would leave px
    # loaded after "uninstall".
    $kept = Get-Content $p | Where-Object {
        -not $_.Contains($marker) -and
        -not $_.Contains('px.ps1') -and
        -not $_.Contains('_px')
    }

    if (-not $kept -or $kept.Count -eq 0) {
        Remove-Item $p -Force
        $lines += "OK   removed empty profile: $p"
    }
    else {
        Set-Content -Path $p -Value $kept -Encoding UTF8
        $lines += "OK   cleaned loader from: $p"
    }
}

$lines += "px.ps1 kept at: $(Join-Path $PSScriptRoot 'px.ps1') (delete manually if no longer needed)"
$lines | Set-Content -Path $log -Encoding UTF8
$lines
