class_name VSNduja
extends Node2D
## Nduja Fritta Tanta pickup — the Vampire Survivors "go berserk" lucky drop, a fiery cousin
## of the Rosary/Orologion. Rarely dropped from a shattered candelabra (see VSRun), it
## magnetizes toward a nearby player like the other treats, and on pickup wreathes the player
## in flame for a few seconds: they take NO contact damage AND a burning aura sears every
## enemy they plough through (see VSPlayer._process, which reads run.is_nduja_active()). Unlike
## the Rosary's one-shot screen-clear or the Orologion's freeze, this is a mobile power fantasy —
## charge into the horde untouchable and melt it. Grants no XP or HP itself.

static var DURATION := BalanceData.get_value("nduja_duration", 8.0)            # seconds of game-time the fiery invincibility lasts
const FIRE := Color(1.5, 0.55, 0.2)   # hot orange so the berserk treat reads as a distinct event

var run: VSRun
var _t := 0.0                    # bob timer

func _ready() -> void:
	add_to_group("ndujas")
	var sprite := Sprite2D.new()
	sprite.texture = load("res://art/pickup_nduja.png")
	VSPickup.apply(sprite)
	add_child(sprite)

func _process(delta: float) -> void:
	if run == null or run.phase != "playing" or run.player == null or not is_instance_valid(run.player):
		return
	# Gentle bob so it reads as a live, grabbable pickup rather than debris.
	_t += delta
	scale = Vector2.ONE * (1.0 + 0.06 * sin(_t * 4.0))
	var pl := run.player
	var to := pl.position - position
	var d := to.length()
	if d < VSPickup.MAGNET_RADIUS * run.pickup_range_mult and d > 0.5:
		position += to / d * VSPickup.MAGNET_SPEED * delta
	if d < VSPickup.GRAB_RADIUS + VSPlayer.PICKUP_RADIUS:
		_collect()

func _collect() -> void:
	# Fiery invincibility: arm the run window that VSPlayer reads each frame to (a) ignore all
	# contact damage and (b) burn nearby enemies. Measured in the run's own `elapsed` clock so it
	# pauses cleanly with the game during level-up. A fresh pickup refreshes to the full duration.
	if run:
		run.nduja_until = run.elapsed + DURATION
	AgentBridge.emit_event("pickup", {"type": "nduja", "duration": DURATION})
	var parent := get_parent()
	if parent != null:
		# Fiery bloom + label so the berserk buff reads as a distinct, exciting event.
		VSPickupFlash.spawn(parent, position, FIRE)
		VSFloatText.spawn(parent, position, "Nduja!", FIRE)
	if run:
		run.add_camera_shake(0.5)
	queue_free()
