class_name SpawnDirector extends RefCounted

## Owns every timed appearance: per-minute wave top-ups (at the wave interval,
## Curse-scaled), bosses, map events, the 300/500 caps, and the 30:00 Reaper
## (+1 per minute after). Pure; reads StageDef + GameData, mutates the arrays.
##
## Wave dict shape (StageDef.waves): {minute, enemy_ids:Array, min_alive, interval}.

const SPAWN_RING_MIN: float = 400.0  # min distance from player for off-screen spawns
const SPAWN_RING_MAX: float = 500.0
const PERIODIC_HALT_CAP: int = 300  # default soft cap (periodic spawns halt)
const HARD_CAP: int = 500  # default absolute cap
const SWARM_SPACING: float = 24.0


static func step(state: GameState, stage: StageDef, dt: float) -> void:
	state.time_elapsed += dt
	var new_minute: int = int(state.time_elapsed / 60.0)
	if new_minute > state.current_minute:
		state.current_minute = new_minute
		_on_minute_change(state, stage, new_minute)

	if stage == null:
		return
	# After the Reaper minute the board is Reaper-only; no normal top-ups.
	if state.current_minute >= stage.reaper_minute:
		return

	var wave := _get_current_wave(stage, state.current_minute)
	if wave.is_empty():
		return
	var curse: float = maxf(state.player.derived.curse, 0.01)
	var interval: float = float(wave["interval"]) / curse
	state.spawn_timer += dt
	if state.spawn_timer >= interval:
		state.spawn_timer -= interval
		_spawn_wave_topup(state, wave, _soft_cap(stage))


## Spawn the initial burst (StageDef.starting_spawn_count) at run start.
static func spawn_starting(state: GameState, stage: StageDef) -> void:
	var wave := _get_current_wave(stage, 0)
	var ids: Array = wave["enemy_ids"] if not wave.is_empty() else ["bat"]
	for i in stage.starting_spawn_count:
		_spawn_one(state, _pick(ids, state.rng))


static func _on_minute_change(state: GameState, stage: StageDef, minute: int) -> void:
	if stage == null:
		return
	if minute >= stage.reaper_minute:
		_spawn_reaper(state, minute == stage.reaper_minute)  # clear board only on arrival
		return
	_spawn_bosses(state, stage, minute)
	for ev in stage.events:
		if int(ev["minute"]) == minute:
			_run_event(state, ev)


static func _spawn_wave_topup(state: GameState, wave: Dictionary, soft_cap: int) -> void:
	var ids: Array = wave["enemy_ids"]
	if ids.is_empty():
		return
	var target: int = mini(int(wave["min_alive"]), soft_cap)
	while state.enemies.size() < target:
		_spawn_one(state, _pick(ids, state.rng))


static func _spawn_bosses(state: GameState, stage: StageDef, minute: int) -> void:
	for boss in stage.bosses:
		if int(boss["minute"]) != minute:
			continue
		for i in int(boss.get("count", 1)):
			var e := _create_enemy(state, String(boss["enemy_id"]))
			e.is_boss = true
			e.pos = _random_ring_pos(state.player.pos, SPAWN_RING_MIN, SPAWN_RING_MAX, state.rng)
			state.enemies.append(e)


static func _run_event(state: GameState, ev: Dictionary) -> void:
	state.event_cursor += 1
	var kind := String(ev["kind"])
	var count: int = int(ev.get("count", 10))
	match kind:
		"bat_swarm":
			_spawn_swarm(state, "bat", count, true)
		"ghost_swarm":
			_spawn_swarm(state, "ghost", count, false)
		"flower_wall":
			_spawn_ring(state, "skeleton", count)
		_:
			pass


static func _spawn_reaper(state: GameState, clear_board: bool) -> void:
	if clear_board:
		state.enemies.clear()
	var reaper := _create_enemy(state, "reaper")  # hp/power come from the def
	reaper.is_boss = true
	reaper.pos = _random_ring_pos(state.player.pos, SPAWN_RING_MIN, SPAWN_RING_MAX, state.rng)
	state.enemies.append(reaper)


# --- helpers ---

static func _get_current_wave(stage: StageDef, minute: int) -> Dictionary:
	var best: Dictionary = {}
	var best_min: int = -1
	for w in stage.waves:
		var m: int = int(w["minute"])
		if m <= minute and m > best_min:
			best_min = m
			best = w
	return best


## EnemyDef by id, loaded directly (Godot caches loads). NOTE: pure logic
## class_name scripts cannot reference the GameData autoload — it is not in scope
## during global-class registration — so SpawnDirector loads defs by path itself.
static func _get_enemy_def(id: String):
	var path := "res://data/enemies/%s.tres" % id
	return load(path) if ResourceLoader.exists(path) else null


static func _create_enemy(state: GameState, id: String) -> Enemy:
	var e := Enemy.new()
	var def = _get_enemy_def(id)
	e.def = def
	if def != null:
		e.hp = def.hp
		e.is_boss = def.is_boss
	return e


static func _spawn_one(state: GameState, id: String) -> void:
	var e := _create_enemy(state, id)
	e.pos = _random_ring_pos(state.player.pos, SPAWN_RING_MIN, SPAWN_RING_MAX, state.rng)
	state.enemies.append(e)


static func _spawn_swarm(state: GameState, id: String, count: int, floaty: bool) -> void:
	var dir := _random_unit(state.rng)
	var perp := dir.orthogonal()
	var def = _get_enemy_def(id)
	var speed: float = def.speed if def != null else 100.0
	var start: Vector2 = state.player.pos - dir * SPAWN_RING_MAX
	for i in count:
		var e := _create_enemy(state, id)
		e.fixed_direction = true
		e.floaty = floaty
		e.velocity = dir * speed
		e.pos = start + perp * (float(i) - count * 0.5) * SWARM_SPACING
		state.enemies.append(e)


static func _spawn_ring(state: GameState, id: String, count: int) -> void:
	var n: int = maxi(count, 1)
	for i in count:
		var angle: float = TAU * float(i) / float(n)
		var e := _create_enemy(state, id)
		e.pos = state.player.pos + Vector2(cos(angle), sin(angle)) * SPAWN_RING_MAX
		state.enemies.append(e)


static func _soft_cap(stage: StageDef) -> int:
	return stage.max_alive_soft if stage.max_alive_soft > 0 else PERIODIC_HALT_CAP


static func _pick(ids: Array, rng: RandomNumberGenerator) -> String:
	return String(ids[rng.randi_range(0, ids.size() - 1)])


static func _random_ring_pos(center: Vector2, min_r: float, max_r: float, rng: RandomNumberGenerator) -> Vector2:
	var angle: float = rng.randf() * TAU
	var dist: float = rng.randf_range(min_r, max_r)
	return center + Vector2(cos(angle), sin(angle)) * dist


static func _random_unit(rng: RandomNumberGenerator) -> Vector2:
	var a: float = rng.randf() * TAU
	return Vector2(cos(a), sin(a))
