<#
.SYNOPSIS
  Periodic goal-aware playtest review for the Vampire Survivors slice.

.DESCRIPTION
  One cycle = PLAY the current build, then SCORE it against workshop/GOAL.md:
    1. Export the web build + drive it with the agent_play harness (one or more personalities),
       producing runs/<ts>-<personality>/findings.md + screenshots.
    2. Run a goal-aware synthesis (claude -p) that reads GOAL.md + those findings/screenshots,
       PREPENDS a scored "closeness to goal" entry to FEEL-REVIEW.md, and APPENDS the top gaps
       as items to workshop/backlog.json — which the Workshop loop then implements.

  Use -Watch to repeat on an interval. This is the "Workshop periodically plays the game to gather
  feedback on how close it is to the goal" loop.

  PREREQUISITES for the PLAY step (the SCORE step only needs Claude Code):
    - Godot web export templates for this version. Auto-detected — incl. scoop's SELF-CONTAINED
      layout (a ._sc_/_sc_ marker next to the real binary redirects editor data to
      <bindir>\editor_data\export_templates, NOT %APPDATA%). Install via Editor > Manage Export
      Templates only if the preflight reports them missing.
    - ANTHROPIC_API_KEY set in the repo-root .env  (the harness drives the game via the API).
    - A "Web" export preset in vampire-survivors-taskmaster/export_presets.cfg (the harness needs
      one named per agent_play config; default "Web"). Create it once in the editor's Export dialog.
  If the play step can't run, the script still SCORES from the most recent existing run, so the
  goal-feedback loop keeps producing signal — it just won't have a fresh playthrough.

.EXAMPLE
  ./tools/playtest-review.ps1                          # one cycle (new-player + art-director)
  ./tools/playtest-review.ps1 -Personalities new-player -Steps 60
  ./tools/playtest-review.ps1 -Watch -IntervalMinutes 30   # run forever every 30 min
  # Or via the loop skill from Claude Code:  /loop 30m ./tools/playtest-review.ps1
#>
[CmdletBinding()]
param(
  [string[]]$Personalities = @('new-player', 'art-director'),
  [int]$Steps = 80,
  [switch]$Watch,
  [int]$IntervalMinutes = 30,
  [int]$Cycles = 0,                # 0 = infinite when -Watch
  [switch]$SkipPlay               # skip the harness; just synthesize from the latest existing run
)
$ErrorActionPreference = 'Stop'
$root         = Split-Path -Parent $PSScriptRoot          # tools/ sits under the repo root
$agentPlay    = Join-Path $root 'agent_play'
$runsDir      = Join-Path $agentPlay 'runs'
$reviewPrompt = Join-Path $PSScriptRoot 'goal-review-prompt.md'
$goalFile     = Join-Path $root 'workshop\GOAL.md'
$backlogFile  = Join-Path $root 'workshop\backlog.json'
$feelFile     = Join-Path $root 'FEEL-REVIEW.md'

function Write-Note($m, $c = 'Cyan') { Write-Host "[playtest-review] $m" -ForegroundColor $c }

# Resolve the export-templates dir Godot ACTUALLY uses for a given version. Godot does NOT always
# use %APPDATA%\Godot: a scoop install is SELF-CONTAINED (a ._sc_ / _sc_ marker next to the real
# binary redirects editor data to <bindir>\editor_data\export_templates, which scoop junctions to
# its persist dir). And `godot` on PATH is usually a scoop SHIM, so resolve the real exe via
# godot.shim first. Returns the version dir if found, else $null. Search order = how Godot resolves.
function Resolve-GodotTemplatesDir {
  param([string]$VersionDir)
  $exe = (Get-Command godot -ErrorAction SilentlyContinue).Source
  $realExe = $exe
  if ($exe) {
    $shimMeta = Join-Path (Split-Path $exe -Parent) 'godot.shim'
    if (Test-Path $shimMeta) {
      $pathLine = Get-Content $shimMeta | Where-Object { $_ -match '^\s*path\s*=' } | Select-Object -First 1
      if ($pathLine) { $realExe = ($pathLine -replace '^\s*path\s*=\s*', '').Trim().Trim('"') }
    }
  }
  $roots = @()
  if ($realExe) {
    $bindir = Split-Path $realExe -Parent
    if ((Test-Path (Join-Path $bindir '._sc_')) -or (Test-Path (Join-Path $bindir '_sc_'))) {
      $roots += (Join-Path $bindir 'editor_data\export_templates')                            # self-contained (scoop)
    }
  }
  $roots += (Join-Path $env:APPDATA 'Godot\export_templates')                                  # OS default
  $roots += (Join-Path $env:USERPROFILE 'scoop\persist\godot\editor_data\export_templates')    # scoop persist (fallback)
  foreach ($r in $roots) {
    $vdir = Join-Path $r $VersionDir
    if (Test-Path $vdir) { return $vdir }
  }
  return $null
}

function Test-Prereqs {
  if (-not (Get-Command godot -ErrorAction SilentlyContinue)) { Write-Note 'godot not on PATH — cannot play or score.' 'Red'; return $null }
  $envFile = Join-Path $root '.env'
  $hasKey = (Test-Path $envFile) -and (Select-String -Path $envFile -Pattern '^\s*ANTHROPIC_API_KEY=\S' -Quiet)
  $ver = ((& godot --version) | Select-Object -First 1).Trim()
  $m = [regex]::Match($ver, '^\d+\.\d+(?:\.\d+)?\.[a-z]+\d*')
  $tplName = if ($m.Success) { $m.Value } else { $ver }
  $tplDir = Resolve-GodotTemplatesDir -VersionDir $tplName
  # PLAY needs WEB templates specifically (web_*.zip), not just any platform.
  $hasTpl = [bool]$tplDir -and (@(Get-ChildItem (Join-Path $tplDir 'web_*.zip') -ErrorAction SilentlyContinue).Count -gt 0)
  $tplShown = if ($tplDir) { $tplDir } else { "none found (searched self-contained editor_data, %APPDATA%, scoop persist for $tplName)" }
  $hasPreset = Test-Path (Join-Path $root 'vampire-survivors-taskmaster\export_presets.cfg')
  [pscustomobject]@{ Key = $hasKey; Templates = $hasTpl; Preset = $hasPreset; TplDir = $tplShown }
}

function Invoke-Play {
  param([object]$pre)
  if ($SkipPlay) { Write-Note 'SkipPlay set — scoring from the latest existing run.' 'Yellow'; return }
  $blockers = @()
  if (-not $pre.Key)       { $blockers += "ANTHROPIC_API_KEY missing in .env (the harness needs it)." }
  if (-not $pre.Templates) { $blockers += "Web export templates not found ($($pre.TplDir))." }
  if (-not $pre.Preset)    { $blockers += "No export_presets.cfg with a 'Web' preset (create it once in the editor)." }
  if ($blockers.Count) {
    Write-Note 'Play step skipped — fix these once, then fresh playthroughs resume:' 'Yellow'
    $blockers | ForEach-Object { Write-Host "    - $_" -ForegroundColor Yellow }
    return
  }
  $first = $true
  foreach ($p in $Personalities) {
    $a = @('agent_play/harness.mjs', '--personality', $p, '--steps', "$Steps")
    if (-not $first) { $a += '--no-export' }       # export once, reuse the build for later personalities
    Write-Note "play: node $($a -join ' ')"
    Push-Location $root
    try { & node @a } catch { Write-Note "harness failed for '$p': $($_.Exception.Message)" 'Yellow' }
    finally { Pop-Location }
    $first = $false
  }
}

function Invoke-Score {
  if (-not (Test-Path $runsDir) -or @(Get-ChildItem $runsDir -Directory -ErrorAction SilentlyContinue).Count -eq 0) {
    Write-Note 'No playtest runs exist yet — nothing to score. Resolve the play prerequisites and re-run.' 'Yellow'
    return
  }
  $recent = Get-ChildItem $runsDir -Directory | Sort-Object LastWriteTime -Descending |
            Select-Object -First ([Math]::Max(1, $Personalities.Count))
  $runList = ($recent | ForEach-Object { $_.FullName }) -join "`n"
  $prompt  = (Get-Content -Raw -Path $reviewPrompt) + @"


--- PATHS FOR THIS CYCLE (use these exact paths) ---
RUN DIR(S):
$runList
GOAL FILE:        $goalFile
BACKLOG FILE:     $backlogFile
FEEL-REVIEW FILE: $feelFile
"@
  Write-Note "scoring against the goal from $(@($recent).Count) run(s) via claude -p ..."
  Push-Location $root
  try { $prompt | & claude -p --dangerously-skip-permissions }
  finally { Pop-Location }
}

function Invoke-Cycle {
  $pre = Test-Prereqs
  if ($null -eq $pre) { return }
  Invoke-Play -pre $pre
  Invoke-Score
  Write-Note 'cycle complete.' 'Green'
}

if ($Watch) {
  $n = 0
  while ($true) {
    $n++
    Write-Note "=== cycle $n$(if ($Cycles) { "/$Cycles" }) ===" 'Magenta'
    Invoke-Cycle
    if ($Cycles -gt 0 -and $n -ge $Cycles) { break }
    Write-Note "sleeping $IntervalMinutes min ..." 'DarkGray'
    Start-Sleep -Seconds ($IntervalMinutes * 60)
  }
} else {
  Invoke-Cycle
}
