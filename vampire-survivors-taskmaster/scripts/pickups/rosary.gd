class_name VSRosary
extends Node2D
## Rosary pickup — the Vampire Survivors "screen clear" lucky drop. Dropped from shattering a
## candelabra (see VSRun.drop_candelabra_bonus), it magnetizes toward a nearby player like food/magnet,
## and on pickup smites EVERY on-screen enemy for a huge holy hit. Ordinary waves are wiped
## outright (their kills still pay out XP/gems/gold), while the enormous-HP finale Reaper and
## elite mini-bosses merely take a big dent — faithful to VS, where the Rosary clears the
## rabble but bosses endure. Grants no XP or HP itself; its payout is the carnage it triggers.

const PICKUP := 26.0
const MAGNET := 110.0           # same wide grab as the Magnet — a treat worth reaching for
const MAGNET_SPEED := 240.0
const SMITE_DAMAGE := 120.0     # enough to clear every normal archetype; bosses (140/600 HP) endure
# The source pickup_rosary.png is a 256px canvas — huge beside the ~40px player/enemies.
# Scale it down to read as a proper grabbable pickup, matching the arena's sprite scale.
const SPRITE_SCALE := 0.14

var run: VSRun
var _t := 0.0                   # bob timer

func _ready() -> void:
	add_to_group("rosaries")
	var sprite := Sprite2D.new()
	sprite.texture = load("res://art/pickup_rosary.png")
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
	# Smite every enemy currently on screen. Routing through hit() means normal enemies play
	# their death pop and pay out XP/gems/gold exactly like any kill — a satisfying mass clear —
	# while bosses survive with a visible chunk taken off their health bar.
	var smote := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e is VSEnemy:
			e.hit(SMITE_DAMAGE, position)
			smote += 1
	AgentBridge.emit_event("pickup", {"type": "rosary", "enemies": smote})
	var parent := get_parent()
	if parent != null:
		# Gold holy bloom + label so the cleanse reads as a distinct, exciting event.
		VSPickupFlash.spawn(parent, position, Color(1.0, 0.92, 0.5))
		VSFloatText.spawn(parent, position, "Cleanse!", Color(1.0, 0.92, 0.5))
	# Extra jolt so the mass clear lands with weight.
	if run:
		run.add_camera_shake(0.6)
	queue_free()
