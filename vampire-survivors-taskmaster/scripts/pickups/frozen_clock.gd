class_name VSFrozenClock
extends Node2D
## Freeze Clock (Orologion) pickup — the Vampire Survivors time-stop lucky drop, the
## Rosary's complement. Rarely dropped on a kill / from a candelabra (see VSRun), it
## magnetizes toward a nearby player like the Rosary/Magnet, and on pickup HALTS every
## enemy in place for a few seconds (sets VSRun.freeze_until; VSEnemy._process skips its
## move + contact while frozen). Distinct from the Rosary's screen-clear: this is a
## breather to reposition, not a wipe — enemies survive and your weapons still hit them.
## Grants no XP or HP itself; its payout is the pause it buys.

static var PICKUP := BalanceData.get_value("frozen_clock_pickup_radius", 26.0)
static var MAGNET := BalanceData.get_value("frozen_clock_magnet_radius", 110.0)            # same wide grab as the Rosary/Magnet — a treat worth reaching for
static var MAGNET_SPEED := BalanceData.get_value("frozen_clock_magnet_speed", 240.0)
static var FREEZE_DURATION := BalanceData.get_value("frozen_clock_freeze_duration", 4.0)     # seconds of game-time enemies stay frozen
# The source frozen_clock.png is a 256px canvas — huge beside the ~40px player/enemies.
# Scale it down to read as a proper grabbable pickup, matching the arena's sprite scale.
static var SPRITE_SCALE := BalanceData.get_value("frozen_clock_sprite_scale", 0.14)
const ICE := Color(0.6, 0.85, 1.15)   # icy blue so the freeze reads as a distinct event

var run: VSRun
var _t := 0.0                    # bob timer

func _ready() -> void:
	add_to_group("frozen_clocks")
	var sprite := Sprite2D.new()
	sprite.texture = load("res://art/frozen_clock.png")
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
	# Time-stop: freeze every enemy in place for FREEZE_DURATION of game-time. VSEnemy reads
	# run.is_frozen() each frame and skips its move + contact while active, so the player gets
	# a clean window to reposition without any enemy dying (that's the Rosary's job).
	if run:
		run.freeze_until = run.elapsed + FREEZE_DURATION
	AgentBridge.emit_event("pickup", {"type": "frozen_clock", "duration": FREEZE_DURATION})
	var parent := get_parent()
	if parent != null:
		# Icy bloom + label so the time-stop reads as a distinct, exciting event.
		VSPickupFlash.spawn(parent, position, ICE)
		VSFloatText.spawn(parent, position, "Freeze!", ICE)
	queue_free()
