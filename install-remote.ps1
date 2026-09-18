# install-remote.ps1 - one-shot installer, meant to be piped straight into iex:
#
#   irm https://raw.githubusercontent.com/weimasun/px/main/install-remote.ps1 | iex
#
# ASCII only: Windows PowerShell 5.1 parses BOM-less .ps1 files as ANSI (GBK).
#
# It downloads the px files into $HOME/px and then runs install-px.ps1 from
# there, which wires the loader into every PowerShell profile on this machine.
# Re-running it upgrades the scripts in place. px-proxy.txt is never touched,
# so your proxy address survives a reinstall.
#
# NOTE: piping a URL into iex runs whatever that URL serves. Read the file
# first (it is short) if you do not trust the source.

$ErrorActionPreference = 'Stop'

# GitHub raw requires TLS 1.2; old Windows builds default to something weaker.
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

$repo  = 'https://raw.githubusercontent.com/weimasun/px/main'
$dir   = Join-Path $HOME 'px'
$files = @(
    'px.ps1', 'install-px.ps1', 'uninstall-px.ps1', 'verify-px.ps1',
    'px.sh', 'install-px.sh', 'uninstall-px.sh'
)

New-Item -ItemType Directory -Force -Path $dir | Out-Null

foreach ($f in $files) {
    $dst = Join-Path $dir $f
    Invoke-WebRequest -Uri "$repo/$f" -OutFile $dst -UseBasicParsing
    Write-Host "downloaded $f"
}

& (Join-Path $dir 'install-px.ps1')
