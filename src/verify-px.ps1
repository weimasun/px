# verify-px.ps1 - px acceptance checklist, run in a fresh shell.
# ASCII only. Usage: pwsh.exe -File verify-px.ps1 -LogPath <file>
param([string]$LogPath)

$o = @()
$o += "shell_version = " + $PSVersionTable.PSVersion.ToString()
$o += "px_loaded     = " + [bool](Get-Command px -ErrorAction SilentlyContinue)

if (-not (Get-Command px -ErrorAction SilentlyContinue)) {
    $o += "ABORT: px not loaded, profile did not dot-source px.ps1"
    $o | Set-Content -Path $LogPath -Encoding UTF8
    return
}

# WorkBuddy injects HTTP_PROXY/HTTPS_PROXY into agent shells; clear first.
foreach ($v in @('HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'NO_PROXY')) {
    [Environment]::SetEnvironmentVariable($v, $null)
}

$url = 'https://github.com/github/awesome-copilot.git'
$fmt = '%{http_code} via %{remote_ip}:%{remote_port}'
function snap($tag) { $tag + " HTTP=[" + [Environment]::GetEnvironmentVariable('HTTP_PROXY') + "]" }

$o += snap("T0 cleared ")

# T1 - no px, no env proxy: baseline
$a = & curl.exe -sS -o NUL -w $fmt --noproxy '*' --max-time 12 https://github.com 2>&1
$o += "T1 direct   exit=" + $LASTEXITCODE + " | " + (($a | Out-String).Trim())

# T2 - px curl: must be 200 and connect through 127.0.0.1:7890
$b = px curl.exe -sS -o NUL -w $fmt --max-time 20 https://github.com 2>&1
$o += "T2 px curl  exit=" + $global:LASTEXITCODE + " | " + (($b | Out-String).Trim())
$o += snap("T2b after px")

# T3 - px git ls-remote
$c = px git ls-remote $url HEAD 2>&1
$o += "T3 px git   exit=" + $global:LASTEXITCODE + " | " + (($c | Out-String).Trim() -replace "\s+", " ")

# T4 - dashed args must pass through
$d = px git ls-remote -h $url 2>&1
$d = ($d | Out-String).Trim()
$o += "T4 px -h    exit=" + $global:LASTEXITCODE + " | " + ($d.Substring(0, [Math]::Min(200, $d.Length)) -replace "\s+", " ")

# T5 - env restored
$o += "T5 restored HTTP_PROXY=[" + $env:HTTP_PROXY + "] HTTPS_PROXY=[" + $env:HTTPS_PROXY + "] ALL_PROXY=[" + $env:ALL_PROXY + "]"

# T6 - px npm ping
$e = px npm ping 2>&1
$o += "T6 px npm   exit=" + $global:LASTEXITCODE + " | " + (($e | Out-String).Trim() -replace "\s+", " ")

# T7 - restore must bring back a PRE-EXISTING proxy value
[Environment]::SetEnvironmentVariable('HTTP_PROXY', 'http://sentinel.example:9999')
px cmd.exe /c "echo ok" | Out-Null
$o += "T7 restore-preexisting = [" + [Environment]::GetEnvironmentVariable('HTTP_PROXY') + "] (expect http://sentinel.example:9999)"
[Environment]::SetEnvironmentVariable('HTTP_PROXY', $null)

$o | Set-Content -Path $LogPath -Encoding UTF8
