class_name VSCandelabraShatter
extends Node2D
## One-shot golden shard/spark burst spawned when a candelabra shatters. Purely cosmetic:
## it self-frees and touches no gameplay state. Each shard flies outward, falls under a little
## gravity, spins, and fades — so breaking a light source reads as a satisfying pop of debris.

static var DURATION := BalanceData.get_value("candelabra_shatter_duration", 0.5)
static var SHARDS: int = int(BalanceData.get_value("candelabra_shatter_shards", 9.0))
static var SPEED_MIN := BalanceData.get_value("candelabra_shatter_speed_min", 70.0)
static var SPEED_MAX := BalanceData.get_value("candelabra_shatter_speed_max", 190.0)
static var GRAVITY := BalanceData.get_value("candelabra_shatter_gravity", 260.0)            # px/s^2 pulling debris back down as it arcs out

# Per-shard state, all indexed together.
var _dirs: Array[Vector2] = []    # initial velocity (px/s)
var _sizes: Array[float] = []     # half-length of each shard
var _colors: Array[Color] = []    # golden spark/debris tints
var _spins: Array[float] = []     # rotation speed (rad/s)
var _t := 0.0                     # 0..1 progress

## Drop a shatter burst at `at` (in `parent`'s coordinate space).
static func spawn(parent: Node, at: Vector2) -> void:
	var fx := VSCandelabraShatter.new()
	fx.position = at
	parent.add_child(fx)

func _ready() -> void:
	for i in SHARDS:
		var ang := randf() * TAU
		var speed := randf_range(SPEED_MIN, SPEED_MAX)
		_dirs.append(Vector2.RIGHT.rotated(ang) * speed)
		_sizes.append(randf_range(2.0, 5.0))
		# Mix bright sparks with warmer amber debris for a golden shatter.
		var warm := randf()
		_colors.append(Color(1.0, 0.95, 0.6).lerp(Color(1.0, 0.7, 0.25), warm))
		_spins.append(randf_range(-8.0, 8.0))
	var tw := create_tween()
	tw.tween_method(_advance, 0.0, 1.0, DURATION)
	tw.tween_callback(queue_free)

func _advance(t: float) -> void:
	_t = t
	queue_redraw()

func _draw() -> void:
	var elapsed := _t * DURATION
	var fade := 1.0 - _t
	for i in SHARDS:
		# Ballistic arc: outward drift plus accumulating gravity.
		var pos := _dirs[i] * elapsed + Vector2.DOWN * (0.5 * GRAVITY * elapsed * elapsed)
		var half := _sizes[i] * fade
		var rot := _spins[i] * elapsed
		var dir := Vector2.RIGHT.rotated(rot) * half
		var col := Color(_colors[i].r, _colors[i].g, _colors[i].b, 0.9 * fade)
		draw_line(pos - dir, pos + dir, col, maxf(1.0, half * 0.6))
