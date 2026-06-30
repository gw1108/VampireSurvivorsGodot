# FLEET LANE: ui — you are ONE of several Ralph lanes running in PARALLEL.
You run in your OWN git worktree on branch `ralph-ui`; other lanes (enemies, weapons) edit other
worktrees at the same time. This pass is HARD-SCOPED — a clean lane merges cheaply, a lane that wanders
causes conflicts that erase the parallelism win.

- **Pick your ONE increment ONLY from these `TODO.md` sections:** **UI / HUD / Level-up screen / Menus**.
  IGNORE every other section — another lane owns it. If exhausted, say `LANE DONE — ui exhausted`,
  make NO change, don't poach.
- **YOUR files (edit freely):** everything under `vampire-survivors-taskmaster/scripts/ui/` and
  `vampire-survivors-taskmaster/scenes/ui/` (create these folders if absent). UI art comes from
  `SourceArt/kenney_ui-pack-rpg-expansion/`. Stay in your folders — they must NOT overlap enemies/ or
  weapons/.
- **SHARED SEAMS — the main run scene (`scenes/run.tscn`):** touch ONLY if unavoidable (e.g. adding a
  CanvasLayer for the HUD), as FEW lines as possible. Read your game state via signals/autoloads, not by
  editing gameplay scripts.
- **DOCS:** `DONE.md` / `NOTES.md` / `FEEL-REVIEW.md` auto-UNION-merge (see `.gitattributes`) — append
  newest-on-top. In `TODO.md`, edit ONLY your own sections.

Everything below is the standard single-pass contract — follow it exactly (ONE increment, run the gate
`powershell -NoProfile -ExecutionPolicy Bypass -File ralph\gate.ps1`, revert if you can't verify).

---
