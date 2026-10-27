param([switch]$TestOnly, [switch]$Restart)
$ErrorActionPreference = 'Stop'
$bridgeRoot = $PSScriptRoot
$runtimeRoot = Join-Path $bridgeRoot '.runtime'
New-Item -ItemType Directory -Path $runtimeRoot -Force | Out-Null
$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
& icacls.exe $runtimeRoot /inheritance:r /grant:r "${identity}:(OI)(CI)F" | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Cannot protect the credential directory.' }
$nodePath = (Get-Command node.exe -ErrorAction Stop).Source
$cliCommand = Get-Command codex.exe -ErrorAction SilentlyContinue
$package = Get-AppxPackage -Name OpenAI.Codex | Select-Object -First 1
if ($cliCommand) { $cliPath = $cliCommand.Source }
elseif ($package) { $cliPath = Join-Path $package.InstallLocation 'app\resources\codex.exe' }
else { throw 'Codex CLI was not found in PATH or the installed desktop app.' }
if (!(Test-Path -LiteralPath $cliPath)) { throw 'Codex CLI executable was not found.' }
if ($TestOnly) {
    $previousTestCli = $env:CODEX_BRIDGE_CLI
    try {
        $env:CODEX_BRIDGE_CLI = $cliPath
        & $nodePath (Join-Path $bridgeRoot 'bridge.mjs') --test
        if ($LASTEXITCODE -ne 0) { throw 'Bridge self-test failed.' }
    } finally { $env:CODEX_BRIDGE_CLI = $previousTestCli }
    return
}
if (Get-Process ChatGPT -ErrorAction SilentlyContinue) {
    throw 'Save your work and fully quit the ChatGPT/Codex desktop app first, then run this script again. It will reopen the app with the shared connection.'
}
$previousProbeCli = $env:CODEX_BRIDGE_CLI
try {
    $env:CODEX_BRIDGE_CLI = $cliPath
    & $nodePath (Join-Path $bridgeRoot 'sandbox.test.mjs')
    if ($LASTEXITCODE -ne 0) { throw 'Member sandbox preflight failed. The existing bridge has not been stopped.' }
} finally { $env:CODEX_BRIDGE_CLI = $previousProbeCli }
if ($Restart) { & (Join-Path $bridgeRoot 'Stop-Bridge.ps1') -ForRestart }
elseif (Test-Path -LiteralPath (Join-Path $runtimeRoot 'ready.json')) {
    $previousState = Get-Content -LiteralPath (Join-Path $runtimeRoot 'ready.json') -Raw | ConvertFrom-Json
    $previousProcess = Get-CimInstance Win32_Process -Filter "ProcessId=$($previousState.pid)" -ErrorAction SilentlyContinue
    if ($previousProcess -and $previousProcess.CommandLine -match [regex]::Escape((Join-Path $bridgeRoot 'bridge.mjs'))) {
        throw 'A bridge is already running. Quit the desktop app and use -Restart to update it.'
    }
}
if (!$package) { throw 'Installed OpenAI.Codex desktop app was not found.' }
$desktopPath = Join-Path $package.InstallLocation 'app\ChatGPT.exe'
if (!(Test-Path -LiteralPath $desktopPath)) { throw 'Desktop executable was not found.' }
$secret = Read-Host 'Paste the QQ Bot AppSecret (hidden input; not saved)' -AsSecureString
$plainSecret = [System.Net.NetworkCredential]::new('', $secret).Password
if ([string]::IsNullOrWhiteSpace($plainSecret)) { throw 'AppSecret is empty.' }
$previousSecret = $env:QQ_BOT_SECRET
$previousCli = $env:CODEX_BRIDGE_CLI
$previousUrl = $env:CODEX_APP_SERVER_WS_URL
$previousForce = $env:CODEX_APP_SERVER_FORCE_CLI
$previousDaemon = $env:CODEX_APP_SERVER_USE_LOCAL_DAEMON
try {
    $env:QQ_BOT_SECRET = $plainSecret
    $env:CODEX_BRIDGE_CLI = $cliPath
    $service = Start-Process -FilePath $nodePath -ArgumentList @('"' + (Join-Path $bridgeRoot 'bridge.mjs') + '"') -WorkingDirectory $bridgeRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $runtimeRoot 'service.stdout.log') -RedirectStandardError (Join-Path $runtimeRoot 'service.stderr.log')
    $env:QQ_BOT_SECRET = $previousSecret
    $plainSecret = $null
    $secret.Dispose()
    $readyPath = Join-Path $runtimeRoot 'ready.json'
    $ready = $null
    for ($attempt = 0; $attempt -lt 150; $attempt++) {
        $service.Refresh()
        if ($service.HasExited) { throw 'Bridge exited. Inspect .runtime/events.jsonl for the failed stage.' }
        if (Test-Path -LiteralPath $readyPath) {
            $candidate = Get-Content -LiteralPath $readyPath -Raw | ConvertFrom-Json
            if ($candidate.pid -eq $service.Id) { $ready = $candidate; break }
        }
        Start-Sleep -Milliseconds 200
    }
    if (!$ready) { throw 'Shared service did not become ready. Run Stop-Bridge.ps1 before retrying.' }
    $qqReadyPath = Join-Path $runtimeRoot 'qq-ready.json'
    $qqReady = $false
    Write-Host 'Waiting for QQ authentication and gateway connection...'
    for ($attempt = 0; $attempt -lt 300; $attempt++) {
        $service.Refresh()
        if ($service.HasExited) { throw 'QQ connection failed. Inspect .runtime/events.jsonl; the desktop app has not been switched.' }
        if (Test-Path -LiteralPath $qqReadyPath) {
            $candidate = Get-Content -LiteralPath $qqReadyPath -Raw | ConvertFrom-Json
            if ($candidate.pid -eq $service.Id) { $qqReady = $true; break }
        }
        Start-Sleep -Milliseconds 200
    }
    if (!$qqReady) { throw 'QQ gateway is not ready. Run Stop-Bridge.ps1 before retrying; the desktop app has not been switched.' }
    $env:CODEX_APP_SERVER_WS_URL = (Get-Content -LiteralPath (Join-Path $runtimeRoot 'desktop-url.key') -Raw).Trim()
    $env:CODEX_APP_SERVER_FORCE_CLI = $null
    $env:CODEX_APP_SERVER_USE_LOCAL_DAEMON = $null
    Start-Process -FilePath $desktopPath -WindowStyle Hidden | Out-Null
    Write-Host 'Desktop reopened. Open the original QQ connection chat; do not create a new chat.'
    $pairingPath = Join-Path $runtimeRoot 'pairing.txt'
    if (!(Test-Path -LiteralPath (Join-Path $runtimeRoot 'owner.json'))) {
        for ($attempt = 0; $attempt -lt 50; $attempt++) {
            if (Test-Path -LiteralPath $pairingPath) { break }
            Start-Sleep -Milliseconds 100
        }
        Write-Host 'Privately send this one-time command to your QQ Bot:'
        Get-Content -LiteralPath $pairingPath
    }
    Write-Host "Then send /status in QQ. Expected thread: $($ready.threadId); desktop connections must be at least 1."
    Write-Host 'Finish verification by sending: Reply with QQ connection successful.'
} finally {
    $env:QQ_BOT_SECRET = $previousSecret
    $env:CODEX_BRIDGE_CLI = $previousCli
    $env:CODEX_APP_SERVER_WS_URL = $previousUrl
    $env:CODEX_APP_SERVER_FORCE_CLI = $previousForce
    $env:CODEX_APP_SERVER_USE_LOCAL_DAEMON = $previousDaemon
    $plainSecret = $null
}
