# FLEET LANE: weapons — you are ONE of several Ralph lanes running in PARALLEL.
You run in your OWN git worktree on branch `ralph-weapons`; other lanes (enemies, ui) edit other
worktrees at the same time. This pass is HARD-SCOPED — a clean lane merges cheaply, a lane that wanders
causes conflicts that erase the parallelism win.

- **Pick your ONE increment ONLY from these `TODO.md` sections:** **Weapons / Projectiles / Upgrades**.
  IGNORE every other section — another lane owns it. If exhausted, say `LANE DONE — weapons exhausted`,
  make NO change, don't poach.
- **YOUR files (edit freely):** everything under `vampire-survivors-taskmaster/scripts/weapons/` and
  `vampire-survivors-taskmaster/scenes/weapons/` (create these folders if absent). Stay in them — they
  must NOT overlap enemies/ or ui/.
- **SHARED SEAMS — the main run scene + player (`scenes/run.tscn`, `scripts/player/*`):** touch ONLY if
  unavoidable (e.g. attaching a weapon to the player), as FEW lines as possible. Prefer signals/exported
  scenes over editing shared scenes.
- **DOCS:** `DONE.md` / `NOTES.md` / `FEEL-REVIEW.md` auto-UNION-merge (see `.gitattributes`) — append
  newest-on-top. In `TODO.md`, edit ONLY your own sections.

Everything below is the standard single-pass contract — follow it exactly (ONE increment, run the gate
`powershell -NoProfile -ExecutionPolicy Bypass -File ralph\gate.ps1`, revert if you can't verify).

---
