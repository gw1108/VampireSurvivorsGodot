# Agent guide — VampireSurvivorsGodot

The primary project guide is [`claude.md`](claude.md) (Project Map, operating rules, testing philosophy).
Read it first. This repo is a Godot 4.6 Vampire Survivors vertical slice; the actual Godot project is
`vampire-survivors-taskmaster/`.

## Balance & tuning convention (hard rule)

All tunable gameplay/visual scalars — player move speed, pickup radius, sprite scales, aura/light
radii, damage, cooldowns, spawn pacing — live as `id,value,description` rows in
`vampire-survivors-taskmaster/data/balance.csv`, read via
`BalanceData.get_value("<id>", default)`. Never add them as hardcoded `.gd` consts; migrate any you
touch. Full rule in [`claude.md`](claude.md) Operating Principles.

## Autonomous agent tooling (cosmic-agent-tools)

Three installed tools for running coding agents autonomously. **Read the linked doc before you run,
configure, or reason about any of them.**

- **Fleet orchestrator — `ralph/`** — many agent loops grind in parallel, each in its own git worktree
  with a hard file scope, while a **refinery** merges their branches under a gate and a **planner** keeps
  the backlog file-disjoint. Read [`ralph/SETUP.md`](ralph/SETUP.md). Entry points (PowerShell, from repo
  root): `./ralph/start-fleet.ps1 -LaneIterations 3 -RefineryIterations 12` (bounded), `-WithPlanner`
  (open-ended), `./ralph/watch-fleet.ps1` (dashboard), `./ralph/ralph.ps1 -Random` (single loop). Project
  knobs in `ralph/fleet.config.ps1`; lanes in `ralph/lanes.txt` + `ralph/lane-*.md`.
- **Workshop — `workshop/`** — the SINGLE-agent counterpart: one agent, fresh context each pass, draining
  an operator-curated backlog toward `workshop/GOAL.md`, with a live web UI. Read
  [`workshop/README.md`](workshop/README.md). Run: `node workshop/ui/server.js` → http://localhost:4455,
  or `./workshop/start-workshop.ps1`. Knobs in `workshop/workshop.config.ps1`.
- **Skill — `.claude/skills/2d-game-art-direction/`** — art-direction decision guide for 2D games.

**The gate** (the fleet's whole safety story) is `ralph/gate.ps1`: headless Godot import + the gdUnit4
suite. Keep it honest as the game grows.

### ⚠️ Sacred files — do not destroy
- `ralph/PROMPT.md`, `ralph/PLAN-PROMPT.md`, `workshop/PROMPT.md`, `workshop/GOAL.md`,
  `workshop/backlog.json` are the operator's REAL task files and are **gitignored — overwriting or
  deleting them is unrecoverable**. NEVER copy/write/rm them to smoke-test; point tests at a throwaway
  prompt instead.
- The fleet/workshop run agents UNATTENDED (`--dangerously-skip-permissions`). Only run where you can
  fully revert via git. Start bounded and keep the gate honest.
