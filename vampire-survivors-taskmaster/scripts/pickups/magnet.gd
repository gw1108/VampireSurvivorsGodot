class_name VSMagnet
extends Node2D
## Magnet pickup — the Vampire Survivors "vacuum" reward. Dropped from shattering a candelabra
## (the Vacuum entry, see VSRun.drop_candelabra_bonus), it magnetizes toward a nearby player
## like food/gems, and on pickup marks EVERY on-screen XP gem `attracted` so the whole field
## homes in and is swept up at once. Grants no XP or HP itself; its payout is the gem harvest
## it triggers.

static var PICKUP := BalanceData.get_value("magnet_pickup_radius", 26.0)
static var MAGNET := BalanceData.get_value("magnet_magnet_radius", 110.0)          # slightly wider grab than food/gems — a treat worth reaching for
static var MAGNET_SPEED := BalanceData.get_value("magnet_magnet_speed", 240.0)
# The source magnet.png is a 256px canvas — huge beside the ~40px player/enemies.
# Scale it down to read as a proper grabbable pickup, matching the arena's sprite scale.
static var SPRITE_SCALE := BalanceData.get_value("magnet_sprite_scale", 0.14)

var run: VSRun
var _t := 0.0                 # bob timer

func _ready() -> void:
	add_to_group("magnets")
	var sprite := Sprite2D.new()
	sprite.texture = load("res://art/magnet.png")
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
	if d < PICKUP + VSPlayer.RADIUS:
		_collect()

func _collect() -> void:
	# Mark every gem on screen as attracted so they all vacuum to the player at once.
	var pulled := 0
	for g in get_tree().get_nodes_in_group("gems"):
		if is_instance_valid(g) and g is VSGem:
			g.attracted = true
			pulled += 1
	AgentBridge.emit_event("pickup", {"type": "magnet", "gems": pulled})
	var parent := get_parent()
	if parent != null:
		# Cyan bloom + label so the vacuum reads as a distinct, exciting event.
		VSPickupFlash.spawn(parent, position, Color(0.4, 0.85, 1.0))
		VSFloatText.spawn(parent, position, "Vacuum!", Color(0.4, 0.85, 1.0))
	queue_free()
