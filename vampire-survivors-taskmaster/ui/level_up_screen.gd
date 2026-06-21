class_name LevelUpScreen extends Control

## Modal overlay shown while GameState.phase == LEVEL_UP. Builds one button per
## offer option, emits option_chosen(index) on a press, and hides itself. The
## RunController wires option_chosen -> on_option_chosen and feeds offers in via
## level_up_started. Pure view: it never touches GameState.
##
## Correction vs the task sketch: option dicts are accessed with ["key"] (GDScript
## Dictionaries have no dot-access; `opt.is_upgrade` is a runtime error), and
## grab_focus is guarded so a max-state (empty) offer can't index an empty array.

signal option_chosen(index: int)

@onready var options_container: VBoxContainer = $Panel/VBoxContainer

var _option_buttons: Array[Button] = []


func _ready() -> void:
	hide()


func show_offer(offer: LevelUpOffer) -> void:
	_clear_buttons()
	for i in offer.options.size():
		var opt: Dictionary = offer.options[i]
		var btn := Button.new()
		btn.text = _format_option(opt)
		btn.pressed.connect(_on_option_pressed.bind(i))
		options_container.add_child(btn)
		_option_buttons.append(btn)
	show()
	if not _option_buttons.is_empty():
		_option_buttons[0].grab_focus()


func _format_option(opt: Dictionary) -> String:
	var def_name: String = opt["def"].name
	if opt["is_upgrade"]:
		var target: int = opt["target_level"]
		return "%s Lv %d → %d" % [def_name, target - 1, target]
	return "NEW: %s" % def_name


func _clear_buttons() -> void:
	for btn in _option_buttons:
		btn.queue_free()
	_option_buttons.clear()


func _on_option_pressed(index: int) -> void:
	hide()
	option_chosen.emit(index)
