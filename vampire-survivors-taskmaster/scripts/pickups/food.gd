class_name VSFood
extends Node2D
## Roast-chicken food pickup — the iconic Vampire Survivors heal. Dropped from shattering a
## candelabra (the Floor Chicken entry, see VSRun.drop_candelabra_bonus), it magnetizes toward
## a nearby player and restores a chunk of HP on pickup, giving the survival loop a real
## recovery lever instead of relying solely on the rare Vitality upgrade. Cosmetic-only
## otherwise; grants no XP.

const PICKUP := 26.0
const MAGNET := 95.0
const MAGNET_SPEED := 240.0
const HEAL := 30.0            # HP restored on pickup (VS roast-chicken convention)

var run: VSRun
var _t := 0.0                 # bob timer

func _ready() -> void:
	add_to_group("food")
	var sprite := Sprite2D.new()
	sprite.texture = load("res://art/food_chicken.png")
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
	# Attractorb passive widens the base magnet radius so food flies in from farther.
	if d < MAGNET * run.pickup_range_mult and d > 0.5:
		position += to / d * MAGNET_SPEED * delta
	if d < PICKUP + VSPlayer.RADIUS:
		var healed := 0.0
		if pl.alive and pl.health < pl.max_health:
			var before := pl.health
			pl.health = minf(pl.max_health, pl.health + HEAL)
			healed = pl.health - before
		AgentBridge.emit_event("pickup", {"type": "food"})
		# Green healing bloom, parented to the world so it outlives this pickup.
		var parent := get_parent()
		if parent != null:
			VSPickupFlash.spawn(parent, position, Color(0.5, 1.0, 0.55))
			# Floating "+N" so the recovery reads clearly — only when HP actually rose.
			if healed > 0.0:
				VSFloatText.spawn(parent, position, "+%d" % int(round(healed)), Color(0.5, 1.0, 0.55))
		queue_free()
		return
