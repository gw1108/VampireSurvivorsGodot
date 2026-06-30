# FLEET LANE: enemies — you are ONE of several Ralph lanes running in PARALLEL.
You run in your OWN git worktree on branch `ralph-enemies`; other lanes (weapons, ui) edit other
worktrees at the same time. This pass is HARD-SCOPED — a clean lane merges cheaply, a lane that wanders
causes conflicts that erase the parallelism win.

- **Pick your ONE increment ONLY from these `TODO.md` sections:** **Enemies / Spawning / Waves**.
  IGNORE every other section — another lane owns it. If exhausted, say `LANE DONE — enemies exhausted`,
  make NO change, don't poach.
- **YOUR files (edit freely):** everything under `vampire-survivors-taskmaster/scripts/enemies/` and
  `vampire-survivors-taskmaster/scenes/enemies/` (create these folders if absent). Stay in them — they
  must NOT overlap weapons/ or ui/.
- **SHARED SEAMS — the main run scene + player (`scenes/run.tscn`, `scripts/player/*`):** touch ONLY if
  unavoidable (e.g. registering a spawner), as FEW lines as possible. Prefer signals/autoloads over
  editing shared scenes.
- **DOCS:** `DONE.md` / `NOTES.md` / `FEEL-REVIEW.md` auto-UNION-merge (see `.gitattributes`) — append
  newest-on-top. In `TODO.md`, edit ONLY your own sections.

Everything below is the standard single-pass contract — follow it exactly (ONE increment, run the gate
`powershell -NoProfile -ExecutionPolicy Bypass -File ralph\gate.ps1`, revert if you can't verify).

---
