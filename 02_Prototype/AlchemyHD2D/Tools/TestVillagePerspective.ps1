# Compatibility entry: ground-homography checks were superseded by stable-artwork validation.
param([int]$Width=1280,[int]$Height=720)
& (Join-Path $PSScriptRoot 'TestVillagePresentation.ps1') -Width $Width -Height $Height
