param([string]$BuildDirectory='HD2D_PC_UI')
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression
$projectRoot=Split-Path -Parent $PSScriptRoot
$buildRoot=[IO.Path]::GetFullPath((Join-Path $projectRoot "../../03_Build/$BuildDirectory"))
$allowedRoot=[IO.Path]::GetFullPath((Join-Path $projectRoot '../../03_Build'))
if(-not $buildRoot.StartsWith($allowedRoot+'\')) {throw 'Export target must stay inside 03_Build.'}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'LaunchDemo.cmd') -Destination (Join-Path $buildRoot '启动Demo.cmd')
$zipPath=Join-Path $buildRoot '冒牌炼金术士_Demo_Win64_字体90_72.zip'
$writePath=Join-Path $buildRoot ('Demo_'+[guid]::NewGuid().ToString('N')+'.zip')
$stream=[IO.File]::Open($writePath,[IO.FileMode]::CreateNew)
$zip=[IO.Compression.ZipArchive]::new($stream,[IO.Compression.ZipArchiveMode]::Create)
try {
    $files=@(Get-Item -LiteralPath (Join-Path $buildRoot '启动Demo.cmd'),(Join-Path $buildRoot '运行说明.txt'))
    $files+=Get-ChildItem -LiteralPath (Join-Path $buildRoot 'Windows') -File -Recurse | Where-Object { $_.FullName -notmatch '\\(Saved|Evidence)\\' -and $_.Extension -ne '.pdb' -and $_.Name -ne 'Manifest_DebugFiles_Win64.txt' }
    foreach($file in $files) {
        $entryName=$file.FullName.Substring($buildRoot.Length+1).Replace('\','/')
        $entry=$zip.CreateEntry($entryName,[IO.Compression.CompressionLevel]::Fastest)
        $inputFile=[IO.File]::OpenRead($file.FullName);$outputFile=$entry.Open()
        try {$inputFile.CopyTo($outputFile)} finally {$outputFile.Dispose();$inputFile.Dispose()}
    }
} finally {$zip.Dispose();$stream.Dispose()}
if(Test-Path -LiteralPath $zipPath) {
    $archiveRoot=[IO.Path]::GetFullPath((Join-Path $projectRoot '../../04_Archive/运行包导出历史'))
    New-Item -ItemType Directory -Path $archiveRoot -Force | Out-Null
    Move-Item -LiteralPath $zipPath -Destination (Join-Path $archiveRoot ((Get-Date -Format 'yyyyMMdd-HHmmss-')+[IO.Path]::GetFileName($zipPath)))
}
Move-Item -LiteralPath $writePath -Destination $zipPath
Get-FileHash -LiteralPath $zipPath -Algorithm SHA256
