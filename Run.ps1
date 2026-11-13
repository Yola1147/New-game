param([switch]$Editor, [switch]$Test)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$engine = Get-ChildItem "$PSScriptRoot/.tools/godot" -Filter '*console.exe' | Select-Object -First 1
if (-not $engine) { throw 'Godot missing: install Godot 4.x or open project.godot using your editor.' }
$env:APPDATA = Join-Path $PSScriptRoot '.tools/profile'
$env:LOCALAPPDATA = $env:APPDATA
if ($Test) { & $engine.FullName --headless --path $PSScriptRoot --script tests/smoke.gd }
elseif ($Editor) { & $engine.FullName --path $PSScriptRoot --editor }
else { & $engine.FullName --path $PSScriptRoot }
exit $LASTEXITCODE
