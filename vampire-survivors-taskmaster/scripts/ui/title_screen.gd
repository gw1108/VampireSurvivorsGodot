class_name VSTitleScreen
extends CanvasLayer
## The run's title / main menu, GDD MVP: "Main menu -> Start -> straight into Mad Forest".
##
## A lightweight full-screen overlay shown at run start while VSRun sits in its "title" phase
## (the whole world is frozen — nothing keys off "title", only "playing"). Start (Enter or the
## button) flips the run into play; B drops into the between-run PowerUp shop so meta-coins can
## be spent before diving in. Built in code to match the rest of the UI (HUD/shop), styled with
## the same panel art.
##
## Harness note: this menu is INERT for autonomous playtests — VSRun auto-starts past it the
## instant the AgentBridge is live, so the agent_play harness never has to press a title button.
## Kept purely so human play gets the GDD's front door.

signal start_requested
signal shop_requested

const PANEL_TEX := "res://art/ui_panel.png"

var _root: Control
var _coins_label: Label
var _start_button: Button

func _ready() -> void:
	layer = 12                       # above the shop (11) so the title sits on top until Start
	visible = false

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.05, 0.82)
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
	title.text = "VAMPIRE SURVIVORS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", Color(0.85, 0.18, 0.2))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("outline_size", 6)
	col.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "MAD FOREST"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.modulate = Color(0.8, 0.85, 0.95)
	col.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	col.add_child(spacer)

	_start_button = Button.new()
	_start_button.text = "START"
	_start_button.custom_minimum_size = Vector2(220, 52)
	_start_button.focus_mode = Control.FOCUS_ALL
	_start_button.add_theme_font_size_override("font_size", 24)
	_start_button.pressed.connect(func() -> void: start_requested.emit())
	col.add_child(_start_button)

	_coins_label = Label.new()
	_coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coins_label.add_theme_font_size_override("font_size", 16)
	_coins_label.modulate = Color(0.95, 0.82, 0.35)   # coin gold
	col.add_child(_coins_label)

	var hint := Label.new()
	hint.text = "Enter / click START to play  ·  B for the PowerUp shop  ·  WASD to move"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.modulate = Color(0.78, 0.78, 0.82)
	col.add_child(hint)

## Show the title and refresh the banked-coin readout so the player sees their meta purse
## before choosing to spend it in the shop or dive straight in.
func open() -> void:
	visible = true
	_coins_label.text = "Coins Banked  %d" % MetaSave.load_coins()
	if _start_button:
		_start_button.grab_focus()

func close() -> void:
	visible = false
