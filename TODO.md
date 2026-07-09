# TODO — Vampire Survivors vertical slice

Durable, cross-pass backlog for the Ralph loop / fleet. The planner (`ralph/plan.ps1`) keeps this carved
into the per-lane sections below; each fleet lane picks ONLY from its own section. The single loop
(`ralph/ralph.ps1`) and Workshop can pull from anywhere. Check items off (`[x]`) and log to `DONE.md`.

A minimal playable slice now exists (player, ramping enemy waves, auto-weapon + projectiles, XP gems,
HP/level HUD, game-over/restart) under `vampire-survivors-taskmaster/`, with placeholder vector art.
Next work is about depth + feel + real art — and the playtest reviewer (`tools/playtest-review.ps1`)
will keep adding goal-driven items here / in `workshop/backlog.json`.

## Enemies / Spawning / Waves
- [x] Base enemy: chases the player, deals contact damage, dies to projectiles.
- [x] Time-based wave spawner that ramps count/rate over a run.
- [ ] Add 2–3 enemy archetypes (fast/swarm, tanky/slow) with distinct stats + color/shape.
- [ ] Wave director: timed "events" (a rush, a mini-horde) instead of a flat ramp.

## Weapons / Projectiles / Upgrades
- [x] Base auto-weapon: fires at the nearest enemy on a timer; projectile damages + despawns.
- [ ] A second weapon with a different pattern (area/aura or spread) to make builds matter.
- [ ] Weapon level-up effects (more projectiles / faster fire / more damage) driven by player level.
- [ ] Make each weapon follow its wiki level-up table (like the Whip now does). One ready-to-enqueue
      task per weapon — King Bible, Lightning Ring, Garlic, Fire Wand, Knife, Runetracer, Magic Wand —
      with the wiki table + suggested `data/<weapon>_levels.csv` in `WEAPON-LEVELUP-TABLES.md`.

## UI / HUD / Level-up screen / Menus
- [x] HUD: HP, survival time, kills, level + XP.
- [ ] Level-up screen: pause on level-up and offer a choice of 3 upgrades (the core VS decision).
- [ ] Start + game-over screens beyond the placeholder banner.

## Art / Feel  (honor VISUAL_RULES.md; art from SourceArt/)
- [ ] Replace placeholder circles with real sprites from `SourceArt/extracted_clean/` (player, enemy, gem).
- [ ] Juice: hit flash, death pop, pickup sparkle, light screen shake on damage.

## SEAM — main run scene + player (touch sparingly, coordinate)
- [x] `scenes/run.tscn` + player (move, HP, XP pickup) wiring spawner + weapon. Built in code in `scripts/run/run.gd`.

## Setup prerequisites (one-time, for the playtest reviewer's PLAY step)
- [x] Godot 4.6 **web export templates** — already installed. scoop runs Godot self-contained (a `._sc_`
      marker by the binary), so they live at `scoop\apps\godot\current\editor_data\export_templates\4.6.2.stable`
      (junctioned to `scoop\persist\godot\…`), not `%APPDATA%`. The reviewer's preflight detects this.
- [x] **ANTHROPIC_API_KEY** in repo-root `.env` — set (the harness drives the game via the API).
- [x] **"Web" export preset** — created (`vampire-survivors-taskmaster/export_presets.cfg`, non-threaded).
      Verified: a real headless export builds `index.html/.wasm/.pck` and the build boots in-browser
      with the AgentBridge + adapter live (`agent_play/boot-check.mjs`).
- [ ] **Fund the Anthropic balance** — the key is valid but the account is out of credits, so the
      harness's per-step AI decisions return "credit balance is too low" (0 findings). All the
      plumbing (export → boot → drive → screenshot → report) works; a real autonomous play-through
      just needs credits. The SCORE step run via Claude Code is unaffected.
