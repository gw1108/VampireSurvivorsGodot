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
## Set by a Magnet pickup: the gem homes on the player from anywhere on screen,
## ignoring the normal short-range MAGNET radius, so the whole field vacuums in.
var attracted := false

## Sprite tint per XP value so reward reads at a glance (blue=1, green=2, red=3+).
const VALUE_COLORS := {
	1: Color(0.45, 0.7, 1.0),   # blue
	2: Color(0.5, 1.0, 0.55),   # green
	3: Color(1.0, 0.45, 0.45),  # red
}

func _ready() -> void:
	add_to_group("gems")
	var sprite := Sprite2D.new()
	sprite.texture = load("res://art/gem.png")
	sprite.modulate = VALUE_COLORS.get(value, VALUE_COLORS[3])
	add_child(sprite)
	# Higher-value gems read bigger (1.0 at value 1, +0.12 per extra point).
	var s := 1.0 + 0.12 * float(maxi(value - 1, 0))
	scale = Vector2(s, s)

func _process(delta: float) -> void:
	if run == null or run.phase != "playing" or run.player == null or not is_instance_valid(run.player):
		return
	var pl := run.player
	var to := pl.position - position
	var d := to.length()
	# Attractorb passive widens the base magnet radius so gems fly in from farther.
	var mag := MAGNET * run.pickup_range_mult
	if (attracted or d < mag) and d > 0.5:
		position += to / d * MAGNET_SPEED * delta
	if d < PICKUP + VSPlayer.RADIUS:
		run.collect_xp(value)
		AgentBridge.emit_event("pickup", {"type": "xp"})
		# Cosmetic pickup pop: a ring bloom at the gem, parented to the world so it
		# outlives this gem. Tinted by value so richer gems flash brighter reward.
		var parent := get_parent()
		if parent != null:
			VSPickupFlash.spawn(parent, position, VALUE_COLORS.get(value, VALUE_COLORS[3]))
		queue_free()
		return
