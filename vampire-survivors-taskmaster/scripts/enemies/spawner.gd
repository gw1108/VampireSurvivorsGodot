class_name VSSpawner
extends Node2D
## Time-based wave spawner. Spawns enemies on a ring just outside view around the
## player; the rate ramps up over the run. Capped for performance.

const MAX_ENEMIES := 90
const SPAWN_RING := 520.0
const ELITE_INTERVAL := 35.0   # seconds between mini-boss spawns
const ELITE_FIRST := 35.0      # delay before the first elite appears
const WAVE_INTERVAL := 60.0    # seconds between minute-milestone wave surges
const WAVE_BASE := 8           # enemies in the first (1:00) surge
const WAVE_GROWTH := 6         # extra enemies per subsequent minute mark
const WAVE_OVERFLOW := 40      # headroom a surge may push past MAX_ENEMIES

var run: VSRun
var _accum := 0.0
var _next_elite := ELITE_FIRST
var _next_wave := WAVE_INTERVAL

func _process(delta: float) -> void:
	if run == null or run.phase != "playing" or run.player == null:
		return
	var rate := 1.0 + run.elapsed / 20.0   # enemies/sec, ramps with time survived
	_accum += rate * delta
	while _accum >= 1.0:
		_accum -= 1.0
		_spawn_one()
	if run.elapsed >= _next_elite:
		_next_elite += ELITE_INTERVAL
		_spawn_elite()
	# Each minute mark crescendos into a coordinated ring-burst so the run visibly
	# escalates toward RUN_DURATION. The final minute is skipped — the Reaper finale
	# owns that beat.
	if run.elapsed >= _next_wave and _next_wave < VSRun.RUN_DURATION:
		var minute := int(round(_next_wave / WAVE_INTERVAL))
		_next_wave += WAVE_INTERVAL
		_spawn_wave(minute)

func _spawn_one() -> void:
	if get_tree().get_nodes_in_group("enemies").size() >= MAX_ENEMIES:
		return
	var ang := randf() * TAU
	var pos := run.player.position + Vector2(cos(ang), sin(ang)) * SPAWN_RING
	pos.x = clampf(pos.x, -run.arena_half.x, run.arena_half.x)
	pos.y = clampf(pos.y, -run.arena_half.y, run.arena_half.y)
	var e := VSEnemy.new()
	e.type = _pick_type()
	e.position = pos
	e.run = run
	e.target = run.player
	run.add_child(e)
	AgentBridge.emit_event("spawn", {"type": "enemy", "pos": [pos.x, pos.y]})

## Spawn a single elite/mini-boss on the ring. Bypasses the enemy cap so the
## boss always shows up, and tags its event so tooling can tell it apart.
func _spawn_elite() -> void:
	var ang := randf() * TAU
	var pos := run.player.position + Vector2(cos(ang), sin(ang)) * SPAWN_RING
	pos.x = clampf(pos.x, -run.arena_half.x, run.arena_half.x)
	pos.y = clampf(pos.y, -run.arena_half.y, run.arena_half.y)
	var e := VSEnemy.new()
	e.type = VSEnemy.Type.ELITE
	e.position = pos
	e.run = run
	e.target = run.player
	run.add_child(e)
	AgentBridge.emit_event("spawn", {"type": "elite", "pos": [pos.x, pos.y]})

## Minute-milestone surge: drop a full ring of enemies around the player in one beat so the
## survival clock reads as escalating waves (a VS "wave" event) rather than a smooth trickle.
## Count grows with each minute mark; the burst may briefly exceed MAX_ENEMIES by WAVE_OVERFLOW
## so the crescendo lands, but stays bounded for performance.
func _spawn_wave(minute: int) -> void:
	var count := WAVE_BASE + maxi(minute - 1, 0) * WAVE_GROWTH
	var ceiling := MAX_ENEMIES + WAVE_OVERFLOW
	var base_ang := randf() * TAU
	for i in count:
		if get_tree().get_nodes_in_group("enemies").size() >= ceiling:
			break
		# Evenly space the ring (with a little jitter) so it reads as a coordinated surge.
		var ang := base_ang + TAU * float(i) / float(count) + randf_range(-0.12, 0.12)
		var pos := run.player.position + Vector2(cos(ang), sin(ang)) * SPAWN_RING
		pos.x = clampf(pos.x, -run.arena_half.x, run.arena_half.x)
		pos.y = clampf(pos.y, -run.arena_half.y, run.arena_half.y)
		var e := VSEnemy.new()
		e.type = _pick_type()
		e.position = pos
		e.run = run
		e.target = run.player
		run.add_child(e)
	AgentBridge.emit_event("wave", {"minute": minute, "count": count})

## Summon the finale Reaper on the spawn ring. Modeled on _spawn_elite (bypasses the
## enemy cap, tags its event) but injects the single, near-unkillable REAPER that VSRun
## triggers at the survival time limit for the run's climactic last stand.
func spawn_reaper() -> void:
	var ang := randf() * TAU
	var pos := run.player.position + Vector2(cos(ang), sin(ang)) * SPAWN_RING
	pos.x = clampf(pos.x, -run.arena_half.x, run.arena_half.x)
	pos.y = clampf(pos.y, -run.arena_half.y, run.arena_half.y)
	var e := VSEnemy.new()
	e.type = VSEnemy.Type.REAPER
	e.position = pos
	e.run = run
	e.target = run.player
	run.add_child(e)
	AgentBridge.emit_event("spawn", {"type": "reaper", "pos": [pos.x, pos.y]})

## Weighted enemy-type roll that introduces tougher archetypes as the run ramps.
func _pick_type() -> int:
	var t := run.elapsed
	var roll := randf()
	if t < 30.0:
		return VSEnemy.Type.BAT if roll < 0.8 else VSEnemy.Type.ZOMBIE
	elif t < 90.0:
		if roll < 0.45: return VSEnemy.Type.BAT
		elif roll < 0.70: return VSEnemy.Type.ZOMBIE
		elif roll < 0.90: return VSEnemy.Type.SKELETON
		else: return VSEnemy.Type.GHOST
	else:
		if roll < 0.30: return VSEnemy.Type.BAT
		elif roll < 0.50: return VSEnemy.Type.ZOMBIE
		elif roll < 0.70: return VSEnemy.Type.SKELETON
		elif roll < 0.85: return VSEnemy.Type.GHOST
		else: return VSEnemy.Type.MUMMY
