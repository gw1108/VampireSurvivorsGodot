# parse-prd Prompt Trace

## Metadata
- **timestamp:** 2026-06-29T21:46:12.733Z
- **research:** false
- **append:** false
- **nextId:** 1
- **variant:** default

## System Prompt

```
You are tasked with analyzing Product Requirements Documents (PRDs) and generating a structured, logically ordered, dependency-aware and sequenced list of development tasks in JSON format.

Analyze the provided PRD content and generate an appropriate number of top-level development tasks. If the complexity or the level of detail of the PRD is high, generate more tasks relative to the complexity of the PRD
Each task should represent a logical unit of work needed to implement the requirements and focus on the most direct and effective way to implement the requirements without unnecessary complexity or overengineering. Include pseudo-code and implementation details for each task. Find the most up to date information to implement each task.
Assign sequential IDs starting from 1. Infer title, description, and details for each task based *only* on the PRD content.
Set status to 'pending', dependencies to an empty array [], and priority to 'medium' initially for all tasks.
Generate a response containing a single key "tasks", where the value is an array of task objects adhering to the provided schema.

Each task should follow this JSON structure:
{
	"id": number,
	"title": string,
	"description": string,
	"status": "pending",
	"dependencies": number[] (IDs of tasks this depends on),
	"priority": "high" | "medium" | "low",
	"details": string (implementation details)
}

Guidelines:
1. Depending on the complexity, create an appropriate number of tasks, numbered sequentially starting from 1
2. Each task should be atomic and focused on a single responsibility following the most up to date best practices and standards
3. Order tasks logically - consider dependencies and implementation sequence
4. Early tasks should focus on setup, core functionality first, then advanced features
5. To verify, update the golden path test. You do not have to test if there is not sufficient complexity or edge cases. You should never have manual testing.
6. Set appropriate dependency IDs (a task can only depend on tasks with lower IDs, potentially including existing tasks with IDs less than 1 if applicable)
7. Include detailed implementation guidance in the "details" field
8. If the PRD contains specific requirements for libraries, database schemas, frameworks, tech stacks, or any other implementation details, STRICTLY ADHERE to these requirements in your task breakdown and do not discard them under any circumstance
9. Focus on filling in any gaps left by the PRD or areas that aren't fully specified, while preserving all explicit requirements
10. Always aim to provide the most direct path to implementation, avoiding over-engineering or roundabout approaches
```

## User Prompt

```
Here's the Product Requirements Document (PRD) to break down into an appropriate number of tasks, starting IDs from 1:

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


IMPORTANT: Your response must be a JSON object with a "tasks" property containing an array of task objects. You may optionally include a "metadata" object. Do not include any other properties.
```

## LLM Response

```json
{
  "tasks": [
    {
      "id": 1,
      "title": "Create Plain Data Containers (RunState & Core Data Model)",
      "description": "Implement all RefCounted data container classes that form the backbone of the game state: RunState, PlayerState, StatBlock, WeaponInstance, PassiveInstance, and RunResult.",
      "details": "Create res://logic/data/ directory structure. Implement each as a RefCounted script with no scene dependencies:\n\n**run_state.gd:**\n```gdscript\nclass_name RunState extends RefCounted\n\nenum Phase { PLAYING, LEVEL_UP, PAUSED, GAME_OVER }\n\nvar phase: int = Phase.PLAYING\nvar elapsed: float = 0.0\nvar player: PlayerState\nvar enemies: EnemyPool\nvar projectiles: ProjectilePool\nvar pickups: PickupPool\nvar floaters: FloatingTextPool\nvar grid: SpatialGrid\nvar spawn: SpawnDirectorState\nvar rng: RandomNumberGenerator\nvar level_up_queue: int = 0\nvar freeze_timer: float = 0.0\nvar firebreath_timer: float = 0.0\nvar camera_world_rect: Rect2\nvar result: RunResult\n```\n\n**player_state.gd:**\n```gdscript\nclass_name PlayerState extends RefCounted\n\nvar pos: Vector2\nvar vel: Vector2\nvar facing: Vector2 = Vector2.RIGHT\nvar hp: float = 120.0\nvar max_hp: float = 120.0\nvar iframe_timer: float = 0.0\nvar level: int = 1\nvar xp: float = 0.0\nvar xp_to_next: float = 5.0\nvar gold: int = 0\nvar kills: int = 0\nvar weapons: Array[WeaponInstance] = []\nvar passives: Array[PassiveInstance] = []\nvar stats: StatBlock\nvar reroll_charges: int = 0\nvar skip_charges: int = 0\nvar banish_charges: int = 0\nvar revival: int = 0\nvar stats_dirty: bool = true\n```\n\n**stat_block.gd:** All derived stats with caps (max_health, recovery, armor, move_speed, might, area, speed, duration, cooldown, amount, magnet, luck, growth, greed, curse).\n\n**weapon_instance.gd:** id (StringName), level (int), cooldown_timer (float), runtime (Dictionary).\n\n**passive_instance.gd:** id (StringName), level (int).\n\n**run_result.gd:** survival_time, final_level, total_kills, total_gold.",
      "priority": "high",
      "dependencies": [],
      "status": "pending"
    },
    {
      "id": 2,
      "title": "Implement Entity Pool Data Structures",
      "description": "Create the data-oriented pool structures for enemies, projectiles, pickups, and floating text using parallel arrays with free-list allocation.",
      "details": "Implement in res://logic/data/:\n\n**enemy_pool.gd:**\n```gdscript\nclass_name EnemyPool extends RefCounted\n\nconst CAPACITY := 512\n\nvar pos: PackedVector2Array\nvar vel: PackedVector2Array\nvar hp: PackedFloat32Array\nvar max_hp: PackedFloat32Array\nvar power: PackedFloat32Array\nvar move_speed: PackedFloat32Array\nvar knockback_resist: PackedFloat32Array\nvar xp_value: PackedFloat32Array\nvar type_id: Array[StringName]\nvar ai_kind: PackedInt32Array  # 0=homing, 1=fixed, 2=wavy, 3=none\nvar is_boss: Array[bool]\nvar knockback_timer: PackedFloat32Array\nvar hit_flash: PackedFloat32Array\nvar alive: Array[bool]\nvar free_list: PackedInt32Array\nvar active_count: int = 0\n\nfunc _init():\n    _preallocate(CAPACITY)\n\nfunc spawn(position: Vector2, enemy_def: Dictionary) -> int:\n    if free_list.is_empty(): return -1\n    var idx = free_list[-1]\n    free_list.resize(free_list.size() - 1)\n    # Initialize slot from enemy_def\n    alive[idx] = true\n    active_count += 1\n    return idx\n\nfunc despawn(idx: int):\n    if not alive[idx]: return\n    alive[idx] = false\n    free_list.push_back(idx)\n    active_count -= 1\n```\n\n**projectile_pool.gd:** Similar structure with pos, vel, damage, pierce_left, lifetime, area_scale, behavior (enum: STRAIGHT/HOMING/BOUNCE/ORBIT/AURA), owner_weapon, type_id, crit_chance, crit_mult, hit_cooldown, recent_hits (Dictionary for pierce tracking).\n\n**pickup_pool.gd:** pos, kind (enum: GEM/GOLD/CHICKEN/ROSARY/OROLOGION/VACUUM/NDUJA/REROLLO/CHEST), value, gem_tier (BLUE/GREEN/RED), magnetized, alive. Track gem_count for the 400-gem merge cap.\n\n**floating_text_pool.gd:** pos, vel, text, ttl, alive, free_list.",
      "priority": "high",
      "dependencies": [
        1
      ],
      "status": "pending"
    },
    {
      "id": 3,
      "title": "Implement SpatialGrid and SpatialIndex System",
      "description": "Create the uniform-grid spatial hash for broadphase collision detection, enabling efficient circle-vs-circle queries against hundreds of enemies.",
      "details": "**res://logic/data/spatial_grid.gd:**\n```gdscript\nclass_name SpatialGrid extends RefCounted\n\nvar cell_size: float = 64.0\nvar cells: Dictionary = {}  # Vector2i -> PackedInt32Array\n\nfunc clear():\n    cells.clear()\n\nfunc get_cell_key(world_pos: Vector2) -> Vector2i:\n    return Vector2i(int(world_pos.x / cell_size), int(world_pos.y / cell_size))\n```\n\n**res://logic/spatial_index.gd:**\n```gdscript\nclass_name SpatialIndex extends RefCounted\n\nstatic func rebuild(grid: SpatialGrid, enemies: EnemyPool) -> void:\n    grid.clear()\n    for i in range(enemies.CAPACITY):\n        if not enemies.alive[i]: continue\n        var key = grid.get_cell_key(enemies.pos[i])\n        if not grid.cells.has(key):\n            grid.cells[key] = PackedInt32Array()\n        grid.cells[key].push_back(i)\n\nstatic func query_circle(grid: SpatialGrid, enemies: EnemyPool, center: Vector2, radius: float) -> PackedInt32Array:\n    var result := PackedInt32Array()\n    var radius_sq := radius * radius\n    var min_cell := grid.get_cell_key(center - Vector2(radius, radius))\n    var max_cell := grid.get_cell_key(center + Vector2(radius, radius))\n    \n    for cx in range(min_cell.x, max_cell.x + 1):\n        for cy in range(min_cell.y, max_cell.y + 1):\n            var key := Vector2i(cx, cy)\n            if not grid.cells.has(key): continue\n            for idx in grid.cells[key]:\n                if not enemies.alive[idx]: continue\n                if center.distance_squared_to(enemies.pos[idx]) <= radius_sq:\n                    result.push_back(idx)\n    return result\n```\n\nThis avoids running Area2D monitors for 500+ enemies by using pure data lookup with O(1) cell access.",
      "priority": "high",
      "dependencies": [
        2
      ],
      "status": "pending"
    },
    {
      "id": 4,
      "title": "Create GameDatabase Autoload with Static Game Data",
      "description": "Implement the read-only database autoload containing all authored constants: weapon definitions, passive definitions, enemy definitions, Mad Forest wave table, XP curve, and drop tables.",
      "details": "**res://autoload/game_database.gd:**\n```gdscript\nextends Node\n\n# Weapon definitions with base stats and per-level deltas\nconst WEAPONS := {\n    &\"whip\": { base_dmg = 10, cooldown = 1.35, amount = 1, pattern = \"slash\", pierce = true,\n        levels = [{}, {dmg=+2.5}, {area=+0.1}, {dmg=+2.5}, ...] },\n    &\"knife\": { base_dmg = 6.5, cooldown = 1.0, amount = 1, pattern = \"directional\", ... },\n    # ... all 8 weapons\n}\n\nconst PASSIVES := {\n    &\"spinach\": { stat = \"might\", per_level = 0.10, max_level = 5 },\n    &\"armor\": { stat = \"armor\", per_level = 1.0, max_level = 5, retaliatory = true },\n    # ... all 8 passives\n}\n\nconst ENEMIES := {\n    &\"zombie\": { hp = 10, power = 10, move_speed = 100, xp = 1, ai = \"homing\" },\n    &\"skeleton\": { hp = 15, power = 10, move_speed = 100, xp = 2, ai = \"homing\" },\n    # ... full Mad Forest roster including bosses\n    &\"reaper\": { hp = 655350, power = 65535, move_speed = 1200, xp = 0, ai = \"homing\", immune = true },\n}\n\n# Verbatim per-minute Mad Forest wave table\nconst MAD_FOREST_WAVES := [\n    { enemies = [\"zombie\"], count = 15, interval = 1.0 },  # minute 0\n    { enemies = [\"zombie\", \"skeleton\"], count = 25, interval = 0.8, boss = \"glowing_bat\" },  # minute 1\n    # ... through minute 30\n]\n\n# XP curve: L1->L2=5, +10/level through L20, +13 L21-40, +16 L41+, lumps at L20/L40\nstatic func xp_to_next(level: int) -> float:\n    # Implementation of the exact curve\n\nstatic func weapon(id: StringName) -> Dictionary\nstatic func passive(id: StringName) -> Dictionary\nstatic func enemy(id: StringName) -> Dictionary\nstatic func wave(minute: int) -> Dictionary\n```\n\nRegister as autoload in project.godot. This is the single source of truth for all game constants.",
      "priority": "high",
      "dependencies": [],
      "status": "pending"
    },
    {
      "id": 5,
      "title": "Implement StatSystem (Pure Logic)",
      "description": "Create the pure stateless system that resolves PlayerState inventory and level into the derived StatBlock, applying all passive bonuses and character modifiers.",
      "details": "**res://logic/stat_system.gd:**\n```gdscript\nclass_name StatSystem extends RefCounted\n\nstatic func recompute(player: PlayerState, db: Node) -> void:\n    var stats := player.stats\n    if stats == null:\n        stats = StatBlock.new()\n        player.stats = stats\n    \n    # Reset to base values\n    stats.max_health = 100.0\n    stats.recovery = 0.0\n    stats.armor = 0.0\n    stats.move_speed = 1.0\n    stats.might = 1.0\n    stats.area = 1.0\n    stats.speed = 1.0\n    stats.duration = 1.0\n    stats.cooldown = 1.0\n    stats.amount = 0\n    stats.magnet = 30.0\n    stats.luck = 1.0\n    stats.growth = 1.0\n    stats.greed = 1.0\n    stats.curse = 1.0\n    \n    # Apply Antonio's character bonuses: +20 Max HP, +1 Armor\n    stats.max_health += 20.0\n    stats.armor += 1.0\n    \n    # Apply Antonio's level bonus: +10% Might every 10 levels (max +50% at L50)\n    var might_bonus := mini(player.level / 10, 5) * 0.10\n    stats.might += might_bonus\n    \n    # Apply each passive's contribution\n    for passive in player.passives:\n        var def = db.passive(passive.id)\n        var value = def.per_level * passive.level\n        match def.stat:\n            \"might\": stats.might += value\n            \"armor\": stats.armor += value\n            \"max_health\": stats.max_health *= (1.0 + value)\n            \"cooldown\": stats.cooldown -= value  # negative = faster\n            \"area\": stats.area += value\n            \"speed\": stats.speed += value\n            \"move_speed\": stats.move_speed += value\n            \"amount\": stats.amount += int(value)\n    \n    # Apply caps\n    stats.might = minf(stats.might, 10.0)  # 1000%\n    stats.cooldown = maxf(stats.cooldown, 0.1)  # -90% floor\n    stats.amount = mini(stats.amount, 10)\n    \n    player.stats_dirty = false\n```",
      "priority": "high",
      "dependencies": [
        1,
        4
      ],
      "status": "pending"
    },
    {
      "id": 6,
      "title": "Implement MovementSystem (Pure Logic)",
      "description": "Create the pure stateless system that integrates all kinematics: player movement, enemy AI (homing/fixed/wavy), projectile motion, magnetized pickups, knockback decay, and i-frame decay.",
      "details": "**res://logic/movement_system.gd:**\n```gdscript\nclass_name MovementSystem extends RefCounted\n\nstatic func step(state: RunState, delta: float) -> void:\n    _move_player(state, delta)\n    _move_enemies(state, delta)\n    _move_projectiles(state, delta)\n    _move_pickups(state, delta)\n\nstatic func _move_player(state: RunState, delta: float) -> void:\n    var player := state.player\n    var speed := 200.0 * player.stats.move_speed\n    player.pos += player.vel.normalized() * speed * delta\n    \n    if player.vel.length_squared() > 0.01:\n        player.facing = player.vel.normalized()\n    \n    player.iframe_timer = maxf(0.0, player.iframe_timer - delta)\n\nstatic func _move_enemies(state: RunState, delta: float) -> void:\n    var enemies := state.enemies\n    var player_pos := state.player.pos\n    var frozen := state.freeze_timer > 0.0\n    \n    for i in range(enemies.CAPACITY):\n        if not enemies.alive[i]: continue\n        if frozen: continue  # Orologion freeze\n        \n        # Decay knockback\n        if enemies.knockback_timer[i] > 0:\n            enemies.knockback_timer[i] -= delta\n            enemies.pos[i] += enemies.vel[i] * delta\n            continue\n        \n        # AI movement\n        var dir := Vector2.ZERO\n        match enemies.ai_kind[i]:\n            0:  # HOMING\n                dir = (player_pos - enemies.pos[i]).normalized()\n            1:  # FIXED\n                dir = enemies.vel[i].normalized()\n            2:  # WAVY\n                dir = (player_pos - enemies.pos[i]).normalized()\n                dir = dir.rotated(sin(state.elapsed * 3.0) * 0.5)\n        \n        enemies.vel[i] = dir * enemies.move_speed[i]\n        enemies.pos[i] += enemies.vel[i] * delta\n        \n        # Lightweight separation push\n        # (Simple O(n) neighbor check or use spatial grid)\n\nstatic func _move_projectiles(state: RunState, delta: float) -> void:\n    # Handle STRAIGHT, BOUNCE, ORBIT, AURA behaviors\n    # Decay lifetime\n\nstatic func _move_pickups(state: RunState, delta: float) -> void:\n    # Pull magnetized gems toward player\n    var magnet_speed := 400.0\n    for i in range(state.pickups.CAPACITY):\n        if not state.pickups.alive[i]: continue\n        if state.pickups.magnetized[i]:\n            var dir := (state.player.pos - state.pickups.pos[i]).normalized()\n            state.pickups.pos[i] += dir * magnet_speed * delta\n```",
      "priority": "high",
      "dependencies": [
        1,
        2,
        5
      ],
      "status": "pending"
    },
    {
      "id": 7,
      "title": "Implement CollisionSystem (Pure Logic)",
      "description": "Create the pure stateless system that resolves all overlap interactions: weapon hits with damage/crit/knockback, contact damage with i-frames, and pickup collection with magnet radius.",
      "details": "**res://logic/collision_system.gd:**\n```gdscript\nclass_name CollisionSystem extends RefCounted\n\nclass CollisionResult extends RefCounted:\n    var xp_gained: float = 0.0\n    var boss_deaths: Array[int] = []\n    var collected_chests: Array[int] = []\n    var collected_effects: Array[Dictionary] = []  # {kind, value}\n\nstatic func resolve(state: RunState, db: Node, delta: float) -> CollisionResult:\n    var result := CollisionResult.new()\n    \n    _resolve_weapon_hits(state, db, delta, result)\n    _resolve_contact_damage(state, db, delta)\n    _resolve_pickup_collection(state, result)\n    \n    return result\n\nstatic func _resolve_weapon_hits(state: RunState, db: Node, delta: float, result: CollisionResult) -> void:\n    var projectiles := state.projectiles\n    var enemies := state.enemies\n    \n    for p in range(projectiles.CAPACITY):\n        if not projectiles.alive[p]: continue\n        \n        var hit_radius := 16.0 * projectiles.area_scale[p]\n        var candidates := SpatialIndex.query_circle(state.grid, enemies, projectiles.pos[p], hit_radius)\n        \n        for enemy_idx in candidates:\n            # Skip if recently hit (pierce cooldown)\n            if projectiles.recent_hits[p].has(enemy_idx): continue\n            \n            # Calculate damage\n            var base_dmg := projectiles.damage[p] * state.player.stats.might\n            var is_crit := state.rng.randf() < projectiles.crit_chance[p] * state.player.stats.luck\n            var final_dmg := base_dmg * (projectiles.crit_mult[p] if is_crit else 1.0)\n            \n            enemies.hp[enemy_idx] -= final_dmg\n            enemies.hit_flash[enemy_idx] = 0.1  # Flash duration\n            \n            # Apply knockback (unless resistant)\n            if enemies.knockback_resist[enemy_idx] < 1.0:\n                var kb_dir := (enemies.pos[enemy_idx] - projectiles.pos[p]).normalized()\n                enemies.vel[enemy_idx] = kb_dir * 200.0 * (1.0 - enemies.knockback_resist[enemy_idx])\n                enemies.knockback_timer[enemy_idx] = 0.12\n            \n            # Track pierce\n            projectiles.recent_hits[p][enemy_idx] = true\n            projectiles.pierce_left[p] -= 1\n            \n            # Check death\n            if enemies.hp[enemy_idx] <= 0:\n                _on_enemy_death(state, enemy_idx, result)\n            \n            if projectiles.pierce_left[p] <= 0:\n                projectiles.alive[p] = false\n                break\n\nstatic func _on_enemy_death(state: RunState, idx: int, result: CollisionResult) -> void:\n    var xp := state.enemies.xp_value[idx]\n    state.player.kills += 1\n    \n    # Spawn XP gem\n    var gem_tier := 0 if xp <= 2 else (1 if xp <= 9 else 2)\n    state.pickups.spawn(state.enemies.pos[idx], PickupPool.Kind.GEM, xp, gem_tier)\n    \n    if state.enemies.is_boss[idx]:\n        result.boss_deaths.push_back(idx)\n    \n    state.enemies.despawn(idx)\n\nstatic func _resolve_contact_damage(state: RunState, db: Node, delta: float) -> void:\n    if state.player.iframe_timer > 0: return\n    \n    var player_radius := 20.0\n    var candidates := SpatialIndex.query_circle(state.grid, state.enemies, state.player.pos, player_radius)\n    \n    for enemy_idx in candidates:\n        var damage := maxf(1.0, state.enemies.power[enemy_idx] - state.player.stats.armor)\n        state.player.hp -= damage\n        state.player.iframe_timer = 0.24  # 240ms i-frames\n        break  # Only take damage from one enemy per tick\n\nstatic func _resolve_pickup_collection(state: RunState, result: CollisionResult) -> void:\n    var pickups := state.pickups\n    var player_pos := state.player.pos\n    var magnet_radius := state.player.stats.magnet\n    var collect_radius := 16.0\n    \n    for i in range(pickups.CAPACITY):\n        if not pickups.alive[i]: continue\n        var dist := player_pos.distance_to(pickups.pos[i])\n        \n        # Magnetize\n        if dist <= magnet_radius:\n            pickups.magnetized[i] = true\n        \n        # Collect\n        if dist <= collect_radius:\n            match pickups.kind[i]:\n                PickupPool.Kind.GEM:\n                    result.xp_gained += pickups.value[i]\n                PickupPool.Kind.CHEST:\n                    result.collected_chests.push_back(i)\n                _:\n                    result.collected_effects.push_back({kind = pickups.kind[i], value = pickups.value[i]})\n            pickups.despawn(i)\n```",
      "priority": "high",
      "dependencies": [
        2,
        3,
        5
      ],
      "status": "pending"
    },
    {
      "id": 8,
      "title": "Implement WeaponSystem (Pure Logic)",
      "description": "Create the pure stateless system that ticks weapon cooldowns and fires each weapon's pattern into the projectile pool, applying all stat scaling.",
      "details": "**res://logic/weapon_system.gd:**\n```gdscript\nclass_name WeaponSystem extends RefCounted\n\nstatic func step(state: RunState, db: Node, delta: float) -> void:\n    for weapon in state.player.weapons:\n        var def := db.weapon(weapon.id)\n        var scaled_cooldown := def.cooldown * state.player.stats.cooldown\n        \n        weapon.cooldown_timer -= delta\n        if weapon.cooldown_timer > 0: continue\n        \n        weapon.cooldown_timer = scaled_cooldown\n        _fire_weapon(state, weapon, def, db)\n\nstatic func _fire_weapon(state: RunState, weapon: WeaponInstance, def: Dictionary, db: Node) -> void:\n    var stats := state.player.stats\n    var amount := def.amount + stats.amount\n    var damage := def.base_dmg * stats.might\n    var area_scale := stats.area\n    var proj_speed := 300.0 * stats.speed\n    \n    match weapon.id:\n        &\"whip\":\n            _fire_whip(state, weapon, damage, area_scale, amount)\n        &\"knife\":\n            _fire_knife(state, weapon, damage, proj_speed, amount)\n        &\"magic_wand\":\n            _fire_magic_wand(state, weapon, damage, proj_speed, amount)\n        &\"runetracer\":\n            _fire_runetracer(state, weapon, damage, amount)\n        &\"garlic\":\n            _fire_garlic(state, weapon, damage, area_scale)\n        &\"king_bible\":\n            _fire_king_bible(state, weapon, damage, amount)\n        &\"fire_wand\":\n            _fire_fire_wand(state, weapon, damage, amount)\n        &\"lightning_ring\":\n            _fire_lightning_ring(state, weapon, damage, amount)\n\nstatic func _fire_whip(state: RunState, weapon: WeaponInstance, damage: float, area: float, amount: int) -> void:\n    # Horizontal slash in facing direction, pierces all enemies in arc\n    var proj := state.projectiles.spawn()\n    if proj < 0: return\n    state.projectiles.pos[proj] = state.player.pos + state.player.facing * 32\n    state.projectiles.damage[proj] = damage\n    state.projectiles.area_scale[proj] = area\n    state.projectiles.pierce_left[proj] = 999  # Pierce all\n    state.projectiles.lifetime[proj] = 0.3\n    state.projectiles.behavior[proj] = ProjectilePool.Behavior.AURA  # Stays in place\n\nstatic func _fire_knife(state: RunState, weapon: WeaponInstance, damage: float, speed: float, amount: int) -> void:\n    for i in range(amount):\n        var proj := state.projectiles.spawn()\n        if proj < 0: return\n        state.projectiles.pos[proj] = state.player.pos\n        state.projectiles.vel[proj] = state.player.facing * speed\n        state.projectiles.damage[proj] = damage\n        state.projectiles.pierce_left[proj] = 1\n        state.projectiles.lifetime[proj] = 2.0\n        state.projectiles.behavior[proj] = ProjectilePool.Behavior.STRAIGHT\n\nstatic func _fire_magic_wand(state: RunState, weapon: WeaponInstance, damage: float, speed: float, amount: int) -> void:\n    # Fire at nearest enemy\n    var nearest := _find_nearest_enemy(state)\n    if nearest < 0: return\n    var dir := (state.enemies.pos[nearest] - state.player.pos).normalized()\n    \n    var proj := state.projectiles.spawn()\n    if proj < 0: return\n    state.projectiles.pos[proj] = state.player.pos\n    state.projectiles.vel[proj] = dir * speed\n    state.projectiles.damage[proj] = damage\n    state.projectiles.pierce_left[proj] = 1\n    state.projectiles.lifetime[proj] = 2.0\n    state.projectiles.behavior[proj] = ProjectilePool.Behavior.STRAIGHT\n\n# ... implement _fire_runetracer (BOUNCE), _fire_garlic (AURA around player),\n#     _fire_king_bible (ORBIT), _fire_fire_wand (random targets),\n#     _fire_lightning_ring (instant strikes)\n\nstatic func _find_nearest_enemy(state: RunState) -> int:\n    var nearest := -1\n    var nearest_dist := INF\n    for i in range(state.enemies.CAPACITY):\n        if not state.enemies.alive[i]: continue\n        var dist := state.player.pos.distance_squared_to(state.enemies.pos[i])\n        if dist < nearest_dist:\n            nearest_dist = dist\n            nearest = i\n    return nearest\n```",
      "priority": "high",
      "dependencies": [
        1,
        2,
        3,
        4,
        5
      ],
      "status": "pending"
    },
    {
      "id": 9,
      "title": "Implement SpawnDirector (Pure Logic)",
      "description": "Create the pure stateless system that drives the verbatim Mad Forest escalation: periodic spawns, swarm events, bosses, braziers, and the Reaper at 30:00.",
      "details": "**res://logic/data/spawn_director_state.gd:**\n```gdscript\nclass_name SpawnDirectorState extends RefCounted\n\nvar minute: int = 0\nvar periodic_timer: float = 0.0\nvar event_cursor: int = 0\nvar boss_cursor: int = 0\nvar brazier_timer: float = 0.0\nvar brazier_count: int = 0\nvar chests_opened: int = 0\nvar reaper_timer: float = 0.0\n```\n\n**res://logic/spawn_director.gd:**\n```gdscript\nclass_name SpawnDirector extends RefCounted\n\nconst PERIODIC_CAP := 300\nconst HARD_CAP := 500\nconst REAPER_TIME := 30.0 * 60.0  # 30 minutes\n\nstatic func step(state: RunState, db: Node, delta: float) -> void:\n    state.elapsed += delta\n    var spawn_state := state.spawn\n    \n    # Update minute\n    var new_minute := int(state.elapsed / 60.0)\n    if new_minute > spawn_state.minute:\n        spawn_state.minute = new_minute\n    \n    # Check for Reaper spawn at 30:00\n    if state.elapsed >= REAPER_TIME:\n        _handle_reaper(state, db, delta)\n        return\n    \n    _spawn_periodic(state, db, delta)\n    _spawn_events(state, db)\n    _spawn_bosses(state, db)\n    _spawn_braziers(state, db, delta)\n    _cull_distant_enemies(state)\n\nstatic func _spawn_periodic(state: RunState, db: Node, delta: float) -> void:\n    if state.enemies.active_count >= PERIODIC_CAP: return\n    \n    var wave := db.wave(state.spawn.minute)\n    state.spawn.periodic_timer -= delta\n    \n    if state.spawn.periodic_timer <= 0:\n        state.spawn.periodic_timer = wave.interval / state.player.stats.curse\n        \n        if state.enemies.active_count < HARD_CAP:\n            var enemy_type: StringName = wave.enemies[state.rng.randi() % wave.enemies.size()]\n            var pos := _get_offscreen_spawn_pos(state)\n            var def := db.enemy(enemy_type)\n            state.enemies.spawn(pos, def)\n\nstatic func _get_offscreen_spawn_pos(state: RunState) -> Vector2:\n    # Spawn on a ring just outside camera_world_rect\n    var rect := state.camera_world_rect.grow(64.0)  # 64px outside visible\n    var side := state.rng.randi() % 4\n    match side:\n        0: return Vector2(state.rng.randf_range(rect.position.x, rect.end.x), rect.position.y)  # Top\n        1: return Vector2(state.rng.randf_range(rect.position.x, rect.end.x), rect.end.y)      # Bottom\n        2: return Vector2(rect.position.x, state.rng.randf_range(rect.position.y, rect.end.y))  # Left\n        _: return Vector2(rect.end.x, state.rng.randf_range(rect.position.y, rect.end.y))       # Right\n\nstatic func _handle_reaper(state: RunState, db: Node, delta: float) -> void:\n    # First Reaper spawn clears the field\n    if state.spawn.reaper_timer == 0:\n        _clear_field(state)\n        _spawn_reaper(state, db)\n        state.spawn.reaper_timer = 60.0  # Next Reaper in 1 minute\n    else:\n        state.spawn.reaper_timer -= delta\n        if state.spawn.reaper_timer <= 0:\n            _spawn_reaper(state, db)\n            state.spawn.reaper_timer = 60.0\n\nstatic func _clear_field(state: RunState) -> void:\n    for i in range(state.enemies.CAPACITY):\n        if state.enemies.alive[i] and not state.enemies.type_id[i] == &\"reaper\":\n            state.enemies.despawn(i)\n\nstatic func _spawn_reaper(state: RunState, db: Node) -> void:\n    var def := db.enemy(&\"reaper\")\n    var pos := _get_offscreen_spawn_pos(state)\n    state.enemies.spawn(pos, def)\n```",
      "priority": "high",
      "dependencies": [
        1,
        2,
        4
      ],
      "status": "pending"
    },
    {
      "id": 10,
      "title": "Implement LevelingSystem (Pure Logic)",
      "description": "Create the pure stateless system that converts XP into levels, generates level-up option sets (3-4 unique choices), and applies chosen upgrades.",
      "details": "**res://logic/leveling_system.gd:**\n```gdscript\nclass_name LevelingSystem extends RefCounted\n\nconst INVENTORY_CAP := 6  # 6 weapons + 6 passives\n\nstatic func add_xp(player: PlayerState, db: Node, amount: float) -> void:\n    var growth_mult := player.stats.growth\n    player.xp += amount * growth_mult\n    \n    while player.xp >= player.xp_to_next:\n        player.xp -= player.xp_to_next\n        player.level += 1\n        player.xp_to_next = db.xp_to_next(player.level)\n        \n        # Antonio level bonus: +10% Might every 10 levels\n        if player.level % 10 == 0:\n            player.stats_dirty = true\n        \n        player.level_up_queue += 1\n\nstatic func make_options(player: PlayerState, db: Node, rng: RandomNumberGenerator) -> Array:\n    # Determine option count: 3, or 4 with luck chance\n    var option_count := 3\n    if rng.randf() < (1.0 - 1.0 / player.stats.luck):\n        option_count = 4\n    \n    var options: Array = []\n    var excluded: Array[StringName] = []\n    \n    # Exclude maxed items\n    for w in player.weapons:\n        if w.level >= 8:\n            excluded.append(w.id)\n    for p in player.passives:\n        if p.level >= 5:\n            excluded.append(p.id)\n    \n    # Check if inventory is full\n    var weapons_full := player.weapons.size() >= INVENTORY_CAP\n    var passives_full := player.passives.size() >= INVENTORY_CAP\n    \n    # Build candidate pool\n    var candidates: Array = []\n    \n    # Add owned items (upgrades)\n    for w in player.weapons:\n        if w.level < 8:\n            candidates.append({type = \"weapon_upgrade\", id = w.id, level = w.level + 1})\n    for p in player.passives:\n        if p.level < 5:\n            candidates.append({type = \"passive_upgrade\", id = p.id, level = p.level + 1})\n    \n    # Add new items if not full\n    if not weapons_full:\n        for wid in db.WEAPONS.keys():\n            if not _has_weapon(player, wid):\n                candidates.append({type = \"new_weapon\", id = wid})\n    if not passives_full:\n        for pid in db.PASSIVES.keys():\n            if not _has_passive(player, pid):\n                candidates.append({type = \"new_passive\", id = pid})\n    \n    # If no candidates, offer gold/chicken\n    if candidates.is_empty():\n        return [{type = \"gold\", value = 25}, {type = \"chicken\"}]\n    \n    # Pick unique options\n    candidates.shuffle()\n    for i in range(mini(option_count, candidates.size())):\n        options.append(candidates[i])\n    \n    return options\n\nstatic func apply_choice(player: PlayerState, db: Node, choice: Dictionary) -> void:\n    match choice.type:\n        \"weapon_upgrade\":\n            for w in player.weapons:\n                if w.id == choice.id:\n                    w.level = choice.level\n                    break\n        \"passive_upgrade\":\n            for p in player.passives:\n                if p.id == choice.id:\n                    p.level = choice.level\n                    break\n        \"new_weapon\":\n            var inst := WeaponInstance.new()\n            inst.id = choice.id\n            inst.level = 1\n            player.weapons.append(inst)\n        \"new_passive\":\n            var inst := PassiveInstance.new()\n            inst.id = choice.id\n            inst.level = 1\n            player.passives.append(inst)\n        \"gold\":\n            player.gold += choice.value\n        \"chicken\":\n            player.hp = minf(player.hp + 30.0, player.stats.max_health)\n    \n    player.stats_dirty = true\n\nstatic func reroll(player: PlayerState, db: Node, rng: RandomNumberGenerator) -> Array:\n    if player.reroll_charges <= 0:\n        return []\n    player.reroll_charges -= 1\n    return make_options(player, db, rng)\n\nstatic func _has_weapon(player: PlayerState, id: StringName) -> bool:\n    for w in player.weapons:\n        if w.id == id: return true\n    return false\n\nstatic func _has_passive(player: PlayerState, id: StringName) -> bool:\n    for p in player.passives:\n        if p.id == id: return true\n    return false\n```",
      "priority": "high",
      "dependencies": [
        1,
        4,
        5
      ],
      "status": "pending"
    },
    {
      "id": 11,
      "title": "Implement EffectsSystem and ChestSystem (Pure Logic)",
      "description": "Create the pure systems for applying consumable pickup effects (chicken, gold, Rosary, Orologion, Vacuum, Nduja, Rerollo), ticking timed effects, and rolling/applying Treasure Chest contents.",
      "details": "**res://logic/effects_system.gd:**\n```gdscript\nclass_name EffectsSystem extends RefCounted\n\nstatic func apply_pickup(state: RunState, kind: int, value: float) -> void:\n    var player := state.player\n    match kind:\n        PickupPool.Kind.CHICKEN:\n            player.hp = minf(player.hp + 30.0, player.stats.max_health)\n        PickupPool.Kind.GOLD:\n            player.gold += int(value * player.stats.greed)\n        PickupPool.Kind.ROSARY:\n            _screen_clear(state)\n        PickupPool.Kind.OROLOGION:\n            state.freeze_timer = 10.0\n        PickupPool.Kind.VACUUM:\n            _magnetize_all_gems(state)\n        PickupPool.Kind.NDUJA:\n            state.firebreath_timer = 10.0\n        PickupPool.Kind.REROLLO:\n            player.reroll_charges += 1\n\nstatic func _screen_clear(state: RunState) -> void:\n    for i in range(state.enemies.CAPACITY):\n        if not state.enemies.alive[i]: continue\n        var def_id := state.enemies.type_id[i]\n        # Don't kill immune enemies (Reaper, certain bosses)\n        if def_id == &\"reaper\": continue\n        state.enemies.despawn(i)  # Rosary grants no gems per VS\n\nstatic func _magnetize_all_gems(state: RunState) -> void:\n    for i in range(state.pickups.CAPACITY):\n        if not state.pickups.alive[i]: continue\n        if state.pickups.kind[i] == PickupPool.Kind.GEM:\n            state.pickups.magnetized[i] = true\n\nstatic func tick_effects(state: RunState, delta: float) -> void:\n    if state.freeze_timer > 0:\n        state.freeze_timer = maxf(0.0, state.freeze_timer - delta)\n    \n    if state.firebreath_timer > 0:\n        state.firebreath_timer = maxf(0.0, state.firebreath_timer - delta)\n        # Emit fire-breath aura projectile each tick\n        _emit_firebreath(state)\n\nstatic func _emit_firebreath(state: RunState) -> void:\n    # Spawn a short-lived aura projectile around player\n    var proj := state.projectiles.spawn()\n    if proj < 0: return\n    state.projectiles.pos[proj] = state.player.pos\n    state.projectiles.damage[proj] = 20.0 * state.player.stats.might\n    state.projectiles.behavior[proj] = ProjectilePool.Behavior.AURA\n    state.projectiles.lifetime[proj] = 0.1\n    state.projectiles.area_scale[proj] = 1.5\n```\n\n**res://logic/chest_system.gd:**\n```gdscript\nclass_name ChestSystem extends RefCounted\n\nconst BEGINNER_SEQUENCE := [1, 1, 3, 1, 1, 5]\n\nstatic func open(player: PlayerState, spawn_state: SpawnDirectorState, db: Node, rng: RandomNumberGenerator) -> Dictionary:\n    var item_count: int\n    \n    # Beginner luck sequence for first 6 chests\n    if spawn_state.chests_opened < BEGINNER_SEQUENCE.size():\n        item_count = BEGINNER_SEQUENCE[spawn_state.chests_opened]\n    else:\n        # Roll: 5 -> 3 -> 1 with Luck scaling\n        var roll := rng.randf() * player.stats.luck\n        if roll > 0.9: item_count = 5\n        elif roll > 0.5: item_count = 3\n        else: item_count = 1\n    \n    spawn_state.chests_opened += 1\n    \n    var granted: Array = []\n    for i in range(item_count):\n        var options := LevelingSystem.make_options(player, db, rng)\n        if options.is_empty(): break\n        var choice: Dictionary = options[0]  # Auto-pick first option\n        LevelingSystem.apply_choice(player, db, choice)\n        granted.append(choice)\n    \n    # Roll gold by tier\n    var gold_range := [100, 200] if item_count == 1 else ([300, 600] if item_count == 3 else [500, 1000])\n    var gold := rng.randi_range(gold_range[0], gold_range[1])\n    player.gold += int(gold * player.stats.greed)\n    \n    return {items = granted, gold = gold}\n```",
      "priority": "medium",
      "dependencies": [
        1,
        2,
        4,
        10
      ],
      "status": "pending"
    },
    {
      "id": 12,
      "title": "Implement GameManager Autoload (State Machine)",
      "description": "Create the top-level game state machine autoload that owns screen flow (Menu → Playing ⇄ Paused → LevelUp → GameOver), creates/destroys RunState, and controls pause.",
      "details": "**res://autoload/game_manager.gd:**\n```gdscript\nextends Node\n\nenum State { MENU, PLAYING, PAUSED, LEVEL_UP, GAME_OVER }\n\nsignal state_changed(new_state: State)\nsignal run_started(run_state: RunState)\nsignal level_up_requested()\nsignal game_over_triggered(result: RunResult)\n\nvar current_state: State = State.MENU\nvar run_state: RunState = null\n\nfunc _ready() -> void:\n    process_mode = Node.PROCESS_MODE_ALWAYS\n\nfunc start_run() -> void:\n    # Create fresh RunState with Antonio's starting kit\n    run_state = RunState.new()\n    run_state.player = PlayerState.new()\n    run_state.player.pos = Vector2.ZERO\n    run_state.player.hp = 120.0\n    run_state.player.max_hp = 120.0\n    \n    # Grant starting Whip\n    var whip := WeaponInstance.new()\n    whip.id = &\"whip\"\n    whip.level = 1\n    run_state.player.weapons.append(whip)\n    \n    run_state.enemies = EnemyPool.new()\n    run_state.projectiles = ProjectilePool.new()\n    run_state.pickups = PickupPool.new()\n    run_state.floaters = FloatingTextPool.new()\n    run_state.grid = SpatialGrid.new()\n    run_state.spawn = SpawnDirectorState.new()\n    run_state.rng = RandomNumberGenerator.new()\n    run_state.rng.randomize()\n    run_state.result = RunResult.new()\n    \n    current_state = State.PLAYING\n    get_tree().paused = false\n    emit_signal(\"run_started\", run_state)\n    emit_signal(\"state_changed\", current_state)\n    \n    # Load run scene\n    get_tree().change_scene_to_file(\"res://scenes/run.tscn\")\n\nfunc pause() -> void:\n    if current_state != State.PLAYING: return\n    current_state = State.PAUSED\n    get_tree().paused = true\n    emit_signal(\"state_changed\", current_state)\n\nfunc resume() -> void:\n    if current_state != State.PAUSED: return\n    current_state = State.PLAYING\n    get_tree().paused = false\n    emit_signal(\"state_changed\", current_state)\n\nfunc open_level_up() -> void:\n    if current_state != State.PLAYING: return\n    current_state = State.LEVEL_UP\n    get_tree().paused = true\n    emit_signal(\"level_up_requested\")\n    emit_signal(\"state_changed\", current_state)\n\nfunc close_level_up() -> void:\n    if current_state != State.LEVEL_UP: return\n    run_state.level_up_queue -= 1\n    \n    if run_state.level_up_queue > 0:\n        # More level-ups queued, stay in level-up state\n        emit_signal(\"level_up_requested\")\n    else:\n        current_state = State.PLAYING\n        get_tree().paused = false\n        emit_signal(\"state_changed\", current_state)\n\nfunc game_over(result: RunResult) -> void:\n    current_state = State.GAME_OVER\n    get_tree().paused = true\n    emit_signal(\"game_over_triggered\", result)\n    emit_signal(\"state_changed\", current_state)\n\nfunc to_menu() -> void:\n    run_state = null\n    current_state = State.MENU\n    get_tree().paused = false\n    emit_signal(\"state_changed\", current_state)\n    get_tree().change_scene_to_file(\"res://scenes/main_menu.tscn\")\n\nfunc restart() -> void:\n    to_menu()\n    start_run()\n```\n\nRegister in project.godot autoloads.",
      "priority": "high",
      "dependencies": [
        1,
        4
      ],
      "status": "pending"
    },
    {
      "id": 13,
      "title": "Implement RunController (Conductor Node Shell)",
      "description": "Create the main conductor node that owns the authoritative tick: gathering input, stepping every pure system in order over RunState, dispatching results, syncing views, and requesting screen transitions.",
      "details": "**res://nodes/run_controller.gd:**\n```gdscript\nextends Node2D\n\nvar run_state: RunState\nvar player_shell: Node2D\nvar view_sync: Node\n\n@onready var game_manager := get_node(\"/root/GameManager\")\n@onready var game_db := get_node(\"/root/GameDatabase\")\n\nfunc _ready() -> void:\n    run_state = game_manager.run_state\n    player_shell = $World/Player\n    view_sync = $ViewSync\n    \n    # Initialize player shell with state reference\n    player_shell.init(run_state.player)\n    view_sync.init(run_state, game_db)\n\nfunc _process(delta: float) -> void:\n    if game_manager.current_state != game_manager.State.PLAYING:\n        return\n    \n    # 1. Gather input and update facing\n    var move_intent := player_shell._gather_input()\n    run_state.player.vel = move_intent\n    run_state.camera_world_rect = player_shell.get_camera_rect()\n    \n    # 2. Recompute stats if dirty\n    if run_state.player.stats_dirty:\n        StatSystem.recompute(run_state.player, game_db)\n    \n    # 3. Spawn director\n    SpawnDirector.step(run_state, game_db, delta)\n    \n    # 4. Rebuild spatial index\n    SpatialIndex.rebuild(run_state.grid, run_state.enemies)\n    \n    # 5. Movement\n    MovementSystem.step(run_state, delta)\n    \n    # 6. Weapons\n    WeaponSystem.step(run_state, game_db, delta)\n    \n    # 7. Collision\n    var collision_result := CollisionSystem.resolve(run_state, game_db, delta)\n    \n    # 8. Dispatch collision results\n    if collision_result.xp_gained > 0:\n        LevelingSystem.add_xp(run_state.player, game_db, collision_result.xp_gained)\n    \n    for effect in collision_result.collected_effects:\n        EffectsSystem.apply_pickup(run_state, effect.kind, effect.value)\n    \n    for boss_idx in collision_result.boss_deaths:\n        var chest_result := ChestSystem.open(run_state.player, run_state.spawn, game_db, run_state.rng)\n        _show_chest_reveal(chest_result)\n    \n    for chest_idx in collision_result.collected_chests:\n        var chest_result := ChestSystem.open(run_state.player, run_state.spawn, game_db, run_state.rng)\n        _show_chest_reveal(chest_result)\n    \n    # 9. Tick timed effects\n    EffectsSystem.tick_effects(run_state, delta)\n    \n    # 10. Death check (takes precedence over level-up)\n    if run_state.player.hp <= 0 and run_state.player.revival == 0:\n        run_state.result.survival_time = run_state.elapsed\n        run_state.result.final_level = run_state.player.level\n        run_state.result.total_kills = run_state.player.kills\n        run_state.result.total_gold = run_state.player.gold\n        game_manager.game_over(run_state.result)\n        return\n    \n    # 11. Level-up check\n    if run_state.level_up_queue > 0:\n        game_manager.open_level_up()\n        return\n    \n    # 12. Sync views\n    _sync_views()\n\nfunc _sync_views() -> void:\n    view_sync.sync_enemies(run_state.enemies)\n    view_sync.sync_projectiles(run_state.projectiles)\n    view_sync.sync_pickups(run_state.pickups)\n    view_sync.sync_floaters(run_state.floaters)\n    player_shell.render(run_state.player)\n\nfunc _show_chest_reveal(chest_result: Dictionary) -> void:\n    # Brief non-blocking overlay showing granted items\n    pass  # Implement with OverlayLayer\n\nfunc _input(event: InputEvent) -> void:\n    if event.is_action_pressed(\"pause\"):\n        if game_manager.current_state == game_manager.State.PLAYING:\n            game_manager.pause()\n        elif game_manager.current_state == game_manager.State.PAUSED:\n            game_manager.resume()\n```",
      "priority": "high",
      "dependencies": [
        1,
        2,
        3,
        5,
        6,
        7,
        8,
        9,
        10,
        11,
        12
      ],
      "status": "pending"
    },
    {
      "id": 14,
      "title": "Implement PlayerShell (Node Shell)",
      "description": "Create the player node shell that bridges engine input/rendering with PlayerState: gathering 8-directional input, rendering sprite/animation/flip, updating the world-space health bar, and computing camera viewport rect.",
      "details": "**res://nodes/player_shell.gd:**\n```gdscript\nextends Node2D\n\nvar player_state: PlayerState\n\n@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D\n@onready var health_bar: ProgressBar = $HealthBar  # Or custom Sprite2D-based\n@onready var camera: Camera2D = $Camera2D\n\nconst CAMERA_ZOOM := 2  # Integer zoom for pixel-perfect rendering\n\nfunc _ready() -> void:\n    camera.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)\n\nfunc init(state: PlayerState) -> void:\n    player_state = state\n    position = state.pos\n\nfunc _gather_input() -> Vector2:\n    var input := Input.get_vector(\"move_left\", \"move_right\", \"move_up\", \"move_down\")\n    \n    # Normalize to 8-directional\n    if input.length() > 0.1:\n        # Round to 8 directions\n        var angle := input.angle()\n        var snapped := snappedf(angle, PI / 4)\n        input = Vector2.from_angle(snapped)\n    \n    return input\n\nfunc get_camera_rect() -> Rect2:\n    var viewport_size := get_viewport_rect().size\n    var world_size := viewport_size / camera.zoom\n    var center := position\n    return Rect2(center - world_size / 2, world_size)\n\nfunc render(state: PlayerState) -> void:\n    position = state.pos\n    \n    # Flip sprite based on facing\n    if state.facing.x < 0:\n        sprite.flip_h = true\n    elif state.facing.x > 0:\n        sprite.flip_h = false\n    \n    # Animation state\n    if state.vel.length() > 0.1:\n        sprite.play(\"walk\")\n    else:\n        sprite.play(\"idle\")\n    \n    # I-frame flash\n    if state.iframe_timer > 0:\n        sprite.modulate.a = 0.5 + 0.5 * sin(state.iframe_timer * 30)\n    else:\n        sprite.modulate.a = 1.0\n    \n    # Health bar\n    health_bar.value = state.hp / state.max_hp * 100\n    health_bar.visible = state.hp < state.max_hp\n```\n\n**Input actions in project.godot:**\nAdd move_left, move_right, move_up, move_down (WASD + Arrows), and pause (ESC).",
      "priority": "high",
      "dependencies": [
        1,
        12
      ],
      "status": "pending"
    },
    {
      "id": 15,
      "title": "Implement ViewSync (Pooled View Layers)",
      "description": "Create the view synchronization system that renders data pools using fixed pools of dumb visual nodes, syncing position/frame/visible/modulate from data slots each tick.",
      "details": "**res://nodes/view_sync.gd:**\n```gdscript\nextends Node\n\nvar run_state: RunState\nvar game_db: Node\n\n# Pre-instanced node pools\nvar enemy_sprites: Array[AnimatedSprite2D] = []\nvar projectile_sprites: Array[Sprite2D] = []\nvar pickup_sprites: Array[Sprite2D] = []\nvar floater_labels: Array[Label] = []\n\n@onready var enemy_layer: Node2D = get_parent().get_node(\"World/EnemyLayer\")\n@onready var projectile_layer: Node2D = get_parent().get_node(\"World/ProjectileLayer\")\n@onready var pickup_layer: Node2D = get_parent().get_node(\"World/PickupLayer\")\n@onready var floater_layer: Node2D = get_parent().get_node(\"World/FloatingTextLayer\")\n\nfunc init(state: RunState, db: Node) -> void:\n    run_state = state\n    game_db = db\n    _create_enemy_pool(512)\n    _create_projectile_pool(256)\n    _create_pickup_pool(512)\n    _create_floater_pool(64)\n\nfunc _create_enemy_pool(count: int) -> void:\n    for i in range(count):\n        var sprite := AnimatedSprite2D.new()\n        sprite.visible = false\n        enemy_layer.add_child(sprite)\n        enemy_sprites.append(sprite)\n\nfunc _create_projectile_pool(count: int) -> void:\n    for i in range(count):\n        var sprite := Sprite2D.new()\n        sprite.visible = false\n        projectile_layer.add_child(sprite)\n        projectile_sprites.append(sprite)\n\nfunc _create_pickup_pool(count: int) -> void:\n    for i in range(count):\n        var sprite := Sprite2D.new()\n        sprite.visible = false\n        pickup_layer.add_child(sprite)\n        pickup_sprites.append(sprite)\n\nfunc _create_floater_pool(count: int) -> void:\n    for i in range(count):\n        var label := Label.new()\n        label.visible = false\n        floater_layer.add_child(label)\n        floater_labels.append(label)\n\nfunc sync_enemies(enemies: EnemyPool) -> void:\n    for i in range(mini(enemy_sprites.size(), enemies.CAPACITY)):\n        var sprite := enemy_sprites[i]\n        if enemies.alive[i]:\n            sprite.visible = true\n            sprite.position = enemies.pos[i]\n            \n            # Hit flash\n            if enemies.hit_flash[i] > 0:\n                sprite.modulate = Color.WHITE\n            else:\n                sprite.modulate = Color(1, 1, 1, 1)\n            \n            # Animation from type_id -> SpriteFrames lookup\n            # var def := game_db.enemy(enemies.type_id[i])\n            # sprite.sprite_frames = def.sprite_frames\n        else:\n            sprite.visible = false\n\nfunc sync_projectiles(projectiles: ProjectilePool) -> void:\n    for i in range(mini(projectile_sprites.size(), projectiles.CAPACITY)):\n        var sprite := projectile_sprites[i]\n        if projectiles.alive[i]:\n            sprite.visible = true\n            sprite.position = projectiles.pos[i]\n            sprite.scale = Vector2.ONE * projectiles.area_scale[i]\n            # Rotation from velocity\n            if projectiles.vel[i].length_squared() > 0:\n                sprite.rotation = projectiles.vel[i].angle()\n        else:\n            sprite.visible = false\n\nfunc sync_pickups(pickups: PickupPool) -> void:\n    for i in range(mini(pickup_sprites.size(), pickups.CAPACITY)):\n        var sprite := pickup_sprites[i]\n        if pickups.alive[i]:\n            sprite.visible = true\n            sprite.position = pickups.pos[i]\n            # Visual from kind + gem_tier\n        else:\n            sprite.visible = false\n\nfunc sync_floaters(floaters: FloatingTextPool) -> void:\n    for i in range(mini(floater_labels.size(), floaters.CAPACITY)):\n        var label := floater_labels[i]\n        if floaters.alive[i]:\n            label.visible = true\n            label.position = floaters.pos[i]\n            label.text = floaters.text[i]\n        else:\n            label.visible = false\n```",
      "priority": "high",
      "dependencies": [
        2,
        4
      ],
      "status": "pending"
    },
    {
      "id": 16,
      "title": "Create Run Scene Structure",
      "description": "Build the run.tscn scene with the complete node hierarchy: RunController, World layers (Ground, Pickups, Enemies, Projectiles, Player, FloatingText), HUD CanvasLayer, and Overlay CanvasLayer.",
      "details": "**res://scenes/run.tscn structure:**\n```\nRunController (Node2D) <- run_controller.gd\n├── World (Node2D)\n│   ├── GroundLayer (Sprite2D or TileMapLayer) - tiled grass texture\n│   ├── PickupLayer (Node2D) - ViewSync pickup pool\n│   ├── EnemyLayer (Node2D) - ViewSync enemy pool\n│   ├── ProjectileLayer (Node2D) - ViewSync projectile pool\n│   ├── Player (Node2D) <- player_shell.gd\n│   │   ├── AnimatedSprite2D (Antonio sprite)\n│   │   ├── HealthBar (ProgressBar or Sprite2D-based)\n│   │   └── Camera2D (zoom=2, integer)\n│   └── FloatingTextLayer (Node2D) - ViewSync floater pool\n├── ViewSync (Node) <- view_sync.gd\n├── HUDLayer (CanvasLayer, layer=1)\n│   └── HUD (Control) <- hud.gd\n└── OverlayLayer (CanvasLayer, layer=2)\n    ├── LevelUpScreen (Control, PROCESS_MODE_ALWAYS) <- level_up_screen.gd\n    ├── PauseScreen (Control, PROCESS_MODE_ALWAYS) <- pause_screen.gd\n    └── ResultScreen (Control, PROCESS_MODE_ALWAYS) <- result_screen.gd\n```\n\n**Ground layer:** Use a large tiled Sprite2D with grass texture or a simple TileMapLayer. The player never hits boundaries - the field is effectively infinite (enemies spawn off-screen).\n\n**Camera settings:** Camera2D with integer zoom (2x suggested), anchored to the player. Smooth scrolling disabled for pixel-perfect look.\n\n**Layer order:** PickupLayer (bottom) → EnemyLayer → ProjectileLayer → Player (top of world). HUD and overlays on separate CanvasLayers above.",
      "priority": "high",
      "dependencies": [
        13,
        14,
        15
      ],
      "status": "pending"
    },
    {
      "id": 17,
      "title": "Implement HUD (In-Run UI)",
      "description": "Create the HUD Control that displays XP bar (top), weapon/passive inventory icons (top-left), survival timer (top-center), gold and kill count (top-right), and reads from PlayerState each frame.",
      "details": "**res://nodes/hud.gd:**\n```gdscript\nextends Control\n\n@onready var xp_bar: ProgressBar = $XPBar\n@onready var timer_label: Label = $TimerLabel\n@onready var gold_label: Label = $GoldLabel\n@onready var kills_label: Label = $KillsLabel\n@onready var level_label: Label = $LevelLabel\n@onready var weapon_container: HBoxContainer = $WeaponContainer\n@onready var passive_container: HBoxContainer = $PassiveContainer\n\n@onready var game_manager := get_node(\"/root/GameManager\")\n\nfunc _process(_delta: float) -> void:\n    if game_manager.run_state == null: return\n    var player := game_manager.run_state.player\n    var elapsed := game_manager.run_state.elapsed\n    \n    # XP bar\n    xp_bar.value = player.xp / player.xp_to_next * 100\n    \n    # Timer (MM:SS format)\n    var minutes := int(elapsed) / 60\n    var seconds := int(elapsed) % 60\n    timer_label.text = \"%02d:%02d\" % [minutes, seconds]\n    \n    # Stats\n    gold_label.text = str(player.gold)\n    kills_label.text = str(player.kills)\n    level_label.text = \"LV %d\" % player.level\n    \n    # Update inventory icons (only when changed)\n    _update_inventory(player)\n\nfunc _update_inventory(player: PlayerState) -> void:\n    # Clear and rebuild weapon icons\n    for child in weapon_container.get_children():\n        child.queue_free()\n    \n    for weapon in player.weapons:\n        var icon := TextureRect.new()\n        icon.custom_minimum_size = Vector2(32, 32)\n        # icon.texture = preload weapon icon by ID\n        weapon_container.add_child(icon)\n    \n    # Same for passives\n    for child in passive_container.get_children():\n        child.queue_free()\n    \n    for passive in player.passives:\n        var icon := TextureRect.new()\n        icon.custom_minimum_size = Vector2(32, 32)\n        passive_container.add_child(icon)\n```\n\n**Layout anchors:**\n- XPBar: top stretch (full width, anchored top)\n- TimerLabel: top-center\n- GoldLabel, KillsLabel, LevelLabel: top-right\n- WeaponContainer, PassiveContainer: top-left below XP bar",
      "priority": "medium",
      "dependencies": [
        1,
        12,
        16
      ],
      "status": "pending"
    },
    {
      "id": 18,
      "title": "Implement LevelUpScreen (Overlay UI)",
      "description": "Create the level-up overlay Control that displays 3-4 item choices with icons/names/descriptions, the live stat rail, Reroll/Skip/Banish buttons, and handles player selection to apply choices via LevelingSystem.",
      "details": "**res://nodes/level_up_screen.gd:**\n```gdscript\nextends Control\n\nsignal choice_made(choice: Dictionary)\n\n@onready var title_label: Label = $Panel/TitleLabel\n@onready var options_container: VBoxContainer = $Panel/OptionsContainer\n@onready var stat_rail: VBoxContainer = $Panel/StatRail\n@onready var reroll_button: Button = $Panel/RerollButton\n@onready var skip_button: Button = $Panel/SkipButton\n@onready var banish_button: Button = $Panel/BanishButton\n\n@onready var game_manager := get_node(\"/root/GameManager\")\n@onready var game_db := get_node(\"/root/GameDatabase\")\n\nvar current_options: Array = []\n\nfunc _ready() -> void:\n    process_mode = Node.PROCESS_MODE_ALWAYS\n    visible = false\n    game_manager.level_up_requested.connect(_on_level_up_requested)\n    reroll_button.pressed.connect(_on_reroll)\n\nfunc _on_level_up_requested() -> void:\n    visible = true\n    _generate_options()\n    _update_stat_rail()\n    _update_buttons()\n\nfunc _generate_options() -> void:\n    var player := game_manager.run_state.player\n    var rng := game_manager.run_state.rng\n    current_options = LevelingSystem.make_options(player, game_db, rng)\n    \n    # Clear old options\n    for child in options_container.get_children():\n        child.queue_free()\n    \n    # Create option buttons\n    for i in range(current_options.size()):\n        var opt := current_options[i]\n        var btn := Button.new()\n        btn.custom_minimum_size = Vector2(300, 60)\n        \n        match opt.type:\n            \"new_weapon\":\n                var def := game_db.weapon(opt.id)\n                btn.text = \"%s - NEW!\\n%s\" % [opt.id, def.get(\"description\", \"\")]\n            \"weapon_upgrade\":\n                btn.text = \"%s - LV %d\" % [opt.id, opt.level]\n            \"new_passive\":\n                var def := game_db.passive(opt.id)\n                btn.text = \"%s - NEW!\\n%s\" % [opt.id, def.get(\"description\", \"\")]\n            \"passive_upgrade\":\n                btn.text = \"%s - LV %d\" % [opt.id, opt.level]\n            \"gold\":\n                btn.text = \"+%d Gold\" % opt.value\n            \"chicken\":\n                btn.text = \"Floor Chicken (+30 HP)\"\n        \n        btn.pressed.connect(_on_option_selected.bind(i))\n        options_container.add_child(btn)\n\nfunc _on_option_selected(index: int) -> void:\n    var choice := current_options[index]\n    LevelingSystem.apply_choice(game_manager.run_state.player, game_db, choice)\n    visible = false\n    game_manager.close_level_up()\n\nfunc _on_reroll() -> void:\n    var player := game_manager.run_state.player\n    if player.reroll_charges <= 0: return\n    \n    current_options = LevelingSystem.reroll(player, game_db, game_manager.run_state.rng)\n    _generate_options()\n    _update_buttons()\n\nfunc _update_buttons() -> void:\n    var player := game_manager.run_state.player\n    reroll_button.text = \"Reroll (%d)\" % player.reroll_charges\n    reroll_button.disabled = player.reroll_charges <= 0\n    skip_button.text = \"Skip (0)\"\n    skip_button.disabled = true  # Always disabled this slice\n    banish_button.text = \"Banish (0)\"\n    banish_button.disabled = true  # Always disabled this slice\n\nfunc _update_stat_rail() -> void:\n    # Display current stats from player.stats\n    var stats := game_manager.run_state.player.stats\n    # Populate stat_rail with labels showing Might, Area, Speed, etc.\n```",
      "priority": "medium",
      "dependencies": [
        10,
        12,
        17
      ],
      "status": "pending"
    },
    {
      "id": 19,
      "title": "Implement PauseScreen and ResultScreen (Overlay UI)",
      "description": "Create the pause overlay showing 'PAUSED' with current build display, and the game-over result screen showing survival time, level, kills, gold with restart/menu buttons.",
      "details": "**res://nodes/pause_screen.gd:**\n```gdscript\nextends Control\n\n@onready var build_container: VBoxContainer = $Panel/BuildContainer\n@onready var resume_button: Button = $Panel/ResumeButton\n@onready var quit_button: Button = $Panel/QuitButton\n\n@onready var game_manager := get_node(\"/root/GameManager\")\n\nfunc _ready() -> void:\n    process_mode = Node.PROCESS_MODE_ALWAYS\n    visible = false\n    game_manager.state_changed.connect(_on_state_changed)\n    resume_button.pressed.connect(_on_resume)\n    quit_button.pressed.connect(_on_quit)\n\nfunc _on_state_changed(new_state: int) -> void:\n    visible = (new_state == game_manager.State.PAUSED)\n    if visible:\n        _update_build_display()\n\nfunc _update_build_display() -> void:\n    var player := game_manager.run_state.player\n    # Show weapons and passives with levels\n    for child in build_container.get_children():\n        child.queue_free()\n    \n    for weapon in player.weapons:\n        var label := Label.new()\n        label.text = \"%s LV%d\" % [weapon.id, weapon.level]\n        build_container.add_child(label)\n    \n    for passive in player.passives:\n        var label := Label.new()\n        label.text = \"%s LV%d\" % [passive.id, passive.level]\n        build_container.add_child(label)\n\nfunc _on_resume() -> void:\n    game_manager.resume()\n\nfunc _on_quit() -> void:\n    game_manager.to_menu()\n```\n\n**res://nodes/result_screen.gd:**\n```gdscript\nextends Control\n\n@onready var time_label: Label = $Panel/TimeLabel\n@onready var level_label: Label = $Panel/LevelLabel\n@onready var kills_label: Label = $Panel/KillsLabel\n@onready var gold_label: Label = $Panel/GoldLabel\n@onready var restart_button: Button = $Panel/RestartButton\n@onready var menu_button: Button = $Panel/MenuButton\n\n@onready var game_manager := get_node(\"/root/GameManager\")\n\nfunc _ready() -> void:\n    process_mode = Node.PROCESS_MODE_ALWAYS\n    visible = false\n    game_manager.game_over_triggered.connect(_on_game_over)\n    restart_button.pressed.connect(_on_restart)\n    menu_button.pressed.connect(_on_menu)\n\nfunc _on_game_over(result: RunResult) -> void:\n    visible = true\n    \n    var minutes := int(result.survival_time) / 60\n    var seconds := int(result.survival_time) % 60\n    time_label.text = \"Time: %02d:%02d\" % [minutes, seconds]\n    level_label.text = \"Level: %d\" % result.final_level\n    kills_label.text = \"Kills: %d\" % result.total_kills\n    gold_label.text = \"Gold: %d\" % result.total_gold\n\nfunc _on_restart() -> void:\n    visible = false\n    game_manager.restart()\n\nfunc _on_menu() -> void:\n    visible = false\n    game_manager.to_menu()\n```",
      "priority": "medium",
      "dependencies": [
        12,
        17
      ],
      "status": "pending"
    },
    {
      "id": 20,
      "title": "Implement MainMenu Scene",
      "description": "Create the main menu scene with a Start button that launches directly into Mad Forest as Antonio, plus any placeholder title/branding.",
      "details": "**res://scenes/main_menu.tscn:**\n```\nMainMenu (Control) <- main_menu.gd\n├── Panel (PanelContainer, centered)\n│   ├── TitleLabel (Label) - \"Vampire Survivors Clone\"\n│   ├── StartButton (Button) - \"Start Game\"\n│   └── QuitButton (Button) - \"Quit\"\n```\n\n**res://nodes/main_menu.gd:**\n```gdscript\nextends Control\n\n@onready var start_button: Button = $Panel/StartButton\n@onready var quit_button: Button = $Panel/QuitButton\n\n@onready var game_manager := get_node(\"/root/GameManager\")\n\nfunc _ready() -> void:\n    start_button.pressed.connect(_on_start)\n    quit_button.pressed.connect(_on_quit)\n    start_button.grab_focus()\n\nfunc _on_start() -> void:\n    game_manager.start_run()\n\nfunc _on_quit() -> void:\n    get_tree().quit()\n```\n\n**Project settings:**\n- Set main_menu.tscn as the main scene in project.godot\n- Ensure GameManager, GameDatabase, AudioManager are registered as autoloads",
      "priority": "medium",
      "dependencies": [
        12
      ],
      "status": "pending"
    },
    {
      "id": 21,
      "title": "Implement AudioManager Autoload (Placeholder)",
      "description": "Create a thin placeholder AudioManager autoload with pooled AudioStreamPlayers for SFX events (hit, death, gem, level-up, chest) and background music loop.",
      "details": "**res://autoload/audio_manager.gd:**\n```gdscript\nextends Node\n\nvar sfx_pool: Array[AudioStreamPlayer] = []\nvar music_player: AudioStreamPlayer\n\nconst POOL_SIZE := 8\n\n# Placeholder audio references (replace with actual assets)\nvar sfx_hit: AudioStream = null\nvar sfx_death: AudioStream = null\nvar sfx_gem: AudioStream = null\nvar sfx_levelup: AudioStream = null\nvar sfx_chest: AudioStream = null\nvar music_stage: AudioStream = null\n\nfunc _ready() -> void:\n    # Create SFX pool\n    for i in range(POOL_SIZE):\n        var player := AudioStreamPlayer.new()\n        player.bus = \"SFX\"\n        add_child(player)\n        sfx_pool.append(player)\n    \n    # Create music player\n    music_player = AudioStreamPlayer.new()\n    music_player.bus = \"Music\"\n    add_child(music_player)\n\nfunc play(event: StringName) -> void:\n    var stream: AudioStream = null\n    match event:\n        &\"hit\": stream = sfx_hit\n        &\"death\": stream = sfx_death\n        &\"gem\": stream = sfx_gem\n        &\"levelup\": stream = sfx_levelup\n        &\"chest\": stream = sfx_chest\n    \n    if stream == null: return\n    \n    # Find available player\n    for player in sfx_pool:\n        if not player.playing:\n            player.stream = stream\n            player.play()\n            return\n\nfunc play_music(track: StringName) -> void:\n    match track:\n        &\"stage\":\n            if music_stage:\n                music_player.stream = music_stage\n                music_player.play()\n\nfunc stop_music() -> void:\n    music_player.stop()\n```\n\nRegister as autoload. Actual audio assets can be added later; the system is ready to hook into collision/leveling events.",
      "priority": "low",
      "dependencies": [],
      "status": "pending"
    },
    {
      "id": 22,
      "title": "Configure Project Settings and Input Actions",
      "description": "Update project.godot with all required settings: autoload registrations, input actions (WASD/Arrows/ESC), window settings (1445×900, resizable), stretch mode disabled, and NEAREST texture filtering.",
      "details": "**project.godot updates:**\n\n```ini\n[application]\nconfig/name=\"VampireSurvivorsTaskmaster\"\nrun/main_scene=\"res://scenes/main_menu.tscn\"\nconfig/features=PackedStringArray(\"4.6\", \"GL Compatibility\")\n\n[autoload]\nGameManager=\"*res://autoload/game_manager.gd\"\nGameDatabase=\"*res://autoload/game_database.gd\"\nAudioManager=\"*res://autoload/audio_manager.gd\"\n\n[display]\nwindow/size/viewport_width=1445\nwindow/size/viewport_height=900\nwindow/size/resizable=true\nwindow/stretch/mode=\"disabled\"\n\n[input]\nmove_left={\n\"deadzone\": 0.5,\n\"events\": [InputEventKey:A, InputEventKey:Left]\n}\nmove_right={\n\"deadzone\": 0.5,\n\"events\": [InputEventKey:D, InputEventKey:Right]\n}\nmove_up={\n\"deadzone\": 0.5,\n\"events\": [InputEventKey:W, InputEventKey:Up]\n}\nmove_down={\n\"deadzone\": 0.5,\n\"events\": [InputEventKey:S, InputEventKey:Down]\n}\npause={\n\"deadzone\": 0.5,\n\"events\": [InputEventKey:Escape]\n}\n\n[rendering]\ntextures/canvas_textures/default_texture_filter=0\nrenderer/rendering_method=\"gl_compatibility\"\n```\n\n**Stretch mode = disabled** ensures that window resizing reveals more of the game field rather than scaling sprites, per the Visual GDD requirement.",
      "priority": "high",
      "dependencies": [
        4,
        12,
        21
      ],
      "status": "pending"
    },
    {
      "id": 23,
      "title": "Import Antonio Player Sprite with Animations",
      "description": "Import the Antonio character sprite sheet, create SpriteFrames resource with idle and walk animations, and set up the AnimatedSprite2D in the Player scene with proper pixel-art settings.",
      "details": "Use the `import_sprite_sheet_animation` skill or manual import:\n\n1. **Locate source art:** Check `SourceArt/extracted_clean/` for Antonio character sprite or use placeholder.\n\n2. **Import settings (per VISUAL_RULES.md):**\n   - Compress Mode: Lossless\n   - Mipmaps Generate: OFF\n   - No texture filter override (inherit NEAREST from project)\n\n3. **Create SpriteFrames resource:**\n   - res://assets/sprites/antonio.tres (SpriteFrames)\n   - Animation \"idle\": 1-4 frames, 8 FPS, loop\n   - Animation \"walk\": 4-8 frames, 12 FPS, loop\n\n4. **Configure AnimatedSprite2D in PlayerShell:**\n   - Assign sprite_frames = antonio.tres\n   - centered = true\n   - texture_filter = inherited (NEAREST)\n\n5. **Target on-screen size:** ~50×62 px at camera zoom 2, so native sprite should be ~25×31 px.\n\nIf no Antonio sprite exists, create a simple colored rectangle placeholder that matches the size requirements.",
      "priority": "medium",
      "dependencies": [
        16
      ],
      "status": "pending"
    },
    {
      "id": 24,
      "title": "Import Enemy Sprites and Configure ViewSync",
      "description": "Import sprite sheets for the Mad Forest enemy roster (Zombie, Skeleton, Ghost, etc.), create SpriteFrames resources, and wire them into ViewSync's enemy sprite pool via GameDatabase lookups.",
      "details": "1. **Enemy roster to import:**\n   - Zombie, Skeleton, Ghost, Mudman, Werewolf, Giant Bat, Big Mummy\n   - Bosses: Glowing Bat, Silver Bat, Giant Werewolf, Giant Mummy, Giant Blue Venus\n   - The Reaper\n\n2. **For each enemy, create SpriteFrames:**\n   - res://assets/sprites/enemies/<enemy_name>.tres\n   - Walk animation (or idle for static enemies)\n   - Import with Lossless, no mipmaps, NEAREST inherited\n\n3. **Update GameDatabase with visual references:**\n```gdscript\nconst ENEMIES := {\n    &\"zombie\": { \n        hp = 10, power = 10, move_speed = 100, xp = 1, ai = \"homing\",\n        sprite_frames = preload(\"res://assets/sprites/enemies/zombie.tres\")\n    },\n    # ...\n}\n```\n\n4. **Update ViewSync.sync_enemies():**\n```gdscript\nfunc sync_enemies(enemies: EnemyPool) -> void:\n    for i in range(mini(enemy_sprites.size(), enemies.CAPACITY)):\n        var sprite := enemy_sprites[i]\n        if enemies.alive[i]:\n            sprite.visible = true\n            sprite.position = enemies.pos[i]\n            \n            # Get SpriteFrames from database\n            var def := game_db.enemy(enemies.type_id[i])\n            if sprite.sprite_frames != def.sprite_frames:\n                sprite.sprite_frames = def.sprite_frames\n                sprite.play(\"walk\")\n```\n\n5. **Placeholder option:** Use colored rectangles of varying sizes if sprites not available.",
      "priority": "medium",
      "dependencies": [
        4,
        15,
        23
      ],
      "status": "pending"
    },
    {
      "id": 25,
      "title": "Import Pickup and Projectile Sprites",
      "description": "Import sprites for XP gems (blue/green/red tiers), gold coins, chicken, consumable items, and weapon projectiles, wiring them into ViewSync.",
      "details": "1. **Pickup sprites needed:**\n   - XP Gems: blue (~20×20), green (~20×20), red (~20×20) - different colors/sizes\n   - Gold: coin, coin bag, rich coin bag\n   - Consumables: Floor Chicken, Rosary, Orologion, Vacuum, Nduja, Rerollo\n   - Treasure Chest\n\n2. **Projectile sprites needed:**\n   - Whip slash arc\n   - Knife\n   - Magic Wand bolt\n   - Runetracer orb\n   - Garlic aura circle\n   - King Bible book\n   - Fire Wand fireball\n   - Lightning Ring strike\n\n3. **Create resources:**\n   - res://assets/sprites/pickups/ - individual Texture2D or SpriteFrames\n   - res://assets/sprites/projectiles/ - per weapon\n\n4. **Wire into GameDatabase:**\n```gdscript\nconst PICKUP_SPRITES := {\n    \"gem_blue\": preload(\"res://assets/sprites/pickups/gem_blue.png\"),\n    \"gem_green\": preload(\"res://assets/sprites/pickups/gem_green.png\"),\n    \"gem_red\": preload(\"res://assets/sprites/pickups/gem_red.png\"),\n    # ...\n}\n\nconst WEAPON_SPRITES := {\n    &\"whip\": preload(\"res://assets/sprites/projectiles/whip_slash.png\"),\n    # ...\n}\n```\n\n5. **Update ViewSync.sync_pickups() and sync_projectiles()** to use the appropriate sprites based on kind/type_id.",
      "priority": "medium",
      "dependencies": [
        15,
        24
      ],
      "status": "pending"
    },
    {
      "id": 26,
      "title": "Create Ground Tileset and Mad Forest Background",
      "description": "Set up the Mad Forest ground layer with tiled grass texture, ensuring pixel-perfect rendering and effectively infinite scrolling as the player moves.",
      "details": "**Option A: Large tiled Sprite2D (simpler)**\n```gdscript\n# GroundLayer as Sprite2D\nvar grass_texture: Texture2D = preload(\"res://assets/sprites/ground/grass_tile.png\")\n\nfunc _ready():\n    texture = grass_texture\n    texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED\n    region_enabled = true\n    region_rect = Rect2(0, 0, 4096, 4096)  # Large tiled area\n    \n    # Center on origin\n    position = Vector2(-2048, -2048)\n```\n\n**Option B: TileMapLayer (more control)**\n1. Create TileSet resource with grass tile\n2. Use TileMapLayer node\n3. Procedurally fill tiles around player position\n\n**Option C: ParallaxBackground**\n1. Use ParallaxBackground with ParallaxLayer\n2. Set motion_mirroring for seamless tiling\n\n**Requirements:**\n- Grass texture from SourceArt or placeholder green\n- NEAREST filtering (inherited)\n- No visible seams when player moves\n- Performance: don't render tiles far off-screen",
      "priority": "low",
      "dependencies": [
        16
      ],
      "status": "pending"
    },
    {
      "id": 27,
      "title": "Populate GameDatabase with Complete Mad Forest Wave Table",
      "description": "Transcribe the verbatim per-minute Mad Forest spawn table from the wiki into GameDatabase, including enemy types, counts, intervals, events, and boss spawns for all 30 minutes.",
      "details": "**Reference:** `.firecrawl/wiki-offline/` for exact Mad Forest wave data.\n\n**GameDatabase MAD_FOREST_WAVES array structure:**\n```gdscript\nconst MAD_FOREST_WAVES := [\n    # Minute 0\n    {\n        enemies = [&\"zombie\"],\n        base_count = 15,\n        interval = 1.0,\n        events = [],\n        boss = null\n    },\n    # Minute 1\n    {\n        enemies = [&\"zombie\", &\"skeleton\"],\n        base_count = 20,\n        interval = 0.9,\n        events = [],\n        boss = &\"glowing_bat\"\n    },\n    # Minute 2\n    {\n        enemies = [&\"zombie\", &\"skeleton\", &\"ghost\"],\n        base_count = 25,\n        interval = 0.8,\n        events = [{time = 120, type = \"bat_swarm\"}],\n        boss = null\n    },\n    # ... continue for all 30 minutes\n    # Include:\n    # - Bat Swarm events\n    # - Ghost Swarm events  \n    # - Flower Wall events\n    # - Boss spawn times (Giant Werewolf, Giant Bat, Big Mummy, etc.)\n    # - Enemy roster progression\n    # - Spawn interval tightening\n    # - Count escalation toward 300 periodic cap\n]\n\nconst MAD_FOREST_EVENTS := {\n    \"bat_swarm\": { enemy = &\"pippistrello\", count = 50, ai = \"fixed_direction\" },\n    \"ghost_swarm\": { enemy = &\"ghost\", count = 30, ai = \"fixed_direction\" },\n    \"flower_wall\": { enemy = &\"venus\", count = 20, formation = \"line\" },\n}\n```\n\n**SpawnDirector integration:**\n- Read wave[minute] for current spawn parameters\n- Check events array against elapsed time\n- Spawn boss when boss field is non-null and minute transitions",
      "priority": "medium",
      "dependencies": [
        4
      ],
      "status": "pending"
    },
    {
      "id": 28,
      "title": "Populate GameDatabase with Complete Weapon Definitions",
      "description": "Transcribe the verbatim weapon stats and per-level upgrade curves for all 8 slice weapons from the wiki into GameDatabase.",
      "details": "**Reference:** `.firecrawl/wiki-offline/` for exact weapon stats.\n\n**Complete WEAPONS dictionary:**\n```gdscript\nconst WEAPONS := {\n    &\"whip\": {\n        name = \"Whip\",\n        description = \"Attacks horizontally, passes through enemies.\",\n        base_dmg = 10.0,\n        cooldown = 1.35,\n        amount = 1,\n        pattern = \"slash\",\n        pierce = 999,  # Infinite\n        area = 1.0,\n        speed = 1.0,\n        duration = 0.3,\n        crit_chance = 0.0,\n        crit_mult = 1.0,\n        # Per-level upgrades (level 2-8)\n        levels = [\n            {},  # Level 1 = base\n            { dmg = 2.5 },  # Level 2\n            { area = 0.1 },  # Level 3\n            { dmg = 2.5 },  # Level 4\n            { area = 0.1 },  # Level 5\n            { dmg = 2.5 },  # Level 6\n            { area = 0.1 },  # Level 7\n            { dmg = 2.5, area = 0.1 }  # Level 8\n        ]\n    },\n    &\"knife\": {\n        name = \"Knife\",\n        description = \"Fires quickly in the faced direction.\",\n        base_dmg = 6.5,\n        cooldown = 1.0,\n        amount = 1,\n        pattern = \"directional\",\n        pierce = 1,\n        # ... full level curve\n    },\n    # Complete all 8: whip, knife, magic_wand, runetracer, garlic, king_bible, fire_wand, lightning_ring\n}\n\nstatic func weapon(id: StringName) -> Dictionary:\n    return WEAPONS.get(id, {})\n\nstatic func weapon_stat_at_level(id: StringName, level: int, stat: String) -> float:\n    var def := weapon(id)\n    var value: float = def.get(stat, 0.0)\n    for i in range(1, mini(level, def.levels.size())):\n        value += def.levels[i].get(stat, 0.0)\n    return value\n```",
      "priority": "medium",
      "dependencies": [
        4
      ],
      "status": "pending"
    },
    {
      "id": 29,
      "title": "Populate GameDatabase with Complete Passive Definitions",
      "description": "Transcribe the verbatim passive item stats and per-level values for all 8 slice passives from the wiki into GameDatabase.",
      "details": "**Complete PASSIVES dictionary:**\n```gdscript\nconst PASSIVES := {\n    &\"spinach\": {\n        name = \"Spinach\",\n        description = \"Raises inflicted damage by 10%.\",\n        stat = \"might\",\n        per_level = 0.10,  # +10% per level\n        max_level = 5,\n        levels = [0.10, 0.20, 0.30, 0.40, 0.50]  # Cumulative at each level\n    },\n    &\"armor\": {\n        name = \"Armor\",\n        description = \"Reduces incoming damage by 1. Increases retaliatory damage.\",\n        stat = \"armor\",\n        per_level = 1.0,  # +1 armor per level\n        max_level = 5,\n        retaliatory = true,  # Special flag for armor retaliation\n        levels = [1, 2, 3, 4, 5]\n    },\n    &\"hollow_heart\": {\n        name = \"Hollow Heart\",\n        description = \"Augments max health by 20%.\",\n        stat = \"max_health\",\n        per_level = 0.20,  # +20% per level (multiplicative)\n        max_level = 5,\n        multiplicative = true,\n        levels = [1.20, 1.44, 1.73, 2.07, 2.49]  # 1.2^n\n    },\n    &\"empty_tome\": {\n        name = \"Empty Tome\",\n        description = \"Reduces weapons cooldown by 8%.\",\n        stat = \"cooldown\",\n        per_level = -0.08,  # -8% per level\n        max_level = 5,\n        levels = [-0.08, -0.16, -0.24, -0.32, -0.40]\n    },\n    &\"candelabrador\": {\n        name = \"Candelabrador\",\n        description = \"Augments area of attacks by 10%.\",\n        stat = \"area\",\n        per_level = 0.10,\n        max_level = 5,\n        levels = [0.10, 0.20, 0.30, 0.40, 0.50]\n    },\n    &\"bracer\": {\n        name = \"Bracer\", \n        description = \"Increases projectile speed by 10%.\",\n        stat = \"speed\",\n        per_level = 0.10,\n        max_level = 5,\n        levels = [0.10, 0.20, 0.30, 0.40, 0.50]\n    },\n    &\"wings\": {\n        name = \"Wings\",\n        description = \"Character moves 10% faster.\",\n        stat = \"move_speed\",\n        per_level = 0.10,\n        max_level = 5,\n        levels = [0.10, 0.20, 0.30, 0.40, 0.50]\n    },\n    &\"duplicator\": {\n        name = \"Duplicator\",\n        description = \"Weapons fire more projectiles.\",\n        stat = \"amount\",\n        per_level = 1,  # +1 projectile per level\n        max_level = 2,\n        levels = [1, 2]\n    }\n}\n```",
      "priority": "medium",
      "dependencies": [
        4
      ],
      "status": "pending"
    },
    {
      "id": 30,
      "title": "Implement Complete XP Curve in GameDatabase",
      "description": "Implement the exact VS XP curve formula: base 5, +10/level through L20, +13/level L21-40, +16/level L41+, with lump additions at L20 (+600) and L40 (+2400).",
      "details": "**res://autoload/game_database.gd xp_to_next function:**\n```gdscript\nstatic func xp_to_next(level: int) -> float:\n    # Base XP to reach level 2 is 5\n    # Each subsequent level adds:\n    # - +10 XP per level through L20\n    # - +13 XP per level L21-40\n    # - +16 XP per level L41+\n    # Plus lump sums: +600 at L20, +2400 at L40\n    \n    if level < 1:\n        return 5.0\n    \n    var xp: float = 5.0  # Base for level 1->2\n    \n    for l in range(2, level + 1):\n        if l <= 20:\n            xp += 10.0\n        elif l <= 40:\n            xp += 13.0\n        else:\n            xp += 16.0\n        \n        # Lump additions\n        if l == 20:\n            xp += 600.0\n        elif l == 40:\n            xp += 2400.0\n    \n    return xp\n\n# Precomputed table for efficiency (optional)\nconst XP_TABLE := [\n    5,    # L1->L2\n    15,   # L2->L3 (5+10)\n    25,   # L3->L4\n    35,   # L4->L5\n    # ... precompute all levels\n]\n\nstatic func xp_to_next_fast(level: int) -> float:\n    if level < XP_TABLE.size():\n        return float(XP_TABLE[level])\n    return xp_to_next(level)  # Fallback for high levels\n```\n\n**Verification points:**\n- L1→L2: 5 XP\n- L10: ~405 XP cumulative\n- L20: ~1,805 XP cumulative (includes +600 lump)\n- L40: ~6,000+ XP cumulative (includes +2400 lump)",
      "priority": "medium",
      "dependencies": [
        4
      ],
      "status": "pending"
    },
    {
      "id": 31,
      "title": "Implement Chest and Drop Tables in GameDatabase",
      "description": "Add chest roll tables (1/3/5 item counts with luck scaling), brazier drop tables (pickup probabilities), and gem tier thresholds to GameDatabase.",
      "details": "**res://autoload/game_database.gd additions:**\n```gdscript\n# Gem tier thresholds by XP value\nconst GEM_TIERS := {\n    \"blue\": { max_xp = 2 },   # XP <= 2\n    \"green\": { max_xp = 9 },  # 2 < XP <= 9\n    \"red\": { min_xp = 9 }     # XP > 9\n}\n\nstatic func gem_tier_for_xp(xp: float) -> int:\n    if xp <= 2: return 0  # Blue\n    if xp <= 9: return 1  # Green\n    return 2  # Red\n\n# Chest item count probabilities (before luck)\nconst CHEST_TIERS := {\n    5: 0.10,  # 10% chance for 5 items\n    3: 0.30,  # 30% chance for 3 items\n    1: 0.60   # 60% chance for 1 item\n}\n\n# Beginner's luck sequence for first 6 chests\nconst BEGINNER_CHEST_SEQUENCE := [1, 1, 3, 1, 1, 5]\n\n# Gold amounts per chest tier\nconst CHEST_GOLD := {\n    1: { min = 100, max = 200 },\n    3: { min = 300, max = 600 },\n    5: { min = 500, max = 1000 }\n}\n\n# Brazier drop table (weighted probabilities)\nconst BRAZIER_DROPS := {\n    &\"gem_blue\": 0.40,\n    &\"gem_green\": 0.25,\n    &\"gold_coin\": 0.15,\n    &\"chicken\": 0.05,\n    &\"rosary\": 0.02,\n    &\"orologion\": 0.02,\n    &\"vacuum\": 0.03,\n    &\"nduja\": 0.02,\n    &\"rerollo\": 0.02,\n    &\"nothing\": 0.04\n}\n\nstatic func roll_brazier_drop(rng: RandomNumberGenerator, luck: float) -> StringName:\n    # Apply luck weighting and roll\n    var roll := rng.randf()\n    var cumulative := 0.0\n    for drop_id in BRAZIER_DROPS:\n        cumulative += BRAZIER_DROPS[drop_id]\n        if roll <= cumulative:\n            return drop_id\n    return &\"nothing\"\n```",
      "priority": "low",
      "dependencies": [
        4
      ],
      "status": "pending"
    },
    {
      "id": 32,
      "title": "Integration Testing: Full Run Loop Validation",
      "description": "Manually play through a complete 30-minute run to verify all systems work together: spawning, combat, leveling, pickups, UI transitions, and the Reaper ending.",
      "details": "**Validation checklist:**\n\n1. **Boot & Menu:**\n   - [ ] Game launches to main menu\n   - [ ] Start button loads run scene\n   - [ ] Quit button exits\n\n2. **Core Gameplay (0-5 min):**\n   - [ ] Player moves 8-directionally with WASD/Arrows\n   - [ ] Whip auto-fires in facing direction\n   - [ ] Enemies spawn off-screen and home toward player\n   - [ ] Contact damage works with i-frames\n   - [ ] Enemies die and drop XP gems\n   - [ ] Gems magnetize within radius\n   - [ ] Gems collect on overlap\n   - [ ] XP bar fills, level-up triggers\n\n3. **Level-Up System:**\n   - [ ] Game pauses on level-up\n   - [ ] 3-4 options appear\n   - [ ] Selecting option grants weapon/passive\n   - [ ] Stats update correctly\n   - [ ] Game resumes after selection\n   - [ ] Multiple queued level-ups work\n\n4. **Weapons (5-15 min):**\n   - [ ] All 8 weapons fire correctly\n   - [ ] Weapon upgrades increase stats\n   - [ ] Amount/Area/Speed/Cooldown scale properly\n\n5. **Pickups & Consumables:**\n   - [ ] Chicken heals\n   - [ ] Gold increments counter\n   - [ ] Rosary screen-clears\n   - [ ] Orologion freezes enemies\n   - [ ] Vacuum pulls all gems\n   - [ ] Rerollo adds reroll charge\n\n6. **Bosses & Chests (10-25 min):**\n   - [ ] Bosses spawn on schedule\n   - [ ] Boss drops treasure chest\n   - [ ] Chest auto-applies items\n\n7. **Escalation (25-30 min):**\n   - [ ] Enemy count reaches 300+ cap\n   - [ ] Frame rate stays stable\n   - [ ] HUD timer shows correct time\n\n8. **Endgame (30:00):**\n   - [ ] Field clears at 30:00\n   - [ ] Reaper spawns\n   - [ ] Reaper is unkillable\n   - [ ] Death triggers game over screen\n   - [ ] Results show correct stats\n   - [ ] Restart works\n   - [ ] Menu return works\n\n9. **Pause:**\n   - [ ] ESC pauses/unpauses\n   - [ ] Pause shows build\n   - [ ] Resume continues correctly",
      "priority": "high",
      "dependencies": [
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        10,
        11,
        12,
        13,
        14,
        15,
        16,
        17,
        18,
        19,
        20,
        22
      ],
      "status": "pending"
    }
  ],
  "metadata": {
    "projectName": "Vampire Survivors Godot Clone - First Playable Vertical Slice",
    "totalTasks": 32,
    "sourceFile": ".taskmaster/docs/systems.md (Systems Architecture Document)",
    "generatedAt": "2026-06-29"
  }
}
```
