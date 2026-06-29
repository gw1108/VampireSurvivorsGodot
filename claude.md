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
- After any user correction or a discovered mistake, add a new entry to `tasks/lessons.md`.
- Keep each entry minimal: a short **category header** (e.g. `### Research scoping`) plus a **one-line prevention rule**. Nothing else.
- The category lets future agents skim and skip entries that look unrelated without reading the body. If a rule needs more context to be actionable, the category itself is too broad.
- Before adding a new entry, check if an existing category already covers it; extend or refine that line instead of duplicating.