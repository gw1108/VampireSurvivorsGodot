class_name VSOrbit
extends Node2D
## "Blades" — N blades that spin around the player and cut any enemy they sweep past.
## A melee orbit (think Vampire Survivors' King Bible): no aim, no chase — it punishes
## whatever wanders into the spinning ring. Picked and levelled through the level-up
## screen (see VSRun.UPGRADES / apply_upgrade("orbit")): first pick spawns one blade,
## repeats add a blade (up to MAX_BLADES) and deepen the cut, for a real power spike.
## Drawn with primitives like the other juice (impact spark / gem sparkle / garlic), not a sprite.

const TICK := 0.18          # seconds between damage samples (a blade sweeps fast, so this stays small)
const PULSE_DUR := 0.12     # how long the visual flash after a connecting tick lasts
const MAX_BLADES := 6       # blade-count soft cap; further picks keep deepening the cut

var run: VSRun
var orbit_radius := 64.0    # distance the blades ride from the player; widens slightly on each pick
var blade_radius := 16.0    # each blade's cut reach
var spin := 3.4             # rad/s the ring rotates
var damage := 4.0           # per-hit damage; deepens on each pick
var count := 1              # number of blades; +1 per pick up to MAX_BLADES
var level := 0              # how many times Blades has been chosen (drives the power curve)
var _angle := 0.0           # current ring rotation
var _cd := 0.0
var _pulse := 0.0           # 1 -> 0 right after a connecting tick, brightening the blades so the cut reads

func _ready() -> void:
	z_index = 1              # over enemies (z 0) so the blades read as cutting through them

func level_up() -> void:
	# Each pick adds a blade (until the ring is full) and always deepens the cut + widens the ring a touch.
	level += 1
	if level == 1:
		count = 1
		damage = 4.0
		orbit_radius = 64.0
	else:
		if count < MAX_BLADES:
			count += 1
		damage += 2.0
		orbit_radius = minf(orbit_radius + 4.0, 92.0)
	queue_redraw()

func _process(delta: float) -> void:
	if run == null or run.phase != "playing":
		return   # freeze with the world (level-up picker / game over)
	if _pulse > 0.0:
		_pulse = maxf(0.0, _pulse - delta / PULSE_DUR)
	_angle = fmod(_angle + spin * delta, TAU)
	_cd -= delta
	if _cd <= 0.0:
		_tick()
		_cd = TICK
	queue_redraw()

func _blade_offsets() -> Array:
	# Evenly-spaced local offsets of each blade from the node origin (= the player).
	var out := []
	for i in count:
		var a := _angle + float(i) * TAU / float(count)
		out.append(Vector2.from_angle(a) * orbit_radius)
	return out

func _tick() -> void:
	# Sample each blade's reach. get_nodes_in_group returns a snapshot and hit() only marks the
	# corpse _dying (frees later) + drops it from the group, so cutting many in one loop is safe.
	# `struck` keeps two blades from double-cutting the same enemy in a single tick.
	var hit_any := false
	var struck := {}
	var offsets := _blade_offsets()
	for e in get_tree().get_nodes_in_group("enemies"):
		if struck.has(e):
			continue
		for off in offsets:
			if (e.position - (global_position + off)).length() < blade_radius + e.radius:
				e.hit(damage, global_position + off)
				struck[e] = true
				hit_any = true
				break
	if hit_any:
		_pulse = 1.0
		AgentBridge.emit_event("sfx_played", {"name": "orbit"})
		Sfx.play("orbit")

func _draw() -> void:
	if level <= 0:
		return
	# Faint ring marking the blades' path, then a steely blade glint at each blade.
	draw_arc(Vector2.ZERO, orbit_radius, 0.0, TAU, 48, Color(0.75, 0.85, 1.0, 0.12), 1.0)
	var bright := 0.6 + _pulse * 0.4
	for i in count:
		var a := _angle + float(i) * TAU / float(count)
		var lp := Vector2.from_angle(a) * orbit_radius
		var fwd := Vector2.from_angle(a + PI * 0.5)   # travel direction (tangent to the ring)
		var side := fwd.orthogonal()
		# A pointed steel blade leaning into its travel, with a bright core glint.
		var poly := PackedVector2Array([
			lp + fwd * 11.0, lp + side * 4.0, lp - fwd * 11.0, lp - side * 4.0,
		])
		draw_colored_polygon(poly, Color(0.82, 0.88, 1.0, 0.85))
		draw_circle(lp, 3.0, Color(1.0, 1.0, 1.0, bright))
