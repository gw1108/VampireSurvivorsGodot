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
