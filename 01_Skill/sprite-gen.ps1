# Uses the SSD-local virtual environment and stores tool settings/cache on SSD.
$ErrorActionPreference = 'Stop'
$env:SPRITE_GEN_ROOT = Join-Path $PSScriptRoot 'installed/sprite-gen'
$env:SPRITE_GEN_CONFIG_DIR = Join-Path $PSScriptRoot 'config/sprite-gen'
$env:SPRITE_GEN_DATA_DIR = Join-Path $PSScriptRoot 'data/sprite-gen'
$env:PYTHONUTF8 = '1'
$env:PYTHONIOENCODING = 'utf-8'
$env:PYTHONDONTWRITEBYTECODE = '1'
$env:TEMP = Join-Path $PSScriptRoot 'tmp'
$env:TMP = $env:TEMP
New-Item -ItemType Directory -Force -Path $env:TEMP | Out-Null
$toolDirs = @('ffmpeg','libwebp') | ForEach-Object { Join-Path $PSScriptRoot "tools/$_" } | Where-Object { Test-Path $_ }
if ($toolDirs) { $env:PATH = ($toolDirs -join ';') + ';' + $env:PATH }
$codexDir = Join-Path $env:USERPROFILE '.codex/.sandbox-bin'
if ((Test-Path (Join-Path $codexDir 'codex.exe')) -and (($env:PATH -split ';') -notcontains $codexDir)) {
    $env:PATH = "$codexDir;$env:PATH"
}
& (Join-Path $env:SPRITE_GEN_ROOT '.venv/Scripts/sprite-gen.exe') @args
exit $LASTEXITCODE

