param([switch]$ForRestart)
$ErrorActionPreference = 'Stop'
$bridgeRoot = $PSScriptRoot
$readyPath = Join-Path $bridgeRoot '.runtime\ready.json'
if (!(Test-Path -LiteralPath $readyPath)) { Write-Host 'No bridge runtime recorded.'; return }
$state = Get-Content -LiteralPath $readyPath -Raw | ConvertFrom-Json
$lockPath = Join-Path $bridgeRoot '.runtime\project-lock.json'
if (Test-Path -LiteralPath $lockPath) {
    $projectLock = Get-Content -LiteralPath $lockPath -Raw | ConvertFrom-Json
    if ($projectLock -and (Get-Process -Id $state.backendPid -ErrorAction SilentlyContinue)) {
        $nodePath = (Get-Command node.exe -ErrorAction Stop).Source
        & $nodePath (Join-Path $bridgeRoot 'check-stop.mjs')
        if ($LASTEXITCODE -ne 0) { throw 'Project task status is active or uncertain; the bridge has not been stopped.' }
    }
}
$backendPort = 43175
if ($state.backendPort) { $backendPort = [int]$state.backendPort }
$backendPattern = 'app-server.*127\.0\.0\.1:{0}(?:["\s]|$)' -f $backendPort
foreach ($entry in @(@{ Id = $state.backendPid; Pattern = $backendPattern }, @{ Id = $state.pid; Pattern = [regex]::Escape((Join-Path $bridgeRoot 'bridge.mjs')) })) {
    $process = Get-CimInstance Win32_Process -Filter "ProcessId=$($entry.Id)" -ErrorAction SilentlyContinue
    if (!$process) { continue }
    if ($process.CommandLine -notmatch $entry.Pattern) { throw 'PID was reused by another process; refusing to stop it.' }
    $processHandle = Get-Process -Id $process.ProcessId -ErrorAction SilentlyContinue
    if (!$processHandle) { continue }
    Stop-Process -Id $process.ProcessId -ErrorAction Stop
    if (!$processHandle.WaitForExit(10000)) { throw 'Bridge process has not exited; restart was cancelled.' }
}
if ($ForRestart) { Write-Host 'Previous bridge processes stopped. The new bridge will use fresh local ports.' }
else { Write-Host 'Bridge stopped. Fully quit and reopen the desktop app normally to restore its original connection.' }
