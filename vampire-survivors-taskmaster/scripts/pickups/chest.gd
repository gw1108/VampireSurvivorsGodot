class_name VSChest
extends Node2D
## Treasure Chest — the VS build-spike reward dropped by an elite (mini-boss) kill. Walk over it
## to open it: it grants a short burst of random upgrades plus gold (see VSRun.open_chest), the
## faithful "chest = burst of power" moment that carries the back half of a run. Drawn in code as
## a small brown box with a gold lid so it reads as loot without a bespoke sprite (art is a later
## pass per the GDD). Magnetizes at close range like the other pickups so it's easy to grab.

const PICKUP := 26.0
const MAGNET := 80.0
const MAGNET_SPEED := 200.0

var run: VSRun
var _t := 0.0                 # bob timer

func _ready() -> void:
	add_to_group("chest")
	z_index = 1               # read on top of the ground/aura, like the other reward pickups
	queue_redraw()

func _process(delta: float) -> void:
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
		var parent := get_parent()
		run.open_chest(position)
		AgentBridge.emit_event("pickup", {"type": "chest"})
		# Gold reward bloom, parented to the world so it outlives this pickup.
		if parent != null:
			VSPickupFlash.spawn(parent, position, Color(1.0, 0.85, 0.3))
		queue_free()
		return

## A small brown chest with a gold lid, seam-band and lock, centred on the node. Kept a few
## simple rects so it reads clearly against a dense horde and scales cleanly with the bob.
func _draw() -> void:
	var body := Color(0.45, 0.28, 0.12)
	var lid := Color(0.72, 0.5, 0.18)
	var trim := Color(1.0, 0.85, 0.3)
	var w := 20.0
	var h := 16.0
	draw_rect(Rect2(-w * 0.5, -h * 0.35, w, h * 0.7), body)               # body
	draw_rect(Rect2(-w * 0.5, -h * 0.6, w, h * 0.3), lid)                 # lid (top band)
	draw_rect(Rect2(-w * 0.5, -h * 0.34, w, 2.5), trim)                   # gold seam band
	draw_rect(Rect2(-2.5, -h * 0.42, 5.0, 6.0), trim)                     # lock
	draw_rect(Rect2(-w * 0.5, -h * 0.6, w, h * 0.9), Color(0, 0, 0, 0.85), false, 1.5)  # outline
