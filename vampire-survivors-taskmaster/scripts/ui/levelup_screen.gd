class_name VSLevelUpScreen
extends CanvasLayer
## Modal upgrade picker shown on level-up. The run freezes (phase == "level_up")
## until the player picks one of 3 offered upgrades — with the mouse, or keys 1/2/3
## (which also reach the harness via the choose_1/2/3 actions). Emits `chosen(key)`
## with the selected upgrade's key; VSRun owns applying it and freeing this screen.

signal chosen(key: String)

## Per-upgrade icons (item art from SourceArt) shown to the LEFT of each choice so the
## pick reads at a glance, not just from text. Keyed by the same upgrade key as VSRun.UPGRADES;
## sources are square (64 or 256 px) so a 32px cap downscales by an integer ratio — crisp under
## the project's NEAREST filter (see VISUAL_RULES.md).
const ICONS := {
	"damage": preload("res://art/icons/damage.png"),
	"firerate": preload("res://art/icons/firerate.png"),
	"speed": preload("res://art/icons/speed.png"),
	"projectile": preload("res://art/icons/projectile.png"),
	"garlic": preload("res://art/icons/garlic.png"),
	"orbit": preload("res://art/icons/orbit.png"),
	"wand": preload("res://art/icons/wand.png"),
	"regen": preload("res://art/icons/regen.png"),
	"armor": preload("res://art/icons/armor.png"),
}
const ICON_MAX := 32   # cap icon width (px); 64->32 and 256->32 are integer downscales (crisp on NEAREST)

var _options: Array = []   ## Array of {key, title, desc} dicts (set before add_child).
var _owned: Dictionary = {}   ## upgrade key -> times already chosen (drives the Lv/NEW tag).
var _done := false

func setup(options: Array, owned: Dictionary = {}) -> void:
	_options = options
	_owned = owned

func _ready() -> void:
	layer = 100   # above the HUD's CanvasLayer

	# Dim the frozen world so the choice reads as a modal moment.
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	# Centred column: title + one button per offered upgrade.
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	var title := Label.new()
	title.text = "LEVEL UP!  —  choose an upgrade"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)

	for i in _options.size():
		var opt: Dictionary = _options[i]
		var key := str(opt.get("key", ""))
		var owned := int(_owned.get(key, 0))
		var tag := "NEW" if owned == 0 else "Lv%d" % owned
		var btn := Button.new()
		btn.text = "[%d]  %s (%s) — %s" % [i + 1, str(opt.get("title", "")), tag, str(opt.get("desc", ""))]
		btn.custom_minimum_size = Vector2(380, 46)
		btn.add_theme_font_size_override("font_size", 16)
		# Weapon/passive icon to the LEFT of the label. icon_max_width caps it (preserving aspect),
		# left alignment pins it to the button's leading edge, h_separation gaps it from the text.
		var icon: Texture2D = ICONS.get(key, null)
		if icon != null:
			btn.icon = icon
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.add_theme_constant_override("icon_max_width", ICON_MAX)
			btn.add_theme_constant_override("h_separation", 10)
		btn.pressed.connect(func() -> void: _choose(key))
		box.add_child(btn)
		if i == 0:
			btn.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	# Number-key / harness shortcuts. Mouse clicks fire each Button's `pressed`.
	for i in _options.size():
		if event.is_action_pressed("choose_%d" % (i + 1)):
			_choose(str(_options[i].get("key", "")))
			get_viewport().set_input_as_handled()
			return

func _choose(key: String) -> void:
	if _done or key == "":
		return
	_done = true
	chosen.emit(key)
