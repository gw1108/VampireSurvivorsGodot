class_name VSChest
extends Node2D
## Treasure Chest — the VS build-spike reward dropped by an elite (mini-boss) kill. Walk over it
## to open it: it grants a short burst of random upgrades plus gold (see VSRun.open_chest), the
## faithful "chest = burst of power" moment that carries the back half of a run. Uses a bespoke
## pixel-art chest sprite (art/pickup_chest.png) matching the other imported pickups, and does a
## quick lid-open pop when grabbed. Magnetizes at close range like the other pickups.

const PICKUP := 26.0
const MAGNET := 80.0
const MAGNET_SPEED := 200.0

var run: VSRun
var _t := 0.0                 # bob timer
var _sprite: Sprite2D
var _opening := false         # true once grabbed: play the lid-open pop, then free
var _open_t := 0.0            # lid-open animation timer

func _ready() -> void:
	add_to_group("chest")
	z_index = 1               # read on top of the ground/aura, like the other reward pickups
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://art/pickup_chest.png")
	add_child(_sprite)

func _process(delta: float) -> void:
	if _opening:
		_animate_open(delta)
		return
	if run == null or run.phase != "playing" or run.player == null or not is_instance_valid(run.player):
		return
	# Gentle bob so it reads as a live, grabbable reward rather than debris.
	_t += delta
	scale = Vector2.ONE * (1.0 + 0.07 * sin(_t * 3.5))
	var pl := run.player
	var to := pl.position - position
	var d := to.length()
	if d < MAGNET and d > 0.5:
		position += to / d * MAGNET_SPEED * delta
	if d < PICKUP + VSPlayer.RADIUS:
		_open()

func _open() -> void:
	_opening = true
	var parent := get_parent()
	run.open_chest(position)
	AgentBridge.emit_event("pickup", {"type": "chest"})
	# Gold reward bloom, parented to the world so it outlives this pickup.
	if parent != null:
		VSPickupFlash.spawn(parent, position, Color(1.0, 0.85, 0.3))

## Quick lid-open pop: the chest squashes down then springs up tall and fades, so opening it lands
## as a satisfying little burst before the node frees itself.
func _animate_open(delta: float) -> void:
	_open_t += delta
	const DUR := 0.18
	var f := clampf(_open_t / DUR, 0.0, 1.0)
	# Squash-then-stretch: brief downward squash, then pop up taller than life.
	var sx := 1.0 + 0.35 * sin(f * PI)
	var sy := 1.0 - 0.25 * sin(f * PI) + 0.5 * f
	scale = Vector2(sx, sy)
	position.y -= 40.0 * delta
	_sprite.modulate.a = 1.0 - f
	if f >= 1.0:
		queue_free()
