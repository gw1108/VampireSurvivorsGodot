# Claude.md

The role of this file is to describe common mistakes and confusion points that agents might encounter as they work in this project. If you ever encounter something in the project that surprises you, please alert the developer working with you and indicate that this is the case in the AgentMD file to help prevent future agents from having the same issue.

---

## Operating Principles (Non-Negotiable)

- If something is described or asked for do not ask for confirmation.

---

## Project Structure

Do NOT scan files in the /thoughts/ folder unless specified.
Do NOT scan files under any folder named ARCHIVE unless specified.

### Where things are (Project Map)

This is a Godot 4.6 reimplementation of a Vampire Survivors vertical slice.

**`vampire-survivors-taskmaster/`** — the actual Godot project (open *this* folder in the editor, not the repo root).
- `addons/*` — addons and plugins go here. Don't edit or read this unless specified.
- `test/` — test suites live here. New `*_test.gd` go here. (See Testing philosophy below — tests are optional.)
- `reports/*` — generated gdUnit4 HTML/XML test reports. Generated output, not source.
- Game source (scenes `.tscn`, scripts `.gd`, resources) will live under this folder.

**Design, planning & research:**
- `thoughts/shared/game-design/` — the Game Design Document(s). Source of truth for what to build. *(Do not scan unless asked.)*
- `.firecrawl/` — offline reference: a scraped copy of the Vampire Survivors wiki (`wiki-offline/`, `.md` + `.htm` + screenshots), `vampire-survivors-gameplay-extracted.md`.

**Art:**
- `SourceArt/extracted_clean/` — ~96 cleaned PNG sprites (characters, enemies, items, weapons) extracted from the original game. Primary art source.
- `SourceArt/kenney_ui-pack-rpg-expansion/` — UI asset pack for UI.
- `SourceArt/*` — Other files and folders do not need to be opened or reasoned over unless specified.

**Visual / rendering rules:**
- `VISUAL_RULES.md` (repo root) — **this is a pixel-art game.** Read it before importing or rendering any texture, sprite, or VFX. For the step-by-step sprite-sheet → animation import procedure, use the `import_sprite_sheet_animation` skill.

---

## Testing & Verification Philosophy

Tests are **not required**. Do not use TDD / test-first / red-green-refactor on this project.

- **Implementation and tuning come first.** Build the feature, then tune its numbers by feel — game rules and balance are discovered by playing, not specified up front.
- **Tests emerge from play and from regressions, not from process.** Write a test when:
  - playtesting (with agents or with humans) surfaces behavior worth pinning down, or
  - a regression is detected and you want to keep it from recurring.
- **Never propose writing a test before the implementation** for this project.
- Feel, balance, and "is it fun" are verified by running and playing the game, not by assertion.

---

## Workflow Orchestration

### 1. Subagent Strategy (Parallelize Intelligently)
- Use subagents to keep the main context clean and to parallelize:
  - repo exploration, pattern discovery, test failure triage, dependency research, risk review.
- Give each subagent **one focused objective** and a concrete deliverable:
  - "Find where X is implemented and list files + key functions" beats "look around."

### 2. Incremental Delivery (Reduce Risk)
- Prefer **thin vertical slices** over big-bang changes.

### 3. Self-Improvement Loop
- After any user correction or a discovered mistake, add a new entry to `tasks/lessons.md`. `tasks/lessons.md` is the catch-all log — always record there first.
- Then, if the lesson is durable project knowledge tied to specific code or tooling (a tool gotcha, a setup step, a convention, an API quirk), **ask the user whether it should be promoted to a more permanent home** next to what it concerns — e.g. the relevant skill, a README, or this file. Durable knowledge lives beside the code; `lessons.md` keeps the process/meta lessons. Leave it in `lessons.md` if the user declines or it's a one-off process note.
- Keep each entry minimal: a short **category header** (e.g. `### Research scoping`) plus a **one-line prevention rule**. Nothing else.
- The category lets future agents skim and skip entries that look unrelated without reading the body. If a rule needs more context to be actionable, the category itself is too broad.
- Before adding a new entry, check if an existing category already covers it; extend or refine that line instead of duplicating.

---

## Autonomous agent tooling (cosmic-agent-tools)

This repo has three installed tools for running coding agents autonomously. **Read the linked doc before
you run, configure, or reason about any of them.**

- **Fleet orchestrator — `ralph/`** — many agent loops grind in parallel, each in its own git worktree
  with a hard file scope, while a **refinery** merges their branches under a gate and a **planner** keeps
  the backlog file-disjoint. Read [`ralph/SETUP.md`](ralph/SETUP.md). Entry points (PowerShell, from repo
  root): `./ralph/start-fleet.ps1 -LaneIterations 3 -RefineryIterations 12` (bounded), `-WithPlanner`
  (open-ended), `./ralph/watch-fleet.ps1` (dashboard), `./ralph/ralph.ps1 -Random` (single loop, no
  fan-out). Project knobs live in `ralph/fleet.config.ps1`; lanes in `ralph/lanes.txt` + `ralph/lane-*.md`.
- **Workshop — `workshop/`** — the SINGLE-agent counterpart: one agent, fresh context each pass, draining
  an operator-curated backlog toward `workshop/GOAL.md`, with a live web UI. Read
  [`workshop/README.md`](workshop/README.md). Run: `node workshop/ui/server.js` → http://localhost:4455,
  or `./workshop/start-workshop.ps1`. Knobs in `workshop/workshop.config.ps1`.
- **Skill — `.claude/skills/2d-game-art-direction/`** — art-direction decision guide for 2D games
  (palette, value/contrast, composition, shape language, sketch→polish). Loads on demand.
- **Playtest review loop — `tools/playtest-review.ps1`** — plays the current build with the
  `agent_play` harness, then a goal-aware synthesis scores it against `workshop/GOAL.md`, writes the
  newest entry to `FEEL-REVIEW.md`, and appends backlog items the Workshop then implements. Run with
  `-Watch` (or `/loop 30m ./tools/playtest-review.ps1`) for the periodic "play → score → steer" loop.
  Its PLAY step's only remaining setup is a **"Web" export preset** (add it once in the editor) — the
  Godot web export templates (scoop self-contained, auto-detected) are already in place. The harness
  and SCORE step both drive the LLM through the **Claude Code CLI** (`claude -p`), billed to your
  subscription — no `ANTHROPIC_API_KEY` needed; just stay logged in (`claude /login`). It still scores
  from the latest run if the play step can't run.

**The gate** (the whole safety story for the fleet) is `ralph/gate.ps1`: headless Godot import +
the gdUnit4 suite (now incl. a run-scene smoke test). Keep it honest as the game grows.

### ⚠️ Sacred files — do not destroy
- `ralph/PROMPT.md`, `ralph/PLAN-PROMPT.md`, `workshop/PROMPT.md`, `workshop/GOAL.md`,
  `workshop/backlog.json` are the operator's REAL task files and are **gitignored — overwriting or
  deleting them is unrecoverable**. NEVER `cp`/`Write`/`rm` them to smoke-test. Point any test at a
  throwaway prompt: `./ralph/ralph.ps1 -Prompt "$env:TEMP/ralph-test.md" -Iterations 1 -SkipPermissions:$false`.
- The fleet/workshop run agents UNATTENDED (`--dangerously-skip-permissions`). Only run where you can
  fully revert via git. Start bounded and keep the gate honest.