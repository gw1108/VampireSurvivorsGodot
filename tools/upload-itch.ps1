<#
.SYNOPSIS
    Export the Godot web build and push it to itch.io with butler.

.DESCRIPTION
    1. Ensures `butler` (itch.io's CLI) is available, downloading it locally if missing.
    2. Does a clean headless Godot web export into a throwaway `build/web` folder
       (gitignored; so butler only ships the game files, not build.zip / stray artifacts).
    3. Pushes that folder to your itch project's channel via butler's delta uploader.

    The 1280x720 viewport size and the "This file will be played in the browser"
    flag are NOT set by butler -- they are one-time settings on the itch edit page.
    See the notes printed at the end (and the README block below).

.PARAMETER Target
    itch push target in the form  user/game:channel  (lowercase).
    e.g.  gw1108/vampire-survivors:html5
    Find `user/game` from your public page URL: https://USER.itch.io/GAME

.PARAMETER SkipExport
    Skip the Godot re-export and push whatever is already in build/web.

.PARAMETER UserVersion
    Optional human-readable version stamped on the build (e.g. 0.3.1).

.EXAMPLE
    ./tools/upload-itch.ps1 -Target gw1108/vampire-survivors:html5

.EXAMPLE
    $env:BUTLER_API_KEY = "<key from https://itch.io/user/settings/api-keys>"
    ./tools/upload-itch.ps1 -Target gw1108/vampire-survivors:html5 -UserVersion 0.3.1
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Target,

    [switch]$SkipExport,

    [string]$UserVersion,

    [string]$Godot = "Godot_v4.7-stable_win64_console.exe",

    [string]$ExportPreset = "Web"
)

$ErrorActionPreference = "Stop"

# --- Paths -----------------------------------------------------------------
$RepoRoot    = Split-Path $PSScriptRoot -Parent
$ProjectDir  = Join-Path $RepoRoot "vampire-survivors-taskmaster"
$ExportDir   = Join-Path $ProjectDir "build\web"
$ToolsBin    = Join-Path $PSScriptRoot "bin"
$ButlerExe   = Join-Path $ToolsBin "butler.exe"

if ($Target -notmatch '^[^/]+/[^:]+:.+$') {
    throw "Target must look like  user/game:channel  (got '$Target'). e.g. gw1108/vampire-survivors:html5"
}

# --- 1. Ensure butler ------------------------------------------------------
$butler = (Get-Command butler -ErrorAction SilentlyContinue).Source
if (-not $butler) { if (Test-Path $ButlerExe) { $butler = $ButlerExe } }
if (-not $butler) {
    Write-Host "==> butler not found; downloading to $ToolsBin ..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Force -Path $ToolsBin | Out-Null
    $zip = Join-Path $ToolsBin "butler.zip"
    $url = "https://broth.itch.zone/butler/windows-amd64/LATEST/archive/default"
    Invoke-WebRequest -Uri $url -OutFile $zip
    Expand-Archive -Path $zip -DestinationPath $ToolsBin -Force
    Remove-Item $zip
    $butler = $ButlerExe
}
& $butler version
Write-Host ""

# --- 2. Clean web export ---------------------------------------------------
if (-not $SkipExport) {
    $godotCmd = (Get-Command $Godot -ErrorAction SilentlyContinue).Source
    if (-not $godotCmd) { throw "Godot binary '$Godot' not on PATH. Pass -Godot <path> or use -SkipExport." }

    Write-Host "==> Exporting '$ExportPreset' preset -> $ExportDir" -ForegroundColor Cyan
    if (Test-Path $ExportDir) { Remove-Item $ExportDir -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $ExportDir | Out-Null

    # Godot must run with the project as CWD; output path overrides the preset's export_path.
    Push-Location $ProjectDir
    try {
        & $godotCmd --headless --export-release $ExportPreset (Join-Path $ExportDir "index.html")
        # Godot's headless exporter can return non-zero even on success (import warnings);
        # verify the real artifact instead of trusting the exit code.
    } finally {
        Pop-Location
    }
    if (-not (Test-Path (Join-Path $ExportDir "index.wasm"))) {
        throw "Export failed: index.wasm not produced in $ExportDir"
    }
    Write-Host "==> Export OK" -ForegroundColor Green
    Write-Host ""
}

if (-not (Test-Path (Join-Path $ExportDir "index.html"))) {
    throw "Nothing to push: $ExportDir has no index.html (drop -SkipExport to build it)."
}

# --- 3. Push --------------------------------------------------------------
# Auth: interactive `butler login` (opens browser) OR set $env:BUTLER_API_KEY
# from https://itch.io/user/settings/api-keys for headless/CI use.
Write-Host "==> Pushing $ExportDir -> $Target" -ForegroundColor Cyan
$pushArgs = @("push", $ExportDir, $Target)
if ($UserVersion) { $pushArgs += @("--userversion", $UserVersion) }
& $butler @pushArgs

Write-Host ""
Write-Host "Done. One-time settings on https://itch.io/game/edit/4741848 :" -ForegroundColor Yellow
Write-Host "  * Kind of project:            HTML"
Write-Host "  * Uploaded file:              check 'This file will be played in the browser'"
Write-Host "  * Embed options > Dimensions: 1280 x 720  (or 'Manually set...')"
Write-Host "  * Embed options:              enable 'Fullscreen button' and, for Godot 4,"
Write-Host "                                'SharedArrayBuffer support' if the game needs it."
