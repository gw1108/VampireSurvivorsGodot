class_name VSOrbit
extends Node2D
## "King Bible" — N holy tomes that spin around the player and cut any enemy they sweep past.
## A melee orbit (Vampire Survivors' King Bible): no aim, no chase — it punishes
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
	# Faint gold ring marking the tomes' path, then a small spinning holy book at each point.
	draw_arc(Vector2.ZERO, orbit_radius, 0.0, TAU, 48, Color(0.95, 0.85, 0.50, 0.12), 1.0)
	var bright := 0.6 + _pulse * 0.4
	for i in count:
		var a := _angle + float(i) * TAU / float(count)
		var lp := Vector2.from_angle(a) * orbit_radius
		# The book's local basis spins with the ring so each tome tumbles as it flies.
		var along := Vector2.from_angle(a + PI * 0.5)   # spine axis, tangent to travel
		var flat := along.orthogonal()                  # across the cover (radial)
		_draw_tome(lp, along, flat, bright)

func _draw_tome(lp: Vector2, along: Vector2, flat: Vector2, bright: float) -> void:
	# A small closed holy book: cream cover, dark spine on one long edge, bright page fore-edge on the
	# other, and a gold cross on the face — brightened on a connecting tick so the cut still reads.
	const HL := 9.0    # half-length (down the spine)
	const HW := 6.5    # half-width (across the closed cover)
	var cover := Color(0.90, 0.86, 0.72).lerp(Color(1.0, 1.0, 1.0), _pulse * 0.5)
	draw_colored_polygon(PackedVector2Array([
		lp + along * HL + flat * HW, lp + along * HL - flat * HW,
		lp - along * HL - flat * HW, lp - along * HL + flat * HW,
	]), cover)
	# Dark leather spine band on the -flat edge.
	draw_colored_polygon(PackedVector2Array([
		lp + along * HL - flat * HW, lp + along * HL - flat * (HW - 2.0),
		lp - along * HL - flat * (HW - 2.0), lp - along * HL - flat * HW,
	]), Color(0.42, 0.24, 0.14, 0.95))
	# Bright page fore-edge on the +flat edge.
	draw_colored_polygon(PackedVector2Array([
		lp + along * (HL - 1.0) + flat * HW, lp + along * (HL - 1.0) + flat * (HW - 2.0),
		lp - along * (HL - 1.0) + flat * (HW - 2.0), lp - along * (HL - 1.0) + flat * HW,
	]), Color(1.0, 0.98, 0.90, 0.95))
	# Gold cross on the cover face.
	var gold := Color(0.85, 0.70, 0.28, bright)
	draw_line(lp - along * (HL * 0.55), lp + along * (HL * 0.5), gold, 1.5)
	draw_line(lp + along * (HL * 0.1) - flat * (HW * 0.45), lp + along * (HL * 0.1) + flat * (HW * 0.45), gold, 1.5)
