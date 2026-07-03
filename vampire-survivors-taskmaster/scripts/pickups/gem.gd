class_name VSGem
extends Node2D
## XP gem dropped on enemy death. Magnetizes toward a nearby player and grants XP on
## pickup. Feeds the level counter (the upgrade/level-up screen is the next milestone).

const RADIUS := 6.0
const PICKUP := 24.0
const MAGNET := 95.0
const MAGNET_SPEED := 240.0

var run: VSRun
var value := 1   # XP granted on pickup; scaled by the enemy that dropped it

func _ready() -> void:
	add_to_group("gems")
	var sprite := Sprite2D.new()
	sprite.texture = load("res://art/gem.png")
	add_child(sprite)

func _process(delta: float) -> void:
	if run == null or run.phase != "playing" or run.player == null or not is_instance_valid(run.player):
		return
	var pl := run.player
	var to := pl.position - position
	var d := to.length()
	if d < MAGNET and d > 0.5:
		position += to / d * MAGNET_SPEED * delta
	if d < PICKUP + VSPlayer.RADIUS:
		run.collect_xp(value)
		AgentBridge.emit_event("pickup", {"type": "xp"})
		queue_free()
		return
