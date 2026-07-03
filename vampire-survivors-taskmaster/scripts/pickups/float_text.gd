class_name VSFloatText
extends Node2D
## One-shot floating text that rises and fades — the little "+30" heal pop. Purely
## cosmetic sibling to VSPickupFlash: it self-frees and touches no gameplay state.

const DURATION := 0.7
const RISE := 22.0            # pixels the label drifts upward over its life
const FONT_SIZE := 14

var _label: Label

## Drop floating `text` at `at` (in `parent`'s coordinate space), tinted `color`.
static func spawn(parent: Node, at: Vector2, text: String, color: Color) -> void:
	var ft := VSFloatText.new()
	ft.position = at
	ft._make_label(text, color)
	parent.add_child(ft)

func _make_label(text: String, color: Color) -> void:
	_label = Label.new()
	_label.text = text
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", color)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_label.add_theme_constant_override("outline_size", 4)
	# Centre the label over the spawn point rather than anchoring its top-left there.
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.position = Vector2(-24, -8)
	_label.size = Vector2(48, 16)
	add_child(_label)

func _ready() -> void:
	var start_y := position.y
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position:y", start_y - RISE, DURATION)
	tw.tween_property(_label, "modulate:a", 0.0, DURATION).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(queue_free)
