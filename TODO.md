# TODO — Vampire Survivors vertical slice

Durable, cross-pass backlog for the Ralph loop / fleet. The planner (`ralph/plan.ps1`) keeps this carved
into the per-lane sections below; each fleet lane picks ONLY from its own section. The single loop
(`ralph/ralph.ps1`) and Workshop can pull from anywhere. Check items off (`[x]`) and log to `DONE.md`.

> This is a seed. Replace these with the real next steps toward `workshop/GOAL.md`. The lane section
> headers must match the `TODO.md` sections named in each `ralph/lane-*.md`.

## Enemies / Spawning / Waves
- [ ] Stand up a base enemy scene + script (`scripts/enemies/`, `scenes/enemies/`): move toward the player, take damage, die.
- [ ] Add a simple time-based wave spawner that scales count/rate over a run.

## Weapons / Projectiles / Upgrades
- [ ] Stand up a base auto-attacking weapon (`scripts/weapons/`, `scenes/weapons/`): fire on a timer at the nearest enemy.
- [ ] Add a projectile that deals damage on hit and despawns.

## UI / HUD / Level-up screen / Menus
- [ ] HUD showing HP, timer, level, and XP bar (`scripts/ui/`, `scenes/ui/`).
- [ ] Level-up screen that pauses and offers a choice of upgrades.

## SEAM — main run scene + player (touch sparingly, coordinate)
- [ ] Stand up `scenes/run.tscn` + a player (`scripts/player/`): WASD move, HP, XP pickup. Wire spawner + weapon mounts via signals.
