# ============================================================================
#  PROJECT GATE for the Vampire Survivors (Godot 4.6) repo.
#  Invoked by the refinery / single loop via fleet.config.ps1's GateCmd.
#  Contract: print what it did, exit 0 on PASS, non-zero on FAIL.
#
#  Two stages, both run against the Godot project at <repo>\vampire-survivors-taskmaster:
#    1. Headless IMPORT  -- imports resources and surfaces GDScript parse errors.
#    2. gdUnit4 TEST RUN -- runs every suite under res://test (currently a smoke test).
#  Verified green on the clean tree at install time. Strengthen as the game grows.
#
#  Self-locating: resolves the Godot project from THIS script's folder, so it works
#  the same in the main worktree and in any lane worktree. GateDir can stay '.'.
# ============================================================================
$ErrorActionPreference = 'Continue'

# ralph\ lives directly under the repo root; the Godot project is a sibling folder.
$repoRoot = Split-Path -Parent $PSScriptRoot
$proj     = Join-Path $repoRoot 'vampire-survivors-taskmaster'
if (-not (Test-Path (Join-Path $proj 'project.godot'))) {
  Write-Host "GATE FAIL: Godot project not found at $proj" -ForegroundColor Red
  exit 2
}

# Resolve the Godot binary (scoop puts a shim on PATH; gdUnit4 needs an explicit path).
$godot = (Get-Command godot -ErrorAction SilentlyContinue).Source
if (-not $godot) { $godot = Join-Path $env:USERPROFILE 'scoop\shims\godot.exe' }
if (-not (Test-Path $godot)) {
  # Manual installs (e.g. Program Files\Godot) ship a versioned exe, not `godot.exe` on PATH.
  # Prefer the _console build so headless stdout isn't swallowed by the GUI subsystem.
  $installed = Get-ChildItem -Path (Join-Path $env:ProgramFiles 'Godot') -Filter 'Godot_v4*.exe' -ErrorAction SilentlyContinue |
               Sort-Object @{Expression = { $_.Name -notmatch '_console\.exe$' }}, Name
  if ($installed) { $godot = $installed[0].FullName }
}
if (-not (Test-Path $godot)) {
  Write-Host "GATE FAIL: godot not found on PATH (set it / install Godot 4.6)." -ForegroundColor Red
  exit 2
}

# --- Stage 1: headless import (also makes new resources available to the tests) ----
Write-Host "GATE [1/2] godot --import ($proj) ..." -ForegroundColor Cyan
& $godot --headless --path $proj --import 2>&1 | Out-Host

# --- Stage 2: gdUnit4 test suite ---------------------------------------------------
Write-Host "GATE [2/2] gdUnit4 test suite (res://test) ..." -ForegroundColor Cyan
$env:GODOT_BIN = $godot
$runtest = Join-Path $proj 'addons\gdUnit4\runtest.cmd'
if (-not (Test-Path $runtest)) {
  Write-Host "GATE FAIL: gdUnit4 runner missing at $runtest" -ForegroundColor Red
  exit 2
}
Push-Location $proj
try { & cmd /c "`"$runtest`" -a test"; $code = $LASTEXITCODE } finally { Pop-Location }

if ($code -eq 0) { Write-Host "GATE PASS" -ForegroundColor Green }
else             { Write-Host "GATE FAIL (gdUnit4 exit $code)" -ForegroundColor Red }
exit $code
