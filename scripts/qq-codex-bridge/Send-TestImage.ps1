$ErrorActionPreference = 'Stop'
$nodePath = (Get-Command node.exe -ErrorAction Stop).Source
& $nodePath (Join-Path $PSScriptRoot 'send-test-image.mjs')
if ($LASTEXITCODE -ne 0) { throw 'Image preflight failed; no message was sent.' }
