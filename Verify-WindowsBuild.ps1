param([switch]$Graphics)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$engine = Get-ChildItem "$PSScriptRoot/.tools/godot" -Filter '*console.exe' | Select-Object -First 1
if (-not $engine) { throw 'Godot missing: install the portable engine in .tools/godot.' }
$executable = Join-Path $PSScriptRoot 'build/windows/New game.exe'
if (-not (Test-Path -LiteralPath $executable)) { throw 'Run Build.ps1 first.' }
$info = Get-Content (Join-Path $PSScriptRoot 'build/windows/build-info.json') -Raw | ConvertFrom-Json
if ((& $engine.FullName --version | Out-String).Trim() -ne $info.engine) { throw 'Verification runtime must match the export engine version.' }
if ((Get-FileHash -LiteralPath $executable -Algorithm SHA256).Hash -ne $info.executable_sha256) { throw 'Executable does not match build-info.json.' }
$validation = Join-Path $PSScriptRoot 'build/validation'
$testRoot = Join-Path $validation 'tests'
New-Item -ItemType Directory -Force -Path $testRoot | Out-Null
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
try {
    # Separate from both the player's regular profile and Run.ps1's profile.
    $env:APPDATA = Join-Path $PSScriptRoot '.tools/export-profile'
    $env:LOCALAPPDATA = $env:APPDATA
    # Official 4.7.2 templates disable --script. Run the EXE's embedded PCK
    # with the matching editor runtime; keep this distinct from EXE launches.
    foreach ($test in Get-ChildItem (Join-Path $PSScriptRoot 'tests') -Filter '*.gd') {
        $content = [IO.File]::ReadAllText($test.FullName).Replace('res://tests/', ($testRoot.Replace('\', '/') + '/')).Replace('res://.tools/', ($validation.Replace('\', '/') + '/'))
        [IO.File]::WriteAllText((Join-Path $testRoot $test.Name), $content)
    }
    function Invoke-PackTest([string]$Name, [string[]]$UserArgs = @()) {
        $arguments = @('--headless')
        if ($Graphics) { $arguments = @('--disable-vsync') }
        $arguments += @('--main-pack', $executable, '--fixed-fps', '60', '--script', (Join-Path $testRoot $Name), '--log-file', (Join-Path $validation ($Name + ($UserArgs -join '-') + '.log')))
        if ($UserArgs.Count) { $arguments += @('--') + $UserArgs }
        & $engine.FullName @arguments
        if ($LASTEXITCODE -ne 0) { throw "Embedded pack regression failed: $Name" }
        $testLog = Get-Content -LiteralPath (Join-Path $validation ($Name + ($UserArgs -join '-') + '.log')) -Raw
        if ($testLog -match '(?m)(SCRIPT ERROR|ERROR:)') { throw "Embedded pack runtime error: $Name" }
    }
    foreach ($suite in @('smoke', 'combat', 'navigation', 'party', 'abilities', 'team_combat', 'dialogue', 'quest', 'station', 'puzzle', 'memory_echo', 'station_playthrough', 'prologue', 'equipment', 'save_load')) {
        if ($Graphics -and $suite -eq 'station_playthrough') {
            Invoke-PackTest ($suite + '.gd') @('--capture')
        }
        else { Invoke-PackTest ($suite + '.gd') }
    }
    Invoke-PackTest 'save_load.gd' @('--write')
    Invoke-PackTest 'save_load.gd' @('--read')
    # Launch the actual release template, without editor, script or main-pack.
    $launchArgs = @('--headless', '--quit-after', '120')
    if ($Graphics) { $launchArgs = @('--quit-after', '180') }
    $launchLog = Join-Path $validation 'standalone-launch.log'
    $launchArgs += @('--log-file', ('"' + $launchLog + '"'))
    $process = Start-Process -FilePath $executable -WorkingDirectory $validation -ArgumentList $launchArgs -WindowStyle Hidden -PassThru
    if (-not $process.WaitForExit(30000)) { $process.Kill(); throw 'Standalone launch timed out.' }
    if ($process.ExitCode -ne 0) { throw "Standalone exit code: $($process.ExitCode)" }
    $log = Get-Content -LiteralPath $launchLog -Raw
    if ($log -match '(?m)(SCRIPT ERROR|ERROR:)') { throw "Standalone errors: $launchLog" }
    Write-Host 'Embedded PCK regressions and standalone EXE launch passed. This is automated verification, not a manual playthrough.'
}
finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}
