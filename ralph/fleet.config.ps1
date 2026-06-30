# ============================================================================
#  FLEET CONFIG  -- edit these for YOUR project, then run the fleet.
#  Every fleet PowerShell script dot-sources this file for its DEFAULTS.
#  Any CLI param still overrides it (e.g. ./refinery.ps1 -Base other-branch).
#  See SETUP.md for the full walkthrough.
# ============================================================================
$FleetConfig = @{

  # Absolute path to your repo's MAIN git worktree. The trunk branch lives
  # here and the refinery owns this tree (checks out / resets Base in it).
  Root = 'C:\GameDev\VampireSurvivorsGodot'

  # Trunk branch the lanes fork from and the refinery merges back into.
  # Created by the install:  git branch fleet-trunk
  Base = 'fleet-trunk'

  # Working dir for the integration GATE, RELATIVE to Root (use '.' for repo
  # root). The gate script (ralph\gate.ps1) cd's into the Godot project itself,
  # so '.' is correct here.
  GateDir = '.'

  # The integration GATE command. MUST exit 0 on PASS, non-zero on FAIL.
  # This is the WHOLE safety story -- a faster/looser worker makes a strong
  # gate MORE important.
  #   ralph\gate.ps1 = headless Godot import (catches GDScript parse errors)
  #   + the gdUnit4 test suite (res://test). VERIFIED green on the clean tree
  #   at install time. STRENGTHEN it as the game grows (add a smoke run of the
  #   main scene, more tests) -- a thin gate lets fast lanes corrupt the trunk.
  GateCmd = 'powershell -NoProfile -ExecutionPolicy Bypass -File ralph\gate.ps1'

  # Which coding agent drives the lanes by default: 'claude' or 'agy'
  # (Antigravity/Gemini). Per-lane overrides live in lanes.txt.
  Agent = 'claude'

  # Anti-circling pools the fleet (lanes + planner) injects. Filenames are
  # resolved next to the scripts. Game project -> the gamedev pools.
  Personas = 'personas-gamedev.txt'
  Nouns    = 'nouns-gamedev.txt'

  # git stash message used if start-fleet auto-stashes a dirty main tree.
  AutostashTag = 'FLEET_AUTOSTASH'
}

# --- resolution helper used by every fleet script ---------------------------
# Fills a param from $FleetConfig ONLY when the caller didn't pass it and it's
# still empty/default. $boundKeys = $PSBoundParameters.Keys from the caller.
function Resolve-FleetDefault {
  param([string]$Name, $Current, $boundKeys, $Default)
  if ($boundKeys -contains $Name) { return $Current }   # caller set it explicitly
  if ($null -ne $Current -and "$Current" -ne '') { return $Current }
  return $Default
}
