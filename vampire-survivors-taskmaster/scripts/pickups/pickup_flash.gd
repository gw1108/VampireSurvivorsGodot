class_name VSPickupFlash
extends Node2D
## One-shot expanding+fading ring spawned when an XP gem is collected. Purely
## cosmetic: it self-frees and touches no gameplay state.

const DURATION := 0.28
const START_RADIUS := 3.0
const END_RADIUS := 15.0

var _t := 0.0
var _color := Color.WHITE

## Drop a flash at `at` (in `parent`'s coordinate space), tinted `color`.
static func spawn(parent: Node, at: Vector2, color: Color) -> void:
	var fx := VSPickupFlash.new()
	fx.position = at
	fx._color = color
	parent.add_child(fx)

func _ready() -> void:
	var tw := create_tween()
	tw.tween_method(_advance, 0.0, 1.0, DURATION)
	tw.tween_callback(queue_free)

func _advance(t: float) -> void:
	_t = t
	queue_redraw()

func _draw() -> void:
	var r := lerpf(START_RADIUS, END_RADIUS, _t)
	var fade := 1.0 - _t
	var ring := Color(_color.r, _color.g, _color.b, 0.85 * fade)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, ring, 0.5 + 2.0 * fade)
