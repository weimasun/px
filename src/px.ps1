# px.ps1 - run ONE command through a proxy, then restore env vars.
# ASCII only: Windows PowerShell 5.1 parses BOM-less .ps1 files as ANSI (GBK).
#
# Usage:
#   px git clone https://github.com/foo/bar.git      # run through the proxy
#   px --set 127.0.0.1:8080                          # change the default
#   px                                               # usage + current default
#
# The address has ONE source: px-proxy.txt next to this file, written by --set.
# There is no env-var override and no hardcoded fallback; if the file is
# missing or blank, px refuses to run instead of guessing an address.
#
# NOTE 1: Windows environment variable names are case-insensitive, so setting
# both HTTP_PROXY and http_proxy would be the same variable. Only the
# uppercase form is used.
#
# NOTE 2: "Remove-Item Env:X" silently fails to delete a variable that was
# inherited from the parent process (verified on PS 7.6.5). The .NET
# SetEnvironmentVariable API is used instead - it always takes effect.

$script:PxDir = $PSScriptRoot
if (-not $script:PxDir) {
    # Path is $null (not just empty) when piped in with `irm <url> | iex`, and
    # Split-Path rejects a null Path - check it before calling.
    $pxSelf = $MyInvocation.MyCommand.Path
    if ($pxSelf) { $script:PxDir = Split-Path -Parent $pxSelf }
}
# Both are empty when this file is piped in with `irm <url> | iex`. Fall back to
# the same directory install-remote.ps1 uses, so a session-only px still reads
# and writes the same px-proxy.txt as an installed one.
if (-not $script:PxDir) { $script:PxDir = Join-Path $HOME 'px' }
$script:PxVars        = @('HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'NO_PROXY')

function script:ConvertTo-PxUrl {
    param([string]$Addr)
    $Addr = $Addr.Trim()
    if ($Addr -eq '') { return '' }
    if ($Addr -notmatch '^[a-zA-Z][a-zA-Z0-9+.-]*://') { $Addr = 'http://' + $Addr }
    return $Addr
}

function script:Get-PxProxy {
    # Single source: px-proxy.txt, written by --set. Returns '' when unset.
    $cfg = Join-Path $script:PxDir 'px-proxy.txt'
    if (Test-Path $cfg) {
        $v = [string](Get-Content $cfg -Raw)
        if ($v.Trim() -ne '') { return (ConvertTo-PxUrl $v) }
    }

    return ''
}

function script:Test-PxProxy {
    param([string]$Url)
    if ($Url) { return $true }
    Write-Host 'px: no proxy configured, run: px --set <addr>' -ForegroundColor Red
    return $false
}

function px {
    if (-not $args -or $args.Count -eq 0) {
        Write-Host 'Usage: px <command> [args...]'
        Write-Host '       px --set <addr>     set the default proxy'
        $cur = Get-PxProxy
        Write-Host ('Default proxy: ' + $(if ($cur) { $cur } else { '(not set)' }))
        return
    }

    if ($args[0] -eq '--set') {
        if ($args.Count -lt 2) { Write-Host 'px: --set needs an address'; return }
        $u = ConvertTo-PxUrl $args[1]
        # No BOM and no trailing newline: PS 5.1's Set-Content writes a BOM and
        # cmd's "set /p" would keep the CR, both of which break the other shells.
        $cfg = Join-Path $script:PxDir 'px-proxy.txt'
        if (-not (Test-Path $script:PxDir)) { New-Item -ItemType Directory -Force -Path $script:PxDir | Out-Null }
        [System.IO.File]::WriteAllText($cfg, $u, (New-Object System.Text.UTF8Encoding($false)))
        Write-Host ('px: default proxy set to ' + $u)
        return
    }

    $proxy = Get-PxProxy
    if (-not (Test-PxProxy $proxy)) { $global:LASTEXITCODE = 1; return }

    $saved = @{}
    foreach ($k in $script:PxVars) { $saved[$k] = [Environment]::GetEnvironmentVariable($k) }

    foreach ($k in @('HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY')) {
        [Environment]::SetEnvironmentVariable($k, $proxy)
    }
    [Environment]::SetEnvironmentVariable('NO_PROXY', 'localhost,127.0.0.1,::1')

    $code = $null
    try {
        $exe  = $args[0]
        $rest = @()
        if ($args.Count -gt 1) { $rest = $args[1..($args.Count - 1)] }
        & $exe @rest
        $code = $LASTEXITCODE
    }
    finally {
        foreach ($k in $saved.Keys) {
            if ([string]::IsNullOrEmpty($saved[$k])) {
                # Do NOT also call Remove-Item Env:X here: on PS 7 the provider
                # resurrects the value inherited from the parent process.
                [Environment]::SetEnvironmentVariable($k, $null)
            }
            else {
                [Environment]::SetEnvironmentVariable($k, $saved[$k])
            }
        }
    }

    if ($null -ne $code) { $global:LASTEXITCODE = $code }
}

function px-status {
    if ($args -and $args.Count -ge 1) { $p = ConvertTo-PxUrl $args[0] }
    else { $p = Get-PxProxy }
    if (-not (Test-PxProxy $p)) { return }

    $ok  = $false
    $msg = ''
    try {
        $r   = Invoke-WebRequest -Uri 'https://github.com' -Method Head `
               -Proxy $p -TimeoutSec 8 -UseBasicParsing -ErrorAction Stop
        $ok  = ($r.StatusCode -ge 200 -and $r.StatusCode -lt 400)
        $msg = 'HTTP ' + $r.StatusCode
    }
    catch { $ok = $false; $msg = $_.Exception.Message }

    if ($ok) { Write-Host ('px: proxy OK (' + $msg + ') -> ' + $p) -ForegroundColor Green }
    else { Write-Host ('px: proxy NOT reachable -> ' + $p + ' | ' + $msg) -ForegroundColor Red }
}
