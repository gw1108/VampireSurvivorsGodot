
# Taskmaster Loop Progress

- **Started:** 2026-06-21T16:13:06.769Z
- **Preset:** default
- **Max iterations:** 36

---

## Task 2 — Create Core Data Model Classes (DONE)
- Created `vampire-survivors-taskmaster/logic/`: `stat_block.gd`, `resolved_stats.gd`, `player_state.gd`, `game_state.gd` (all `class_name X extends RefCounted`).
- Added gdUnit4 suites in `test/` (stat_block, resolved_stats, player_state, game_state) — 19/19 pass.
- `GameState.index` left **untyped** (`= null`): `SpatialIndex` class is a later task; a typed forward-ref would be a parse error.
- Gitignored `vampire-survivors-taskmaster/reports/` (gdUnit4 run artifacts).

### Learnings
- Godot project lives in `vampire-survivors-taskmaster/`, not repo root (per systems.md note; the skill's `snaketaskmaster/` ref is stale).
- gdUnit4 didn't compile against Godot 4.6.2: `GdUnitFileAccess.gd:199` used `get_as_text(true)` but 4.6.2's `FileAccess.get_as_text()` takes 0 args. Patched the vendored line; documented in `AgentMD.md`. Test runner: `addons/gdUnit4/runtest.cmd --godot_binary <godot.exe> -a test`.

- Iter 1: success | tools: 35 (TM:1 W:14 NW:21) | ctx: 74,486 tokens (7.4% of ctx, 925,514 free) | session: 654a269a

## Task 3 — Create Entity Data Classes (DONE)
- Created 10 `class_name X extends RefCounted` data classes in `logic/`: enemy, projectile, damage_zone, gem, pickup, chest, light_source, weapon_instance, passive_instance, level_up_offer.
- Enums: `DamageZone.Anchor`, `Gem.Tier`, `Pickup.Type`. `def`/`source_weapon` left untyped (`= null`) since Def resources are a later task.
- Added 10 gdUnit4 suites in `test/`. Full suite now 14 files / 56 cases — all pass.

### Learnings
- Bash CWD resets to repo root at the start of each loop turn (does NOT persist across iterations). Always use absolute paths: `godot --path C:/.../vampire-survivors-taskmaster`, and run `runtest.cmd` via `cmd //d //c "cd /d <projdir> && ..."`. Running from repo root silently does nothing (no project.godot there) — nearly skipped verification.
- The `SCRIPT ERROR: Trying to assign value of type 'Nil' to a variable of type 'bool'` line during import is a benign pre-existing gdUnit4 addon message (present since task 2); unrelated to logic classes — tests still pass.
- Iter 2: success | tools: 36 (TM:1 W:22 NW:14) | ctx: 98,242 tokens (9.8% of ctx, 901,758 free) | session: 654a269a

## Task 4 — Create Immutable Data Definition Resources (DONE)
- Created 5 `Resource` def classes in `data/defs/`: weapon_def, enemy_def, passive_def, stage_def, character_def. Plus `data/level_curve.gd` and `data/pickup_table.gd` (RefCounted static-data scripts) — placed at `data/` root per systems.md layout (not under defs/), since they are const tables not Resources.
- `level_curve.gd`: transcribed the EXACT cumulative XP table (L1-60) from `.firecrawl/wiki-offline/Level_up.md` chart; `xp_to_next`/`total_xp_for_level` static funcs; extends +16/level past L60. Verified vs wiki (L1=5, L20=795 incl +600, total L40=9886.5).
- `pickup_table.gd`: weighted drop pool keyed by `Pickup.Type` with seeded `roll(rng)`. Weights are placeholder estimates (commented) pending wiki validation; mechanism is the stable contract.
- Added 7 gdUnit4 suites. Full suite now 21 files / 80 cases — all pass.

### Learnings
- A `const Dictionary` CAN use another global class's enum as keys (`Pickup.Type.COIN`) — cross-class enum refs resolve at compile time in Godot 4.6.2 (confirmed by clean import + passing PickupTable tests).
- Wiki text vs chart disagree on the L21+ XP base (text implies clean ints; chart has .5 values like 266.5). Chose the chart (ground truth) as the const table; documented the rule in comments.
- Iter 3: success | tools: 23 (TM:1 W:15 NW:8) | ctx: 129,024 tokens (12.9% of ctx, 870,976 free) | session: 654a269a

## Task 5 — Create Antonio Character and Whip Weapon Data (DONE)
- Authored `data/character_antonio.tres` (CharacterDef) and `data/weapons/whip.tres` (WeaponDef) via a temp headless ResourceSaver generator (then deleted it) — guarantees valid .tres (typed `Array[Dictionary]([...])` syntax that hand-writing would have gotten wrong).
- Followed WIKI specs over the task `details` shorthand (task description says "based on wiki specifications"):
  - Antonio: max_health 120 (+20), base_stats armor +1, Might +10% every 10 levels cap +50% (NOT "+10%/level" as details said). Extended CharacterDef with `growth_interval` + `growth_cap` to represent stepped growth faithfully.
  - Whip: base_damage 10 (NOT 20), cooldown 1.35 (NOT 1.3), pierce -1 (=infinite/area sweep), knockback 1, ignores Speed/Duration. Levels 2-8: +1 amount@2, +5 dmg@3-8, +10% area@4&6 → max 40 dmg / 120% area / 2 amount (matches wiki).
- Added `L20_BONUS_XP=600` / `L40_BONUS_XP=2400` consts to level_curve.gd (task item 3); intentionally did NOT add a lossy flat `CURVE: Array[int]` (real curve has fractional values past L20 — xp_to_next() is source of truth).
- Added `data_resources_test.gd` (loads + validates both .tres). Full suite now 22 files / 86 cases — all pass.

### Learnings
- ResourceSaver only serializes NON-default property values (e.g. whip area=1.0, amount=1 omitted); loading restores defaults. Don't assert on a .tres text containing default fields.
- Generating .tres via ResourceSaver (headless `-s` script) is far safer than hand-authoring — typed-array/exported-resource serialization syntax is fiddly.
- Iter 4: success | tools: 19 (TM:1 W:8 NW:11) | ctx: 157,112 tokens (15.7% of ctx, 842,888 free) | session: 654a269a

## Task 6 — Implement SpatialIndex System (DONE)
- Created `logic/spatial_index.gd`: uniform spatial-hash grid (CELL_SIZE 64). Combined parallel arrays (entity_positions/types/ids); enemies [0,enemy_count), then gems, then pickups. buckets: Vector2i -> Array[int] of combined indices.
- Implemented rebuild, query_radius, nearest_enemy (linear over enemy entries; exact), random_enemy (seeded), plus get_entity_type/local_id/position accessors to interpret query_radius combined indices.
- FIXED two bugs in the task skeleton: (1) it stored per-category `i` in buckets but indexed the combined `entity_positions` with it; resolved by using combined indices + entity_ids mapping. (2) used `int()` which mis-buckets negative coords (cell 0 double-wide at origin) — switched to `floori()`. World is boundless incl. negatives, so this matters.
- Resolved task-2 deferral: `GameState.index` is now typed `SpatialIndex` (was untyped `= null`).
- Added `spatial_index_test.gd` (14 cases incl. negative coords, boundary-inclusive, mixed types, nearest ignores gems, random determinism). Full suite 23 files / 99 cases — all pass.

### Learnings
- gdUnit4 tip: assert_int(x).is_between(0, 2) works for range checks; tests can use real data classes (Enemy/Gem/Pickup) as fixtures.
- For Dictionary bucket values use plain `Array` (reference type) not PackedInt32Array — `dict[key].append()` mutates in place without CoW surprises.
- Iter 5: success | tools: 9 (TM:1 W:4 NW:5) | ctx: 181,019 tokens (18.1% of ctx, 818,981 free) | session: 654a269a

## Task 27 — Create Mad Forest Stage Data (DONE)
- Generated (headless ResourceSaver, then deleted generator) `data/stage_mad_forest.tres` + 6 enemy defs in `data/enemies/`: bat, skeleton, ghost, giant_bat, werewolf, reaper.
- Enemy stats are WIKI-ACCURATE: bat/Pipeestrello 1hp/5pow/140spd/1xp; skeleton 15/10/100/2; ghost 10/5/200/1.5; giant_bat(boss) 500/20/140/25 kb-immune; werewolf 180/14/130/2; reaper 655350hp/65535pow/1200spd, is_boss, kb-immune.
- NOTE: task said Reaper "65535 HP" — that's actually the one-shot DAMAGE (power); real HP is 655350. Authored faithfully (power=65535, hp=655350).
- Wave script = 30 entries (min 0-29). min_alive + interval are REAL wiki values for min 2-13,15,20-27,29; min 0,1,14,16-19,28 interpolated (commented). Real Mad Forest roster (Mudman/Zombie/Mummy/Venus/Pipeestrello/etc.) mapped onto the task's 6-id set. Bosses at real minutes: giant_bat@8, werewolf@15 (wiki Giant Bat@8 / Giant Werewolf@15). Events: bat_swarm@3, flower_wall@5, ghost_swarm@13&27.
- Extended StageDef with `brazier_interval` (boundless map spawns braziers periodically, not at fixed positions). Mad Forest = 60s.
- Stage modifiers: enemy_move_speed x1.1 (wiki). Added `stage_mad_forest_test.gd` (10 cases incl. all referenced enemies exist). Full suite 24 files / 109 cases — all pass.

### Learnings
- Wiki enemy stat blocks are in a compact `Health; ; N | Power; ; N | MSpeed; ; N | ... | XP; ; N` line; the `★` suffix on HP marks HP-scales-with-level bosses.
- The offline Mad_Forest.md is a repeated-cell HTML dump; the useful minute table reads as `MM:00 [enemies] <min_alive> <interval> [boss] ; Level:1 [event]`.
- Iter 6: success | tools: 17 (TM:1 W:5 NW:12) | ctx: 215,434 tokens (21.5% of ctx, 784,566 free) | session: 654a269a

## Task 7 — Implement StatSystem (DONE)
- Created `logic/stat_system.gd`. Two-phase cached model: `recompute_block(player, character_def=null)` accumulates char base + level growth + passive bonuses into player.stats (StatBlock); `resolve(player, stage_def=null)` copies block->derived, applies stage curse modifier, clamps caps. Per-tick resolve never iterates inventory.
- DEVIATED from skeleton: it applied passives in BOTH resolve and recompute_block (double-count bug). Passives are summed ONCE in recompute_block only. Documented.
- Passive model: PassiveDef.stat_bonuses[stat] = cumulative-at-level array; bonus = arr[clamp(level-1)] added to block (additive multiplier bonuses, VS-style). Character growth = floor(level/growth_interval) * per_step, capped by growth_cap. Generic copy/accumulate via STAT_FIELDS + Object.get/set(name).
- Caps: cooldown floor 0.1, move_speed ≤2, area ≤3, armor 0..100.
- Added `stat_system_test.gd` (13 cases incl. Antonio integration: L1 might 1.0/maxhp 120/armor 1, stepped growth L10=1.1 L25=1.2 L50=1.5 L60 capped, passive stacking, growth+passive combine). Full suite 25 files / 121 cases — all pass.

### Learnings
- `1.0 - 0.9` = 0.09999999998 in float → `is_equal(0.1)` exact-match fails. Use a precomputed exact const (0.1) for cap floors, not inline subtraction.
- `int / int` triggers Godot's "integer division" warning even when intended; silence with `@warning_ignore("integer_division")` to keep test logs clean (it's a warning, not an error — tests still pass).
- Object.get(name)/set(name, v) by string works on GDScript class vars — lets a pure system copy/accumulate stat fields generically from a const name list.
- Iter 7: success | tools: 15 (TM:1 W:6 NW:9) | ctx: 240,309 tokens (24.0% of ctx, 759,691 free) | session: 654a269a

## Task 16 — Create GameData Autoload (DONE)
- Created `autoload/game_data.gd` (extends Node, NO class_name — global name `GameData` is the accessor). Registered in project.godot `[autoload]` as `GameData="*res://autoload/game_data.gd"`.
- Loads weapons/enemies/passives from their subdirs (`_load_subdir`), and characters/stages from individual .tres at data/ root routed BY TYPE (`_load_root_defs`: is CharacterDef / is StageDef). This handles my actual layout (character_antonio.tres & stage_mad_forest.tres are at data/ root, not in subdirs).
- Accessors: get_weapon/enemy/passive/character/stage(id)->Def|null; get_all_weapons/enemies/passives()->typed arrays (built explicitly since Dictionary.values() is untyped). get_xp_for_level/get_total_xp_for_level DELEGATE to LevelCurve (no duplicate `_level_curve` array — avoids drift vs skeleton).
- Graceful: missing passives/ dir guarded via DirAccess.dir_exists_absolute (no error spam).
- Added `game_data_test.gd` (9 cases). Autoload IS accessible by global name in gdUnit4 tests. Full suite 26 files / 130 cases — all pass.

### Learnings
- Returning `Dictionary.values()` from a func typed `-> Array[T]` errors (values() is untyped Array) — build a typed `Array[T]` and append.
- gdUnit4 tests run with project autoloads instantiated; reference the autoload by its global name (`GameData.x`) directly.
- Iter 8: success | tools: 11 (TM:1 W:4 NW:7) | ctx: 255,436 tokens (25.5% of ctx, 744,564 free) | session: 654a269a

## Task 8 — Implement MovementSystem (DONE)
- Created `logic/movement_system.gd`: `step_player(player, input_dir, dt)` (normalize input, set facing on nonzero, velocity zero when idle) and `step_enemies(state, dt)` (freeze tick / knockback slide / home toward player or fixed-direction drift / floaty bob). BASE_PLAYER_SPEED 100 px/s × derived.move_speed.
- Refinements over skeleton: (1) zero velocity when input below deadzone (skeleton left a tiny residual); (2) guard `enemy.def == null` -> speed 0 (no crash); (3) made floaty frame-rate-independent (`* dt`) — skeleton's per-frame `+= sin()` drifts at higher FPS, violating the frame-rate-independence requirement.
- DEFERRED: stage `enemy_move_speed` x1.1 modifier not applied yet (GameState doesn't hold stage_def; wire in RunController/SpawnDirector later). Enemy speed = def.speed for now.
- Added `movement_system_test.gd` (13 cases: diagonal normalization, facing retention, dt scaling, homing normalized, freeze, knockback-overrides-homing, fixed_direction, null def, floaty isolation). Full suite 27 files / 143 cases — all pass.
- Iter 9: success | tools: 8 (TM:1 W:3 NW:5) | ctx: 270,304 tokens (27.0% of ctx, 729,696 free) | session: 654a269a

## Task 13 — Implement PickupSystem (DONE)
- Created `logic/pickup_system.gd`: step() -> _step_gems / _step_pickups / _step_chests / _enforce_gem_cap. Gems collect within 16px (XP×growth -> ProgressionSystem.add_xp), magnetize within derived.magnet at 300px/s. Pickups by type: chicken heal (clamped to max_health), coin/coin_bag gold×greed, vacuum collects all gems; rosary/orologion/nduja/sorbetto/clover flagged in global_effects (effects owned by other systems). Chests increment chest_count (content resolution deferred to task 14). Direct distance loops (no SpatialIndex needed at these counts).
- FORWARD-DEP RESOLVED: PickupSystem needs `ProgressionSystem.add_xp` but task 14 (ProgressionSystem) isn't built. Created `logic/progression_system.gd` with **add_xp ONLY** (corrected) to unblock. ⚠️ TASK 14 must ADD build_offer/apply_choice/open_chest and NOT regress add_xp.
- FIXED 2 bugs in task-14's add_xp sketch: (1) off-by-one — uses `LevelCurve.xp_to_next(player.level)` after leveling, not `level+1` (our get_xp_for_level means "xp from L to L+1"); (2) removed the `add_xp(600)/add_xp(2400)` at L20/L40 — those are requirement INCREASES already baked into LevelCurve.CUMULATIVE_XP, granting them as free XP double-counts. add_xp delegates to LevelCurve (pure, no GameData autoload dep).
- FIXED gem-cap off-by-one in skeleton: it trimmed to GEM_CAP then appended → GEM_CAP+1. Now trims to GEM_CAP-1 then appends 1 red gem = exactly GEM_CAP.
- Added progression_system_test.gd (5) + pickup_system_test.gd (14). Full suite 29 files / 161 cases — all pass.

### Learnings
- When a test routes XP via add_xp, a "raw xp" assertion can fail if the amount crosses the level threshold (resets xp to 0). Keep test XP under xp_to_next (5 at L1) or assert level/pending instead.
- Forward-dependency pattern: when a system's skeleton calls an unbuilt class, implement only that class's minimal needed interface (here add_xp) and loudly flag it for the owning task.
- Iter 10: success | tools: 16 (TM:1 W:6 NW:10) | ctx: 309,867 tokens (31.0% of ctx, 690,133 free) | session: 654a269a

## Task 10 — Implement WeaponSystem Core (DONE)
- Created `logic/weapon_system.gd`: step() ticks each weapon.cooldown_timer, fires when ≤0, resets to resolved_cooldown × derived.cooldown. cast() dispatches by def.id (whip implemented; default no-op for unbuilt patterns). _cast_whip emits FOLLOW_PLAYER DamageZone(s): offset = facing×40×side, radius = 60×area, lifetime 0.15, tick_interval 0 (single hit). Amount adds slashes alternating fwd/back; starting side flips each cast.
- BETTER than skeleton: per-level scaling reads the REAL WeaponDef.levels deltas via `_resolve_weapon_stats` (not the generic 1+(level-1)*0.1). Whip L3 → damage 15, amount 2 (verified vs authored data).
- Emitted zone.damage is BASE (level-scaled) damage only — Might is applied later in CombatSystem (single place), per architecture.
- Added `weapon_system_test.gd` (13 cases: cooldown tick/reset/reduction, multi-weapon independence, whip zone fields, level damage scaling, amount alternation, cross-cast side flip, area→radius, derived amount, facing dir, unknown-id + null-def safety). Full suite 30 files / 174 cases — all pass.

### Learnings
- ⚠️ `var x := obj.untyped_field` (`:=` on a Variant like WeaponInstance.def) is a PARSE error ("Cannot infer type"). Worse: gdUnit4 runs godot with `-d`, so such an error drops into an INTERACTIVE DEBUGGER that HANGS the test run (Debugger Break loop). `--import` grep does NOT catch it (only triggers when the func compiles at runtime). Fix: use `var x = obj.field` (untyped) for Variant fields.
- Mitigation: wrap test runs in `timeout 150 ...` and kill stray godot procs (`taskkill //F //IM godot.exe`/`Godot_v4.6.2-stable_win64_console.exe`) if a run hangs. Validate tricky scripts with a tiny `-s` load() check, not just --import.
- Iter 11: success | tools: 18 (TM:1 W:5 NW:13) | ctx: 335,149 tokens (33.5% of ctx, 664,851 free) | session: 654a269a

## Task 12 — Implement SpawnDirector (DONE)
- Created `logic/spawn_director.gd`: step(state, stage, dt) advances clock/minute; on minute change spawns bosses + runs events (or Reaper at/after reaper_minute); wave top-ups fire on a Curse-scaled spawn_timer (added `spawn_timer` to GameState), filling toward min_alive capped at soft cap (300). Reaper minute clears board + spawns reaper, +1/min after, and disables normal top-ups. spawn_starting() does the 10 opening spawns. Off-screen ring 400-500px.
- Reconciled with REAL data schema: waves use enemy_ids[]/interval/min_alive (skeleton assumed enemy_def/spawn_interval). FIXED skeleton bug: its _spawn_wave_topup filled to min_alive EVERY tick ignoring interval — now gated by spawn_timer >= interval/curse. Reaper hp from def (655350), not skeleton's 65535 (that's power/damage).
- ⚠️ BIG GOTCHA: a `class_name` pure-logic script CANNOT reference the `GameData` autoload (fails global-class registration). Switched to `load("res://data/enemies/<id>.tres")` (Godot-cached). Then needed a clean `--import` to re-register the class before the runner saw it (stale global_script_class_cache caused phantom "SpawnDirector not declared"). Killed 2 stuck debugger-hung godot procs along the way.
- Added `spawn_director_test.gd` (10 cases: clock, interval top-up, soft-cap halt, ring bounds, starting spawns, boss@8, swarm event@3, reaper@30 clears+spawns, +1/min, no top-up post-reaper). Full suite 31 files / 184 cases — all pass.
- Iter 12: success | tools: 21 (TM:1 W:8 NW:13) | ctx: 374,325 tokens (37.4% of ctx, 625,675 free) | session: 654a269a

## Task 14 — Implement ProgressionSystem (DONE)
- Extended `logic/progression_system.gd` (add_xp was pre-built in task 13) with build_offer + apply_choice + option helpers. Options are Dicts {kind, def, is_upgrade, target, target_level}. Pool = upgradeable owned (weapons <L8, passives <max_level) + new (not owned, inventory <6). num_options 3, or 4 if rng.randf() < 1-1/luck.
- FIXED 4 skeleton bugs: (1) pool.shuffle() uses GLOBAL rng → replaced with Fisher-Yates `_shuffle(arr, state.rng)` for determinism; (2) `choice.key` dot-access doesn't work on GDScript Dicts → use `choice["key"]`; (3) `recompute_block(player)` with no character_def WIPES Antonio's base stats on every level-up → added PlayerState.character_def and pass it; (4) GameData autoload can't be referenced from class_name script → catalog loaded by path via DirAccess (`_load_defs`).
- Added PlayerState.character_def field (CharacterDef ref for stat recompute on level-up).
- is_max_state set when pool empty (full+maxed inventory → gold/chicken granted by caller). open_chest NOT implemented (not in task details; PickupSystem chest_count still awaits a chest-resolution task).
- Extended progression_system_test.gd: +9 cases (new/upgrade offers, maxed not offered, 3-option default, deterministic per seed, max_state, apply new/upgrade, character-base-stats regression). Full suite 31 files / 193 cases — all pass (clean --import first avoided the stale-class-cache trap).
- Iter 13: success | tools: 13 (TM:1 W:5 NW:8) | ctx: 396,891 tokens (39.7% of ctx, 603,109 free) | session: 654a269a

## Task 18 — Create Input Actions (DONE)
- Added `[input]` section to project.godot: move_left (A/Left), move_right (D/Right), move_up (W/Up), move_down (S/Down), pause (Escape). Used the exact Godot InputEventKey Object serialization; keycode-based (matches task sketch). Did NOT redefine ui_accept — it's a Godot built-in (Enter/Space); overriding it in project.godot would drop default bindings.
- Added `input_actions_test.gd` (3 cases: actions exist, bound to expected WASD+arrow/Escape keycodes via InputMap.action_get_events, ui_accept built-in still present). Full suite 32 files / 196 cases — all pass.
- Iter 14: success | tools: 9 (TM:1 W:3 NW:6) | ctx: 408,165 tokens (40.8% of ctx, 591,835 free) | session: 654a269a

## Task 9 — Implement CombatMath Utilities (DONE)
- Created `logic/combat_math.gd` (`class_name CombatMath extends RefCounted`): static `calc_damage` (base×might), `roll_crit(rng, chance, mult)`->{is_crit, multiplier} via seeded rng, `apply_armor` (maxf(dmg-armor, 1.0) — VS min-1 rule), `calc_knockback` (resist>=1 immune→ZERO, else dir×force×(1-resist); coincident points→ZERO via normalized zero vec), `is_in_range` (distance_squared_to <= range_sq, sqrt-free). Consts KNOCKBACK_DURATION=0.1, BASE_KNOCKBACK_FORCE=100.0.
- Followed task sketch faithfully (no bugs to fix); used typed `:=` locals (rng.randf() and Vector2 ops are non-Variant, so safe — unlike the WeaponInstance.def Variant trap from iter 11).
- Added `combat_math_test.gd` (18 cases: damage scaling/zero base, crit never@0/always@1/deterministic-per-seed, armor reduce/zero/floor/exact-floor, knockback dir/partial/full/over-resist/coincident, range within/boundary-inclusive/outside). Full suite 33 files / 214 cases — all pass.
- Iter 15: success | task 9 done.

## Task 11 — Implement CombatSystem (DONE)
- Created `logic/combat_system.gd`: step() -> _step_projectiles + _step_zones + _reap_dead. Projectiles tick lifetime, move by velocity, broadphase via SpatialIndex.query_radius, apply Might+crit damage (CombatMath), knockback, pierce decrement. Zones tick lifetime, FOLLOW_PLAYER tracks player, single-hit (tick_interval 0, e.g. Whip) hit once via hit_ids, periodic zones clear hit_ids each tick_interval to re-hit. Death spawns XP gem (tier bracketed by xp) + bumps kills.
- FIXED 4 skeleton bugs: (1) query_radius returns COMBINED indices (enemies+gems+pickups) — must filter to Type.ENEMY and map via get_entity_local_id; sketch's `state.enemies[enemy_idx]` read the wrong array slot. (2) hit-dedup must key on enemy.get_instance_id() (stable/unique), NOT array index — swap-remove reshuffles indices, breaking dedup across the frames a piercing shot lives. (3) enemies NOT removed mid-step (invalidates the shared index for the rest of the tick) — deaths deduped via a set, reaped once at end. (4) magic 100.0/0.1 -> CombatMath.BASE_KNOCKBACK_FORCE/KNOCKBACK_DURATION. Also implemented _step_zones (omitted in sketch). Drops not rolled on normal kills (pickups come from braziers).
- Added combat_system_test.gd (19 cases: move/expire, hit+damage, Might/crit scaling, pierce multi/limit, hit_ids cross-frame dedup, knockback + boss immunity, death gem/kill/reap, double-kill dedup, zone single-hit/miss/follow-player/periodic-rehit/expire, no-index safety). Full suite 34 files / 233 cases — all pass.

### Learnings
- ⚠️ RE-HIT the iter-11 trap: `var eid := enemy.get_instance_id()` where `enemy` is a Variant (untyped array elem) is a PARSE error ("Cannot infer type") that drops gdUnit4's `-d` run into an INTERACTIVE DEBUGGER and HANGS (run timed out, exit 143). `--import` did NOT catch it. Fix: `var eid: int = enemy.get_instance_id()`. Validate func-body parse errors with `godot --headless --check-only --script res://...` (catches what --import misses), THEN run the suite.
- Iter 16-18: success | task 11 done (iter 16 wrote files + hit the eid hang; iter 17 fixed both eid lines + check-only; iter 18 confirmed 233/233).

## Task 15 — Implement HealthSystem (DONE)
- Created `logic/health_system.gd`: step() -> tick iframe_timer, passive recovery (recovery*dt clamped to max_health), contact damage when iframe<=0, then death check. _check_contact_damage broadphases via SpatialIndex.query_radius(PLAYER_HITBOX 16), armor-mitigated (CombatMath.apply_armor, min 1), one enemy per contact (break), sets IFRAME_DURATION 0.24. _on_death: revives if player.revivals>0 (revivals-1, hp=max*0.5, REVIVE_IFRAME 1.0) else phase=GAME_OVER.
- FIXED 2 skeleton bugs (same class as task 11): (1) query_radius returns COMBINED indices — filter to Type.ENEMY + map via get_entity_local_id (sketch's `state.enemies[enemy_idx]` reads wrong slot / OOB when a gem/pickup is inside the hitbox). (2) guard enemy.def==null so a def-less enemy deals no phantom damage (apply_armor's min-1 floor would hit for 1). Added const REVIVE_IFRAME_DURATION (sketch's magic 1.0).
- Added health_system_test.gd (14 cases: iframe block + countdown, contact damage sets iframes, armor reduce + min-1 floor, recovery heal/clamp/noop-at-full, one-enemy-per-contact, gem-in-hitbox ignored, null-def no damage, revival restores half + decrements + burst iframes + stays PLAYING, death->GAME_OVER, contact can kill). Full suite 35 files / 247 cases — all pass.

### Learnings
- NEW class_name scripts are NOT registered by `--check-only` (it only parses) — the gdUnit4 runner then fails with "Identifier <Class> not declared" debugger-break HANGS. MUST run `godot --headless --path <proj> --import` (registers global_script_class_cache, logs `update_scripts_classes | <Class>`) BEFORE the suite whenever a new class_name file is added. (--check-only is still useful for catching func-body Variant-inference parse errors that --import misses; do BOTH for a new file: check-only then import.)
- Iter 19-21: success | task 15 done (iter 19 wrote files + only check-only -> class unregistered hang; iter 20 ran --import to register; iter 21 confirmed 247/247).

## Task 17 — Create RunController Orchestrator (DONE)
- Created `game/run_controller.gd` (`class_name RunController extends Node2D`) — the composition root: owns GameState, drives the 11-step pipeline each physics tick (resolve stats -> player move -> spawn -> enemy move -> rebuild index -> weapons -> combat -> pickups -> health -> phase check). 3 signals: level_up_started, run_ended, phase_changed. Public API: start_run(character_id), on_option_chosen(index). Also created `game/Main.tscn` (Node2D root + script).
- DEVIATED from sketch (documented in header): (1) defs loaded BY PATH (_load_stage/_load_character/_load_weapon -> `res://data/stage_%s.tres` etc.), NOT GameData autoload — a class_name script can't reference an autoload at registration (same constraint SpawnDirector documents). (2) starting enemies via SpawnDirector.spawn_starting() (real API, honors StageDef.starting_spawn_count=10), not the sketch's private _spawn_wave_topup(state, waves[0]) loop. (3) implemented the undefined _create_player_from_def (CharacterDef -> starting whip + StatSystem recompute/resolve, hp=max, revivals=int(derived.revival)). (4) ADDED game-over handling: when HealthSystem flips phase to GAME_OVER, tick emits run_ended (sketch silently left phase changed). (5) extracted _tick(delta, input_dir) from _physics_process so tests drive the pipeline without the Input singleton.
- Added run_controller_test.gd (8 cases: start_run -> PLAYING + phase_changed, player from Antonio def (maxhp 120, full hp, whip, revivals), starting spawns == starting_spawn_count, _tick enters LEVEL_UP + emits offer, on_option_chosen resumes (iframe 0.5), chained level-ups present next offer, death -> GAME_OVER + run_ended summary, physics_process inert pre-start). Used manual signal->Array connect (version-agnostic). Full suite 36 files / 255 cases — all pass.
- Iter 22-23: success | task 17 done (iter 22 wrote files, check-only+import clean (no GameData autoload trap since loaded by path); iter 23 confirmed 255/255).

## Task 22 — Create Level-Up Screen UI (DONE)
- Created `ui/level_up_screen.gd` (`class_name LevelUpScreen extends Control`) + `ui/level_up_screen.tscn` (Control full-rect -> Background ColorRect (0,0,0,0.6) + Panel(PanelContainer, centered) -> VBoxContainer -> TitleLabel "LEVEL UP!"). show_offer(offer) builds one Button per option (text via _format_option), emits option_chosen(index) on press + hides. RunController wires level_up_started -> show_offer and option_chosen -> on_option_chosen.
- FIXED 2 skeleton bugs: (1) Dictionary dot-access (`opt.is_upgrade`, `opt.def.name`) is a runtime error in GDScript — use `opt["is_upgrade"]` / `opt["def"].name` (same fix as ProgressionSystem iter 13). (2) `_option_buttons[0].grab_focus()` crashes on a max-state (empty) offer — guarded with is_empty() check. Both WeaponDef & PassiveDef have `name`, so _format_option is safe for either kind.
- Added level_up_screen_test.gd (7 cases: hidden on ready, one button per option, NEW: label, "X Lv N-1 -> N" upgrade label, re-show clears old buttons, press emits index + hides, empty offer no crash). Tests instantiate the .tscn via load().instantiate()+add_child (triggers @onready). Full suite 37 files / 262 cases — all pass.

### Learnings
- A test helper param named `name` (or any Node property) shadows the base class (GdUnitTestSuite extends Node) -> "shadowing an already-declared property" WARNING (not a failure, but noisy). Name test-helper params distinctly (e.g. `display_name`).
- Iter 24-25: success | task 22 done (iter 24 wrote files + check-only/import clean; iter 25 confirmed 262/262, renamed shadowing `name` param to silence warning).

## Task 19 — Create PresentationLayer (DONE)
- Created `game/presentation_layer.gd` (`class_name PresentationLayer extends Node2D`): per-category Sprite2D pools (enemy/projectile/zone/gem/pickup, POOL_INITIAL_SIZE 100) + player sprite. sync(state) hides all pooled sprites, grows a pool on demand, then positions+shows one per live entity. Reused sprites = no per-frame allocations. _apply_visual tints by category (+ boss vs normal, gem by tier).
- FIXED skeleton bug: `entity.def.texture` — EnemyDef has NO `texture` field (runtime error). Per task ("placeholder textures initially") all sprites share `preload("res://icon.svg")` and are tinted per category/tier instead.
- INTEGRATED with RunController: added `_presentation` ref (get_node_or_null("PresentationLayer") as PresentationLayer) + `_process(delta)` render step calling sync(state) in ALL phases (so frozen frames still render). Added PresentationLayer node to Main.tscn (2nd ext_resource). Existing RunController tests unaffected (they use .new() w/o the scene -> _presentation stays null -> _process no-ops).
- Added presentation_layer_test.gd (8 cases: pools seeded on ready, one sprite per enemy at correct pos, hides when entities decrease, pool expands past initial, player follows+flips by facing, gems tinted by tier, boss tint differs, null-def no crash). Full suite 38 files / 270 cases — all pass.

### Learnings
- `--check-only --script X.gd` does NOT load the project's global_script_class_cache, so it FALSELY reports "Could not find type <OtherClass>" for any OTHER class_name X references — even one that exists on disk. It's only reliable for errors WITHIN the single file (syntax, local Variant inference). For cross-class type resolution, trust `--import` (full cache) instead; re-running check-only AFTER import also resolves it.
- Iter 26-27: success | task 19 done (iter 26 wrote files + integrated into RunController/Main.tscn, import clean; iter 27 confirmed 270/270).

## Task 23 — Create Pause Screen UI (DONE)
- Created `ui/pause_screen.gd` (`class_name PauseScreen extends Control`) + `ui/pause_screen.tscn` (Control full-rect -> Background ColorRect + Panel(centered) -> VBoxContainer -> TitleLabel "PAUSED" + ResumeButton + QuitButton). _input resumes on the pause action while visible (toggle); show_pause shows + focuses resume; buttons emit resume_requested / quit_requested.
- INTEGRATED into RunController: added _pause_screen ref + signal wiring in _ready; _unhandled_input opens pause (only when state != null AND phase PLAYING — sketch's unguarded `state.phase` would crash pre-run); _open_pause sets PAUSED + show_pause; _on_resume_requested -> PLAYING; _on_quit_requested -> GAME_OVER + run_ended (quit-to-results). Added PauseScreen instance to Main.tscn (load_steps 4). PAUSED phase freezes _physics_process (sim) while _process keeps rendering; input still flows (we gate by phase, not SceneTree.paused).
- No double-toggle: PauseScreen._input only acts when visible (close); RunController._unhandled_input only when PLAYING (open) — disjoint.
- Added pause_screen_test.gd (11 cases: hidden on ready, show visible, resume/quit button signals+hide, pause-key resumes when visible, pause-key ignored when hidden; RunController: pause input -> PAUSED, ignored when no state, resume -> PLAYING, quit -> GAME_OVER+run_ended, physics frozen while paused). Synthetic InputEventAction(action="pause", pressed) drives _input/_unhandled_input in tests. Full suite 39 files / 281 cases — all pass.
- Iter 28-29: success | task 23 done (iter 28 wrote files + integrated, check-only(pause)+import clean; iter 29 confirmed 281/281).

## Task 25 — Create Main Menu UI (DONE)
- Created `ui/main_menu.gd` (`class_name MainMenu extends Control`) + `ui/main_menu.tscn` (Control full-rect -> TitleLabel "VAMPIRE SURVIVORS" (top-center) + Panel(centered) -> VBoxContainer -> StartButton "Start (Antonio / Mad Forest)" + QuitButton "Quit"). _ready connects buttons + focuses Start; buttons emit start_game / quit_game.
- DEVIATED from sketch: _on_quit emits quit_game instead of get_tree().quit() directly — keeps the view testable (direct quit would terminate the gdUnit runner) and makes the declared quit_game signal live (matches PauseScreen.quit_requested pattern). The actual app-quit lives in RunController._on_quit_game.
- INTEGRATED into RunController: _main_menu ref + signal wiring in _ready; _on_start_requested -> start_run() + hide menu; _on_quit_game -> get_tree().quit(). Added MainMenu instance to Main.tscn (load_steps 5). Set project.godot run/main_scene="res://game/Main.tscn" (the game is now launchable; MainMenu is the boot screen, sim idle until Start since state stays null).
- Added main_menu_test.gd (4 cases: start button -> start_game, quit button -> quit_game, button labels, RunController._on_start_requested begins a run -> PLAYING). Full suite 40 files / 285 cases — all pass.
- Iter 30-31: success | task 25 done (iter 30 wrote files + integrated + set main_scene; iter 31 confirmed 285/285).

## Task 33 — Create Placeholder Art Assets (DONE)
- Generated 11 placeholder PNGs in `assets/sprites/` via a headless `extends SceneTree` generator (`-s`, then deleted, like iter 5's .tres gen): player (16x24 blue rect), enemy (12x12 red circle), enemy_boss (32x32 magenta circle), reaper (48x48 near-black circle), gem_blue/green/red (6/8/10 diamonds), projectile (8 white circle), zone (64 orange a=0.45 circle), pickup (12 green square), grass (64 green+brown tile). Image.create + per-pixel circle/diamond draw + save_png.
- Ran --import to generate .import sidecars (textures now loadable). Then updated PresentationLayer: loads per-category textures from assets/sprites/ at _ready into member vars (_tex_player/enemy/boss/reaper/projectile/zone/pickup + _tex_gems[tier]) via _load_tex(base_name) with FALLBACK=icon.svg if missing. _apply_visual now sets sprite.texture per category (enemy texture by role: reaper id -> boss flag -> rank-and-file); modulate left white (texture carries colour). Replaced the old modulate-tint scheme.
- Updated presentation_layer_test.gd: swapped 2 modulate-color assertions for texture assertions (gems by tier, boss vs normal) + added placeholder-loaded (not fallback), reaper-distinct, player-sprite-texture. 10 presentation cases. Full suite 41 files / 287 cases — all pass.
- NOTE: per-weapon projectile shapes (knife/wand/whip) and a tiled grass background are deferred — single projectile texture + the grass.png asset exists ready for a later background renderer.

### Learnings
- The base-class-property shadowing trap (var/param named `name` etc.) applies to PRODUCTION node scripts too, not just test suites — a `_load_tex(name)` param on a Node2D shadowed Node.name (warning). Renamed to `base_name`. (Already in lessons; reinforced.)
- Iter 32-33: success | task 33 done (iter 32 generated PNGs + imported + rewired PresentationLayer; iter 33 confirmed 287/287, renamed shadowing `name` param).

## Task 20 — Create Camera System (DONE)
- Added Camera2D follow + scrolling tiled background. RunController._process now centers _camera on player.pos and feeds the background shader's camera_pos uniform each frame (via _follow_camera). New refs _camera (World/Camera2D), _bg_material (Background/BackgroundRect.material), guarded so .new() tests no-op.
- RESTRUCTURED Main.tscn (the sketch's critical omission): a Camera2D moves the ENTIRE default canvas, so UI Controls in layer 0 would scroll with it. New tree: Main -> Background(CanvasLayer layer=-1 -> BackgroundRect ColorRect w/ ShaderMaterial), World(Node2D -> PresentationLayer + Camera2D), UI(CanvasLayer -> PauseScreen + MainMenu). UI in a CanvasLayer stays screen-fixed; world scrolls. Updated RunController get_node paths to World/* and UI/*.
- Created `game/background.gdshader` (canvas_item): tiles grass.png via fract((UV*field_size + camera_pos)/tile_size); improved over sketch (added field_size so it actually repeats vs stretching one tile, + repeat_enable). ShaderMaterial authored as a sub_resource in Main.tscn with tile_texture=grass.png.
- project.godot [display]: viewport 480x270, window override 1920x1080, stretch mode=canvas_items aspect=keep (pixel-art base resolution).
- Added camera_system_test.gd (5 cases: camera follows player, tracks movement each frame, no-camera no-crash, bg shader loads, bg uniform tracks player). Refs injected directly (no Main.tscn load). Full suite 42 files / 292 cases — all pass.
- Existing RunController/pause/menu tests unaffected: they use .new() (paths return null) — the World/UI path change is transparent to them.
- Iter 34-35: success | task 20 done (iter 34 restructured scene + shader + display settings, check-only/import clean (shader compiles, scene loads); iter 35 confirmed 292/292).
- Iter 15: success | tools: 14 (TM:1 W:3 NW:11) | ctx: 64,496 tokens (6.4% of ctx, 935,504 free) | session: 4d40dd77
- Iter 16: success | tools: 24 (TM:0 W:2 NW:22) | ctx: 109,162 tokens (10.9% of ctx, 890,838 free) | session: 4d40dd77
- Iter 17: success | tools: 7 (TM:0 W:2 NW:5) | ctx: 116,940 tokens (11.7% of ctx, 883,060 free) | session: 4d40dd77
- Iter 18: success | tools: 7 (TM:1 W:3 NW:4) | ctx: 125,562 tokens (12.6% of ctx, 874,438 free) | session: 4d40dd77
- Iter 19: success | tools: 5 (TM:0 W:2 NW:3) | ctx: 136,709 tokens (13.7% of ctx, 863,291 free) | session: 4d40dd77
- Iter 20: success | tools: 4 (TM:0 W:0 NW:4) | ctx: 142,023 tokens (14.2% of ctx, 857,977 free) | session: 4d40dd77
- Iter 21: success | tools: 7 (TM:2 W:2 NW:5) | ctx: 147,775 tokens (14.8% of ctx, 852,225 free) | session: 4d40dd77
- Iter 22: success | tools: 10 (TM:0 W:3 NW:7) | ctx: 178,695 tokens (17.9% of ctx, 821,305 free) | session: 4d40dd77
- Iter 23: success | tools: 4 (TM:1 W:1 NW:3) | ctx: 183,148 tokens (18.3% of ctx, 816,852 free) | session: 4d40dd77
- Iter 24: success | tools: 9 (TM:0 W:4 NW:5) | ctx: 194,724 tokens (19.5% of ctx, 805,276 free) | session: 4d40dd77
- Iter 25: success | tools: 8 (TM:1 W:3 NW:5) | ctx: 201,569 tokens (20.2% of ctx, 798,431 free) | session: 4d40dd77
- Iter 26: success | tools: 10 (TM:0 W:4 NW:6) | ctx: 220,230 tokens (22.0% of ctx, 779,770 free) | session: 4d40dd77
- Iter 27: success | tools: 5 (TM:1 W:2 NW:3) | ctx: 225,474 tokens (22.5% of ctx, 774,526 free) | session: 4d40dd77
- Iter 28: success | tools: 9 (TM:0 W:5 NW:4) | ctx: 240,605 tokens (24.1% of ctx, 759,395 free) | session: 4d40dd77
- Iter 29: success | tools: 4 (TM:1 W:1 NW:3) | ctx: 243,645 tokens (24.4% of ctx, 756,355 free) | session: 4d40dd77
- Iter 30: success | tools: 12 (TM:0 W:7 NW:5) | ctx: 259,796 tokens (26.0% of ctx, 740,204 free) | session: 4d40dd77
- Iter 31: success | tools: 4 (TM:1 W:1 NW:3) | ctx: 263,320 tokens (26.3% of ctx, 736,680 free) | session: 4d40dd77
- Iter 32: success | tools: 10 (TM:0 W:3 NW:7) | ctx: 285,377 tokens (28.5% of ctx, 714,623 free) | session: 4d40dd77
- Iter 33: success | tools: 6 (TM:1 W:3 NW:3) | ctx: 290,924 tokens (29.1% of ctx, 709,076 free) | session: 4d40dd77
- Iter 34: success | tools: 12 (TM:0 W:6 NW:6) | ctx: 307,849 tokens (30.8% of ctx, 692,151 free) | session: 4d40dd77
- Iter 35: success | tools: 4 (TM:1 W:1 NW:3) | ctx: 311,442 tokens (31.1% of ctx, 688,558 free) | session: 4d40dd77
- Iter 36: success | tools: 10 (TM:0 W:7 NW:3) | ctx: 322,071 tokens (32.2% of ctx, 677,929 free) | session: 4d40dd77
- Iter 0: complete | tools: 23 (TM:0 W:1 NW:22) | ctx: 102,725 tokens (10.3% of ctx, 897,275 free) | session: 7159515a

---

## Loop Complete

- **Finished:** 2026-06-21T18:35:51.953Z
- **Total iterations:** 36
- **Tasks completed:** 36
- **Final status:** max_iterations
- **Total duration:** 8565184ms

# Taskmaster Loop Progress

- **Started:** 2026-06-21T18:58:48.910Z
- **Preset:** default
- **Max iterations:** 12

---


## Task 21: Create HUD UI
- Implementation already present from a prior iteration: `ui/hud.gd`, `ui/hud.tscn` (XP/HP ProgressBars, timer MM:SS, level/gold/kills labels), `update_from_state(GameState)` pure view.
- Wired in `game/run_controller.gd`: `_hud = get_node_or_null("UI/HUD")`, fed each frame in `_process`.
- Tests `test/hud_test.gd` (6 cases) all PASS.
- Verified via gdUnit4: `godot --path . --headless -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://test/hud_test.gd` → 6/6 passed.
- Action this iter: ran tests, marked task done (was still `pending`).
- Learning: gdUnit4 CLI needs `--ignoreHeadlessMode` placed AFTER the `-s ...GdUnitCmdTool.gd` script path (it's a cmd-tool arg), not as a Godot engine flag.
- Iter 1: success | tools: 19 (TM:2 W:0 NW:19) | ctx: 57,502 tokens (5.8% of ctx, 942,498 free) | session: 4e4dfce4

## Task 24: Death and Results Screens
- Created `ui/death_screen.gd|tscn` (DeathScreen: revive_requested/continue_requested signals, show_death(has_revival) gates Revive button) and `ui/results_screen.gd|tscn` (ResultsScreen: done signal, show_results(summary) renders time/level/kills/gold + per-weapon damage table).
- Per-weapon damage tracking: added `damage_dealt: float` to `WeaponInstance`; `CombatSystem._damage_enemy` now credits final damage to `source_weapon` (both Projectile and DamageZone already carried `source_weapon`).
- `RunController`: discovers UI/DeathScreen + UI/ResultsScreen, wires GAME_OVER -> show death -> Continue -> RESULTS (show results) -> Done -> TITLE; Revive handler restores hp+resumes. Extended `_build_summary()` with `time_formatted` (MM:SS) + `weapon_stats` [{name,total_damage}].
- Mounted both screens in `game/Main.tscn` under UI.
- Tests: `test/death_results_screen_test.gd` (13 cases) + reran combat/run_controller/pause = 51/51 PASS.
- Design note: HealthSystem auto-consumes revivals BEFORE GAME_OVER, so the Revive button is normally hidden; screen+signal kept wired/testable for completeness (documented in DeathScreen docstring).
- LEARNING: new `class_name` scripts are NOT in Godot's global class cache until the project is reimported. Running gdUnit tests that reference a brand-new type fails with "Parser Error: Could not find type X in the current scope" (and spews a multi-GB error log). Fix: run `godot --path . --headless --import` once after adding new class_name scripts, BEFORE running tests.
- Iter 2: success | tools: 47 (TM:1 W:17 NW:30) | ctx: 112,877 tokens (11.3% of ctx, 887,123 free) | session: 4e4dfce4

## Task 34: Wire Complete Game Loop
- Found the real gap: LevelUpScreen was never mounted in Main.tscn nor wired in RunController (level_up_started was emitted into the void; on_option_chosen had no UI caller). The level-up overlay never appeared in an actual run.
- Mounted `ui/level_up_screen.tscn` under Main.tscn UI/. RunController._ready now discovers `_level_up_screen` and wires `level_up_started -> show_offer` and `option_chosen -> on_option_chosen`.
- Added phase-driven visibility for the two PERSISTENT widgets: `_on_phase_changed(phase)` connected to `phase_changed` -> main_menu visible only in TITLE, HUD visible only in PLAYING/PAUSED/LEVEL_UP. Boot sets the TITLE look directly (state is null at boot so _set_phase can't run).
- Transient overlays (pause/level-up/death/results) keep self-managing show/hide via their own button handlers — NOT centralized — to avoid double-management conflicts.
- Test: new `test/game_loop_test.gd` (7 cases) instantiates the real Main.tscn and drives Title->Playing->LevelUp->Pause->Death->Results->Title incl. restart. Regression suites (run_controller/level_up/pause/hud/death_results) still green. 52/52 pass.
- LEARNING: screens hide themselves on their BUTTON press (`_on_x` does hide()+emit), NOT when the controller-facing signal is emitted. An integration test must drive the button's `pressed` signal (e.g. `_option_buttons[0].pressed.emit()`, `resume_btn.pressed.emit()`), not the high-level signal, or the overlay won't self-hide.
- Iter 3: success | tools: 20 (TM:1 W:10 NW:10) | ctx: 148,926 tokens (14.9% of ctx, 851,074 free) | session: 4e4dfce4

## Task 35: Integration Tests for Core Game Loop
- Created `test/integration/simulation_pipeline_test.gd` (5 cases) driving the REAL RunController._tick pipeline (same path as _physics_process):
  1. full tick pipeline -> player moves right + time_elapsed ~= 1.0 after 60 ticks
  2. emergent combat -> injected weak enemy killed by whip, drops an XP gem (kills>=1, gems>=1)
  3. ProgressionSystem.add_xp(state,100) -> pending_levelups>0, level increased
  4. DETERMINISM (the new coverage golden_path lacked): same seed + same scripted inputs over 150 RNG-heavy ticks (spawns/crits) -> bit-identical state signature (kills/gold/level/pos/xp/hp/enemy+gem counts)
  5. anti-vacuous guard: the seeded scenario really simulates (kills>0, time>0)
- Confirmed real APIs (no inventions): `ProgressionSystem.add_xp(state, amount)` exists; `state.time_elapsed += dt` lives in SpawnDirector.step (so _tick advances time).
- Determinism baseline trick: start_run seeds RNG with Time.get_ticks_usec() and spawns starting enemies BEFORE you can pin the seed. So a `_baseline()` helper clears enemies/gems/spawn-cursor/counters and re-pins `state.rng.seed` -> two runs become bit-identical. Used xp_value=0 enemies so the run stays in PLAYING and exercises the full pipeline every tick.
- All 5 pass. Named the file distinctly (simulation_pipeline_test) to avoid a basename clash with the existing test/game_loop_test.gd from task 34.
- Iter 4: success | tools: 9 (TM:1 W:1 NW:8) | ctx: 173,155 tokens (17.3% of ctx, 826,845 free) | session: 4e4dfce4

## Task 36: Performance Profiling and Optimization
- Audited the hot paths first (profile before optimizing). Findings — the pipeline is ALREADY O(n)/tick by design, so NO algorithmic change was needed:
  - SpatialIndex: O(n) rebuild + grid-local query_radius (uniform spatial hash) — already O(n) not O(n^2).
  - Removals: every system uses swap-remove (`_remove_indices`/`_reap_dead`); ZERO Array.erase/remove_at in logic (task's swap-remove hint already satisfied).
  - MovementSystem.step_enemies O(n) (no enemy-enemy separation loop), PickupSystem O(gems)+O(pickups), WeaponSystem loops <=6 weapons.
  - PresentationLayer already sprite-pools (no per-frame alloc) -> MultiMesh rewrite NOT warranted ("keep changes small").
- Added `test/integration/performance_stress_test.gd` (2 cases) driving the REAL RunController._tick at scale:
  1. full stress scene 500 enemies+200 gems+50 projectiles -> measured 2.37 ms/tick (target <8ms) PASS; asserts loose 50ms catastrophic-regression ceiling + population stayed at 500/50 + phase PLAYING.
  2. sub-quadratic scaling: 150->600 enemies (4x N) measured 2.48x time (linear~4x, quadratic~16x); asserts ratio<8.0 -> machine-independent O(n) guard.
- Benchmark design notes: unkillable enemies (hp 1e9) + gems past magnet range + projectiles in empty far region keep the population CONSTANT across the window so timing reflects steady-state cost, not a decaying board. Player hp 1e9 so phase stays PLAYING. Pinned rng seed for reproducibility.
- Conclusion: meets all target metrics (500 entities, <8ms tick, sub-quadratic) with no code change; test added as the regression guard.
- Iter 5: success | tools: 12 (TM:1 W:1 NW:11) | ctx: 203,681 tokens (20.4% of ctx, 796,319 free) | session: 4e4dfce4

## Task 37: Golden Path Test (deterministic replay)
- Created `test/integration/golden_replay_test.gd` (2 cases). Distinct from the existing `test/golden_path_test.gd` (which injects a cluster + asserts ranges) — this is a FRAME-INDEXED INPUT REPLAY with a frozen exact-outcome snapshot.
- GOLDEN_SEED=12345, 900 frames (15s), recorded input sequence (8 direction changes). Driven through the real RunController._tick. Level-ups auto-resolved (always option 0) so the sim keeps flowing headlessly and exercises stats recompute + item acquisition.
- Deterministic board: start_run seeds RNG with Time.get_ticks_usec() and spawns BEFORE you can pin it, so `_start_golden` clears the time-seeded spawns/counters, sets rng.seed=GOLDEN_SEED, and re-runs SpawnDirector.spawn_starting under the golden seed.
- test_golden_path_determinism: two replays -> identical time/kills/gold/level/pending/pos/hp/enemy+gem counts.
- test_golden_path_expected_outcome: frozen snapshot kills=60, level=4, gold=0, weapons=1, passives=0, pending=0, phase=PLAYING. A [golden] print line lets you re-capture if a change is intentional.
- Captured values via a print-first pass, then baked the constants. Cross-process reproducible (capture run == final run).
- LEARNING (tooling): backgrounded godot test runs do NOT inherit the persisted bash cwd, so `--path .` resolved to the wrong dir -> "Attempt to open script GdUnitCmdTool.gd ... File not found". FIX: always pass an ABSOLUTE `--path C:/.../vampire-survivors-taskmaster` to godot (don't rely on `--path .`).
- Iter 6: success | tools: 20 (TM:1 W:5 NW:15) | ctx: 235,154 tokens (23.5% of ctx, 764,846 free) | session: 4e4dfce4

## Task 28: Additional Weapons (8 new)
- WeaponSystem: added cast patterns dispatched by def.id for magic_wand, knife, axe, cross, king_bible, fire_wand, garlic, santa_water (+ shared helpers _new_projectile/_aim_nearest/_random_enemy_pos/_total_amount/_fan_offset).
- CombatSystem: 3 minimal BACKWARD-COMPATIBLE sim features the patterns need (all gated on new fields defaulting to no-op): projectile `accel` (Axe gravity arc), boomerang turn+return (Cross, uses is_boomerang/is_returning/boomerang_range), and ORBIT zone rotation (King Bible, uses new zone.orbit_speed).
- Entity fields added: Projectile.accel, Projectile.boomerang_range; DamageZone.orbit_speed.
- Data: 8 new .tres in data/weapons/ (auto-discovered by GameData dir scan + ProgressionSystem._load_defs). Each has level-scaling entries.
- ProgressionSystem._load_defs now SORTS defs by id -> level-up offer pool order is independent of filesystem iteration order (deterministic offers across machines; aligns with the golden-test/determinism theme).
- Tests: new test/weapon_patterns_test.gd (13: each weapon's emission + accel/boomerang/orbit). Final regression 79/79 across 9 suites.
- RIPPLE FIXES (adding catalog data is a "system change" that golden/pool tests are designed to catch):
  - 3 progression_system_test cases assumed a whip-ONLY catalog (asserted a specific weapon appears in the shuffled 3-4 subset). Rewrote to pool-independent invariants: any-new-weapon-offered; owned weapon present in the upgradeable pool + never offered as new (checked via ProgressionSystem._get_upgradeable_weapons); apply_choice upgrade path tested with a controlled single-option offer.
  - Re-captured golden_replay snapshot: kills 60->63, weapons 1->3 (more weapons => level-ups grant variety). level/gold/passives/pending unchanged.
- LEARNING: adding entries to a data dir that feeds the level-up offer pool changes EVERY downstream golden/replay snapshot and any test that pinned specific offer contents. Expect to re-capture goldens and de-brittle pool-dependent tests in the SAME change. Sorting dir loads keeps it deterministic.
- Iter 7: success | tools: 48 (TM:1 W:23 NW:25) | ctx: 333,673 tokens (33.4% of ctx, 666,327 free) | session: 4e4dfce4

## Task 29: Passive Items (16)
- StatSystem ALREADY consumes passives (recompute_block -> _apply_passive adds stat_bonuses[field][level-1] to the StatBlock). So NO StatSystem change needed — task was purely the 16 PassiveDef .tres files (+ tests + ripple fixes).
- Created 16 .tres in data/passives/ (script res://data/defs/passive_def.gd). stat_bonuses uses CUMULATIVE per-level arrays (index=level-1, since _apply_passive adds arr[level-1] once). Exact StatBlock field names: spinach->might, armor->armor, hollow_heart->max_health, pummarola->recovery, empty_tome->cooldown(neg), candelabrador->area, bracer->speed, spellbinder->duration, duplicator->amount, wings->move_speed, attractorb->magnet, clover->luck, crown->growth, stone_mask->greed, skull_omaniac->curse, tiragisu->revival.
- SEMANTICS: most stats are multipliers (base 1.0) so +10% = +0.1 additive. max_health (base 100) and magnet (base 64) are ABSOLUTE, so their "%" maps to flat values off the base (hollow_heart +20 = 20% of 100; attractorb +16 = 25% of 64).
- New test/passive_items_test.gd (15): all 16 load via GameData + each stat applies correctly through StatSystem.recompute_block, plus flow-through to derived after resolve().
- RIPPLE (populating data/passives enlarges the level-up offer pool, same as task 28 weapons):
  - game_data_test: get_all_passives() now 16 (was asserting 0).
  - progression test_full_maxed_inventory_is_max_state: must now also fill+max the 6 passive slots for max_state.
  - golden_replay snapshot re-captured: kills 63->65, weapons 3->2, passives 0->1 (some level-ups now grant passives).
- FLAKINESS FIX (important): GameState.new().rng is RANDOMLY seeded (Godot auto-seeds RandomNumberGenerator), so tests calling build_offer WITHOUT pinning the seed became flaky once the pool mixed weapons+passives (a shown 3-4 subset could be all passives). Made 3 progression tests seed-independent: offer-new-items asserts the invariant "nothing owned -> no option is an upgrade"; the two apply_choice tests use CONTROLLED single-option offers instead of build_offer's shuffle. Final 58/58 pass, 0 flaky.
- Iter 8: success | tools: 43 (TM:1 W:25 NW:18) | ctx: 391,986 tokens (39.2% of ctx, 608,014 free) | session: 4e4dfce4

## Task 30: Chest System
- ProgressionSystem additions:
  - BEGINNER_LUCK_SEQUENCE [1,1,3,1,1,5] + CHEST_GOLD_REWARD 25.
  - determine_chest_count(state) — PUBLIC (sketch had it private) so CombatSystem can pre-roll at boss death; beginner's luck for first 6 chests (indexed by state.chest_count), then luck-scaled (roll<0.1*luck->5, <0.3*luck->3, else 1).
  - open_chest(state, chest) -> Array — rolls `rolled_count` items via _roll_chest_item (reuses build_offer's pool), applies each; maxed inventory -> CHEST_GOLD_REWARD gold per slot. Caller bumps chest_count.
  - Refactored apply_choice to extract _apply_option(player, choice) (add/upgrade, no recompute) — reused by chest opening. Behavior identical (golden run unchanged).
- CombatSystem._on_enemy_death: if enemy.is_boss, spawn a Chest at enemy.pos with rolled_count = ProgressionSystem.determine_chest_count(state).
- PickupSystem._step_chests: now calls ProgressionSystem.open_chest (was a placeholder that only incremented chest_count).
- Tests: new test/chest_system_test.gd (9). Affected suites all green: combat 19, pickup 13, progression 14, golden_replay 2, golden_path 1. 58/58 pass.
- Note: golden run (15s, minute 0) spawns no boss -> no chest -> chest logic doesn't perturb the golden snapshot; the apply_choice refactor was behavior-preserving so golden values held (kills=65/weapons=2/passives=1).
- Iter 9: success | tools: 17 (TM:1 W:6 NW:11) | ctx: 424,694 tokens (42.5% of ctx, 575,306 free) | session: 4e4dfce4

## Task 26: Create AudioService Stub
- Created `autoload/audio_service.gd` (extends Node, NO class_name — global name `AudioService` is the accessor, same pattern as GameData): round-robin pool of POOL_SIZE=8 AudioStreamPlayers built in _ready; `_sounds` Dictionary of 8 placeholder (null) event streams (hit/death/level_up/pickup/heal/chest/hurt/weapon_fire). `play(sound_name)` is a safe no-op when the name is unknown or its stream is still null, advancing the pool cursor only on a real play. `set_sound(sound_name, stream)` assigns a stream.
- Registered `AudioService="*res://autoload/audio_service.gd"` in project.godot [autoload].
- DEVIATED from task sketch: renamed `set_sound(name, ...)` -> `set_sound(sound_name, ...)` — the sketch's `name` param shadows the inherited Node.name property (the recurring shadowing trap in lessons). Added explicit local types (`var player := AudioStreamPlayer.new()`).
- Added test/audio_service_test.gd (6 cases: pool built at startup, placeholder-name no-op, unknown-name no-op, set_sound stores, play advances one step, play wraps round-robin). State reset in before_test since AudioService is a shared singleton. All 6 PASS (0 errors/failures/orphans).
- LEARNING: `godot --check-only --script res://test/<x>_test.gd` on a test that references an AUTOLOAD global fails with "Identifier not found: <Autoload>" — check-only mode does NOT instantiate autoload singletons. Confirmed the known-good game_data_test.gd fails identically. This is a check-mode artifact, NOT a real error; autoloads resolve under the live gdUnit4 SceneTree run. Validate autoload-using tests via the gdUnit4 suite, not --check-only on the test file. (The implementation script itself still checks clean via --check-only.)
- Iter 10: success | task 26 done.

## Task 32: Implement Special Pickups
- Replaced PickupSystem's dead "set a global_effects flag" stubs (nothing read them) with REAL effects in `_apply_pickup`:
  - rosary -> `_kill_all_enemies`: kills every non-boss via `CombatSystem._on_enemy_death` (credits kills + drops XP gems), then `state.enemies = filter(is_boss)`. CRITICAL: rebuilds the SpatialIndex afterward — HealthSystem (next in the tick) broadphases `state.enemies[get_entity_local_id(...)]` against `state.index`; removing enemies without rebuild leaves a stale index that maps to removed/OOB slots (would crash since rosary can kill an enemy touching the player). Guarded on `state.index != null`.
  - orologion -> `_freeze_all_enemies`: sets `freeze_timer` on ALL enemies (bosses included); MovementSystem already holds frozen enemies still + ticks the timer down (no new wiring).
  - nduja -> Might x2 / clover -> Luck x2 / sorbetto -> Move Speed x1.5, all 10s timed buffs.
- TIMED BUFF MECHANISM (the real design work — sketch omitted expiry/integration): added `PlayerState.buffs` (Array of {stat, mult, time_left}). StatSystem.resolve APPLIES them onto `derived` after the block->derived copy and before caps (so they survive the per-tick stat reset, and a buffed capped stat like move_speed still clamps). PickupSystem `_tick_buffs` (called first in step, has dt) counts them down + drops expired; `_apply_temp_buff` refreshes (replaces) an existing same-stat buff rather than stacking.
  - WHY resolve, not pickups, applies the buff: tick order is resolve(2) -> ... -> combat(8) -> pickups(9). Applying in pickups would land AFTER combat already ran, and next tick's resolve wipes derived. Applying in resolve (runs first) means the buff is live for that tick's combat and persists every tick from the buff list. 1-frame delay from collection is fine.
- SORBETTO is unspecified by the task; systems.md line 70 pairs "nduja/sorbetto", so implemented it as a sibling temp buff (move_speed). Magnitude 1.5x is a documented placeholder.
- Tests: rewrote the obsolete `test_pickup_special_effect_flagged` (asserted the old orologion flag) and added 7 special-pickup cases (rosary kills/spares-boss/empty-safe, orologion freeze, nduja/clover/sorbetto buff via resolve, buff expiry, refresh-not-stack). pickup_system_test 13 -> 20. Regression across pickup/stat/combat/player_state/game_state/golden_path/golden_replay = 66/66 pass.
- NOTE: golden/replay snapshots UNCHANGED — the 15s golden run spawns no braziers (brazier_interval 60s) so no pickups drop; special-pickup logic never fires there. `state.global_effects` is now unwritten (left as a reserved dict; comment updated).
- LEARNING: a system that REMOVES enemies mid-tick must rebuild state.index if any later same-tick system (HealthSystem) queries it — the codebase rebuilds the index only once (pre-weapons), and CombatSystem's own reap already relies on dying enemies not sitting in the player's 16px hitbox. Don't add a second mid-tick board mutation without restoring index consistency.
- Iter 11: success | task 32 done.

## Task 31: Light Source and Brazier System
- `LightSource` entity already existed (pos, hp=10). Wired the two missing halves: SpawnDirector spawns braziers, CombatSystem breaks them.
- SpawnDirector: `_step_braziers(state, stage, dt)` accumulates `GameState.brazier_timer` and spawns a ring-positioned `LightSource` every `stage.brazier_interval` (0 = off; Mad Forest = 60s). New BRAZIER_RING_MIN/MAX 200/350 (nearer the screen edge than the 400/500 enemy ring, so braziers are reachable). Boundless map -> ring-positioned, NOT the StageDef.brazier_positions fixed list. Placed AFTER the reaper-return so braziers stop in the Reaper phase (consistent with "no normal spawns after reaper").
- CombatSystem: added `_damage_light_sources` step (after zones/projectiles, before reap). `_incoming_light_damage` sums damage from any overlapping zone (within radius) + projectile (within PROJECTILE_HIT_RADIUS); raw damage, no Might/crit (environmental). Projectiles pass through (no pierce/hit_ids consumed) so brazier-breaking never perturbs the weapon-vs-enemy logic. `_on_light_break` rolls `PickupTable.roll(state.rng)` and appends a Pickup at the brazier pos.
- DEVIATIONS from sketch: (1) sketch called `PickupTable.roll_brazier_drop(roll)` — that doesn't exist; used the real `PickupTable.roll(rng)`. (2) sketch dropped a pickup with no `value` -> a dropped chicken/coin would be inert (heal 0 / 0 gold). Added `PickupTable.default_value(type)` (chicken 30, coin 1, coin_bag 10, else 0) and set pickup.value on drop. (3) sketch only damaged from zones; also handled projectiles per its own "zone/projectile" comment.
- Direct distance loops (braziers + emissions are few); braziers are NOT in the SpatialIndex.
- Tests: new test/light_source_system_test.gd (9: zone/projectile damage, break+drop-at-pos, out-of-range no-op, empty-safe, brazier spawn-on-interval, interval-0 disabled, ring bounds, default_value mapping). Regression: combat 19, spawn 10, pickup_table 3, game_state 7, golden_path/replay + performance_stress + simulation_pipeline = 61/61 pass.
- NOTE: golden/replay/determinism/perf snapshots UNCHANGED — brazier_interval 60s, and all those runs are <60s sim time, so no brazier spawns there (verified, not assumed).
- LEARNING: when adding a periodic spawner gated on a stage interval, place it relative to the existing reaper-return so behavior stays consistent with the "no spawns after reaper" rule; and existing spawn tests asserting `enemies` (not the new array) stay green even when the new spawner fires, but check any >interval-duration test (e.g. the 61s clock test does spawn a brazier — harmless since it only asserts time/minute).
- Iter 12: success | task 31 done.
- Iter 10: success | tools: 25 (TM:1 W:5 NW:20) | ctx: 99,990 tokens (10.0% of ctx, 900,010 free) | session: a2908759
- Iter 11: success | tools: 29 (TM:1 W:7 NW:22) | ctx: 166,444 tokens (16.6% of ctx, 833,556 free) | session: a2908759
- Iter 12: success | tools: 22 (TM:1 W:10 NW:12) | ctx: 206,438 tokens (20.6% of ctx, 793,562 free) | session: a2908759

---

## Loop Complete

- **Finished:** 2026-06-21T20:36:01.630Z
- **Total iterations:** 12
- **Tasks completed:** 12
- **Final status:** max_iterations
- **Total duration:** 5832720ms
