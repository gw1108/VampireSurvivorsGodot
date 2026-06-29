class_name SpawnDirector extends RefCounted

## Drives the verbatim Mad Forest escalation into the enemy pool: periodic
## spawns (quota-filled per the wiki wave system), swarm/formation events,
## minute-marker bosses, braziers, the Reaper at 30:00, and recycling of
## drifted swarm enemies. Pure logic; `db` is the GameDatabase (wave/enemy
## accessors + brazier constants), passed in for testability.

const PERIODIC_CAP := 300         # periodic spawns halt at 300 alive
const HARD_CAP := 500             # hard on-screen ceiling
const REAPER_TIME := 30.0 * 60.0  # 30 minutes
const REAPER_RESPAWN := 60.0      # one more Reaper each following minute
const SPAWN_RING_MARGIN := 64.0   # how far outside the view enemies appear
const CULL_MARGIN := 256.0        # drift past this (> ring) before a swarm recycles
const SWARM_BATCH := 20           # enemies per swarm/formation event

static func step(state: RunState, db, delta: float) -> void:
	state.elapsed += delta
	var ss: SpawnDirectorState = state.spawn
	var new_minute := int(state.elapsed / 60.0)
	if new_minute > ss.minute:
		ss.minute = new_minute

	if state.elapsed >= REAPER_TIME:
		_handle_reaper(state, db, delta)
		return

	_spawn_periodic(state, db, delta)
	_spawn_events(state, db)
	_spawn_bosses(state, db)
	_spawn_braziers(state, db, delta)
	_cull_distant_enemies(state)

# ---- periodic ----

static func _spawn_periodic(state: RunState, db, delta: float) -> void:
	var enemies: EnemyPool = state.enemies
	if enemies.active_count >= PERIODIC_CAP:
		return
	var wave: Dictionary = db.wave(state.spawn.minute)
	var types: Array = wave.get("enemies", [])
	if types.is_empty():
		return
	state.spawn.periodic_timer -= delta
	if state.spawn.periodic_timer > 0.0:
		return
	var curse := 1.0
	if state.player.stats != null:
		curse = maxf(0.01, state.player.stats.curse)
	state.spawn.periodic_timer = float(wave.get("interval", 1.0)) / curse

	var quota: int = wave.get("count", 0)
	if enemies.active_count < quota:
		# fill up to the minimum (bounded by the caps)
		while enemies.active_count < quota and enemies.active_count < PERIODIC_CAP and enemies.active_count < HARD_CAP:
			var t: StringName = types[state.rng.randi() % types.size()]
			if _spawn_enemy(state, db, t, _get_offscreen_spawn_pos(state)) < 0:
				break
	else:
		# above the minimum: spawn one of each type in the wave
		for t in types:
			if enemies.active_count >= PERIODIC_CAP or enemies.active_count >= HARD_CAP:
				break
			_spawn_enemy(state, db, t, _get_offscreen_spawn_pos(state))

# ---- events (swarms / formations) ----

static func _spawn_events(state: RunState, db) -> void:
	var ss: SpawnDirectorState = state.spawn
	if ss.event_cursor == ss.minute:
		return  # already processed this minute's event
	ss.event_cursor = ss.minute
	var ev: StringName = db.wave(ss.minute).get("event", &"")
	if ev != &"":
		_spawn_event_batch(state, db, ev)

static func _spawn_event_batch(state: RunState, db, ev: StringName) -> void:
	var enemy_id := &""
	match ev:
		&"bat_swarm": enemy_id = &"bat_swarm"
		&"ghost_swarm": enemy_id = &"ghost_swarm"
		&"flower_wall": enemy_id = &"flower_wall"
		_: return
	var enemies: EnemyPool = state.enemies
	var def: Dictionary = db.enemy(enemy_id)
	var is_fixed: bool = def.get("ai", "homing") == "fixed"
	for n in SWARM_BATCH:
		if enemies.active_count >= HARD_CAP:
			break
		var pos := _get_offscreen_spawn_pos(state)
		var idx := _spawn_enemy(state, db, enemy_id, pos)
		if idx >= 0 and is_fixed:
			# fixed-direction swarms sweep across, heading toward the player
			enemies.vel[idx] = (state.player.pos - pos).normalized() * enemies.move_speed[idx]

# ---- bosses ----

static func _spawn_bosses(state: RunState, db) -> void:
	var ss: SpawnDirectorState = state.spawn
	if ss.boss_cursor == ss.minute:
		return
	ss.boss_cursor = ss.minute
	var boss: StringName = db.wave(ss.minute).get("boss", &"")
	if boss != &"":
		_spawn_enemy(state, db, boss, _get_offscreen_spawn_pos(state))

# ---- braziers ----

static func _spawn_braziers(state: RunState, db, delta: float) -> void:
	var ss: SpawnDirectorState = state.spawn
	ss.brazier_timer -= delta
	if ss.brazier_timer > 0.0:
		return
	ss.brazier_timer = db.BRAZIER_CADENCE
	# recount live braziers (their destruction is handled by collision, not here)
	var count := 0
	var enemies: EnemyPool = state.enemies
	for i in EnemyPool.CAPACITY:
		if enemies.alive[i] and enemies.type_id[i] == &"brazier":
			count += 1
	ss.brazier_count = count
	if count >= db.BRAZIER_MAX:
		return
	if state.rng.randf() < db.BRAZIER_SPAWN_CHANCE:
		_spawn_brazier(state, db, _get_offscreen_spawn_pos(state))

static func _spawn_brazier(state: RunState, db, pos: Vector2) -> int:
	# Braziers have no GameDatabase ENEMIES entry; they are a destructible enemy
	# with AI = none, built from the brazier constants.
	var def := {
		hp = float(db.BRAZIER_HP), power = 0.0, move_speed = 0.0,
		knockback_resist = 1.0, xp = 0.0, ai = "none",
	}
	return state.enemies.spawn(&"brazier", pos, def)

# ---- Reaper ----

static func _handle_reaper(state: RunState, db, delta: float) -> void:
	var ss: SpawnDirectorState = state.spawn
	if ss.reaper_timer == 0.0:
		# first Reaper: clear the field, then spawn
		_clear_field(state)
		_spawn_reaper(state, db)
		ss.reaper_timer = REAPER_RESPAWN
	else:
		ss.reaper_timer -= delta
		if ss.reaper_timer <= 0.0:
			_spawn_reaper(state, db)
			ss.reaper_timer = REAPER_RESPAWN

static func _clear_field(state: RunState) -> void:
	var enemies: EnemyPool = state.enemies
	for i in EnemyPool.CAPACITY:
		if enemies.alive[i] and enemies.type_id[i] != &"reaper":
			enemies.despawn(i)

static func _spawn_reaper(state: RunState, db) -> int:
	return _spawn_enemy(state, db, &"reaper", _get_offscreen_spawn_pos(state))

# ---- helpers ----

## Spawn an enemy of `type_id` at `pos`, applying HP-scales-with-level for the
## enemies/bosses/Reaper that carry that flag. Returns the slot index or -1.
static func _spawn_enemy(state: RunState, db, type_id: StringName, pos: Vector2) -> int:
	var def: Dictionary = db.enemy(type_id)
	if def.is_empty():
		return -1
	var idx: int = state.enemies.spawn(type_id, pos, def)
	if idx >= 0 and def.get("hp_per_level", false):
		var lvl := maxf(1.0, float(state.player.level))
		state.enemies.hp[idx] *= lvl
		state.enemies.max_hp[idx] *= lvl
	return idx

## A point on the ring just outside the camera's visible world rect.
static func _get_offscreen_spawn_pos(state: RunState) -> Vector2:
	var rect := state.camera_world_rect.grow(SPAWN_RING_MARGIN)
	match state.rng.randi() % 4:
		0: return Vector2(state.rng.randf_range(rect.position.x, rect.end.x), rect.position.y)  # top
		1: return Vector2(state.rng.randf_range(rect.position.x, rect.end.x), rect.end.y)        # bottom
		2: return Vector2(rect.position.x, state.rng.randf_range(rect.position.y, rect.end.y))   # left
		_: return Vector2(rect.end.x, state.rng.randf_range(rect.position.y, rect.end.y))        # right

## Recycle fixed-direction / wavy swarm enemies that drift far past the ring
## (homing enemies chase forever; bosses and braziers persist).
static func _cull_distant_enemies(state: RunState) -> void:
	if state.camera_world_rect.size == Vector2.ZERO:
		return
	var enemies: EnemyPool = state.enemies
	var cull_rect := state.camera_world_rect.grow(CULL_MARGIN)
	for i in EnemyPool.CAPACITY:
		if not enemies.alive[i] or enemies.is_boss[i]:
			continue
		var ai := enemies.ai_kind[i]
		if ai != EnemyPool.Ai.FIXED and ai != EnemyPool.Ai.WAVY:
			continue
		if not cull_rect.has_point(enemies.pos[i]):
			enemies.despawn(i)
