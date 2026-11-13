param([switch]$Editor, [switch]$Test)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$engine = Get-ChildItem "$PSScriptRoot/.tools/godot" -Filter '*console.exe' | Select-Object -First 1
if (-not $engine) { throw 'Godot missing: install Godot 4.x or open project.godot using your editor.' }
$env:APPDATA = Join-Path $PSScriptRoot '.tools/profile'
$env:LOCALAPPDATA = $env:APPDATA
if ($Test) {
    foreach ($suite in @('tests/smoke.gd', 'tests/combat.gd', 'tests/navigation.gd', 'tests/party.gd')) {
        & $engine.FullName --headless --path $PSScriptRoot --script $suite
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
}
elseif ($Editor) { & $engine.FullName --path $PSScriptRoot --editor }
else { & $engine.FullName --path $PSScriptRoot }
exit $LASTEXITCODE
