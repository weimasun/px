# install-px.ps1 - wire px.ps1 into every PowerShell profile on this machine.
# ASCII only. Idempotent: safe to re-run.
#
#   pwsh.exe -File install-px.ps1
#
# What it does:
#   1. resolves px.ps1 from $PSScriptRoot (no hardcoded absolute path)
#   2. writes that absolute path into every PowerShell profile
#
# Re-running replaces the existing line instead of appending, so moving this
# folder and re-running the script is all it takes to fix the path.

$src   = Join-Path $PSScriptRoot 'px.ps1'
$log   = Join-Path $PSScriptRoot '_install.log'
$lines = @()

if (-not (Test-Path $src)) {
    $lines += "FAIL: px.ps1 not found next to this script: $src"
    $lines | Set-Content -Path $log -Encoding UTF8
    throw "px.ps1 not found: $src"
}

$marker = '# px - single-command proxy prefix'
$loader = $marker + "`n" + 'if (Test-Path "' + $src + '") { . "' + $src + '" }'

$profiles = @(
    (Join-Path $env:USERPROFILE 'Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1'),
    (Join-Path $env:USERPROFILE 'Documents\PowerShell\Microsoft.PowerShell_profile.ps1')
)

foreach ($p in $profiles) {
    $dir = Split-Path $p -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

    # drop the fallback copy left behind by older versions
    $copy = Join-Path $dir 'px.ps1'
    if ((Test-Path $copy) -and ((Get-Content $copy -Raw) -match 'function px')) {
        Remove-Item $copy -Force
        $lines += "OK   removed stale fallback copy: $copy"
    }

    # keep everything that is not a px loader line
    $kept = @()
    if (Test-Path $p) {
        $kept = @(Get-Content $p | Where-Object {
            -not $_.Contains($marker) -and
            -not $_.Contains('px.ps1') -and
            -not $_.Contains('_px')
        })
    }

    Set-Content -Path $p -Value ($kept + $loader) -Encoding UTF8
    $lines += "OK   loader written -> $p"
}

$pol = Get-ExecutionPolicy -Scope CurrentUser
$lines += "CurrentUser ExecutionPolicy (this shell) = $pol"
if ($pol -eq 'Undefined' -or $pol -eq 'Restricted') {
    try {
        Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force
        $lines += "OK   ExecutionPolicy CurrentUser -> RemoteSigned"
    }
    catch { $lines += "WARN could not set ExecutionPolicy: $($_.Exception.Message)" }
}

$lines += "source of truth = $src"
$lines | Set-Content -Path $log -Encoding UTF8
$lines
