class_name VSGem
extends Node2D
## XP gem dropped on enemy death. Magnetizes toward a nearby player and grants XP on
## pickup. Feeds the level counter (the upgrade/level-up screen is the next milestone).

static var RADIUS := BalanceData.get_value("gem_radius", 6.0)
static var PICKUP := BalanceData.get_value("gem_pickup_radius", 24.0)
static var MAGNET := BalanceData.get_value("gem_magnet_radius", 95.0)
static var MAGNET_SPEED := BalanceData.get_value("gem_magnet_speed", 240.0)

var run: VSRun
var value := 1   # XP granted on pickup; scaled by the enemy that dropped it
## Set by a Magnet pickup: the gem homes on the player from anywhere on screen,
## ignoring the normal short-range MAGNET radius, so the whole field vacuums in.
var attracted := false
## Marks this gem as the on-ground-cap accumulator: the wiki's rule folds all excess XP into a
## single RED gem, so once flagged it renders red regardless of its numeric value tier.
var is_accumulator := false

var _sprite: Sprite2D

## Sprite tint per XP value so reward reads at a glance (blue=1, green=2, red=3+).
const VALUE_COLORS := {
	1: Color(0.45, 0.7, 1.0),   # blue
	2: Color(0.5, 1.0, 0.55),   # green
	3: Color(1.0, 0.45, 0.45),  # red
}
## Cap the per-value scale growth: an ordinary red gem tops out here, and a heavily-merged
## gem (from the on-ground cap folding many drops together) stays chunky instead of ballooning
## across the screen. 8 steps -> ~1.96x, matching the wiki's "Red 9+" tier feel.
static var MAX_VISUAL_STEPS: int = int(BalanceData.get_value("gem_max_visual_steps", 8.0))

func _ready() -> void:
	add_to_group("gems")
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://art/gem.png")
	add_child(_sprite)
	_refresh_visual()

## Fold another drop's XP into this gem. The GDD's on-ground gem cap merges excess drops into
## existing gems rather than spawning unbounded nodes; the absorbing gem reddens and fattens so
## it reads as the richer reward it now carries. When the cap folds a drop into an on-screen gem
## (as_accumulator), that gem is forced red per the wiki's "single red gem" rule.
func absorb(extra: int, as_accumulator: bool = false) -> void:
	value += maxi(extra, 0)
	if as_accumulator:
		is_accumulator = true
	_refresh_visual()

## Tint + size the gem from its current value (blue=1, green=2, red=3+; bigger = richer),
## clamped so a merged gem never grows past MAX_VISUAL_STEPS. A cap accumulator is always red.
func _refresh_visual() -> void:
	if _sprite:
		_sprite.modulate = VALUE_COLORS[3] if is_accumulator else VALUE_COLORS.get(value, VALUE_COLORS[3])
	# Higher-value gems read bigger (1.0 at value 1, +0.12 per extra point, capped).
	var s := 1.0 + 0.12 * float(clampi(value - 1, 0, MAX_VISUAL_STEPS))
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
