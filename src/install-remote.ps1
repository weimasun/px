# install-remote.ps1 - one-shot installer, meant to be piped straight into iex:
#
#   irm https://raw.githubusercontent.com/weimasun/px/main/src/install-remote.ps1 | iex
#
# ASCII only: Windows PowerShell 5.1 parses BOM-less .ps1 files as ANSI (GBK).
#
# It downloads the px files into $HOME/px, then wires the loader into every
# PowerShell profile on this machine. Re-running it upgrades the scripts in
# place. px-proxy.txt is never touched, so your proxy address survives.
# Idempotent: the loader line is replaced, not appended.
#
# NOTE: piping a URL into iex runs whatever that URL serves. Read the file
# first (it is short) if you do not trust the source.

$ErrorActionPreference = 'Stop'

# GitHub raw requires TLS 1.2; old Windows builds default to something weaker.
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

# Scripts live in src/ in the repo, but they are installed flat into ~/px so
# that px.ps1, px-proxy.txt and the uninstaller all sit in one directory.
$repo  = 'https://raw.githubusercontent.com/weimasun/px/main/src'
$dir   = Join-Path $HOME 'px'
$files = @(
    'px.ps1', 'uninstall-px.ps1', 'verify-px.ps1',
    'px.sh', 'uninstall-px.sh'
)

New-Item -ItemType Directory -Force -Path $dir | Out-Null

foreach ($f in $files) {
    $dst = Join-Path $dir $f
    Invoke-WebRequest -Uri "$repo/$f" -OutFile $dst -UseBasicParsing
    Write-Host "downloaded $f"
}

# --- wire the loader into every PowerShell profile -------------------------

$src = Join-Path $dir 'px.ps1'
if (-not (Test-Path $src)) { throw "px.ps1 not found: $src" }

$marker = '# px - single-command proxy prefix'
$loader = $marker + "`n" + 'if (Test-Path "' + $src + '") { . "' + $src + '" }'

$profiles = @(
    (Join-Path $env:USERPROFILE 'Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1'),
    (Join-Path $env:USERPROFILE 'Documents\PowerShell\Microsoft.PowerShell_profile.ps1')
)

foreach ($p in $profiles) {
    $pdir = Split-Path $p -Parent
    if (-not (Test-Path $pdir)) { New-Item -ItemType Directory -Path $pdir -Force | Out-Null }

    # drop the fallback copy left behind by older versions
    $copy = Join-Path $pdir 'px.ps1'
    if ((Test-Path $copy) -and ((Get-Content $copy -Raw) -match 'function px')) {
        Remove-Item $copy -Force
        Write-Host "removed stale fallback copy: $copy"
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
    Write-Host "loader written -> $p"
}

$pol = Get-ExecutionPolicy -Scope CurrentUser
if ($pol -eq 'Undefined' -or $pol -eq 'Restricted') {
    try {
        Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force
        Write-Host 'ExecutionPolicy CurrentUser -> RemoteSigned'
    }
    catch { Write-Host "WARN could not set ExecutionPolicy: $($_.Exception.Message)" }
}

Write-Host "px.ps1 = $src"
Write-Host ('Open a new shell, or run:  . "' + $src + '"')
