param()
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$engine = Get-ChildItem "$PSScriptRoot/.tools/godot" -Filter '*console.exe' | Select-Object -First 1
if (-not $engine) { throw 'Godot missing: install the portable engine in .tools/godot.' }
$env:APPDATA = Join-Path $PSScriptRoot '.tools/profile'
$env:LOCALAPPDATA = $env:APPDATA
$output = Join-Path $PSScriptRoot 'build/windows'
New-Item -ItemType Directory -Force -Path $output | Out-Null
& $engine.FullName --headless --path $PSScriptRoot --editor --import
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $engine.FullName --headless --path $PSScriptRoot --export-release 'Windows Desktop' (Join-Path $output 'New game.exe')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'LICENSE') -Destination $output
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'third_party/GODOT_COPYRIGHT.txt') -Destination $output
Write-Host "Built: $output/New game.exe"
