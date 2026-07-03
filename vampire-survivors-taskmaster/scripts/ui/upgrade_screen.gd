class_name VSUpgradeScreen
extends CanvasLayer
## Level-up upgrade picker. Shown when the run hits an XP threshold: it dims the arena
## and offers 2-3 upgrade cards. Pick with the mouse or number keys 1-3. Selecting one
## calls back into VSRun to apply the upgrade and resume the run.
##
## Built in code to match the rest of the slice; swap in Kenney UI art as the UI lane
## matures. The run stays "paused" via VSRun.phase == "level_up" (entities gate on phase),
## so this node processes input normally without touching get_tree().paused.

signal picked(id: String)

var _root: Control
var _cards: VBoxContainer
var _options: Array = []

func _ready() -> void:
	layer = 10                       # above the HUD
	visible = false

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	center.add_child(col)

	var title := Label.new()
	title.text = "LEVEL UP!  —  choose an upgrade"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	col.add_child(title)

	_cards = VBoxContainer.new()
	_cards.add_theme_constant_override("separation", 8)
	col.add_child(_cards)

## options: Array of { "id": String, "title": String, "desc": String }.
func present(options: Array) -> void:
	_options = options
	for c in _cards.get_children():
		c.queue_free()
	for i in options.size():
		var opt: Dictionary = options[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(420, 56)
		btn.text = "[%d]  %s\n%s" % [i + 1, opt.get("title", "?"), opt.get("desc", "")]
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(_choose.bind(i))
		_cards.add_child(btn)
	visible = true
	if _cards.get_child_count() > 0:
		(_cards.get_child(0) as Button).grab_focus()

func option_count() -> int:
	return _options.size() if visible else 0

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	for i in _options.size():
		if event.is_action_pressed("upgrade_%d" % (i + 1)):
			get_viewport().set_input_as_handled()
			_choose(i)
			return

func _choose(index: int) -> void:
	if index < 0 or index >= _options.size():
		return
	var id := str(_options[index].get("id", ""))
	visible = false
	picked.emit(id)
