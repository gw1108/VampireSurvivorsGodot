# Game Systems Architecture: Vampire Survivors (Godot Clone) — First-Playable Vertical Slice

## Source
Derived from `thoughts/shared/game-design/2026-06-25-ENG-vampire-survivors-clone.md` (main GDD) and its companion `thoughts/shared/game-design/2026-06-25-ENG-vampire-survivors-visual-gdd.md` (display/sizing/layout), with rendering constraints from `VISUAL_RULES.md`.

**Game in one line:** An auto-attacking horde-survival roguelite — play Antonio on the Mad Forest, steer only your feet while weapons fire themselves, absorb XP gems to level up and pick weapons/passives, and survive an escalating swarm (up to 500 enemies) for 30 minutes until the Reaper ends the run.

## Architecture Philosophy
Game logic lives in **pure, stateless modules** (`static func`s on plain scripts) that take explicit **data objects** in and **mutate them by reference** — they never touch the scene tree, `get_node`, input polling, or rendering, so they unit-test headlessly under gdUnit4. The Godot side is a thin layer of **node shells** (the `RunController` conductor, the `PlayerShell`, pooled view layers, HUD/overlay `Control`s) plus a few **autoload services** (`GameManager` state machine, `GameDatabase` static data, `AudioManager`). The entire run's mutable state is held in one `RunState` graph of plain data containers; each tick the `RunController` calls the pure systems in a fixed order over that state, then syncs dumb visual nodes from it. High-volume entities (enemies, projectiles, gems, pickups, floating text) are **data-oriented pools**, not one node each — this is what makes the 500-enemy requirement and headless testability both achievable.

## Technical Challenges & Considerations

- **500 live enemies + hundreds of gems/projectiles at stable frame rate (the central challenge).** The GDD lists pooling, simplified per-entity logic, and spatial culling as *hard requirements*. Therefore: **do not** instance a scripted Node + Area2D per entity. Represent enemies/projectiles/gems/pickups as **flat, pre-allocated pools of plain data** (a struct-of-arrays-style `RefCounted` per pool) iterated by central pure systems; render them with a **fixed pool of dumb visual nodes** (`Sprite2D`/`AnimatedSprite2D`) whose only job each frame is to copy `position`/`frame`/`visible` from the data slot. No per-entity `_process`, no per-entity script. Rationale: one tight loop over arrays beats 500 node callbacks, and pooling removes per-spawn allocation cost. *Escalation hatch (not built day one):* if pooled sprite nodes still cost too much, swap a view layer's nodes for a single `MultiMeshInstance2D` — the data/logic side does not change, only `ViewSync`.

- **Collision / overlap by data lookup, not the physics engine.** All interactions are circle-vs-circle: enemy↔player contact, weapon-shape↔enemy, gem/item↔player (magnet). Running 500+ `Area2D` monitors is the classic VS-clone perf trap. Instead use a **uniform-grid spatial hash** rebuilt each tick from enemy positions, and do distance² tests against only the cells near the query shape. Rationale: simplest correct broadphase for many same-scale circles; fully pure and testable; far cheaper than `PhysicsServer2D`. **The physics engine is not used for gameplay.**

- **Update model & frame-rate independence.** Movement, cooldowns, and spawn cadence must be delta-driven. There is no physics-engine stepping and no determinism/replay requirement, so the authoritative simulation runs once per rendered frame in **`RunController._process(delta)`**, which steps every pure system in a fixed order. All timers are delta accumulators; all motion is `pos += vel * delta`. Rationale: a single update path tied to the render frame is the most direct option and sidesteps physics-interpolation jitter on the zoomed pixel-art camera entirely.

- **Coordinate systems & the pixel-art camera.** The world is plain Node2D pixel space; the player is locked to screen center by a **`Camera2D`** (child of `PlayerShell`) with a fixed **integer `zoom`** so native sprites magnify to the Visual-GDD on-screen targets (Antonio ≈50×62) while pixels stay square (per `VISUAL_RULES.md`). Window **Stretch Mode = `disabled`** so resizing/fullscreen *reveals more field* rather than scaling sprites (Visual GDD §1). The **HUD is a `CanvasLayer` of anchored `Control`s** (screen space) that re-anchor to window edges; the **player health bar is world space** under the sprite. Native sprite size = on-screen target ÷ zoom; treat Visual-GDD sizes as ±10% targets.

- **Off-screen spawn ring & culling.** Enemies must appear just off-camera on all sides. Each tick compute the camera's visible world rect (`viewport_size / zoom`, centered on player); the `SpawnDirector` places new enemies on a ring just outside it. Homing enemies are never culled (they chase forever, per VS); **fixed-direction/wavy** enemies that drift far past the ring are recycled to the free list to respect the pool cap.

- **State representation.** One `RunState` object owns: `PlayerState`, the four entity pools, the `SpatialGrid`, `SpawnDirectorState`, a single `RandomNumberGenerator`, the run phase, elapsed time, timed run-effects (freeze/fire-breath), and a level-up queue count. Pools are fixed-capacity with an integer free-list and an `alive` flag per slot — spawning pops a free index, despawning pushes it back; nothing is allocated mid-run.

- **Game state machine.** Screens are Boot → Main Menu → Playing ⇄ Paused, Playing → Level-Up (auto-pause) → Playing, Playing → Game Over → Menu/Restart. Owned by the `GameManager` autoload; pause via `get_tree().paused = true` with overlay `Control`s set to `process_mode = PROCESS_MODE_ALWAYS` so they run while the sim is frozen.

- **Spawning / lifecycle.** Pooling is mandatory (above). The `SpawnDirector` reads the verbatim per-minute Mad Forest wave table from `GameDatabase`; honors caps (periodic spawns halt at 300 alive; hard ceiling 500; bosses/events ignore the periodic halt); fires swarm/formation events at timestamps; spawns bosses on schedule; spawns the Reaper at 30:00 (+1/min) and **clears the field** on Reaper spawn; spawns braziers (10% chance, ≤10, every 1s, off-screen).

- **Leveling edge cases.** A big gem can cross several thresholds at once → `LevelingSystem` enqueues N level-ups; `GameManager` presents them **one at a time**, regenerating each option set *lazily* (inventory may have just filled/maxed an item). Option count is 3 (4 with Luck via `1 − 1/totalLuck`, ≈0 extra at base). Inventory cap 6+6: once full and maxed, level-ups offer **gold or Floor Chicken**. Reroll consumes a Rerollo-fed charge and redraws; Skip/Banish render but stay disabled at 0 charges this slice. Gem on-ground cap 400 → excess merges into one red gem.

- **Other edge cases.** I-frames (240 ms) gate contact damage, evaluated after the collision pass; damage taken = `max(1, power − armor)`. Death (HP≤0, Revival=0 → final) **takes precedence** over a same-tick level-up → go straight to Game Over. First frame: empty pools, player spawned, timer 0. Restart rebuilds a fresh `RunState`.

- **Persistence / determinism.** None required — no save/resume, standard RNG. The single `RandomNumberGenerator` lives in `RunState` and is *passed into* pure systems so randomized logic (chest rolls, option draws, drop tables) is still reproducible in tests by seeding it.

## Shared Data Model
Plain-data containers (`RefCounted` scripts, no scene dependency) that systems read and mutate by reference. These are the backbone — get them right and the systems fall out.

### RunState
- **Purpose:** The single root of all mutable run state; threaded into every pure system.
- **Fields:** `phase: int` (enum Playing/LevelUp/Paused/GameOver) — note GameManager owns the *screen* FSM; this mirrors sim intent · `elapsed: float` (seconds) · `player: PlayerState` · `enemies: EnemyPool` · `projectiles: ProjectilePool` · `pickups: PickupPool` · `floaters: FloatingTextPool` · `grid: SpatialGrid` · `spawn: SpawnDirectorState` · `rng: RandomNumberGenerator` · `level_up_queue: int` · `freeze_timer: float` (Orologion) · `firebreath_timer: float` (Nduja) · `camera_world_rect: Rect2` (set by shell each tick for spawn/cull) · `result: RunResult` (filled on death).
- **Lifecycle:** Created by `GameManager` on Start; mutated every tick by the systems; discarded on return to menu / recreated on restart.

### PlayerState
- **Purpose:** Everything about Antonio.
- **Fields:** `pos: Vector2` · `vel: Vector2` · `facing: Vector2` (last nonzero move dir; drives Whip/Knife) · `hp: float` · `max_hp: float` · `iframe_timer: float` · `level: int` · `xp: float` · `xp_to_next: float` · `gold: int` · `kills: int` · `weapons: Array[WeaponInstance]` (≤6) · `passives: Array[PassiveInstance]` (≤6, each `{id, level}`) · `stats: StatBlock` · `reroll_charges: int` · `skip_charges: int` (0) · `banish_charges: int` (0) · `revival: int` (0) · `stats_dirty: bool`.
- **Lifecycle:** Created with Antonio's starting kit (Whip; +20 Max HP → 120; +1 Armor). Mutated by Collision (hp, kills, gold, xp), Leveling (level, inventory), Effects (hp, charges), Movement (pos/vel/facing). `stats_dirty` set whenever inventory/level changes → triggers `StatSystem.recompute`.

### StatBlock
- **Purpose:** Derived multipliers weapons read when firing (the GDD stat model, fully resolved).
- **Fields:** `max_health, recovery, armor, move_speed, might, area, speed, duration, cooldown, amount, magnet, luck, growth, greed, curse` (floats), each already clamped to its cap (Might ≤1000%, Cooldown floor −90%, Amount ≤+10, etc.).
- **Lifecycle:** Recomputed by `StatSystem` from base + character bonus + per-passive contributions + level bonuses whenever `stats_dirty`. Never mutated directly by other systems.

### WeaponInstance
- **Purpose:** One owned weapon's runtime state.
- **Fields:** `id: StringName` · `level: int` (1–8) · `cooldown_timer: float` · `runtime: Dictionary` (per-pattern scratch: King Bible orbit angle, Runetracer bounce seed, etc.).
- **Lifecycle:** Created on grant (level-up/chest); `cooldown_timer` ticked and reset by `WeaponSystem`; `level` raised on upgrade.

### EnemyPool
- **Purpose:** Data-oriented store of all live enemies, bosses, the Reaper, and braziers (braziers are a destructible enemy type with AI = none).
- **Fields (parallel arrays, capacity ≥ 512):** `pos[]`, `vel[]`, `hp[]`, `max_hp[]`, `power[]`, `move_speed[]`, `knockback_resist[]`, `xp_value[]`, `type_id[]` (→ visual + def), `ai_kind[]` (homing/fixed/wavy/none), `is_boss[]`, `knockback_timer[]`, `hit_flash[]`, `alive[]`, plus `free_list: PackedInt32Array` and `active_count: int`.
- **Lifecycle:** Slots claimed by `SpawnDirector`, mutated by Movement (pos/vel/knockback) and Collision (hp/hit_flash/death→free), cleared en masse on Reaper spawn.

### ProjectilePool
- **Purpose:** All weapon-spawned shapes: bolts, knives, fireballs, runetracers, plus persistent area emitters (Garlic aura, orbiting Bibles) modeled as projectiles with special behavior/lifetime.
- **Fields:** `pos[]`, `vel[]`, `damage[]`, `pierce_left[]`, `lifetime[]`, `area_scale[]`, `behavior[]` (straight/homing/bounce/orbit/aura), `owner_weapon[]`, `type_id[]`, `crit_chance[]`, `crit_mult[]`, `hit_cooldown[] / recent_hits` (for repeat-tick weapons & pierce), `alive[]`, `free_list`, `active_count`.
- **Lifecycle:** Claimed by `WeaponSystem` on fire; moved by Movement; consumed by Collision (pierce/lifetime) → freed.

### PickupPool
- **Purpose:** XP gems and all collectibles (gold coins/bags, chicken, Rosary, Orologion, Vacuum, Nduja, Rerollo, Treasure Chest).
- **Fields:** `pos[]`, `kind[]` (gem/gold/chicken/rosary/orologion/vacuum/nduja/rerollo/chest), `value[]` (gem XP or gold amount or chest tier seed), `gem_tier[]` (blue/green/red), `magnetized[]` (bool), `alive[]`, `free_list`, `active_count`. Tracks `gem_count` for the 400-gem merge cap.
- **Lifecycle:** Gems spawned by Collision on enemy death; items spawned by Effects/Spawn (braziers) / Chest; magnetized & moved by Movement; collected by Collision → routed to Effects/Leveling → freed.

### FloatingTextPool (juice)
- **Purpose:** Damage numbers / pickup pops.
- **Fields:** `pos[]`, `vel[]`, `text[]`, `ttl[]`, `alive[]`, `free_list`.
- **Lifecycle:** Pushed by Collision/Effects; aged by a trivial step; freed at ttl 0. *(Optional — can be deferred without touching other systems.)*

### SpatialGrid
- **Purpose:** Broadphase index of enemy slot-indices by cell.
- **Fields:** `cell_size: float` · `cells: Dictionary` (Vector2i → PackedInt32Array of enemy indices).
- **Lifecycle:** Cleared and rebuilt from `EnemyPool` at the top of each tick; read by Collision queries.

### SpawnDirectorState
- **Purpose:** Bookkeeping for the verbatim Mad Forest curve.
- **Fields:** `minute: int` · `periodic_timer: float` · `event_cursor: int` · `boss_cursor: int` · `brazier_timer: float` · `brazier_count: int` · `chests_opened: int` (for the 1-1-3-1-1-5 beginner-luck sequence) · `reaper_timer: float`.
- **Lifecycle:** Advanced by `SpawnDirector` each tick.

### GameDatabase content (reference data — read-only)
- **Purpose:** Authored constants carried verbatim from the wiki: `WeaponDef` (base dmg/cooldown/amount/pattern + per-level 2–8 deltas), `PassiveDef` (stat + per-level values), `EnemyDef` (HP/power/speed/kb-resist/xp/visual/ai), the **per-minute wave table**, the **XP curve**, gem-tier thresholds, chest roll tables, brazier drop table. Stored as `.tres` Resources or `const` dictionaries.
- **Lifecycle:** Loaded once at boot; never mutated.

## Systems

### StatSystem
- **Goal:** Resolve `PlayerState` inventory + level into the derived `StatBlock`.
- **Type:** pure/stateless logic.
- **Inputs:** `PlayerState`, `GameDatabase` passive/character defs.
- **Outputs / mutations:** writes `player.stats` in place; clears `stats_dirty`.
- **Key functions:** `static func recompute(player: PlayerState, db) -> void`.
- **Dependencies:** PlayerState, GameDatabase. Called by RunController when `stats_dirty`.
- **Godot 4 mapping:** none — pure module.

### MovementSystem
- **Goal:** Integrate all kinematics for one tick (player, enemies, projectiles, magnetized pickups) frame-rate-independently.
- **Type:** pure/stateless logic.
- **Inputs:** `RunState`, `delta`; player move intent already written by the shell.
- **Outputs / mutations:** updates `pos`/`vel` across player and all pools; decays `knockback_timer`/`iframe_timer`; updates `facing`; applies enemy AI (homing toward player, fixed-direction, wavy sine offset); applies lightweight separation so swarms spread; honors `freeze_timer` (Orologion freezes enemies); pulls magnetized gems toward player; integrates projectile motion per `behavior` (straight/bounce/orbit-around-player/aura-follow).
- **Key functions:** `static func step(state: RunState, delta: float) -> void` · helpers `_move_enemies`, `_move_projectiles`, `_move_pickups`.
- **Dependencies:** StatBlock (move_speed, magnet, speed), pools. Called by RunController.
- **Godot 4 mapping:** none — pure module.

### SpatialIndex
- **Goal:** Build and query the broadphase grid over enemies.
- **Type:** pure/stateless logic.
- **Inputs:** `EnemyPool`, a query position + radius.
- **Outputs / mutations:** rebuilds `SpatialGrid.cells`; returns candidate enemy indices for a query.
- **Key functions:** `static func rebuild(grid: SpatialGrid, enemies: EnemyPool) -> void` · `static func query_circle(grid, enemies, center: Vector2, radius: float) -> PackedInt32Array`.
- **Dependencies:** EnemyPool, SpatialGrid. Used by CollisionSystem.
- **Godot 4 mapping:** none — pure module.

### CollisionSystem
- **Goal:** Resolve every overlap interaction for the tick via data lookup.
- **Type:** pure/stateless logic.
- **Inputs:** `RunState` (with grid freshly rebuilt), `delta`, `GameDatabase`.
- **Outputs / mutations:** **Weapon hits** — for each projectile/aura, query nearby enemies, apply `damage = weaponBase × might` (+ crit via `baseCrit × luck`, + Armor retaliatory where applicable), apply knockback (skipped on resistant bosses/Reaper), decrement `pierce_left`, and on enemy death free the slot, increment `kills`, spawn an XP gem (tier by xp value), and flag boss-death for `ChestSystem`. **Contact** — enemies overlapping the player while `iframe_timer<=0` deal `max(1, power − armor)`, set i-frames, apply knockback to the enemy. **Pickups** — gems/items within `magnet` get `magnetized=true`; those overlapping the player are collected and routed (XP→Leveling buffer, gold/chicken/effect→Effects, chest→Chest). Pushes floating-text entries.
- **Key functions:** `static func resolve(state: RunState, db, delta: float) -> CollisionResult` (CollisionResult carries XP gained, boss-deaths, collected chest seeds for the controller to dispatch).
- **Dependencies:** SpatialIndex, StatBlock, all pools; hands off to Leveling/Effects/Chest. Called by RunController.
- **Godot 4 mapping:** none — pure module.

### WeaponSystem
- **Goal:** Tick weapon cooldowns and fire each weapon's pattern into the projectile pool, scaled by stats.
- **Type:** pure/stateless logic.
- **Inputs:** `RunState`, `delta`, `GameDatabase` weapon defs.
- **Outputs / mutations:** decrements each `WeaponInstance.cooldown_timer` by `delta × cooldown` scaling; on ready, spawns projectiles/auras (Whip horizontal slash in `facing`; Knife in facing; Magic Wand at nearest enemy via SpatialIndex; Runetracer bouncing; Garlic persistent aura; King Bible orbiters; Fire Wand at random enemy ×Amount; Lightning Ring strikes ×Amount) applying `might/area/speed/duration/amount/cooldown` and per-level deltas; resets the timer.
- **Key functions:** `static func step(state: RunState, db, delta: float) -> void` · one `_fire_<weapon>` per pattern.
- **Dependencies:** StatBlock, ProjectilePool, EnemyPool (nearest/random target via SpatialIndex), GameDatabase. Called by RunController.
- **Godot 4 mapping:** none — pure module.

### SpawnDirector
- **Goal:** Drive the verbatim Mad Forest escalation — periodic spawns, events, bosses, braziers, and the Reaper — into the enemy/pickup pools.
- **Type:** pure/stateless logic.
- **Inputs:** `RunState`, `delta`, `GameDatabase` wave table, `camera_world_rect`.
- **Outputs / mutations:** advances `elapsed`/`minute`; spawns periodic enemies on the off-screen ring per the current minute's count/interval, halting periodic spawns at 300 alive and hard-capping at 500; triggers swarm/formation events (Bat/Ghost swarm, Flower Wall) at their timestamps; spawns bosses on schedule (don't despawn); spawns braziers (10%, ≤10, ~1s cadence, off-screen); at 30:00 **clears the field** and spawns the Reaper, then +1 Reaper each following minute; recycles fixed-direction enemies that drift far past the ring.
- **Key functions:** `static func step(state: RunState, db, delta: float) -> void` · `_spawn_periodic`, `_spawn_events`, `_spawn_bosses`, `_spawn_braziers`, `_spawn_reaper`.
- **Dependencies:** EnemyPool, PickupPool, SpawnDirectorState, GameDatabase. Called by RunController.
- **Godot 4 mapping:** none — pure module.

### LevelingSystem
- **Goal:** Convert XP into levels and generate/apply level-up choices.
- **Type:** pure/stateless logic.
- **Inputs:** `PlayerState`, accumulated XP (×Growth) from the tick, `GameDatabase` XP curve + item pools, `rng`.
- **Outputs / mutations:** adds XP; while `xp ≥ xp_to_next`, levels up (applies +10% Might per 10 levels, advances the curve incl. L20/L40 lumps + temporary Growth), and increments `level_up_queue`. On demand, **generates one option set** (3, or 4 with Luck): unique weapons/passives weighted by rarity, excluding maxed/full; if inventory full+maxed, offers gold/Floor Chicken. **Applies** a chosen option (new item or `level++`) and sets `stats_dirty`. **Reroll** redraws the current set and spends a charge.
- **Key functions:** `static func add_xp(player, db, amount: float) -> void` · `static func make_options(player, db, rng) -> Array` · `static func apply_choice(player, db, choice) -> void` · `static func reroll(player, db, rng) -> Array`.
- **Dependencies:** StatSystem (via dirty flag), GameDatabase, PlayerState. Driven by RunController + LevelUpScreen.
- **Godot 4 mapping:** none — pure module.

### EffectsSystem
- **Goal:** Apply consumable-pickup effects and tick timed run-effects.
- **Type:** pure/stateless logic.
- **Inputs:** `RunState`, a collected pickup kind/value, `delta`.
- **Outputs / mutations:** chicken → heal 30 (clamp max_hp); gold/bags → `gold += value`; Rosary → kill all non-immune enemies (free slots, spawn gems? — VS Rosary grants no gems; just clear); Orologion → set `freeze_timer=10`; Vacuum → magnetize all on-screen gems; Nduja → set `firebreath_timer=10`; Rerollo → `reroll_charges += 1`. Ages `freeze_timer`/`firebreath_timer` each tick (and emits a fire-breath aura projectile while active).
- **Key functions:** `static func apply_pickup(state, kind, value) -> void` · `static func tick_effects(state, delta) -> void`.
- **Dependencies:** PlayerState, EnemyPool/PickupPool/ProjectilePool. Called by RunController/Collision.
- **Godot 4 mapping:** none — pure module.

### ChestSystem
- **Goal:** Roll and auto-apply Treasure Chest contents on collection.
- **Type:** pure/stateless logic.
- **Inputs:** `PlayerState`, `chests_opened`, `GameDatabase` chest tables, `rng`.
- **Outputs / mutations:** determine item count (first 6 chests fixed **1-1-3-1-1-5**, else roll 5→3→1 with Luck scaling); grant that many upgrades/new items from the 8+8 pool (full/maxed → gold bags) and roll gold by tier (×Greed); increment `chests_opened`; set `stats_dirty`. Returns the granted list for the reveal overlay.
- **Key functions:** `static func open(player, db, rng) -> ChestResult`.
- **Dependencies:** LevelingSystem's grant core (`apply_choice`), GameDatabase, PlayerState. Driven by RunController when a chest pickup is collected.
- **Godot 4 mapping:** none — pure module.

### RunController (the conductor)
- **Goal:** Own the authoritative tick: gather input, step every pure system in order over `RunState`, dispatch results, sync views, and request screen transitions.
- **Type:** stateful node shell.
- **Inputs:** engine `_process(delta)`, player input intent from `PlayerShell`, `RunState`.
- **Outputs / mutations:** orchestrates mutation of `RunState` via the pure systems; emits signals (`level_up_requested`, `player_died`, `chest_opened`, `reaper_spawned`) to `GameManager`/UI.
- **Key functions:** `func _process(delta)` (the ordered pipeline) · `func _sync_views()`.
- **Dependencies:** every pure system; PlayerShell; ViewSync; GameManager.
- **Godot 4 mapping:** root `Node2D` of `run.tscn`. **State note:** holds the `RunState` reference and child-node references because the engine forces a node to receive `_process` and own the scene — all *game* state lives in `RunState`, not here.

### PlayerShell
- **Goal:** Bridge engine input/rendering and `PlayerState`.
- **Type:** stateful node shell.
- **Inputs:** `Input` (WASD/Arrows via `Input.get_vector`; `ESC`), `PlayerState`.
- **Outputs / mutations:** writes move intent (normalized 8-dir vector) into `PlayerState` before the tick; renders sprite/animation/flip from `pos`/`facing`/`hp`; updates the world-space health bar; sets `RunState.camera_world_rect` from the viewport+zoom.
- **Key functions:** `func _gather_input() -> Vector2` · `func render(player: PlayerState)`.
- **Dependencies:** PlayerState; child `Camera2D`. Called by RunController.
- **Godot 4 mapping:** `Node2D` with child `AnimatedSprite2D`, `HealthBar` (`Sprite2D`/`ProgressBar`-like), and `Camera2D` (integer zoom). **State note:** owns only engine I/O (input device, sprite nodes, camera); gameplay state stays in `PlayerState`.

### ViewSync (pooled view layers)
- **Goal:** Render the data pools by syncing fixed pools of dumb visual nodes from the data each tick.
- **Type:** stateful node shell.
- **Inputs:** `EnemyPool`/`ProjectilePool`/`PickupPool`/`FloatingTextPool`.
- **Outputs / mutations:** none on game state; sets each visual node's `position`/`frame`/`visible`/modulate (hit flash) from its data slot; activates/hides nodes as slots free/claim.
- **Key functions:** `func sync(pool, layer)` per pool type.
- **Dependencies:** the pools, `GameDatabase` (type_id → SpriteFrames). Called by RunController.`_sync_views()`.
- **Godot 4 mapping:** one `Node2D` layer per entity class holding a pre-instanced pool of `Sprite2D`/`AnimatedSprite2D` (NEAREST filter inherited). **State note:** owns the visual node pool the engine requires; carries no game logic. *(MultiMeshInstance2D swap-in lives entirely here if needed.)*

### GameManager
- **Goal:** Top-level screen state machine and scene flow.
- **Type:** autoload/service.
- **Inputs:** signals from RunController and UI buttons.
- **Outputs / mutations:** owns the FSM (Menu → Playing ⇄ Paused → LevelUp → GameOver); creates/destroys `RunState`; loads scenes; sets `get_tree().paused`; shows/hides overlays.
- **Key functions:** `func start_run()`, `func pause()`, `func resume()`, `func open_level_up()`, `func game_over(result)`, `func to_menu()`.
- **Dependencies:** RunController, all UI screens.
- **Godot 4 mapping:** autoload `Node`. **State note:** holds the current phase + active `RunState` handle — inherently global session state the scene tree can't carry cleanly otherwise.

### GameDatabase
- **Goal:** Provide read-only authored data (weapons, passives, enemies, wave table, XP curve, chest/drop tables).
- **Type:** autoload/service.
- **Inputs:** none (loads Resources at boot).
- **Outputs / mutations:** none — read-only lookups.
- **Key functions:** `func weapon(id)`, `func passive(id)`, `func enemy(id)`, `func wave(minute)`, `func xp_to_next(level)`, `func chest_table()`.
- **Dependencies:** the `.tres`/const data.
- **Godot 4 mapping:** autoload `Node`. **State note:** immutable after load.

### AudioManager
- **Goal:** Feedback-density SFX/music on game events.
- **Type:** autoload/service.
- **Inputs:** event signals (hit, death, gem absorb, level-up, chest, Reaper, music loop).
- **Outputs / mutations:** plays pooled `AudioStreamPlayer`s.
- **Key functions:** `func play(event)`, `func play_music(stage)`.
- **Godot 4 mapping:** autoload `Node` with an `AudioStreamPlayer` pool. **State note:** owns audio players only. *(Thin/placeholder for the slice.)*

## System Interaction & Data Flow

**One Playing tick — `RunController._process(delta)` runs the pure systems in this fixed order over `RunState`:**

1. `PlayerShell._gather_input()` → writes the 8-dir move intent and updates `facing` into `PlayerState`; sets `RunState.camera_world_rect`.
2. If `player.stats_dirty`: `StatSystem.recompute(player, db)`.
3. `SpawnDirector.step(state, db, delta)` → advances time, spawns enemies/bosses/events/braziers into pools (caps enforced); at 30:00 clears field + spawns Reaper.
4. `SpatialIndex.rebuild(grid, enemies)`.
5. `MovementSystem.step(state, delta)` → integrates player, enemies (AI/separation/freeze), projectiles, magnetized pickups; decays knockback/i-frames.
6. `WeaponSystem.step(state, db, delta)` → ticks cooldowns, fires patterns into the projectile pool.
7. `CollisionSystem.resolve(state, db, delta)` → weapon hits (damage/crit/knockback/pierce, deaths → free slot + kill++ + spawn gem + flag boss-deaths), contact damage (i-frame gated), pickup magnet+collect (returns XP buffer, chest seeds, effect events).
8. Dispatch the `CollisionResult`: `LevelingSystem.add_xp(...)` (may bump `level_up_queue`); `EffectsSystem.apply_pickup(...)` per collected consumable; for each boss-death/collected chest → `ChestSystem.open(...)` (auto-applies, returns reveal list).
9. `EffectsSystem.tick_effects(state, delta)` (freeze/fire-breath timers; emit fire-breath aura).
10. **Death check:** if `player.hp ≤ 0` and `revival == 0` → fill `RunState.result`, signal `player_died` → `GameManager.game_over()` (precedes any level-up).
11. **Level-up check:** else if `level_up_queue > 0` → signal `level_up_requested` → `GameManager.open_level_up()`.
12. `RunController._sync_views()` → `ViewSync.sync(...)` for each pool; `PlayerShell.render(player)`; HUD reads `PlayerState`/`elapsed`.

**Level-up transition:** `GameManager.open_level_up()` sets `get_tree().paused=true`, shows `LevelUpScreen` (process_mode ALWAYS). The screen calls `LevelingSystem.make_options(...)` for **one** level, renders choices + live stat rail; on pick → `LevelingSystem.apply_choice(...)` (sets `stats_dirty`), `level_up_queue--`; if still >0, regenerate the next set; when 0, unpause and resume Playing. Reroll button → `LevelingSystem.reroll(...)` if `reroll_charges>0`; Skip/Banish disabled at 0.

**Pause transition:** `ESC` → `GameManager.pause()` sets `paused=true`, shows `PauseScreen` with current build; `ESC` again → `resume()`.

**Start:** Menu → `GameManager.start_run()` builds a fresh `RunState` (Antonio kit, empty pools, RNG, timer 0), loads `run.tscn`, phase=Playing.

**Death / restart:** Game Over shows `ResultScreen` (time/level/kills/gold); Restart → discard `RunState`, `start_run()` again; Menu → `to_menu()`.

**Chest:** boss death or chest pickup → `ChestSystem.open` auto-applies items/gold and the controller shows a brief non-interactive reveal overlay (reusing the level-up panel styling) without blocking input long.

## Game State Machine
Owned by `GameManager`:

```
Boot → MainMenu
MainMenu → Playing            (Start)
Playing ⇄ Paused              (ESC)                [get_tree().paused]
Playing → LevelUp → Playing   (XP threshold; auto-pause; queue drains 1-at-a-time)
Playing → GameOver            (HP 0, Revival 0 — precedes LevelUp on same tick)
GameOver → Playing            (Restart)
GameOver → MainMenu           (Continue)
```
Paused/LevelUp/GameOver overlay `Control`s run with `process_mode = PROCESS_MODE_ALWAYS`; the `RunController` sim is frozen by `paused`.

## Godot 4 Scene Tree / Node Layout

```
Autoloads:  GameManager (Node)   GameDatabase (Node)   AudioManager (Node)

MainMenu.tscn (Control)                         ← main_menu.gd (shell)

Run.tscn
└─ RunController (Node2D)                        ← run_controller.gd (shell, owns RunState)
   ├─ World (Node2D)
   │  ├─ GroundLayer (Sprite2D, tiled grass / ParallaxBackground)
   │  ├─ PickupLayer (Node2D)                    ← ViewSync pool (Sprite2D ×N)
   │  ├─ EnemyLayer  (Node2D)                    ← ViewSync pool (AnimatedSprite2D ×512)  [MultiMesh swap-in here]
   │  ├─ ProjectileLayer (Node2D)               ← ViewSync pool (Sprite2D/AnimatedSprite2D ×N)
   │  ├─ Player (Node2D)                         ← player_shell.gd
   │  │  ├─ AnimatedSprite2D
   │  │  ├─ HealthBar (world-space)
   │  │  └─ Camera2D (integer zoom)
   │  └─ FloatingTextLayer (Node2D)              ← ViewSync pool (Label ×N) [optional]
   ├─ HUDLayer (CanvasLayer)
   │  └─ HUD (Control, anchored)                 ← hud.gd
   └─ OverlayLayer (CanvasLayer)
      ├─ LevelUpScreen (Control, ALWAYS)         ← level_up_screen.gd
      ├─ PauseScreen   (Control, ALWAYS)         ← pause_screen.gd
      └─ ResultScreen  (Control, ALWAYS)         ← result_screen.gd
```
Project: Stretch Mode = `disabled` (resize reveals more field), NEAREST filter (already set), GL Compatibility (already set).

## File / Module Layout
`res://` maps to `vampire-survivors-taskmaster/`. Pure logic and data live apart from node shells so the logic compiles and tests without a scene.

```
res://data/                      # authored Resources / const data (read-only)
   weapons.tres / weapon_defs.gd
   passives.tres / passive_defs.gd
   enemies.tres / enemy_defs.gd
   mad_forest_waves.tres         # verbatim per-minute table
   xp_curve.gd                   # thresholds + L20/L40 lumps
   chest_tables.gd  drop_tables.gd

res://logic/                     # PURE modules (static funcs) — headless-testable
   data/                         #   plain data containers (RefCounted)
      run_state.gd  player_state.gd  stat_block.gd
      weapon_instance.gd  passive_instance.gd
      enemy_pool.gd  projectile_pool.gd  pickup_pool.gd  floating_text_pool.gd
      spatial_grid.gd  spawn_director_state.gd  run_result.gd
   stat_system.gd
   movement_system.gd
   spatial_index.gd
   collision_system.gd
   weapon_system.gd
   spawn_director.gd
   leveling_system.gd
   effects_system.gd
   chest_system.gd

res://nodes/                     # node SHELLS (engine-coupled)
   run_controller.gd
   player_shell.gd
   view_sync.gd
   hud.gd  level_up_screen.gd  pause_screen.gd  result_screen.gd  main_menu.gd

res://autoload/
   game_manager.gd  game_database.gd  audio_manager.gd

res://scenes/
   main_menu.tscn  run.tscn  level_up_screen.tscn  pause_screen.tscn  result_screen.tscn

test/                            # gdUnit4 — one _test.gd per pure module (see note)
   stat_system_test.gd  movement_system_test.gd  spatial_index_test.gd
   collision_system_test.gd  weapon_system_test.gd  spawn_director_test.gd
   leveling_system_test.gd  effects_system_test.gd  chest_system_test.gd
```

**Testing note (per project `CLAUDE.md`):** the `res://logic/` modules are the unit-testable surface — each is a pure function over data objects, so the `*_test.gd` files above are the *candidate* suites. Per this project's philosophy, tests are **not written up front**; add a suite when playtesting pins down behavior worth locking (e.g., the XP curve, damage formula, chest beginner-luck sequence, pool free-list integrity, spawn caps) or to fix a regression. The architecture simply makes that cheap.

## Vertical Slice Definition
The player launches the game, hits Start on the main menu, and drops straight into the Mad Forest as Antonio with the Whip. They move 8-directionally to dodge contact damage while the Whip — and any weapons/passives they pick up — auto-fire on their own cooldowns. Killing enemies drops XP gems that pull in within the Magnet radius and absorb; filling the XP bar pauses into the level-up screen (3–4 choices, live stat rail, Reroll usable once a Rerollo is found, Skip/Banish visible-but-disabled). Power compounds while the verbatim per-minute Mad Forest wave table escalates the swarm toward 500 enemies, with bosses dropping auto-applied Treasure Chests and braziers dropping pickups (chicken, gold, Rosary, Orologion, Vacuum, Nduja, Rerollo). Surviving to 30:00 clears the field and spawns the unkillable Reaper; death (Revival = 0, always final) ends the run to a result screen showing time/level/kills/gold, from which the player restarts or returns to the menu. ESC pauses to a build overlay throughout.

## Out of Scope
Architecture is deliberately *not* built for: weapon **evolutions** and evolution chest logic; **meta-progression** (gold PowerUp shop, character/weapon/stage unlocks, achievements, Golden Eggs) — gold stays a HUD/score stat only; **Arcanas**/Randomazzo; alt modes (Hyper, Inverse, Endless, Limit Break); the other 30+ stages and the 200+ characters (only Mad Forest + Antonio); weapons/passives beyond the slice's 8+8; saving/resuming a run; determinism/replays; gamepad/touch input; DLC/Adventure/online-co-op. Skip/Banish charges, Recovery/Duration/Magnet/Luck/Growth/Greed/Curse passive sources, and Revival all exist in the data model at base values but have **no in-run source** this slice (faithful-zero) — they are modeled, not built up.
```
