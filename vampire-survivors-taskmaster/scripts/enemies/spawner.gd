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

# Directional swarm surge: a dense marching LINE that pours in from one random flank
# (spaced perpendicular to its approach) rather than a surrounding ring — VS's iconic
# "wall of enemies" you juke around, giving the move-only loop a directional threat to
# flee instead of only concentric pressure. Fires on its own cadence between the minute
# waves; count grows slowly with time survived and it shares the cap so it stays bounded.
const SURGE_INTERVAL := 22.0   # seconds between directional swarm walls
const SURGE_FIRST := 45.0      # delay before the first wall (after the early trickle finds its feet)
const SURGE_BASE := 6          # enemies in the line at SURGE_FIRST
const SURGE_GROWTH := 0.06     # extra line-members per second survived
const SURGE_MAX := 16          # cap the line length so a wall never becomes a full encirclement
const SURGE_SPACING := 46.0    # px between adjacent enemies along the wall

var run: VSRun
var _accum := 0.0
var _next_elite := ELITE_FIRST
var _next_wave := WAVE_INTERVAL
var _next_surge := SURGE_FIRST

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
	# Directional swarm walls fire between the minute rings for a different threat shape.
	# Skipped once the Reaper finale is imminent so the last beat belongs to the boss.
	if run.elapsed >= _next_surge and _next_surge < VSRun.RUN_DURATION - WAVE_INTERVAL:
		_next_surge += SURGE_INTERVAL
		_spawn_surge()

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

## Directional swarm wall: spawn a line of enemies off a single random flank, spaced
## perpendicular to their approach, so the horde sometimes arrives as a wall marching in
## from one side (the player flees perpendicular to it) instead of a surrounding ring.
## Length grows with time survived but is capped so it never becomes a full encirclement;
## shares MAX_ENEMIES so a wall never blows the performance budget.
func _spawn_surge() -> void:
	if get_tree().get_nodes_in_group("enemies").size() >= MAX_ENEMIES:
		return
	var count := clampi(SURGE_BASE + int(run.elapsed * SURGE_GROWTH), SURGE_BASE, SURGE_MAX)
	# The flank the wall comes from, and the perpendicular axis it spreads along.
	var dir := Vector2.from_angle(randf() * TAU)
	var perp := dir.orthogonal()
	var center := run.player.position + dir * SPAWN_RING
	for i in count:
		if get_tree().get_nodes_in_group("enemies").size() >= MAX_ENEMIES:
			break
		# Space members evenly along the wall, centered on the flank point.
		var lane := (float(i) - float(count - 1) * 0.5) * SURGE_SPACING
		var pos := center + perp * lane
		pos.x = clampf(pos.x, -run.arena_half.x, run.arena_half.x)
		pos.y = clampf(pos.y, -run.arena_half.y, run.arena_half.y)
		var e := VSEnemy.new()
		e.type = _pick_type()
		e.position = pos
		e.run = run
		e.target = run.player
		run.add_child(e)
	AgentBridge.emit_event("surge", {"count": count, "dir": [dir.x, dir.y]})

## Summon the finale Reaper on the spawn ring. Modeled on _spawn_elite (bypasses the
## enemy cap, tags its event) but injects the single, near-unkillable REAPER that VSRun
## triggers at the survival time limit for the run's climactic last stand. Returns the
## node so the run can hand it to the HUD for the boss health bar.
func spawn_reaper() -> VSEnemy:
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
	# Telegraph the off-ring arrival with a crimson screen vignette so it reads as an
	# event, echoing the HUD 'THE REAPER COMES' banner.
	VSReaperVignette.spawn(run)
	AgentBridge.emit_event("spawn", {"type": "reaper", "pos": [pos.x, pos.y]})
	return e

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
		if roll < 0.28: return VSEnemy.Type.BAT
		elif roll < 0.46: return VSEnemy.Type.ZOMBIE
		elif roll < 0.63: return VSEnemy.Type.SKELETON
		elif roll < 0.76: return VSEnemy.Type.GHOST
		elif roll < 0.88: return VSEnemy.Type.MANTIS
		elif roll < 0.95: return VSEnemy.Type.MUMMY
		# The armored Mantis Warrior is a rare late-band mini-elite, deepening the bug faction.
		else: return VSEnemy.Type.MANTIS_WARRIOR
