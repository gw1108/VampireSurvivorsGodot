class_name VSLittleClover
extends Node2D
## Little Clover pickup — a rare candelabra drop (see VSRun.CANDELABRA_TABLE /
## drop_candelabra_bonus) that permanently grants +10% Luck on pickup (Little_Clover.md).
## Unlike most candelabra drops its own drop rate is NOT boosted by Luck (wiki: "Drop rate
## affected by Luck: No"), and it can be collected an unlimited number of times per run —
## there is no cap, so run.luck_bonus simply keeps stacking.

static var LUCK_GAIN := BalanceData.get_value("little_clover_luck_gain", 10.0)          # % Luck granted per pickup (Little_Clover.md)
const LUCKY_GREEN := Color(0.5, 1.0, 0.5)

var run: VSRun
var _t := 0.0                    # bob timer

func _ready() -> void:
	add_to_group("little_clovers")
	var sprite := Sprite2D.new()
	sprite.texture = load("res://art/clover_green.png")
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
	if run:
		run.luck_bonus += LUCK_GAIN
	# Finding a Little Clover permanently unlocks the Clover level-up passive (VS-style), so it
	# starts appearing in future level-up rolls this run and in every run after. See VSRun._roll_upgrades.
	MetaSave.unlock(VSRun.CLOVER_UNLOCK_ID)
	AgentBridge.emit_event("pickup", {"type": "little_clover", "luck_bonus": run.luck_bonus if run else 0.0})
	var parent := get_parent()
	if parent != null:
		VSPickupFlash.spawn(parent, position, LUCKY_GREEN)
		VSFloatText.spawn(parent, position, "+%d%% Luck" % roundi(LUCK_GAIN), LUCKY_GREEN)
	queue_free()
