class_name VSCoin
extends Node2D
## Gold-coin pickup — the seed of Vampire Survivors' "coins" meta-currency. Occasionally
## dropped on kills (with a fatter chance from elites, see VSRun.add_kill), it magnetizes
## toward a nearby player like food/gems and increments the run's `gold` counter on pickup.
## Grants no XP or HP; it exists to bank currency for a future between-run meta-progression.

const PICKUP := 26.0
const MAGNET := 95.0
const MAGNET_SPEED := 240.0

var run: VSRun
var value := 1                # gold banked on pickup
var _t := 0.0                 # bob timer

func _ready() -> void:
	add_to_group("coins")
	var sprite := Sprite2D.new()
	sprite.texture = load("res://art/gold_coin.png")
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
	if d < MAGNET and d > 0.5:
		position += to / d * MAGNET_SPEED * delta
	if d < PICKUP + VSPlayer.RADIUS:
		_collect()

func _collect() -> void:
	run.add_gold(value)
	AgentBridge.emit_event("pickup", {"type": "coin", "gold": value})
	var parent := get_parent()
	if parent != null:
		# Gold bloom + "+N" so banking currency reads as a distinct little reward.
		VSPickupFlash.spawn(parent, position, Color(1.0, 0.85, 0.3))
		VSFloatText.spawn(parent, position, "+%d" % value, Color(1.0, 0.85, 0.3))
	queue_free()
