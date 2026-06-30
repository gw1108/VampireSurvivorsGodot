class_name VSAura
extends Node2D
## "Garlic" — a damaging halo that hugs the player. On a fixed tick it wounds EVERY
## enemy inside its radius: no aim, no chase, it just punishes anything that draws near.
## The iconic Vampire Survivors swarm-clearer and a real mid-run power spike — picked and
## levelled through the level-up screen (see VSRun.UPGRADES / apply_upgrade("garlic")).
## Drawn with primitives like the other juice (impact spark / gem sparkle), not a sprite.

const TICK := 0.5            # seconds between damage ticks
const PULSE_DUR := 0.18      # how long the visual swell after a tick lasts

var run: VSRun
var radius := 70.0           # damage reach; widens on each Garlic pick
var damage := 3.0            # per-tick damage; deepens on each Garlic pick
var level := 0               # how many times Garlic has been chosen (drives the power curve)
var _cd := 0.0
var _pulse := 0.0            # 1 -> 0 right after a tick, swelling the halo so the bite reads

func _ready() -> void:
	z_index = -10            # under the player/enemy sprites so it reads as a ground-hugging halo

func level_up() -> void:
	# Each Garlic pick widens the halo and deepens the bite — a real spike, soft-capped by feel.
	level += 1
	if level == 1:
		radius = 70.0
		damage = 3.0
	else:
		radius += 22.0
		damage += 2.0
	queue_redraw()

func _process(delta: float) -> void:
	if run == null or run.phase != "playing":
		return   # freeze with the world (level-up picker / game over)
	if _pulse > 0.0:
		_pulse = maxf(0.0, _pulse - delta / PULSE_DUR)
	_cd -= delta
	if _cd <= 0.0:
		_tick()
		_cd = TICK
	queue_redraw()

func _tick() -> void:
	_pulse = 1.0
	# get_nodes_in_group returns a snapshot, and hit() only marks the corpse _dying (frees
	# later) + drops it from the group, so wounding many in one loop is safe and never doubles.
	var hit_any := false
	for e in get_tree().get_nodes_in_group("enemies"):
		if (e.position - global_position).length() < radius + e.radius:
			e.hit(damage, global_position)
			hit_any = true
	if hit_any:
		AgentBridge.emit_event("sfx_played", {"name": "garlic"})
		Sfx.play("garlic")

func _draw() -> void:
	if level <= 0:
		return
	# A faint pale-green haze that swells on each tick — bright enough to read on the dark ground.
	var pulse_r := radius * (1.0 + _pulse * 0.06)
	var fill := Color(0.70, 0.90, 0.50, 0.10 + _pulse * 0.08)
	draw_circle(Vector2.ZERO, pulse_r, fill)
	draw_arc(Vector2.ZERO, pulse_r, 0.0, TAU, 48, Color(0.85, 1.0, 0.6, 0.35 + _pulse * 0.30), 2.0)
