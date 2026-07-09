class_name VSGildedClover
extends Node2D
## Gilded Clover pickup — a rare, high-level candelabra drop (see VSRun.CANDELABRA_TABLE /
## drop_candelabra_bonus, unlocked at player level 30) that instantly banks every VSCoin
## currently on screen and starts a Gold Fever (Gilded_Clover.md: "Gathers all Gold left on
## the ground and starts a Gold Fever"). See VSRun.start_gold_fever / is_gold_fever_active for
## the fever window itself.

static var PICKUP := BalanceData.get_value("gilded_clover_pickup_radius", 26.0)
static var MAGNET := BalanceData.get_value("gilded_clover_magnet_radius", 110.0)            # same wide grab as the Rosary/Nduja/Orologion treats
static var MAGNET_SPEED := BalanceData.get_value("gilded_clover_magnet_speed", 240.0)
# The source clover_gold.png is a 256px canvas — huge beside the ~40px player/enemies.
# Scale it down to read as a proper grabbable pickup, matching the arena's sprite scale.
static var SPRITE_SCALE := BalanceData.get_value("gilded_clover_sprite_scale", 0.14)
const GOLD_FEVER_COLOR := Color(1.0, 0.85, 0.2)

var run: VSRun
var _t := 0.0                    # bob timer

func _ready() -> void:
	add_to_group("gilded_clovers")
	var sprite := Sprite2D.new()
	sprite.texture = load("res://art/clover_gold.png")
	sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
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
	if d < PICKUP + VSPlayer.PICKUP_RADIUS:
		_collect()

func _collect() -> void:
	# Gathers all Gold left on the ground: bank every VSCoin currently on screen instead of
	# making the player walk each one down. Looked up via this node's own tree (not run's —
	# VSRun itself isn't guaranteed to be in the tree, e.g. under this project's bare-state-bag
	# pickup tests), same pattern VSRosary uses for its screen-wide smite.
	var collected := 0
	for node in get_tree().get_nodes_in_group("coins"):
		if run and is_instance_valid(node) and node is VSCoin:
			run.add_gold(node.value)
			AgentBridge.emit_event("pickup", {"type": "coin", "gold": node.value})
			collected += 1
			node.queue_free()
	if run:
		run.start_gold_fever()
	AgentBridge.emit_event("pickup", {"type": "gilded_clover", "coins_collected": collected})
	var parent := get_parent()
	if parent != null:
		VSPickupFlash.spawn(parent, position, GOLD_FEVER_COLOR)
		VSFloatText.spawn(parent, position, "Gold Fever!", GOLD_FEVER_COLOR)
	if run:
		run.add_camera_shake(0.5)
	queue_free()
