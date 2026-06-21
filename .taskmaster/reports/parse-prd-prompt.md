# parse-prd Prompt Trace

## Metadata
- **timestamp:** 2026-06-21T05:51:51.690Z
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
## IMPORTANT: Codebase Analysis Required

You have access to powerful codebase analysis tools. Before generating tasks:

1. Use the Glob tool to explore the project structure (e.g., "**/*.js", "**/*.json", "**/README.md")
2. Use the Grep tool to search for existing implementations, patterns, and technologies
3. Use the Read tool to examine key files like package.json, README.md, and main entry points
4. Analyze the current state of implementation to understand what already exists

Based on your analysis:
- Identify what components/features are already implemented
- Understand the technology stack, frameworks, and patterns in use
- Generate tasks that build upon the existing codebase rather than duplicating work
- Ensure tasks align with the project's current architecture and conventions

Project Root: C:\GameDev\VampireSurvivorsGodot

Here's the Product Requirements Document (PRD) to break down into an appropriate number of tasks, starting IDs from 1:

# Game Systems Architecture: Vampire Survivors — Vertical Slice (Godot Recreation)

## Source
Derived from `thoughts/shared/game-design/2026-06-21-ENG-vampire-survivors-vertical-slice.md` — a faithful Godot 4 recreation of a single Vampire Survivors run: control Antonio on the Mad Forest stage, move only (weapons auto-fire), collect XP gems to level up and stack weapon/passive upgrades, and survive a 30-minute escalating horde that ends when The Reaper arrives at 30:00.

> **Project location note:** the Godot 4.6 project lives in `vampire-survivors-taskmaster/` (run `godot --path vampire-survivors-taskmaster`). The skill's reference to `snaketaskmaster/` is stale. All `res://` paths below resolve inside `vampire-survivors-taskmaster/`. The project is currently empty (icon only), uses the **GL Compatibility** renderer, and has **no gdUnit4 addon installed yet** — installing gdUnit4 is a setup prerequisite for the `res://test/` modules described here.

## Architecture Philosophy
All game logic lives in **pure, stateless GDScript modules** (`static func`s) that operate on a small number of explicit plain-data objects (`RefCounted`) passed **by reference and mutated in place**. The Godot scene tree is a thin shell: a single `RunController` node owns the `GameState`, gathers input, and calls the pure systems in a fixed order each physics tick; presentation/UI nodes only *read* state to render. Because the logic never touches `get_node`, input polling, or rendering, every system is unit-testable headlessly with gdUnit4. Static game numbers (weapon curves, enemy stats, the Mad Forest wave script) live in an immutable **data layer** authored from the offline wiki, separate from the mutable runtime state.

## Technical Challenges & Considerations

- **Performance at scale (the stated main risk).** The design demands 500 enemies (hard cap) plus hundreds of projectiles and up to 400 gems at 60 FPS. **Decision: do not back entities with `Area2D`/physics bodies.** Enemies, projectiles, gems, pickups, chests, light sources, and damage zones are plain data records in flat arrays; all overlap detection is done by a pure **uniform spatial-hash grid** (`SpatialIndex`) rebuilt each tick. Rationale: per-entity physics nodes + signal callbacks at this volume are the actual bottleneck and would couple logic to the scene tree (untestable); a data-driven hash is faster, deterministic, and headless-testable. Rendering uses a **pooled-sprite presentation layer** (one reused `Sprite2D` per active entity) synced from the arrays each frame; `MultiMeshInstance2D` (one draw call per entity type, per-instance color) is the documented escalation path if node count profiles as the limit.

- **Timing & update model.** Movement, cooldowns, the 30:00 timer, i-frames, and spawn intervals must be frame-rate independent. **Decision:** the pure `step(state, dt)` pipeline is authoritative and is driven from `RunController._physics_process(delta)` at Godot's fixed 60 Hz physics tick. Every timer is a float accumulator in `GameState`/`PlayerState` advanced by `dt`. `_process` is used only for presentation interpolation/juice, never for simulation. No custom accumulator is needed — the fixed physics step already provides a stable `dt`.

- **Coordinate systems.** One world space in pixels; the map is effectively boundless with no walls, so the player has no world-collision to resolve — only data-driven contact checks. A `Camera2D` centered on the player; the native low-res canvas is upscaled to 1080p via the project's stretch settings. The tiled field is a camera-following wrapping background (shader-tiled `ColorRect`/`TextureRect`), not real geometry.

- **State representation.** A single `GameState` `RefCounted` holds the whole run: a clock, the `PlayerState`, typed arrays per entity category, the `SpatialIndex`, the seeded RNG, score counters, the spawn/event director cursors, and a queue of pending level-ups. Systems receive `GameState` and mutate it; nothing else owns run state.

- **Determinism & RNG.** Crits, drop rolls, the level-up 3rd/4th-option choice, chest item counts, and spawn jitter all need randomness. **Decision:** one seeded `RandomNumberGenerator` lives in `GameState` and is passed into the pure systems, so a given seed + input trace reproduces a run exactly — essential for unit tests. The "beginner's luck" `1-1-3-1-1-5` chest sequence and the L20/L40 XP specials are deterministic table lookups, not RNG.

- **Static data, not wiki parsing.** The wiki pages under `.firecrawl/wiki-offline/` are messy HTML-dump markdown (human reference only). **Decision:** transcribe the needed numbers once into a typed data layer (`WeaponDef`, `EnemyDef`, `PassiveDef`, `StageDef`/wave script, level curve, pickup table, `CharacterDef`) as Godot `Resource`s or `const` tables exposed by a `GameData` autoload. The runtime never reads the wiki.

- **Collision / overlap detection.** All of it (projectile→enemy, zone→enemy, enemy→player contact, gem/pickup→magnet, weapon targeting "nearest/random enemy") is a `SpatialIndex` radius/point query over the arrays. No physics engine involvement (the project's Jolt setting is for 3D and is irrelevant here).

- **Spawning / lifecycle & pooling.** The `SpawnDirector` tops up enemies toward the per-minute minimum at the wave interval, scaled by Curse, around an off-screen ring near the player; it enforces the 300-alive (periodic-spawn halt) and 500-alive (hard) caps, runs map events and bosses, and at 30:00 clears the board and spawns The Reaper (+1/min). Entity creation/destruction is array append + swap-remove; the **presentation** layer pools the visual nodes (the GDD's pooling requirement applies to the engine-facing render shells, not the data records).

- **Game state machine.** Screen/flow states (title, playing, paused, level-up modal, game over, results) gate whether the sim ticks. Owned by `RunController`; the sim simply isn't stepped unless the phase is `PLAYING`.

- **Persistence.** None — explicitly out of scope. Gold is an in-`GameState` score counter, never written to `user://`. No mid-run save.

- **Edge cases the rules create.** First frame (10 starting spawns); simultaneous multi-level-ups from one gem (queue and present sequentially); the 400-gem cap (no new gems, surplus XP funnels into one red gem); 300/500 enemy caps; full inventory (6 weapons + 6 passives → level-ups grant gold/chicken; all-maxed chests → coin bags); knockback-resistant bosses; armor flooring damage at 1; i-frame gating of contact damage and the brief i-frames granted on level-up resume; Reaper's 65,535 one-shot vs. a held Revival.

## Shared Data Model
All are mutable `RefCounted` plain-data containers (the run "state"), distinct from the immutable data-layer `Resource`s in **File / Module Layout**.

### GameState
- **Purpose:** the entire mutable state of one run; the single object threaded through every system.
- **Fields:** `time_elapsed: float` (sim seconds) — `current_minute: int` — `phase: int` (enum) — `rng: RandomNumberGenerator` — `player: PlayerState` — `enemies: Array[Enemy]` — `projectiles: Array[Projectile]` — `zones: Array[DamageZone]` — `gems: Array[Gem]` — `pickups: Array[Pickup]` — `chests: Array[Chest]` — `light_sources: Array[LightSource]` — `index: SpatialIndex` — `spawn_cursor` / `event_cursor` / `chest_count` (director progress) — `kills: int` — `gold: int` — `pending_levelups: int` — `current_offer: LevelUpOffer` — `global_effects` (orologion freeze timer, breath timer, temp-growth timer).
- **Lifecycle:** created by `RunController` on run start; mutated by every system each tick; discarded (and recreated) on restart.

### PlayerState
- **Purpose:** Antonio's runtime state.
- **Fields:** `pos: Vector2` — `facing: Vector2` (last nonzero move dir; default right) — `velocity: Vector2` — `hp: float` — `level: int` — `xp: float` — `xp_to_next: float` — `iframe_timer: float` — `revivals: int` — `weapons: Array[WeaponInstance]` (≤6) — `passives: Array[PassiveInstance]` (≤6) — `stats: StatBlock` — `derived: ResolvedStats` (cache).
- **Lifecycle:** created from `CharacterDef` (Antonio) at run start; mutated by Movement, Health, Progression, Pickup, Stat systems.

### StatBlock / ResolvedStats
- **Purpose:** `StatBlock` holds the accumulated raw modifiers from passives/character; `ResolvedStats` is the per-tick computed effective values (with caps applied) consumed by other systems.
- **Fields (the 17 stats):** might, area, cooldown, amount, duration, speed, move_speed, max_health, recovery, armor, magnet, luck, growth, greed, curse, revival — plus cap metadata. `ResolvedStats` exposes the same as final multipliers/values.
- **Lifecycle:** `StatBlock` mutated when an item is added/upgraded; `ResolvedStats` recomputed by `StatSystem` at the top of each tick.

### Enemy
- **Purpose:** one alive monster.
- **Fields:** `def: EnemyDef` — `pos: Vector2` — `velocity: Vector2` — `hp: float` — `knockback: Vector2` + `knockback_timer: float` — `freeze_timer: float` — `flags` (is_boss, fixed_direction, floaty) — `hit_cooldowns` (per-source, for per-hit-delay weapons like Garlic).
- **Lifecycle:** created by `SpawnDirector`; mutated by Movement/Combat; on death → Combat spawns a `Gem` (+ optional drop / chest if boss) and swap-removes it.

### Projectile
- **Purpose:** a moving weapon emission with finite pierce.
- **Fields:** `source_weapon: WeaponInstance` — `pos`/`velocity: Vector2` — `damage: float` — `crit_mult: float` + `crit_chance: float` — `pierce_left: int` — `lifetime: float` — `bounces_left: int` (Runetracer) — `hit_ids: PackedInt64Array` (already-hit enemies) — `pattern` flags (boomerang/return for Cross).
- **Lifecycle:** created by `WeaponSystem`; moved/resolved by `CombatSystem`; removed on pierce/lifetime/bounce exhaustion.

### DamageZone
- **Purpose:** an AoE source: Garlic aura, King Bible orbiters, Santa Water puddles, Lightning strikes, Peachone/Ebony bombards.
- **Fields:** `source_weapon` — `anchor` (`FOLLOW_PLAYER` | `WORLD` | `ORBIT`) — `pos`/`offset`/`angle`/`radius: float` — `damage: float` — `tick_interval` + `tick_timer: float` — `lifetime: float` — `hit_ids` with per-tick reset.
- **Lifecycle:** created by `WeaponSystem`; updated/resolved by `CombatSystem`; removed on lifetime end.

### Gem / Pickup / Chest / LightSource
- **Gem:** `pos`, `xp: float`, `tier` (blue/green/red); created on enemy death; magnetized & collected by `PickupSystem`.
- **Pickup:** `pos`, `type` (chicken, coin variants, vacuum, rosary, orologion, nduja/sorbetto, clover…), `value`; from drops/braziers; collected by `PickupSystem`.
- **Chest:** `pos`, `rolled_count` (resolved on open); dropped by bosses; opened by `PickupSystem`→`ProgressionSystem`.
- **LightSource:** `pos`, `hp` (10); spawned by `SpawnDirector`; damaged by `CombatSystem`; on break drops from the weighted pool.

### WeaponInstance / PassiveInstance
- **WeaponInstance:** `def: WeaponDef`, `level: int` (1–8), `cooldown_timer: float`, per-weapon scratch (e.g. Whip side alternation, Pentagram 90s timer).
- **PassiveInstance:** `def: PassiveDef`, `level: int`, `stacks`.
- **Lifecycle:** created/leveled by `ProgressionSystem`; weapon timers ticked by `WeaponSystem`.

### LevelUpOffer
- **Purpose:** the 3–4 options presented on a level-up.
- **Fields:** `options: Array` of `{kind, def, is_upgrade, target_level}`; `is_max_state` flags for full inventory display.
- **Lifecycle:** built by `ProgressionSystem` when a level-up fires; consumed when the player chooses; cleared on resume.

## Systems

### StatSystem
- **Goal:** compute Antonio's effective stats each tick from base + passives + character growth + stage modifiers + temporary buffs, applying caps.
- **Type:** pure/stateless logic
- **Inputs:** `PlayerState` (stats, level, inventory), `StageDef` modifiers, `global_effects`.
- **Outputs / mutations:** writes `player.derived: ResolvedStats`.
- **Key functions:** `static func resolve(player: PlayerState, stage: StageDef) -> void` ; `static func recompute_block(player: PlayerState) -> void` (called when an item changes).
- **Dependencies:** reads `PassiveDef`/`CharacterDef`; touches `PlayerState`.
- **Godot 4 mapping:** none — pure module.

### MovementSystem
- **Goal:** advance player and enemy positions for the tick.
- **Type:** pure/stateless logic
- **Inputs:** input vector, `dt`, `GameState` (player + enemies), resolved move speed, freeze/knockback timers.
- **Outputs / mutations:** updates `player.pos`/`facing`; each `enemy.pos`/`velocity` (homing toward player, fixed-direction for swarms, floaty sine offset); decays knockback/freeze.
- **Key functions:** `static func step_player(player: PlayerState, input_dir: Vector2, dt: float) -> void` ; `static func step_enemies(state: GameState, dt: float) -> void`.
- **Dependencies:** `StatSystem` (move speed); `PlayerState`, `Enemy`.
- **Godot 4 mapping:** none — pure module.

### SpatialIndex
- **Goal:** the collision backbone — bucket entities into a uniform grid and answer radius/nearest/point queries without physics nodes.
- **Type:** pure/stateless logic (a small data structure + query functions; the grid buckets live on `GameState` and are rebuilt, holding no cross-tick state of their own).
- **Inputs:** entity arrays, cell size.
- **Outputs / mutations:** rebuilds its bucket map; returns index lists.
- **Key functions:** `static func rebuild(index: SpatialIndex, enemies: Array, gems: Array, pickups: Array) -> void` ; `static func query_radius(index, center: Vector2, r: float) -> PackedInt32Array` ; `static func nearest_enemy(index, from: Vector2) -> int` ; `static func random_enemy(index, rng) -> int`.
- **Dependencies:** none (consumed by Weapon, Combat, Pickup, Health systems).
- **Godot 4 mapping:** none — pure module.

### WeaponSystem
- **Goal:** tick each owned weapon's cooldown and, when ready, emit projectiles/zones per its pattern using resolved stats and targeting.
- **Type:** pure/stateless logic
- **Inputs:** `GameState` (player weapons, `SpatialIndex` for targeting, `rng`), `dt`, resolved stats (cooldown/amount/area/speed/duration/might).
- **Outputs / mutations:** decrements `cooldown_timer`s; appends to `state.projectiles` / `state.zones`; handles per-weapon patterns (Whip facing slash w/ side alternation, Magic Wand nearest, Knife/Axe facing, Cross boomerang, King Bible orbit, Fire/Lightning random, Garlic aura, Santa Water puddles, Runetracer bounce dir, Peachone/Ebony circling, Pentagram 90s wipe).
- **Key functions:** `static func step(state: GameState, dt: float) -> void` ; `static func cast(state, weapon: WeaponInstance) -> void`.
- **Dependencies:** `StatSystem`, `SpatialIndex`; reads `WeaponDef`.
- **Godot 4 mapping:** none — pure module.

### CombatSystem
- **Goal:** move and resolve everything weapons emit — projectiles and damage zones — against enemies, applying damage, crits, knockback, pierce, and enemy death/drops; also damage light sources.
- **Type:** pure/stateless logic
- **Inputs:** `GameState` (projectiles, zones, enemies, light_sources, `SpatialIndex`, `rng`), `dt`, resolved Might.
- **Outputs / mutations:** moves projectiles/zones; via `SpatialIndex` finds enemies in contact/area; applies `damage = baseDamage × Might` with crit roll (per crit-capable weapon) and knockback (boss-resisted); decrements pierce/lifetime; on enemy `hp ≤ 0` spawns a `Gem` (+ rolls a drop, + boss chest) and swap-removes the enemy; breaks light sources → drop.
- **Key functions:** `static func step(state: GameState, dt: float) -> void` ; helper `static func apply_hit(state, enemy: Enemy, dmg: float, crit: bool, kb: Vector2) -> void`. Damage/crit/knockback math lives in `CombatMath` (pure util) shared with this module.
- **Dependencies:** `SpatialIndex`, `StatSystem`, `CombatMath`; mutates `Enemy`, `Projectile`, `DamageZone`, `Gem`, `Chest`, `Pickup`, `LightSource`.
- **Godot 4 mapping:** none — pure module.

### SpawnDirector
- **Goal:** own every timed appearance — per-minute waves with min-alive top-ups, bosses, map events (Bat/Ghost Swarm, Flower Wall), brazier light sources, caps, and the 30:00 Reaper (+1/min).
- **Type:** pure/stateless logic
- **Inputs:** `GameState` (clock, enemies, director cursors, `rng`), `StageDef`/wave script, Curse from resolved stats, `dt`.
- **Outputs / mutations:** advances `time_elapsed`/`current_minute`; appends enemies around an off-screen ring near the player at `effectiveInterval = baseInterval / curse` until min-alive; spawns bosses/events/braziers per the script; enforces 300 (periodic halt) and 500 (hard) caps; at 30:00 clears non-immune enemies and spawns The Reaper, then +1 each subsequent minute.
- **Key functions:** `static func step(state: GameState, dt: float) -> void` ; `static func spawn_wave_topup(state, wave) -> void` ; `static func run_events(state) -> void` ; `static func spawn_reaper(state) -> void`.
- **Dependencies:** `StatSystem` (Curse), `SpatialIndex` (placement); reads `StageDef`/`EnemyDef`; mutates `Enemy`/`LightSource` arrays.
- **Godot 4 mapping:** none — pure module.

### PickupSystem
- **Goal:** magnetize and collect gems/pickups, applying their effects.
- **Type:** pure/stateless logic
- **Inputs:** `GameState` (player, gems, pickups, chests, `SpatialIndex`), `dt`, resolved Magnet/Growth/Greed.
- **Outputs / mutations:** pulls gems within Magnet radius toward the player and collects on contact → routes XP (×Growth) to `ProgressionSystem`, gold (×Greed) to `state.gold`, chicken → heal, vacuum/rosary/orologion/breath/clover → `global_effects` or board mutation; enforces the 400-gem cap (merge surplus into one red gem); opens chests.
- **Key functions:** `static func step(state: GameState, dt: float) -> void`.
- **Dependencies:** `SpatialIndex`, `StatSystem`, `ProgressionSystem` (xp & chest application); mutates `Gem`/`Pickup`/`Chest`/`PlayerState`.
- **Godot 4 mapping:** none — pure module.

### ProgressionSystem
- **Goal:** XP/leveling, level-up offer generation and application, and chest resolution — everything that converts pickups into permanent power.
- **Type:** pure/stateless logic
- **Inputs:** `GameState` (player inventory, `rng`), level curve, resolved Luck; chosen option index from UI.
- **Outputs / mutations:** adds XP and crosses thresholds (L20 +600 / L40 +2400 specials + temp +100% Growth), enqueues `pending_levelups`; builds `LevelUpOffer` (3 options; 4th with chance `1 − 1/Luck`; respects 6/6 caps; full-inventory → gold/chicken); applies a choice (add item or +1 level); rolls chest contents (1/3/5 via beginner's-luck `1-1-3-1-1-5` then Luck-scaled L5→L3→L1, all-maxed → coins) and applies them.
- **Key functions:** `static func add_xp(state: GameState, amount: float) -> void` ; `static func build_offer(state: GameState) -> LevelUpOffer` ; `static func apply_choice(state: GameState, index: int) -> void` ; `static func open_chest(state: GameState, chest: Chest) -> void`.
- **Dependencies:** reads `LevelCurve`/`WeaponDef`/`PassiveDef`; mutates `PlayerState`/`GameState`; triggers `StatSystem.recompute_block` after item changes.
- **Godot 4 mapping:** none — pure module. (`RunController` flips `phase` to `LEVEL_UP` when `pending_levelups > 0`.)

### HealthSystem
- **Goal:** the player's damage intake and lifecycle — contact damage, i-frames, armor, recovery regen, death, and revival.
- **Type:** pure/stateless logic
- **Inputs:** `GameState` (player, enemies via `SpatialIndex`), `dt`, resolved Armor/Recovery/MaxHealth.
- **Outputs / mutations:** if `iframe_timer ≤ 0` and an enemy overlaps the player, applies `max(power − armor, 1)` and sets 240 ms i-frames; applies Recovery/s; on `hp ≤ 0`: if `revivals ≥ 1` consume one, restore 50% Max HP, grant burst i-frames; else set `phase = GAME_OVER`. Handles the Reaper one-shot through the same path.
- **Key functions:** `static func step(state: GameState, dt: float) -> void`.
- **Dependencies:** `SpatialIndex`, `StatSystem`; mutates `PlayerState`/`GameState.phase`.
- **Godot 4 mapping:** none — pure module.

### RunController (orchestrator shell)
- **Goal:** own `GameState` and the phase machine; gather input; call the pure systems in order; bridge sim ↔ UI/presentation.
- **Type:** stateful node shell
- **Inputs:** engine `_physics_process(delta)`, input map (WASD/arrows, pause).
- **Outputs / mutations:** builds/owns `GameState`; sets `phase`; emits signals to UI.
- **Key functions:** `func _physics_process(delta: float) -> void` (early-returns unless `PLAYING`); `func _on_option_chosen(i: int) -> void`; `func start_run() / restart()`.
- **Dependencies:** every pure system; `GameData` autoload.
- **Godot 4 mapping:** root script of `Main.tscn` (a `Node2D`). Emits `signal level_up_started(offer)`, `signal run_ended(summary)`, `signal phase_changed(phase)`.
- **State note:** holds `GameState` and the active phase because the engine event loop and scene transitions are inherently stateful; the *game logic* it calls remains pure — `GameState` is data, not behavior.

### PresentationLayer / EntityRenderer
- **Goal:** render the data arrays and the camera; add juice (hit flash, gem sparkle, magnet streaks, level-up flash).
- **Type:** stateful node shell
- **Inputs:** `GameState` (read-only), `_process` for smooth interpolation.
- **Outputs / mutations:** none to `GameState`; updates pooled `Sprite2D`s, camera, background.
- **Key functions:** `func sync(state: GameState) -> void`.
- **Godot 4 mapping:** `Node2D` with a pooled-sprite manager per entity category and a `Camera2D` following `player.pos`; background as a wrapping shader-tiled node. **Escalation:** swap pools for `MultiMeshInstance2D` if node count limits FPS.
- **State note:** owns the engine-side visual node pool (the GDD's pooling requirement); pure logic stays unaware of it.

### GameData (data service)
- **Goal:** load and expose the immutable data layer (weapon/enemy/passive defs, Mad Forest wave script, level curve, pickup table, Antonio).
- **Type:** autoload/service
- **Inputs:** preloaded `Resource`s / `const` tables.
- **Outputs / mutations:** read-only accessors.
- **Godot 4 mapping:** autoload singleton `GameData`.
- **State note:** holds only immutable defs loaded once at startup; safe as a singleton because it is never mutated at runtime.

### AudioService (stub)
- **Goal:** play placeholder SFX cues (weapon fire, hit/death, level-up, pickup, heal, chest, Reaper, hurt/death).
- **Type:** autoload/service
- **Godot 4 mapping:** autoload with pooled `AudioStreamPlayer`s; driven by signals/events. Minimal per the GDD.

## System Interaction & Data Flow
One `RunController._physics_process(dt)` while `phase == PLAYING` (else early-return; UI overlays still process):

1. **Input** — `RunController` polls the move axis → `input_dir: Vector2`.
2. **Stats** — `StatSystem.resolve(player, stage)` → fills `player.derived` (might, cooldown, area, speed, move_speed, magnet, armor, recovery, curse, luck, growth, greed…), caps applied.
3. **Player move** — `MovementSystem.step_player(player, input_dir, dt)` updates `pos`/`facing`.
4. **Spawning** — `SpawnDirector.step(state, dt)` advances the clock, tops up the wave toward min-alive (Curse-scaled interval), spawns bosses/events/braziers, enforces 300/500 caps, and at 30:00 clears + spawns Reaper.
5. **Enemy move** — `MovementSystem.step_enemies(state, dt)`.
6. **Index** — `SpatialIndex.rebuild(...)` buckets enemies/gems/pickups for this tick.
7. **Weapons** — `WeaponSystem.step(state, dt)` ticks cooldowns and appends projectiles/zones (targeting via `SpatialIndex`/facing/`rng`).
8. **Combat** — `CombatSystem.step(state, dt)` moves projectiles/zones, resolves hits (`damage × Might`, crit, knockback, pierce), kills enemies → spawns gems/drops/boss chests, breaks braziers.
9. **Pickups** — `PickupSystem.step(state, dt)` magnetizes/collects gems & pickups → XP (×Growth) to Progression, gold (×Greed), heals, special effects; 400-gem cap merge; opens chests.
10. **Progression** — `ProgressionSystem.add_xp(...)` crosses thresholds → increments `pending_levelups`.
11. **Health** — `HealthSystem.step(state, dt)` applies contact damage (i-frames/armor), recovery, death/revival.
12. **Phase check** — if `pending_levelups > 0` → `RunController` builds the offer (`ProgressionSystem.build_offer`) and sets `phase = LEVEL_UP` (sim pauses); if `phase == GAME_OVER` → death flow.
13. **Render** — `PresentationLayer.sync(state)` + HUD read `GameState`: sprites, camera, XP/HP bars, timer, level, gold, kills.

**Key transitions.**
- **Start:** `RunController.start_run()` builds `GameState` from Antonio's `CharacterDef` + Mad Forest `StageDef` (10 starting spawns), seeds `rng`, sets `phase = PLAYING`.
- **Level-up:** `LEVEL_UP` modal reads `current_offer`; on `_on_option_chosen(i)` → `ProgressionSystem.apply_choice` (+ `StatSystem.recompute_block`); if more queued, present the next; else grant brief i-frames and return to `PLAYING`.
- **Death/loss:** `GAME_OVER` → DeathScreen (Revive if `revivals ≥ 1`, else Quit) → `RESULTS` (run summary) → `TITLE`.
- **Restart:** discard `GameState`, build a fresh one, return to `PLAYING`.

## Game State Machine
Owned by `RunController` (a phase enum gating the sim):

```
TITLE ──start──▶ PLAYING ──Esc──▶ PAUSED ──Esc──▶ PLAYING
                   │  ▲                │
        pending    │  │ resume         └──quit──▶ TITLE
        level-up   ▼  │
                LEVEL_UP ──choice (queue empty)──▶ PLAYING
                   │
   hp≤0 & no revival ▼
                GAME_OVER ──revive──▶ PLAYING
                   │
                  done ▼
                RESULTS ──done──▶ TITLE
```
Only `PLAYING` advances the simulation pipeline. `PAUSED`, `LEVEL_UP`, `GAME_OVER`, `RESULTS`, and `TITLE` skip `step()` and show their overlays (Control nodes that keep processing). The 30:00 Reaper occurs *within* `PLAYING` (handled by `SpawnDirector`), leading to `GAME_OVER` via the one-shot.

## Godot 4 Scene Tree / Node Layout
```
Main (Node2D)  ── run_controller.gd  [orchestrator shell; owns GameState + phase machine]
├── World (Node2D)
│   ├── Background (TextureRect/ColorRect + tiling shader)   [follows camera; wrapping field]
│   ├── EntityRenderer (Node2D)  ── presentation_layer.gd    [pooled Sprite2D per category;
│   │       (pools: enemies / projectiles / zones / gems / pickups / chests / lights / player)
│   └── Camera2D                                             [follows player.pos]
└── UILayer (CanvasLayer)
    ├── HUD (Control)            ── hud.gd                   [XP bar, timer, level, gold, kills, HP]
    ├── LevelUpScreen (Control)  ── level_up_screen.gd       [reads current_offer; emits option_chosen]
    ├── PauseScreen (Control)    ── pause_screen.gd
    ├── DeathScreen (Control)    ── death_screen.gd          [Revive / Quit]
    ├── ResultsScreen (Control)  ── results_screen.gd        [run summary + per-weapon DPS table]
    └── MainMenu (Control)       ── main_menu.gd             [Start (Antonio/Mad Forest) / Quit]

Autoloads:  GameData (game_data.gd)   AudioService (audio_service.gd)
```
Pure logic modules (`res://logic/`) are **not** in the tree — they are `static func` scripts called by `run_controller.gd`. The data-layer `Resource`s (`res://data/`) are loaded by the `GameData` autoload.

## File / Module Layout
Paths are under `vampire-survivors-taskmaster/` (i.e. `res://…`). One `_test.gd` per pure logic module.

```
res://logic/                         # PURE modules (static funcs) + mutable data-model classes
  game_state.gd  player_state.gd  stat_block.gd  resolved_stats.gd
  enemy.gd  projectile.gd  damage_zone.gd  gem.gd  pickup.gd  chest.gd  light_source.gd
  weapon_instance.gd  passive_instance.gd  level_up_offer.gd
  stat_system.gd  movement_system.gd  spatial_index.gd  weapon_system.gd
  combat_system.gd  combat_math.gd  spawn_director.gd  pickup_system.gd
  progression_system.gd  health_system.gd

res://data/                          # IMMUTABLE data layer (Resource classes / const tables)
  defs/ weapon_def.gd  enemy_def.gd  passive_def.gd  stage_def.gd  character_def.gd
  weapons/*.tres  enemies/*.tres  passives/*.tres
  stage_mad_forest.tres  (wave/boss/event/Reaper script)
  level_curve.gd  pickup_table.gd  character_antonio.tres

res://game/                          # NODE shells
  Main.tscn  run_controller.gd
  presentation_layer.gd  (EntityRenderer)

res://ui/                            # Control shells (.tscn + .gd each)
  hud  level_up_screen  pause_screen  death_screen  results_screen  main_menu

res://autoload/  game_data.gd  audio_service.gd

res://test/                          # gdUnit4 — mirrors res://logic/ (one per pure module)
  stat_system_test.gd  movement_system_test.gd  spatial_index_test.gd
  weapon_system_test.gd  combat_system_test.gd  combat_math_test.gd
  spawn_director_test.gd  pickup_system_test.gd  progression_system_test.gd
  health_system_test.gd
```
**Setup prerequisite:** add the gdUnit4 addon (`res://addons/gdUnit4/`) and a project `TESTING.md`; the `res://test/` modules above assume it. Because every system is a `static func` over plain data with a seeded RNG, each test constructs a `GameState`, calls one `step`, and asserts on mutated fields — no scene tree required.

## Vertical Slice Definition
The architecture supports the GDD's full 30-minute MVP; because all content is data, the *first end-to-end playable* exercises every system with a reduced data set and then scales by filling `res://data/`. First-light slice: Antonio spawns on the Mad Forest field; the player moves with WASD/arrows while the Whip auto-fires in the facing direction; the `SpawnDirector` produces the early waves (e.g. bats/skeletons) that home in; killing them drops gems that magnetize, fill the XP bar, and trigger the pause-and-choose level-up screen offering real weapons/passives (add or upgrade); chosen items immediately change weapon behavior and stats; contact damage with i-frames can kill the player → death → results → menu. That single loop — move, auto-attack, collect, level, grow, take damage, end — runs through Stat → Movement → Spawn → SpatialIndex → Weapon → Combat → Pickup → Progression → Health every tick, and the full roster, wave script, bosses, chests, events, and the 30:00 Reaper are added purely by extending the data layer.

## Out of Scope
Restated from the GDD so the architecture is not over-built: **weapon evolutions** and the Vandalier union (chests grant standard multi-item upgrades + gold only); **Reroll / Skip / Banish**; between-run meta (PowerUp shop, character unlocks, Golden Eggs — gold is a per-run score stat only, no persistence/`user://` save); other characters and the character-select screen; other stages, Adventures mode, DLC; Arcanas and run modifiers (Hyper / Endless / Limit Break); achievements/collection UI; online/multiplayer, gamepad, and mobile/touch. The data layer leaves room (e.g. a documented base→evolved weapon map) for these as later extensions without changing the system boundaries.


IMPORTANT: Your response must be a JSON object with a "tasks" property containing an array of task objects. You may optionally include a "metadata" object. Do not include any other properties.
```

## LLM Response

```json
{
  "tasks": [
    {
      "id": 1,
      "title": "Install gdUnit4 Testing Framework",
      "description": "Install and configure the gdUnit4 addon for headless unit testing of pure GDScript modules",
      "details": "1. Download gdUnit4 from Godot Asset Library or GitHub (https://github.com/MikeSchulze/gdUnit4)\n2. Extract to `res://addons/gdUnit4/`\n3. Enable the plugin in Project Settings → Plugins\n4. Create `res://test/` directory for test files\n5. Create a `TESTING.md` documenting the test approach\n6. Verify installation by running gdUnit4 from the Godot editor\n\nPseudo-code for verification:\n```gdscript\n# res://test/sanity_test.gd\nextends GdUnitTestSuite\n\nfunc test_sanity() -> void:\n    assert_bool(true).is_true()\n```",
      "priority": "high",
      "dependencies": [],
      "status": "pending"
    },
    {
      "id": 2,
      "title": "Create Core Data Model Classes",
      "description": "Implement the fundamental RefCounted data classes that hold mutable game state: StatBlock, ResolvedStats, PlayerState, and GameState",
      "details": "Create `res://logic/` directory and implement:\n\n1. `stat_block.gd` - StatBlock (RefCounted):\n```gdscript\nclass_name StatBlock extends RefCounted\n\nvar might: float = 1.0\nvar area: float = 1.0\nvar cooldown: float = 1.0\nvar amount: int = 0\nvar duration: float = 1.0\nvar speed: float = 1.0\nvar move_speed: float = 1.0\nvar max_health: float = 100.0\nvar recovery: float = 0.0\nvar armor: float = 0.0\nvar magnet: float = 64.0  # pixels\nvar luck: float = 1.0\nvar growth: float = 1.0\nvar greed: float = 1.0\nvar curse: float = 1.0\nvar revival: int = 0\n```\n\n2. `resolved_stats.gd` - ResolvedStats (computed each tick with caps):\n```gdscript\nclass_name ResolvedStats extends RefCounted\n# Same fields but computed values after multipliers and caps\n```\n\n3. `player_state.gd` - PlayerState:\n```gdscript\nclass_name PlayerState extends RefCounted\nvar pos: Vector2 = Vector2.ZERO\nvar facing: Vector2 = Vector2.RIGHT\nvar velocity: Vector2 = Vector2.ZERO\nvar hp: float = 100.0\nvar level: int = 1\nvar xp: float = 0.0\nvar xp_to_next: float = 5.0\nvar iframe_timer: float = 0.0\nvar revivals: int = 0\nvar weapons: Array = []  # Array[WeaponInstance]\nvar passives: Array = []  # Array[PassiveInstance]\nvar stats: StatBlock = StatBlock.new()\nvar derived: ResolvedStats = ResolvedStats.new()\n```\n\n4. `game_state.gd` - GameState:\n```gdscript\nclass_name GameState extends RefCounted\nenum Phase { TITLE, PLAYING, PAUSED, LEVEL_UP, GAME_OVER, RESULTS }\nvar time_elapsed: float = 0.0\nvar current_minute: int = 0\nvar phase: int = Phase.TITLE\nvar rng: RandomNumberGenerator = RandomNumberGenerator.new()\nvar player: PlayerState = PlayerState.new()\nvar enemies: Array = []\nvar projectiles: Array = []\nvar zones: Array = []\nvar gems: Array = []\nvar pickups: Array = []\nvar chests: Array = []\nvar light_sources: Array = []\nvar index: SpatialIndex = null  # Set after SpatialIndex created\nvar spawn_cursor: int = 0\nvar event_cursor: int = 0\nvar chest_count: int = 0\nvar kills: int = 0\nvar gold: int = 0\nvar pending_levelups: int = 0\nvar current_offer = null\nvar global_effects: Dictionary = {}\n```\n\nWrite unit tests for each class verifying default values and mutability.",
      "priority": "high",
      "dependencies": [
        1
      ],
      "status": "pending"
    },
    {
      "id": 3,
      "title": "Create Entity Data Classes",
      "description": "Implement data classes for game entities: Enemy, Projectile, DamageZone, Gem, Pickup, Chest, LightSource, WeaponInstance, PassiveInstance, LevelUpOffer",
      "details": "Create in `res://logic/`:\n\n1. `enemy.gd`:\n```gdscript\nclass_name Enemy extends RefCounted\nvar def = null  # EnemyDef resource\nvar pos: Vector2 = Vector2.ZERO\nvar velocity: Vector2 = Vector2.ZERO\nvar hp: float = 1.0\nvar knockback: Vector2 = Vector2.ZERO\nvar knockback_timer: float = 0.0\nvar freeze_timer: float = 0.0\nvar is_boss: bool = false\nvar fixed_direction: bool = false\nvar floaty: bool = false\nvar hit_cooldowns: Dictionary = {}  # source_id -> timer\n```\n\n2. `projectile.gd`:\n```gdscript\nclass_name Projectile extends RefCounted\nvar source_weapon = null\nvar pos: Vector2\nvar velocity: Vector2\nvar damage: float\nvar crit_mult: float = 1.0\nvar crit_chance: float = 0.0\nvar pierce_left: int = 1\nvar lifetime: float = 2.0\nvar bounces_left: int = 0\nvar hit_ids: PackedInt64Array = []\nvar is_boomerang: bool = false\nvar is_returning: bool = false\n```\n\n3. `damage_zone.gd`:\n```gdscript\nclass_name DamageZone extends RefCounted\nenum Anchor { FOLLOW_PLAYER, WORLD, ORBIT }\nvar source_weapon = null\nvar anchor: int = Anchor.WORLD\nvar pos: Vector2\nvar offset: Vector2 = Vector2.ZERO\nvar angle: float = 0.0\nvar radius: float = 32.0\nvar damage: float\nvar tick_interval: float = 0.5\nvar tick_timer: float = 0.0\nvar lifetime: float = 1.0\nvar hit_ids: PackedInt64Array = []\n```\n\n4. `gem.gd`, `pickup.gd`, `chest.gd`, `light_source.gd` with appropriate fields\n5. `weapon_instance.gd` and `passive_instance.gd` for inventory items\n6. `level_up_offer.gd` for the upgrade selection menu data\n\nWrite tests verifying construction and field access.",
      "priority": "high",
      "dependencies": [
        2
      ],
      "status": "pending"
    },
    {
      "id": 4,
      "title": "Create Immutable Data Definition Resources",
      "description": "Create the Resource-based definition classes for static game data: WeaponDef, EnemyDef, PassiveDef, StageDef, CharacterDef",
      "details": "Create `res://data/defs/` directory with Resource classes:\n\n1. `weapon_def.gd`:\n```gdscript\nclass_name WeaponDef extends Resource\n@export var id: String\n@export var name: String\n@export var description: String\n@export var base_damage: float\n@export var cooldown: float\n@export var pierce: int = 1\n@export var projectile_speed: float = 200.0\n@export var area: float = 1.0\n@export var amount: int = 1\n@export var duration: float = 0.0\n@export var crit_chance: float = 0.0\n@export var crit_mult: float = 1.5\n@export var knockback: float = 0.0\n@export var levels: Array[Dictionary] = []  # Level-up progression\n```\n\n2. `enemy_def.gd`:\n```gdscript\nclass_name EnemyDef extends Resource\n@export var id: String\n@export var name: String\n@export var hp: float\n@export var power: float  # Contact damage\n@export var speed: float\n@export var knockback_resist: float = 0.0\n@export var xp_value: float = 1.0\n@export var is_boss: bool = false\n```\n\n3. `passive_def.gd`:\n```gdscript\nclass_name PassiveDef extends Resource\n@export var id: String\n@export var name: String\n@export var stat_bonuses: Dictionary = {}  # stat_name -> Array of per-level values\n```\n\n4. `stage_def.gd` with wave script, boss spawns, events, brazier locations\n5. `character_def.gd` with starting stats, starting weapon, base stats\n6. `level_curve.gd` as const table for XP thresholds\n7. `pickup_table.gd` for drop weights",
      "priority": "high",
      "dependencies": [
        1
      ],
      "status": "pending"
    },
    {
      "id": 5,
      "title": "Create Antonio Character and Whip Weapon Data",
      "description": "Author the concrete data files for Antonio (starting character) and the Whip (starting weapon) based on wiki specifications",
      "details": "Create `.tres` resource files:\n\n1. `res://data/character_antonio.tres`:\n- Starting HP: 120 (Antonio gets +20% Max Health)\n- Starting weapon: Whip\n- Base stats: might 1.0, all others default\n- Character bonus: +10% Might per level\n\n2. `res://data/weapons/whip.tres`:\n- Base damage: 20\n- Cooldown: 1.3s\n- Pierce: infinite within sweep\n- Area: medium horizontal sweep\n- Levels 1-8 progression (damage, area, amount scaling)\n- Pattern: horizontal slash in facing direction, alternating sides\n\n3. Create level curve data in `res://data/level_curve.gd`:\n```gdscript\nconst CURVE: Array[int] = [5, 10, 20, 40, ...]  # XP needed for each level\nconst L20_BONUS_XP: int = 600\nconst L40_BONUS_XP: int = 2400\n```\n\n4. Create a basic test that loads and validates these resources.",
      "priority": "high",
      "dependencies": [
        4
      ],
      "status": "pending"
    },
    {
      "id": 6,
      "title": "Implement SpatialIndex System",
      "description": "Create the uniform spatial-hash grid system for efficient collision queries without physics nodes",
      "details": "Create `res://logic/spatial_index.gd`:\n\n```gdscript\nclass_name SpatialIndex extends RefCounted\n\nconst CELL_SIZE: float = 64.0\nvar buckets: Dictionary = {}  # Vector2i -> Array[int] (entity indices)\nvar entity_positions: PackedVector2Array = []\nvar entity_types: PackedInt32Array = []  # enum for enemy/gem/pickup\n\nstatic func rebuild(index: SpatialIndex, enemies: Array, gems: Array, pickups: Array) -> void:\n    index.buckets.clear()\n    index.entity_positions.clear()\n    index.entity_types.clear()\n    # Hash each entity position to cell, store index in bucket\n    for i in enemies.size():\n        var cell = _pos_to_cell(enemies[i].pos)\n        _add_to_bucket(index, cell, i, TYPE_ENEMY)\n    # ... repeat for gems, pickups\n\nstatic func _pos_to_cell(pos: Vector2) -> Vector2i:\n    return Vector2i(int(pos.x / CELL_SIZE), int(pos.y / CELL_SIZE))\n\nstatic func query_radius(index: SpatialIndex, center: Vector2, r: float) -> PackedInt32Array:\n    var results: PackedInt32Array = []\n    var min_cell = _pos_to_cell(center - Vector2(r, r))\n    var max_cell = _pos_to_cell(center + Vector2(r, r))\n    for x in range(min_cell.x, max_cell.x + 1):\n        for y in range(min_cell.y, max_cell.y + 1):\n            var cell = Vector2i(x, y)\n            if index.buckets.has(cell):\n                for entry in index.buckets[cell]:\n                    var pos = index.entity_positions[entry]\n                    if center.distance_squared_to(pos) <= r * r:\n                        results.append(entry)\n    return results\n\nstatic func nearest_enemy(index: SpatialIndex, from: Vector2) -> int:\n    # Spiral outward from center cell until enemy found\n    pass\n\nstatic func random_enemy(index: SpatialIndex, rng: RandomNumberGenerator) -> int:\n    # Return random valid enemy index\n    pass\n```\n\nWrite comprehensive tests for rebuild, query_radius, nearest_enemy, and random_enemy with various entity configurations.",
      "priority": "high",
      "dependencies": [
        3
      ],
      "status": "pending"
    },
    {
      "id": 7,
      "title": "Implement StatSystem",
      "description": "Create the pure stat resolution system that computes effective stats from base + passives + character + buffs with caps",
      "details": "Create `res://logic/stat_system.gd`:\n\n```gdscript\nclass_name StatSystem extends RefCounted\n\n# Stat caps from the game\nconst MAX_COOLDOWN_REDUCTION: float = 0.9  # Can't go below 10% of base\nconst MAX_MOVE_SPEED_MULT: float = 2.0\nconst MAX_AREA_MULT: float = 3.0\nconst MIN_ARMOR: float = 0.0\nconst MAX_ARMOR: float = 100.0\n\nstatic func resolve(player: PlayerState, stage_def = null) -> void:\n    var derived = player.derived\n    var block = player.stats\n    \n    # Start from base stats\n    derived.might = block.might\n    derived.area = block.area\n    # ... etc\n    \n    # Add passive bonuses\n    for passive in player.passives:\n        _apply_passive(derived, passive)\n    \n    # Apply stage modifiers if any\n    if stage_def:\n        derived.curse *= stage_def.curse_mult\n    \n    # Apply caps\n    derived.cooldown = maxf(1.0 - MAX_COOLDOWN_REDUCTION, derived.cooldown)\n    derived.move_speed = minf(derived.move_speed, MAX_MOVE_SPEED_MULT)\n    derived.area = minf(derived.area, MAX_AREA_MULT)\n    derived.armor = clampf(derived.armor, MIN_ARMOR, MAX_ARMOR)\n\nstatic func recompute_block(player: PlayerState) -> void:\n    # Called when items change - rebuild block from inventory\n    player.stats = StatBlock.new()  # Reset to defaults\n    # Apply character base stats\n    # Sum all passive contributions\n```\n\nWrite tests verifying stat calculations, cap enforcement, and passive stacking.",
      "priority": "high",
      "dependencies": [
        2,
        4
      ],
      "status": "pending"
    },
    {
      "id": 8,
      "title": "Implement MovementSystem",
      "description": "Create the pure movement system for player and enemy position updates",
      "details": "Create `res://logic/movement_system.gd`:\n\n```gdscript\nclass_name MovementSystem extends RefCounted\n\nconst BASE_PLAYER_SPEED: float = 100.0  # pixels/sec\n\nstatic func step_player(player: PlayerState, input_dir: Vector2, dt: float) -> void:\n    # Normalize input and apply move speed\n    if input_dir.length_squared() > 0.01:\n        input_dir = input_dir.normalized()\n        player.facing = input_dir\n    \n    var speed = BASE_PLAYER_SPEED * player.derived.move_speed\n    player.velocity = input_dir * speed\n    player.pos += player.velocity * dt\n\nstatic func step_enemies(state: GameState, dt: float) -> void:\n    var player_pos = state.player.pos\n    \n    for enemy in state.enemies:\n        # Skip if frozen\n        if enemy.freeze_timer > 0:\n            enemy.freeze_timer -= dt\n            continue\n        \n        # Apply knockback decay\n        if enemy.knockback_timer > 0:\n            enemy.knockback_timer -= dt\n            enemy.pos += enemy.knockback * dt\n            continue\n        \n        # Movement based on type\n        if enemy.fixed_direction:\n            # Swarm enemies move in fixed direction\n            enemy.pos += enemy.velocity * dt\n        else:\n            # Home toward player\n            var dir = (player_pos - enemy.pos).normalized()\n            var speed = enemy.def.speed\n            enemy.velocity = dir * speed\n            enemy.pos += enemy.velocity * dt\n        \n        # Floaty sine offset for appropriate enemies\n        if enemy.floaty:\n            enemy.pos.y += sin(state.time_elapsed * 3.0) * 0.5\n```\n\nWrite tests for player movement with various inputs, enemy homing, knockback decay, and freeze behavior.",
      "priority": "high",
      "dependencies": [
        2,
        3,
        7
      ],
      "status": "pending"
    },
    {
      "id": 9,
      "title": "Implement CombatMath Utilities",
      "description": "Create shared combat math functions for damage calculation, crits, and knockback",
      "details": "Create `res://logic/combat_math.gd`:\n\n```gdscript\nclass_name CombatMath extends RefCounted\n\nconst KNOCKBACK_DURATION: float = 0.1  # seconds\nconst BASE_KNOCKBACK_FORCE: float = 100.0\n\nstatic func calc_damage(base_damage: float, might: float) -> float:\n    return base_damage * might\n\nstatic func roll_crit(rng: RandomNumberGenerator, crit_chance: float, crit_mult: float) -> Dictionary:\n    var is_crit = rng.randf() < crit_chance\n    return {\n        \"is_crit\": is_crit,\n        \"multiplier\": crit_mult if is_crit else 1.0\n    }\n\nstatic func apply_armor(damage: float, armor: float) -> float:\n    # Damage is reduced by armor, minimum 1\n    return maxf(damage - armor, 1.0)\n\nstatic func calc_knockback(from_pos: Vector2, to_pos: Vector2, force: float, resist: float) -> Vector2:\n    if resist >= 1.0:\n        return Vector2.ZERO  # Boss immune\n    var dir = (to_pos - from_pos).normalized()\n    return dir * force * (1.0 - resist)\n\nstatic func is_in_range(a: Vector2, b: Vector2, range_sq: float) -> bool:\n    return a.distance_squared_to(b) <= range_sq\n```\n\nWrite unit tests for each function with edge cases (zero armor, full resist, etc.).",
      "priority": "medium",
      "dependencies": [
        2
      ],
      "status": "pending"
    },
    {
      "id": 10,
      "title": "Implement WeaponSystem Core",
      "description": "Create the weapon system that ticks cooldowns and emits projectiles/zones based on weapon patterns",
      "details": "Create `res://logic/weapon_system.gd`:\n\n```gdscript\nclass_name WeaponSystem extends RefCounted\n\nstatic func step(state: GameState, dt: float) -> void:\n    for weapon in state.player.weapons:\n        weapon.cooldown_timer -= dt\n        if weapon.cooldown_timer <= 0:\n            cast(state, weapon)\n            # Reset cooldown with player's cooldown reduction\n            weapon.cooldown_timer = weapon.def.cooldown * state.player.derived.cooldown\n\nstatic func cast(state: GameState, weapon: WeaponInstance) -> void:\n    var def = weapon.def\n    var player = state.player\n    var amount = def.amount + player.derived.amount\n    \n    match def.id:\n        \"whip\":\n            _cast_whip(state, weapon, amount)\n        \"magic_wand\":\n            _cast_magic_wand(state, weapon, amount)\n        \"knife\":\n            _cast_knife(state, weapon, amount)\n        # ... other weapons\n\nstatic func _cast_whip(state: GameState, weapon: WeaponInstance, amount: int) -> void:\n    # Horizontal slash in facing direction\n    # Create a wide damage zone that hits all enemies in sweep\n    var zone = DamageZone.new()\n    zone.source_weapon = weapon\n    zone.anchor = DamageZone.Anchor.FOLLOW_PLAYER\n    zone.offset = state.player.facing * 40.0\n    zone.radius = 60.0 * state.player.derived.area\n    zone.damage = weapon.def.base_damage * _level_mult(weapon.level)\n    zone.lifetime = 0.15  # Brief slash\n    zone.tick_interval = 0.0  # Single hit\n    state.zones.append(zone)\n    \n    # Alternate sides for next cast\n    weapon.scratch[\"side\"] = -weapon.scratch.get(\"side\", 1)\n\nstatic func _level_mult(level: int) -> float:\n    # Damage scaling per level\n    return 1.0 + (level - 1) * 0.1\n```\n\nImplement Whip pattern first, add other weapons incrementally. Write tests for cooldown ticking and projectile/zone creation.",
      "priority": "high",
      "dependencies": [
        3,
        5,
        6,
        7
      ],
      "status": "pending"
    },
    {
      "id": 11,
      "title": "Implement CombatSystem",
      "description": "Create the combat resolution system that processes projectile/zone hits against enemies",
      "details": "Create `res://logic/combat_system.gd`:\n\n```gdscript\nclass_name CombatSystem extends RefCounted\n\nstatic func step(state: GameState, dt: float) -> void:\n    _step_projectiles(state, dt)\n    _step_zones(state, dt)\n\nstatic func _step_projectiles(state: GameState, dt: float) -> void:\n    var to_remove: Array[int] = []\n    \n    for i in state.projectiles.size():\n        var proj = state.projectiles[i]\n        proj.lifetime -= dt\n        if proj.lifetime <= 0:\n            to_remove.append(i)\n            continue\n        \n        # Move projectile\n        proj.pos += proj.velocity * dt\n        \n        # Check enemy hits via SpatialIndex\n        var nearby = SpatialIndex.query_radius(state.index, proj.pos, 16.0)\n        for enemy_idx in nearby:\n            if enemy_idx in proj.hit_ids:\n                continue  # Already hit this enemy\n            \n            var enemy = state.enemies[enemy_idx]\n            _apply_hit(state, enemy, proj)\n            proj.hit_ids.append(enemy_idx)\n            proj.pierce_left -= 1\n            \n            if proj.pierce_left <= 0:\n                to_remove.append(i)\n                break\n    \n    # Remove expired/pierced projectiles (reverse order)\n    for i in range(to_remove.size() - 1, -1, -1):\n        _swap_remove(state.projectiles, to_remove[i])\n\nstatic func _apply_hit(state: GameState, enemy: Enemy, proj: Projectile) -> void:\n    var damage = CombatMath.calc_damage(proj.damage, state.player.derived.might)\n    var crit = CombatMath.roll_crit(state.rng, proj.crit_chance, proj.crit_mult)\n    damage *= crit.multiplier\n    \n    enemy.hp -= damage\n    \n    # Apply knockback\n    var kb = CombatMath.calc_knockback(proj.pos, enemy.pos, 100.0, enemy.def.knockback_resist)\n    if kb.length_squared() > 0:\n        enemy.knockback = kb\n        enemy.knockback_timer = 0.1\n    \n    if enemy.hp <= 0:\n        _on_enemy_death(state, enemy)\n\nstatic func _on_enemy_death(state: GameState, enemy: Enemy) -> void:\n    state.kills += 1\n    # Spawn gem\n    var gem = Gem.new()\n    gem.pos = enemy.pos\n    gem.xp = enemy.def.xp_value\n    state.gems.append(gem)\n    # Roll for drops...\n```\n\nWrite tests for projectile movement, hit detection, damage application, pierce mechanics, and enemy death spawns.",
      "priority": "high",
      "dependencies": [
        3,
        6,
        9,
        10
      ],
      "status": "pending"
    },
    {
      "id": 12,
      "title": "Implement SpawnDirector",
      "description": "Create the spawn system that manages enemy waves, bosses, events, and the 30-minute Reaper",
      "details": "Create `res://logic/spawn_director.gd`:\n\n```gdscript\nclass_name SpawnDirector extends RefCounted\n\nconst SPAWN_RING_MIN: float = 400.0  # Min distance from player\nconst SPAWN_RING_MAX: float = 500.0  # Max distance\nconst PERIODIC_HALT_CAP: int = 300\nconst HARD_CAP: int = 500\nconst REAPER_TIME: float = 1800.0  # 30 minutes\n\nstatic func step(state: GameState, stage: StageDef, dt: float) -> void:\n    state.time_elapsed += dt\n    var new_minute = int(state.time_elapsed / 60.0)\n    \n    if new_minute > state.current_minute:\n        state.current_minute = new_minute\n        _on_minute_change(state, stage)\n    \n    # Check for Reaper spawn\n    if state.time_elapsed >= REAPER_TIME and not _has_reaper(state):\n        _spawn_reaper(state)\n    \n    # Top up enemies toward min-alive\n    var wave = _get_current_wave(stage, state.current_minute)\n    if wave and state.enemies.size() < PERIODIC_HALT_CAP:\n        _spawn_wave_topup(state, wave)\n\nstatic func _spawn_wave_topup(state: GameState, wave: Dictionary) -> void:\n    var min_alive = wave.min_alive\n    var curse = state.player.derived.curse\n    var interval = wave.spawn_interval / curse\n    \n    while state.enemies.size() < min_alive and state.enemies.size() < HARD_CAP:\n        var enemy = _create_enemy(state, wave.enemy_def)\n        enemy.pos = _random_ring_pos(state.player.pos, SPAWN_RING_MIN, SPAWN_RING_MAX, state.rng)\n        state.enemies.append(enemy)\n\nstatic func _spawn_reaper(state: GameState) -> void:\n    # Clear all non-immune enemies\n    state.enemies.clear()\n    # Spawn The Reaper\n    var reaper = Enemy.new()\n    reaper.def = GameData.get_enemy(\"reaper\")\n    reaper.hp = 65535\n    reaper.pos = _random_ring_pos(state.player.pos, SPAWN_RING_MIN, SPAWN_RING_MAX, state.rng)\n    reaper.is_boss = true\n    state.enemies.append(reaper)\n\nstatic func _random_ring_pos(center: Vector2, min_r: float, max_r: float, rng: RandomNumberGenerator) -> Vector2:\n    var angle = rng.randf() * TAU\n    var dist = rng.randf_range(min_r, max_r)\n    return center + Vector2(cos(angle), sin(angle)) * dist\n```\n\nWrite tests for wave spawning, cap enforcement, ring positioning, and Reaper trigger.",
      "priority": "high",
      "dependencies": [
        3,
        4,
        6,
        7
      ],
      "status": "pending"
    },
    {
      "id": 13,
      "title": "Implement PickupSystem",
      "description": "Create the system for magnetizing and collecting gems and pickups",
      "details": "Create `res://logic/pickup_system.gd`:\n\n```gdscript\nclass_name PickupSystem extends RefCounted\n\nconst COLLECTION_RADIUS: float = 16.0\nconst MAGNET_SPEED: float = 300.0\nconst GEM_CAP: int = 400\n\nstatic func step(state: GameState, dt: float) -> void:\n    var player_pos = state.player.pos\n    var magnet_range = state.player.derived.magnet\n    var growth = state.player.derived.growth\n    var greed = state.player.derived.greed\n    \n    _step_gems(state, player_pos, magnet_range, growth, dt)\n    _step_pickups(state, player_pos, dt)\n    _step_chests(state, player_pos)\n    _enforce_gem_cap(state)\n\nstatic func _step_gems(state: GameState, player_pos: Vector2, magnet_range: float, growth: float, dt: float) -> void:\n    var collected: Array[int] = []\n    \n    for i in state.gems.size():\n        var gem = state.gems[i]\n        var dist = player_pos.distance_to(gem.pos)\n        \n        if dist <= COLLECTION_RADIUS:\n            # Collect gem\n            var xp = gem.xp * growth\n            ProgressionSystem.add_xp(state, xp)\n            collected.append(i)\n        elif dist <= magnet_range:\n            # Magnetize toward player\n            var dir = (player_pos - gem.pos).normalized()\n            gem.pos += dir * MAGNET_SPEED * dt\n    \n    # Remove collected (reverse order)\n    for i in range(collected.size() - 1, -1, -1):\n        _swap_remove(state.gems, collected[i])\n\nstatic func _enforce_gem_cap(state: GameState) -> void:\n    if state.gems.size() > GEM_CAP:\n        # Merge excess into one red gem\n        var excess_xp = 0.0\n        while state.gems.size() > GEM_CAP:\n            excess_xp += state.gems.pop_back().xp\n        if excess_xp > 0:\n            var red_gem = Gem.new()\n            red_gem.xp = excess_xp\n            red_gem.tier = 2  # Red\n            red_gem.pos = state.gems[GEM_CAP - 1].pos\n            state.gems.append(red_gem)\n```\n\nWrite tests for magnet behavior, collection, XP routing, and gem cap enforcement.",
      "priority": "high",
      "dependencies": [
        3,
        6,
        7
      ],
      "status": "pending"
    },
    {
      "id": 14,
      "title": "Implement ProgressionSystem",
      "description": "Create the XP/leveling system with level-up offer generation and item application",
      "details": "Create `res://logic/progression_system.gd`:\n\n```gdscript\nclass_name ProgressionSystem extends RefCounted\n\nconst MAX_WEAPONS: int = 6\nconst MAX_PASSIVES: int = 6\n\nstatic func add_xp(state: GameState, amount: float) -> void:\n    var player = state.player\n    player.xp += amount\n    \n    while player.xp >= player.xp_to_next:\n        player.xp -= player.xp_to_next\n        player.level += 1\n        state.pending_levelups += 1\n        \n        # Calculate next threshold from curve\n        player.xp_to_next = GameData.get_xp_for_level(player.level + 1)\n        \n        # Special level bonuses\n        if player.level == 20:\n            add_xp(state, 600)  # L20 bonus\n        elif player.level == 40:\n            add_xp(state, 2400)  # L40 bonus\n\nstatic func build_offer(state: GameState) -> LevelUpOffer:\n    var offer = LevelUpOffer.new()\n    var player = state.player\n    var options: Array = []\n    \n    # Gather available options\n    var available_weapons = _get_upgradeable_weapons(player)\n    var available_passives = _get_upgradeable_passives(player)\n    var new_weapons = _get_new_weapons(player) if player.weapons.size() < MAX_WEAPONS else []\n    var new_passives = _get_new_passives(player) if player.passives.size() < MAX_PASSIVES else []\n    \n    # Build 3-4 options\n    var pool = available_weapons + available_passives + new_weapons + new_passives\n    pool.shuffle()  # Use state.rng for determinism\n    \n    var num_options = 3\n    if state.rng.randf() < (1.0 - 1.0 / state.player.derived.luck):\n        num_options = 4\n    \n    for i in mini(num_options, pool.size()):\n        options.append(pool[i])\n    \n    offer.options = options\n    return offer\n\nstatic func apply_choice(state: GameState, index: int) -> void:\n    var choice = state.current_offer.options[index]\n    var player = state.player\n    \n    if choice.is_upgrade:\n        choice.target.level += 1\n    else:\n        # New item\n        if choice.kind == \"weapon\":\n            var inst = WeaponInstance.new()\n            inst.def = choice.def\n            inst.level = 1\n            player.weapons.append(inst)\n        else:\n            var inst = PassiveInstance.new()\n            inst.def = choice.def\n            inst.level = 1\n            player.passives.append(inst)\n    \n    StatSystem.recompute_block(player)\n    state.pending_levelups -= 1\n```\n\nWrite tests for XP accumulation, level-up triggers, offer generation, choice application, and inventory limits.",
      "priority": "high",
      "dependencies": [
        2,
        4,
        5,
        7
      ],
      "status": "pending"
    },
    {
      "id": 15,
      "title": "Implement HealthSystem",
      "description": "Create the player health system with contact damage, i-frames, armor, recovery, and revival",
      "details": "Create `res://logic/health_system.gd`:\n\n```gdscript\nclass_name HealthSystem extends RefCounted\n\nconst IFRAME_DURATION: float = 0.24  # 240ms\nconst PLAYER_HITBOX: float = 16.0\n\nstatic func step(state: GameState, dt: float) -> void:\n    var player = state.player\n    \n    # Tick i-frame timer\n    if player.iframe_timer > 0:\n        player.iframe_timer -= dt\n    \n    # Apply recovery\n    var recovery = player.derived.recovery\n    if recovery > 0 and player.hp < player.derived.max_health:\n        player.hp = minf(player.hp + recovery * dt, player.derived.max_health)\n    \n    # Check enemy contact damage\n    if player.iframe_timer <= 0:\n        _check_contact_damage(state)\n    \n    # Check death\n    if player.hp <= 0:\n        _on_death(state)\n\nstatic func _check_contact_damage(state: GameState) -> void:\n    var player = state.player\n    var nearby = SpatialIndex.query_radius(state.index, player.pos, PLAYER_HITBOX)\n    \n    for enemy_idx in nearby:\n        var enemy = state.enemies[enemy_idx]\n        var raw_damage = enemy.def.power\n        var damage = CombatMath.apply_armor(raw_damage, player.derived.armor)\n        \n        player.hp -= damage\n        player.iframe_timer = IFRAME_DURATION\n        \n        # Only take damage from one enemy per contact\n        break\n\nstatic func _on_death(state: GameState) -> void:\n    var player = state.player\n    \n    if player.revivals > 0:\n        # Revive\n        player.revivals -= 1\n        player.hp = player.derived.max_health * 0.5\n        player.iframe_timer = 1.0  # Burst i-frames on revive\n    else:\n        state.phase = GameState.Phase.GAME_OVER\n```\n\nWrite tests for i-frame gating, armor application (min 1 damage), recovery tick, revival mechanics, and death transition.",
      "priority": "high",
      "dependencies": [
        3,
        6,
        7,
        9
      ],
      "status": "pending"
    },
    {
      "id": 16,
      "title": "Create GameData Autoload",
      "description": "Implement the autoload singleton that loads and exposes all immutable game data",
      "details": "Create `res://autoload/game_data.gd`:\n\n```gdscript\nextends Node\n\n# Preloaded resources\nvar _weapons: Dictionary = {}\nvar _enemies: Dictionary = {}\nvar _passives: Dictionary = {}\nvar _characters: Dictionary = {}\nvar _stages: Dictionary = {}\nvar _level_curve: Array[int] = []\n\nfunc _ready() -> void:\n    _load_weapons()\n    _load_enemies()\n    _load_passives()\n    _load_characters()\n    _load_stages()\n    _load_level_curve()\n\nfunc _load_weapons() -> void:\n    var dir = DirAccess.open(\"res://data/weapons/\")\n    if dir:\n        dir.list_dir_begin()\n        var file = dir.get_next()\n        while file != \"\":\n            if file.ends_with(\".tres\"):\n                var weapon = load(\"res://data/weapons/\" + file) as WeaponDef\n                _weapons[weapon.id] = weapon\n            file = dir.get_next()\n\nfunc get_weapon(id: String) -> WeaponDef:\n    return _weapons.get(id)\n\nfunc get_enemy(id: String) -> EnemyDef:\n    return _enemies.get(id)\n\nfunc get_passive(id: String) -> PassiveDef:\n    return _passives.get(id)\n\nfunc get_character(id: String) -> CharacterDef:\n    return _characters.get(id)\n\nfunc get_stage(id: String) -> StageDef:\n    return _stages.get(id)\n\nfunc get_xp_for_level(level: int) -> float:\n    if level <= 0 or level > _level_curve.size():\n        return 99999.0\n    return float(_level_curve[level - 1])\n\nfunc get_all_weapons() -> Array[WeaponDef]:\n    return _weapons.values()\n\nfunc get_all_passives() -> Array[PassiveDef]:\n    return _passives.values()\n```\n\nRegister in project.godot autoloads. Test that data loads correctly.",
      "priority": "high",
      "dependencies": [
        4,
        5
      ],
      "status": "pending"
    },
    {
      "id": 17,
      "title": "Create RunController Orchestrator",
      "description": "Implement the main game controller that owns GameState, handles input, and calls systems in order each tick",
      "details": "Create `res://game/run_controller.gd`:\n\n```gdscript\nextends Node2D\nclass_name RunController\n\nsignal level_up_started(offer: LevelUpOffer)\nsignal run_ended(summary: Dictionary)\nsignal phase_changed(phase: int)\n\nvar state: GameState = null\nvar _stage_def: StageDef = null\n\nfunc _ready() -> void:\n    _stage_def = GameData.get_stage(\"mad_forest\")\n\nfunc _physics_process(delta: float) -> void:\n    if state == null or state.phase != GameState.Phase.PLAYING:\n        return\n    \n    # 1. Input\n    var input_dir = _get_input_direction()\n    \n    # 2. Stats\n    StatSystem.resolve(state.player, _stage_def)\n    \n    # 3. Player movement\n    MovementSystem.step_player(state.player, input_dir, delta)\n    \n    # 4. Spawning\n    SpawnDirector.step(state, _stage_def, delta)\n    \n    # 5. Enemy movement\n    MovementSystem.step_enemies(state, delta)\n    \n    # 6. Spatial index rebuild\n    SpatialIndex.rebuild(state.index, state.enemies, state.gems, state.pickups)\n    \n    # 7. Weapons\n    WeaponSystem.step(state, delta)\n    \n    # 8. Combat\n    CombatSystem.step(state, delta)\n    \n    # 9. Pickups\n    PickupSystem.step(state, delta)\n    \n    # 10. Health\n    HealthSystem.step(state, delta)\n    \n    # 11. Phase check\n    if state.pending_levelups > 0 and state.phase == GameState.Phase.PLAYING:\n        state.current_offer = ProgressionSystem.build_offer(state)\n        _set_phase(GameState.Phase.LEVEL_UP)\n        level_up_started.emit(state.current_offer)\n\nfunc _get_input_direction() -> Vector2:\n    return Input.get_vector(\"move_left\", \"move_right\", \"move_up\", \"move_down\")\n\nfunc start_run(character_id: String = \"antonio\") -> void:\n    state = GameState.new()\n    state.rng.seed = Time.get_ticks_usec()\n    state.index = SpatialIndex.new()\n    \n    # Initialize player from character def\n    var char_def = GameData.get_character(character_id)\n    state.player = _create_player_from_def(char_def)\n    \n    # 10 starting spawns\n    for i in 10:\n        SpawnDirector._spawn_wave_topup(state, _stage_def.waves[0])\n    \n    _set_phase(GameState.Phase.PLAYING)\n\nfunc on_option_chosen(index: int) -> void:\n    ProgressionSystem.apply_choice(state, index)\n    state.current_offer = null\n    \n    if state.pending_levelups > 0:\n        state.current_offer = ProgressionSystem.build_offer(state)\n        level_up_started.emit(state.current_offer)\n    else:\n        state.player.iframe_timer = 0.5  # Brief post-levelup i-frames\n        _set_phase(GameState.Phase.PLAYING)\n\nfunc _set_phase(phase: int) -> void:\n    state.phase = phase\n    phase_changed.emit(phase)\n```\n\nCreate `res://game/Main.tscn` with RunController as root.",
      "priority": "high",
      "dependencies": [
        7,
        8,
        10,
        11,
        12,
        13,
        14,
        15,
        16
      ],
      "status": "pending"
    },
    {
      "id": 18,
      "title": "Create Input Actions",
      "description": "Configure the input map for player movement and UI interactions",
      "details": "Update `project.godot` to add input actions:\n\n```ini\n[input]\nmove_left={\n\"deadzone\": 0.5,\n\"events\": [Object(InputEventKey,\"resource_local_to_scene\":false,\"resource_name\":\"\",\"device\":-1,\"window_id\":0,\"alt_pressed\":false,\"shift_pressed\":false,\"ctrl_pressed\":false,\"meta_pressed\":false,\"pressed\":false,\"keycode\":65,\"physical_keycode\":0,\"key_label\":0,\"unicode\":97,\"location\":0,\"echo\":false,\"script\":null), Object(InputEventKey,\"resource_local_to_scene\":false,\"resource_name\":\"\",\"device\":-1,\"window_id\":0,\"alt_pressed\":false,\"shift_pressed\":false,\"ctrl_pressed\":false,\"meta_pressed\":false,\"pressed\":false,\"keycode\":4194319,\"physical_keycode\":0,\"key_label\":0,\"unicode\":0,\"location\":0,\"echo\":false,\"script\":null)]\n}\nmove_right={\n\"deadzone\": 0.5,\n\"events\": [Object(InputEventKey,\"resource_local_to_scene\":false,\"resource_name\":\"\",\"device\":-1,\"window_id\":0,\"alt_pressed\":false,\"shift_pressed\":false,\"ctrl_pressed\":false,\"meta_pressed\":false,\"pressed\":false,\"keycode\":68,\"physical_keycode\":0,\"key_label\":0,\"unicode\":100,\"location\":0,\"echo\":false,\"script\":null), Object(InputEventKey,\"resource_local_to_scene\":false,\"resource_name\":\"\",\"device\":-1,\"window_id\":0,\"alt_pressed\":false,\"shift_pressed\":false,\"ctrl_pressed\":false,\"meta_pressed\":false,\"pressed\":false,\"keycode\":4194321,\"physical_keycode\":0,\"key_label\":0,\"unicode\":0,\"location\":0,\"echo\":false,\"script\":null)]\n}\nmove_up={\n# W and Up arrow\n}\nmove_down={\n# S and Down arrow\n}\npause={\n# Escape key\n}\nui_accept={\n# Enter/Space for menu selection\n}\n```\n\nActions: move_left (A, Left), move_right (D, Right), move_up (W, Up), move_down (S, Down), pause (Escape)",
      "priority": "medium",
      "dependencies": [],
      "status": "pending"
    },
    {
      "id": 19,
      "title": "Create PresentationLayer and EntityRenderer",
      "description": "Implement the visual rendering system with pooled sprites for all entity types",
      "details": "Create `res://game/presentation_layer.gd`:\n\n```gdscript\nextends Node2D\nclass_name PresentationLayer\n\n# Sprite pools per entity category\nvar _enemy_pool: Array[Sprite2D] = []\nvar _projectile_pool: Array[Sprite2D] = []\nvar _zone_pool: Array[Sprite2D] = []\nvar _gem_pool: Array[Sprite2D] = []\nvar _pickup_pool: Array[Sprite2D] = []\nvar _player_sprite: Sprite2D = null\n\nconst POOL_INITIAL_SIZE: int = 100\n\nfunc _ready() -> void:\n    _init_pools()\n    _create_player_sprite()\n\nfunc _init_pools() -> void:\n    for i in POOL_INITIAL_SIZE:\n        _enemy_pool.append(_create_sprite())\n        _projectile_pool.append(_create_sprite())\n        _gem_pool.append(_create_sprite())\n\nfunc _create_sprite() -> Sprite2D:\n    var sprite = Sprite2D.new()\n    sprite.visible = false\n    add_child(sprite)\n    return sprite\n\nfunc sync(state: GameState) -> void:\n    _sync_player(state.player)\n    _sync_entities(state.enemies, _enemy_pool, \"enemy\")\n    _sync_entities(state.projectiles, _projectile_pool, \"projectile\")\n    _sync_entities(state.zones, _zone_pool, \"zone\")\n    _sync_entities(state.gems, _gem_pool, \"gem\")\n    _sync_entities(state.pickups, _pickup_pool, \"pickup\")\n\nfunc _sync_player(player: PlayerState) -> void:\n    _player_sprite.position = player.pos\n    # Flip based on facing\n    _player_sprite.flip_h = player.facing.x < 0\n\nfunc _sync_entities(entities: Array, pool: Array[Sprite2D], type: String) -> void:\n    # Hide all sprites first\n    for sprite in pool:\n        sprite.visible = false\n    \n    # Expand pool if needed\n    while pool.size() < entities.size():\n        pool.append(_create_sprite())\n    \n    # Position visible sprites\n    for i in entities.size():\n        var sprite = pool[i]\n        sprite.position = entities[i].pos\n        sprite.visible = true\n        # Set texture/modulate based on entity type and def\n        _apply_visual(sprite, entities[i], type)\n\nfunc _apply_visual(sprite: Sprite2D, entity, type: String) -> void:\n    match type:\n        \"enemy\":\n            sprite.texture = entity.def.texture if entity.def else preload(\"res://icon.svg\")\n        \"gem\":\n            sprite.modulate = [Color.CYAN, Color.GREEN, Color.RED][entity.tier]\n        # etc.\n```\n\nIntegrate with RunController's render step. Use placeholder textures initially.",
      "priority": "high",
      "dependencies": [
        2,
        3,
        17
      ],
      "status": "pending"
    },
    {
      "id": 20,
      "title": "Create Camera System",
      "description": "Implement the Camera2D that follows the player with proper viewport setup",
      "details": "Add Camera2D setup to Main.tscn:\n\n1. Create Camera2D as child of World node\n2. Configure in `run_controller.gd`:\n```gdscript\n@onready var camera: Camera2D = $World/Camera2D\n\nfunc _process(delta: float) -> void:\n    if state and state.player:\n        camera.position = state.player.pos\n```\n\n3. Update project.godot for stretch settings:\n```ini\n[display]\nwindow/size/viewport_width=480\nwindow/size/viewport_height=270\nwindow/size/window_width_override=1920\nwindow/size/window_height_override=1080\nwindow/stretch/mode=\"canvas_items\"\nwindow/stretch/aspect=\"keep\"\n```\n\n4. Create tiled background shader for infinite field effect:\n```gdscript\n# res://game/background.gdshader\nshader_type canvas_item;\nuniform vec2 camera_pos;\nuniform sampler2D tile_texture;\n\nvoid fragment() {\n    vec2 uv = UV + camera_pos / 64.0;  // tile size\n    COLOR = texture(tile_texture, fract(uv));\n}\n```",
      "priority": "medium",
      "dependencies": [
        17,
        19
      ],
      "status": "pending"
    },
    {
      "id": 21,
      "title": "Create HUD UI",
      "description": "Implement the heads-up display showing XP bar, timer, level, gold, kills, and HP",
      "details": "Create `res://ui/hud.tscn` and `res://ui/hud.gd`:\n\n```gdscript\nextends Control\nclass_name HUD\n\n@onready var xp_bar: ProgressBar = $XPBar\n@onready var hp_bar: ProgressBar = $HPBar\n@onready var timer_label: Label = $TimerLabel\n@onready var level_label: Label = $LevelLabel\n@onready var gold_label: Label = $GoldLabel\n@onready var kills_label: Label = $KillsLabel\n\nfunc update_from_state(state: GameState) -> void:\n    var player = state.player\n    \n    # XP bar\n    xp_bar.max_value = player.xp_to_next\n    xp_bar.value = player.xp\n    \n    # HP bar\n    hp_bar.max_value = player.derived.max_health\n    hp_bar.value = player.hp\n    \n    # Timer (MM:SS format)\n    var minutes = int(state.time_elapsed / 60)\n    var seconds = int(state.time_elapsed) % 60\n    timer_label.text = \"%02d:%02d\" % [minutes, seconds]\n    \n    # Stats\n    level_label.text = \"Lv %d\" % player.level\n    gold_label.text = str(state.gold)\n    kills_label.text = str(state.kills)\n```\n\nScene structure:\n- HUD (Control, full_rect anchors)\n  - XPBar (ProgressBar, top)\n  - HPBar (ProgressBar, below XP)\n  - TimerLabel (Label, top-right)\n  - LevelLabel (Label)\n  - GoldLabel (Label)\n  - KillsLabel (Label)\n\nConnect to RunController to update each frame.",
      "priority": "medium",
      "dependencies": [
        2,
        17
      ],
      "status": "pending"
    },
    {
      "id": 22,
      "title": "Create Level-Up Screen UI",
      "description": "Implement the modal overlay for selecting level-up options",
      "details": "Create `res://ui/level_up_screen.tscn` and `res://ui/level_up_screen.gd`:\n\n```gdscript\nextends Control\nclass_name LevelUpScreen\n\nsignal option_chosen(index: int)\n\n@onready var options_container: VBoxContainer = $Panel/VBoxContainer\nvar _option_buttons: Array[Button] = []\n\nfunc _ready() -> void:\n    hide()\n\nfunc show_offer(offer: LevelUpOffer) -> void:\n    # Clear existing buttons\n    for btn in _option_buttons:\n        btn.queue_free()\n    _option_buttons.clear()\n    \n    # Create button for each option\n    for i in offer.options.size():\n        var opt = offer.options[i]\n        var btn = Button.new()\n        btn.text = _format_option(opt)\n        btn.pressed.connect(_on_option_pressed.bind(i))\n        options_container.add_child(btn)\n        _option_buttons.append(btn)\n    \n    show()\n    _option_buttons[0].grab_focus()\n\nfunc _format_option(opt: Dictionary) -> String:\n    if opt.is_upgrade:\n        return \"%s Lv %d → %d\" % [opt.def.name, opt.target_level - 1, opt.target_level]\n    else:\n        return \"NEW: %s\" % opt.def.name\n\nfunc _on_option_pressed(index: int) -> void:\n    hide()\n    option_chosen.emit(index)\n```\n\nScene structure:\n- LevelUpScreen (Control, full_rect, semi-transparent bg)\n  - Panel (PanelContainer, centered)\n    - VBoxContainer\n      - TitleLabel \"LEVEL UP!\"\n      - (Buttons added dynamically)\n\nConnect signal to RunController.on_option_chosen().",
      "priority": "high",
      "dependencies": [
        14,
        17
      ],
      "status": "pending"
    },
    {
      "id": 23,
      "title": "Create Pause Screen UI",
      "description": "Implement the pause menu with resume and quit options",
      "details": "Create `res://ui/pause_screen.tscn` and `res://ui/pause_screen.gd`:\n\n```gdscript\nextends Control\nclass_name PauseScreen\n\nsignal resume_requested\nsignal quit_requested\n\n@onready var resume_btn: Button = $Panel/VBoxContainer/ResumeButton\n@onready var quit_btn: Button = $Panel/VBoxContainer/QuitButton\n\nfunc _ready() -> void:\n    hide()\n    resume_btn.pressed.connect(_on_resume)\n    quit_btn.pressed.connect(_on_quit)\n\nfunc _input(event: InputEvent) -> void:\n    if event.is_action_pressed(\"pause\") and visible:\n        _on_resume()\n        get_viewport().set_input_as_handled()\n\nfunc show_pause() -> void:\n    show()\n    resume_btn.grab_focus()\n\nfunc _on_resume() -> void:\n    hide()\n    resume_requested.emit()\n\nfunc _on_quit() -> void:\n    hide()\n    quit_requested.emit()\n```\n\nUpdate RunController to handle pause input:\n```gdscript\nfunc _unhandled_input(event: InputEvent) -> void:\n    if event.is_action_pressed(\"pause\"):\n        if state.phase == GameState.Phase.PLAYING:\n            _set_phase(GameState.Phase.PAUSED)\n            pause_screen.show_pause()\n```",
      "priority": "medium",
      "dependencies": [
        17
      ],
      "status": "pending"
    },
    {
      "id": 24,
      "title": "Create Death and Results Screens",
      "description": "Implement game over screen with revive option and results summary",
      "details": "Create `res://ui/death_screen.tscn`, `res://ui/death_screen.gd`:\n\n```gdscript\nextends Control\nclass_name DeathScreen\n\nsignal revive_requested\nsignal continue_requested\n\nfunc show_death(has_revival: bool) -> void:\n    $Panel/ReviveButton.visible = has_revival\n    $Panel/ReviveButton.disabled = not has_revival\n    show()\n```\n\nCreate `res://ui/results_screen.tscn`, `res://ui/results_screen.gd`:\n\n```gdscript\nextends Control\nclass_name ResultsScreen\n\nsignal done\n\nfunc show_results(summary: Dictionary) -> void:\n    $Panel/TimeLabel.text = \"Time: %s\" % summary.time_formatted\n    $Panel/LevelLabel.text = \"Level: %d\" % summary.level\n    $Panel/KillsLabel.text = \"Kills: %d\" % summary.kills\n    $Panel/GoldLabel.text = \"Gold: %d\" % summary.gold\n    \n    # Per-weapon DPS table\n    var dps_text = \"\"\n    for weapon_stat in summary.weapon_stats:\n        dps_text += \"%s: %d total damage\\n\" % [weapon_stat.name, weapon_stat.total_damage]\n    $Panel/WeaponStatsLabel.text = dps_text\n    \n    show()\n```\n\nWire both to RunController phase transitions.",
      "priority": "medium",
      "dependencies": [
        15,
        17
      ],
      "status": "pending"
    },
    {
      "id": 25,
      "title": "Create Main Menu UI",
      "description": "Implement the title screen with start and quit buttons",
      "details": "Create `res://ui/main_menu.tscn` and `res://ui/main_menu.gd`:\n\n```gdscript\nextends Control\nclass_name MainMenu\n\nsignal start_game\nsignal quit_game\n\n@onready var start_btn: Button = $Panel/VBoxContainer/StartButton\n@onready var quit_btn: Button = $Panel/VBoxContainer/QuitButton\n\nfunc _ready() -> void:\n    start_btn.pressed.connect(_on_start)\n    quit_btn.pressed.connect(_on_quit)\n    start_btn.grab_focus()\n\nfunc _on_start() -> void:\n    start_game.emit()\n\nfunc _on_quit() -> void:\n    get_tree().quit()\n```\n\nScene structure:\n- MainMenu (Control)\n  - TitleLabel \"VAMPIRE SURVIVORS\"\n  - Panel\n    - VBoxContainer\n      - StartButton \"Start (Antonio / Mad Forest)\"\n      - QuitButton \"Quit\"\n\nThis is the initial screen shown. Connects to RunController.start_run().",
      "priority": "medium",
      "dependencies": [
        17
      ],
      "status": "pending"
    },
    {
      "id": 26,
      "title": "Create AudioService Stub",
      "description": "Implement a minimal audio service autoload for placeholder sound effects",
      "details": "Create `res://autoload/audio_service.gd`:\n\n```gdscript\nextends Node\n\nconst POOL_SIZE: int = 8\nvar _sfx_pool: Array[AudioStreamPlayer] = []\nvar _pool_index: int = 0\n\n# Placeholder - actual sounds loaded when available\nvar _sounds: Dictionary = {\n    \"hit\": null,\n    \"death\": null,\n    \"level_up\": null,\n    \"pickup\": null,\n    \"heal\": null,\n    \"chest\": null,\n    \"hurt\": null,\n    \"weapon_fire\": null\n}\n\nfunc _ready() -> void:\n    for i in POOL_SIZE:\n        var player = AudioStreamPlayer.new()\n        add_child(player)\n        _sfx_pool.append(player)\n\nfunc play(sound_name: String) -> void:\n    var sound = _sounds.get(sound_name)\n    if sound == null:\n        return  # No sound loaded yet\n    \n    var player = _sfx_pool[_pool_index]\n    player.stream = sound\n    player.play()\n    _pool_index = (_pool_index + 1) % POOL_SIZE\n\nfunc set_sound(name: String, stream: AudioStream) -> void:\n    _sounds[name] = stream\n```\n\nRegister as autoload in project.godot. Called from systems when events occur.",
      "priority": "low",
      "dependencies": [],
      "status": "pending"
    },
    {
      "id": 27,
      "title": "Create Mad Forest Stage Data",
      "description": "Author the Mad Forest stage definition with complete wave script, bosses, and events",
      "details": "Create `res://data/stage_mad_forest.tres` (StageDef resource):\n\n```gdscript\n# Stage definition with 30-minute wave script\n# Based on wiki data for Mad Forest\n\nvar id = \"mad_forest\"\nvar name = \"Mad Forest\"\nvar curse_mult = 1.0\n\n# Wave script: minute -> wave config\nvar waves = {\n    0: { enemy_id = \"bat\", min_alive = 20, spawn_interval = 1.5 },\n    1: { enemy_id = \"skeleton\", min_alive = 30, spawn_interval = 1.2 },\n    2: { enemy_id = \"ghost\", min_alive = 25, spawn_interval = 1.0 },\n    # Continue for all 30 minutes...\n}\n\n# Boss spawns\nvar bosses = {\n    5: { enemy_id = \"giant_bat\", count = 1 },\n    10: { enemy_id = \"werewolf\", count = 1 },\n    # etc.\n}\n\n# Map events\nvar events = {\n    3: { type = \"bat_swarm\", count = 50 },\n    7: { type = \"ghost_swarm\", count = 30 },\n    # etc.\n}\n\n# Brazier positions (relative to player spawn ring)\nvar brazier_spawn_enabled = true\nvar brazier_interval = 60.0  # seconds\n```\n\nAlso create basic enemy definitions in `res://data/enemies/`:\n- bat.tres, skeleton.tres, ghost.tres (basic enemies)\n- giant_bat.tres, werewolf.tres (bosses)\n- reaper.tres (65535 HP, high speed, one-shots player)",
      "priority": "high",
      "dependencies": [
        4
      ],
      "status": "pending"
    },
    {
      "id": 28,
      "title": "Add Additional Weapons",
      "description": "Implement weapon patterns for Magic Wand, Knife, Axe, Cross, King Bible, Fire Wand, Garlic, Santa Water",
      "details": "Extend WeaponSystem with patterns for each weapon:\n\n1. Magic Wand - fires at nearest enemy:\n```gdscript\nstatic func _cast_magic_wand(state: GameState, weapon: WeaponInstance, amount: int) -> void:\n    var target_idx = SpatialIndex.nearest_enemy(state.index, state.player.pos)\n    if target_idx < 0:\n        return\n    var target = state.enemies[target_idx]\n    for i in amount:\n        var proj = Projectile.new()\n        proj.pos = state.player.pos\n        proj.velocity = (target.pos - state.player.pos).normalized() * 300.0\n        proj.damage = weapon.def.base_damage * _level_mult(weapon.level)\n        state.projectiles.append(proj)\n```\n\n2. Knife - fires in facing direction, high speed\n3. Axe - lobs upward with gravity arc, high damage\n4. Cross - boomerang pattern, returns to player\n5. King Bible - orbiting zones around player\n6. Fire Wand - random target, creates brief explosion zone\n7. Garlic - persistent aura zone around player with tick damage\n8. Santa Water - drops puddles that persist and tick\n\nCreate .tres files for each in `res://data/weapons/` with appropriate base stats and level scaling.",
      "priority": "medium",
      "dependencies": [
        10,
        27
      ],
      "status": "pending"
    },
    {
      "id": 29,
      "title": "Add Passive Items",
      "description": "Implement passive item definitions and stat applications",
      "details": "Create passive definitions in `res://data/passives/`:\n\n1. Spinach (Might +10% per level, max 5)\n2. Armor (Armor +1 per level, max 5)\n3. Hollow Heart (Max HP +20% per level, max 5)\n4. Pummarola (Recovery +0.2/s per level, max 5)\n5. Empty Tome (Cooldown -8% per level, max 5)\n6. Candelabrador (Area +10% per level, max 5)\n7. Bracer (Projectile Speed +10% per level, max 5)\n8. Spellbinder (Duration +10% per level, max 5)\n9. Duplicator (Amount +1 per level, max 2)\n10. Wings (Move Speed +10% per level, max 5)\n11. Attractorb (Magnet +25% per level, max 5)\n12. Clover (Luck +10% per level, max 5)\n13. Crown (Growth +8% per level, max 5)\n14. Stone Mask (Greed +10% per level, max 5)\n15. Skull O'Maniac (Curse +10% per level, max 5)\n16. Tiragisú (Revival +1 at level 1, max 2)\n\nUpdate StatSystem to read passive bonuses and apply them during resolve().",
      "priority": "medium",
      "dependencies": [
        4,
        7,
        14
      ],
      "status": "pending"
    },
    {
      "id": 30,
      "title": "Implement Chest System",
      "description": "Complete the chest drop and opening mechanics with beginner's luck and item selection",
      "details": "Enhance ProgressionSystem and CombatSystem for chest handling:\n\n```gdscript\n# In progression_system.gd\nconst BEGINNER_LUCK_SEQUENCE: Array[int] = [1, 1, 3, 1, 1, 5]\n\nstatic func open_chest(state: GameState, chest: Chest) -> Array:\n    var results: Array = []\n    var count = chest.rolled_count\n    \n    # Roll items\n    for i in count:\n        var item = _roll_chest_item(state)\n        if item:\n            results.append(item)\n            _apply_item_to_player(state, item)\n        else:\n            # All maxed - give gold instead\n            results.append({\"type\": \"gold\", \"amount\": 25})\n            state.gold += 25\n    \n    return results\n\nstatic func _determine_chest_count(state: GameState) -> int:\n    if state.chest_count < BEGINNER_LUCK_SEQUENCE.size():\n        return BEGINNER_LUCK_SEQUENCE[state.chest_count]\n    # After beginner's luck, scale with player luck\n    var roll = state.rng.randf()\n    var luck = state.player.derived.luck\n    if roll < 0.1 * luck:\n        return 5\n    elif roll < 0.3 * luck:\n        return 3\n    return 1\n```\n\nBoss death in CombatSystem spawns a chest with pre-rolled count.",
      "priority": "medium",
      "dependencies": [
        11,
        14,
        27
      ],
      "status": "pending"
    },
    {
      "id": 31,
      "title": "Implement Light Source and Brazier System",
      "description": "Add breakable light sources that drop items from a weighted pool",
      "details": "Create LightSource entity handling:\n\n```gdscript\n# In light_source.gd\nclass_name LightSource extends RefCounted\nvar pos: Vector2\nvar hp: float = 10.0\n\n# In combat_system.gd - add light source damage\nstatic func _damage_light_sources(state: GameState) -> void:\n    var to_remove: Array[int] = []\n    \n    for i in state.light_sources.size():\n        var light = state.light_sources[i]\n        # Check if hit by any active zone/projectile\n        for zone in state.zones:\n            if light.pos.distance_to(zone.pos) < zone.radius:\n                light.hp -= zone.damage\n                break\n        \n        if light.hp <= 0:\n            _on_light_break(state, light)\n            to_remove.append(i)\n    \n    for i in range(to_remove.size() - 1, -1, -1):\n        _swap_remove(state.light_sources, to_remove[i])\n\nstatic func _on_light_break(state: GameState, light: LightSource) -> void:\n    # Roll drop from weighted table\n    var roll = state.rng.randf()\n    var drop_type = PickupTable.roll_brazier_drop(roll)\n    if drop_type:\n        var pickup = Pickup.new()\n        pickup.pos = light.pos\n        pickup.type = drop_type\n        state.pickups.append(pickup)\n```\n\nSpawnDirector spawns braziers periodically around the map edge.",
      "priority": "low",
      "dependencies": [
        3,
        11,
        12
      ],
      "status": "pending"
    },
    {
      "id": 32,
      "title": "Implement Special Pickups",
      "description": "Add vacuum (collect all gems), rosary (kill all enemies), orologion (freeze), and other special items",
      "details": "Extend PickupSystem to handle special pickup types:\n\n```gdscript\nstatic func _apply_pickup(state: GameState, pickup: Pickup) -> void:\n    match pickup.type:\n        \"chicken\":\n            state.player.hp = minf(state.player.hp + 30, state.player.derived.max_health)\n        \"coin_bag\":\n            state.gold += pickup.value\n        \"vacuum\":\n            _vacuum_all_gems(state)\n        \"rosary\":\n            _kill_all_enemies(state)\n        \"orologion\":\n            _freeze_all_enemies(state, 8.0)  # 8 second freeze\n        \"nduja\":\n            _apply_temp_buff(state, \"might\", 2.0, 10.0)  # 2x might for 10s\n        \"clover\":\n            _apply_temp_buff(state, \"luck\", 2.0, 10.0)\n\nstatic func _vacuum_all_gems(state: GameState) -> void:\n    for gem in state.gems:\n        gem.pos = state.player.pos  # Instant collect next tick\n\nstatic func _kill_all_enemies(state: GameState) -> void:\n    for enemy in state.enemies:\n        if not enemy.is_boss:\n            _on_enemy_death(state, enemy)  # Spawn gems\n    state.enemies = state.enemies.filter(func(e): return e.is_boss)\n\nstatic func _freeze_all_enemies(state: GameState, duration: float) -> void:\n    for enemy in state.enemies:\n        enemy.freeze_timer = duration\n```",
      "priority": "low",
      "dependencies": [
        13
      ],
      "status": "pending"
    },
    {
      "id": 33,
      "title": "Create Placeholder Art Assets",
      "description": "Create simple colored rectangle or circle sprites for all entity types",
      "details": "Create minimal placeholder visuals in `res://assets/sprites/`:\n\n1. Player: Blue rectangle 16x24\n2. Enemies: Red circles of varying sizes\n   - Basic: 12x12\n   - Boss: 32x32\n   - Reaper: 48x48 (black with scythe shape)\n3. Gems: Small diamonds\n   - Blue: 6x6\n   - Green: 8x8  \n   - Red: 10x10\n4. Projectiles: Small colored shapes by weapon\n   - Knife: white rectangle 4x12\n   - Wand: blue circle 8x8\n   - Whip: yellow arc shape\n5. Zones: Semi-transparent circles\n6. Pickups: Various colored squares\n7. Background: Green/brown grass tile 64x64\n\nCan use Godot's built-in primitives or simple `.png` files. Update PresentationLayer to load these textures.",
      "priority": "medium",
      "dependencies": [
        19
      ],
      "status": "pending"
    },
    {
      "id": 34,
      "title": "Wire Complete Game Loop",
      "description": "Connect all systems, UI, and state transitions into a playable vertical slice",
      "details": "Update Main.tscn to include all components and wire signals:\n\n```gdscript\n# run_controller.gd additions\n\n@onready var presentation: PresentationLayer = $World/EntityRenderer\n@onready var hud: HUD = $UILayer/HUD\n@onready var level_up_screen: LevelUpScreen = $UILayer/LevelUpScreen\n@onready var pause_screen: PauseScreen = $UILayer/PauseScreen\n@onready var death_screen: DeathScreen = $UILayer/DeathScreen\n@onready var results_screen: ResultsScreen = $UILayer/ResultsScreen\n@onready var main_menu: MainMenu = $UILayer/MainMenu\n\nfunc _ready() -> void:\n    # Connect signals\n    level_up_started.connect(level_up_screen.show_offer)\n    level_up_screen.option_chosen.connect(on_option_chosen)\n    pause_screen.resume_requested.connect(_on_resume)\n    pause_screen.quit_requested.connect(_on_quit_to_menu)\n    death_screen.revive_requested.connect(_on_revive)\n    death_screen.continue_requested.connect(_on_show_results)\n    results_screen.done.connect(_on_results_done)\n    main_menu.start_game.connect(start_run)\n    phase_changed.connect(_on_phase_changed)\n    \n    _set_phase(GameState.Phase.TITLE)\n\nfunc _process(delta: float) -> void:\n    if state:\n        presentation.sync(state)\n        hud.update_from_state(state)\n\nfunc _on_phase_changed(phase: int) -> void:\n    main_menu.visible = phase == GameState.Phase.TITLE\n    hud.visible = phase == GameState.Phase.PLAYING or phase == GameState.Phase.PAUSED\n    # etc.\n```\n\nEnsure the complete flow: Title → Playing → (Pause/LevelUp) → Death → Results → Title works.",
      "priority": "high",
      "dependencies": [
        17,
        19,
        21,
        22,
        23,
        24,
        25
      ],
      "status": "pending"
    },
    {
      "id": 35,
      "title": "Add Integration Tests for Core Game Loop",
      "description": "Write gdUnit4 tests that exercise the full simulation pipeline",
      "details": "Create `res://test/integration/` with comprehensive tests:\n\n```gdscript\n# game_loop_test.gd\nextends GdUnitTestSuite\n\nfunc test_full_tick_pipeline() -> void:\n    var state = _create_test_state()\n    state.phase = GameState.Phase.PLAYING\n    \n    # Simulate 60 ticks (1 second)\n    for i in 60:\n        _run_tick(state, 1.0/60.0, Vector2.RIGHT)\n    \n    # Player should have moved\n    assert_float(state.player.pos.x).is_greater(0)\n    # Time should have advanced\n    assert_float(state.time_elapsed).is_equal_approx(1.0, 0.01)\n\nfunc test_enemy_spawns_and_dies() -> void:\n    var state = _create_test_state()\n    state.phase = GameState.Phase.PLAYING\n    \n    # Give player a weapon\n    _add_weapon(state.player, \"whip\")\n    \n    # Spawn an enemy near player\n    var enemy = _spawn_enemy_at(state, state.player.pos + Vector2(50, 0))\n    \n    # Run ticks until enemy dies or timeout\n    var ticks = 0\n    while state.enemies.size() > 0 and ticks < 300:\n        _run_tick(state, 1.0/60.0, Vector2.ZERO)\n        ticks += 1\n    \n    assert_int(state.enemies.size()).is_equal(0)\n    assert_int(state.kills).is_equal(1)\n    assert_int(state.gems.size()).is_greater(0)\n\nfunc test_level_up_flow() -> void:\n    var state = _create_test_state()\n    state.phase = GameState.Phase.PLAYING\n    \n    # Add enough XP to level up\n    ProgressionSystem.add_xp(state, 100)\n    \n    assert_int(state.pending_levelups).is_greater(0)\n```\n\nTest determinism by running same seed twice and comparing results.",
      "priority": "medium",
      "dependencies": [
        34
      ],
      "status": "pending"
    },
    {
      "id": 36,
      "title": "Performance Profiling and Optimization",
      "description": "Profile the game at scale (300-500 enemies) and optimize bottlenecks",
      "details": "1. Create a stress test scenario:\n```gdscript\n# Debug command to spawn max enemies\nfunc _debug_spawn_stress_test() -> void:\n    while state.enemies.size() < 500:\n        SpawnDirector._spawn_enemy_random(state)\n```\n\n2. Profile with Godot's built-in profiler:\n- Check `_physics_process` time\n- Monitor node count\n- Track memory usage\n\n3. Likely optimization targets:\n- SpatialIndex.rebuild() - ensure O(n) not O(n²)\n- Array operations - use swap-remove not erase\n- Presentation sync - consider MultiMeshInstance2D if sprite count is issue\n\n4. Target metrics:\n- 500 enemies + 200 gems + 50 projectiles\n- Stable 60 FPS\n- Physics tick < 8ms\n\n5. If needed, implement MultiMesh escalation:\n```gdscript\n# Use MultiMeshInstance2D for large entity counts\nvar enemy_multimesh: MultiMeshInstance2D\n\nfunc _sync_enemies_multimesh(enemies: Array) -> void:\n    enemy_multimesh.multimesh.instance_count = enemies.size()\n    for i in enemies.size():\n        var xform = Transform2D(0, enemies[i].pos)\n        enemy_multimesh.multimesh.set_instance_transform_2d(i, xform)\n```",
      "priority": "medium",
      "dependencies": [
        34
      ],
      "status": "pending"
    },
    {
      "id": 37,
      "title": "Add Golden Path Test",
      "description": "Create a deterministic replay test that validates a known-good run sequence",
      "details": "Create a golden path test that replays a fixed input sequence with a fixed seed and validates the final state:\n\n```gdscript\n# golden_path_test.gd\nextends GdUnitTestSuite\n\nconst GOLDEN_SEED: int = 12345\nconst GOLDEN_INPUT_SEQUENCE: Array = [\n    # [frame, input_vector]\n    [0, Vector2.RIGHT],\n    [60, Vector2.DOWN],\n    [120, Vector2.LEFT],\n    # ... recorded input for a full test run\n]\n\nfunc test_golden_path_determinism() -> void:\n    var state1 = _run_golden_path(GOLDEN_SEED)\n    var state2 = _run_golden_path(GOLDEN_SEED)\n    \n    # Same seed + same inputs = same result\n    assert_float(state1.time_elapsed).is_equal(state2.time_elapsed)\n    assert_int(state1.kills).is_equal(state2.kills)\n    assert_int(state1.player.level).is_equal(state2.player.level)\n    assert_vector2(state1.player.pos).is_equal(state2.player.pos)\n\nfunc test_golden_path_expected_outcome() -> void:\n    var state = _run_golden_path(GOLDEN_SEED)\n    \n    # Expected outcomes for this specific seed/input\n    assert_int(state.kills).is_equal(EXPECTED_KILLS)\n    assert_int(state.player.level).is_equal(EXPECTED_LEVEL)\n\nfunc _run_golden_path(seed: int) -> GameState:\n    var state = GameState.new()\n    state.rng.seed = seed\n    # ... initialize from Antonio/Mad Forest\n    \n    var frame = 0\n    var input_idx = 0\n    var current_input = Vector2.ZERO\n    \n    while frame < GOLDEN_RUN_FRAMES:\n        if input_idx < GOLDEN_INPUT_SEQUENCE.size():\n            if GOLDEN_INPUT_SEQUENCE[input_idx][0] == frame:\n                current_input = GOLDEN_INPUT_SEQUENCE[input_idx][1]\n                input_idx += 1\n        \n        _run_tick(state, 1.0/60.0, current_input)\n        frame += 1\n    \n    return state\n```\n\nThis catches regressions when systems are modified.",
      "priority": "medium",
      "dependencies": [
        35
      ],
      "status": "pending"
    }
  ],
  "metadata": {
    "projectName": "Vampire Survivors Godot Recreation",
    "totalTasks": 37,
    "sourceFile": "thoughts/shared/game-design/2026-06-21-ENG-vampire-survivors-vertical-slice.md",
    "generatedAt": "2026-06-20"
  }
}
```
