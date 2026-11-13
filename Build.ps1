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
$executable = Join-Path $output 'New game.exe'
$revision = & git rev-parse HEAD
if ($LASTEXITCODE -ne 0) { throw 'Cannot identify build revision.' }
$dirty = [bool](& git status --porcelain --untracked-files=normal)
@{
    revision = $revision
    source_modified = $dirty
    engine = (& $engine.FullName --version | Out-String).Trim()
    built_utc = [DateTime]::UtcNow.ToString('o')
    executable_sha256 = (Get-FileHash -LiteralPath $executable -Algorithm SHA256).Hash
} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $output 'build-info.json') -Encoding UTF8
# Package only explicit deliverables: never an old PCK, profile or editor cache.
Compress-Archive -LiteralPath @($executable, (Join-Path $output 'LICENSE'), (Join-Path $output 'GODOT_COPYRIGHT.txt'), (Join-Path $output 'build-info.json')) -DestinationPath (Join-Path $PSScriptRoot 'build/New-game-windows-x64.zip') -Force
Write-Host "Built: $output/New game.exe"
