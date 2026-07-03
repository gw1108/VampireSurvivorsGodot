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

## Per-upgrade icon, mapped by option id. Weapon/passive sprites from
## SourceArt/extracted_clean (copied into res://art) so each choice reads at a glance:
## strength=Power, dusty tome=cooldown/Haste, boots=Swift, heart=Vitality,
## duplicator ring=Multishot, garlic bulb=Garlic aura, whip=Whip arc. Ids without an entry just render text.
const ICONS := {
	"damage": "res://art/up_damage.png",
	"firerate": "res://art/up_firerate.png",
	"speed": "res://art/up_speed.png",
	"health": "res://art/up_health.png",
	"multishot": "res://art/up_multishot.png",
	"garlic": "res://art/up_garlic.png",
	"whip": "res://art/up_whip.png",
	"bible": "res://art/up_bible.png",
	"unholy_vespers": "res://art/up_bible.png",   # King Bible evolution reuses the tome icon
}
const PANEL_TEX := "res://art/ui_panel.png"       # Kenney RPG panel (brown)
const PANEL_TEX_SEL := "res://art/ui_panel_sel.png"  # highlighted (blue) for hover/focus

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
		_cards.add_child(_make_card(i, options[i]))
	visible = true
	if _cards.get_child_count() > 0:
		(_cards.get_child(0) as Button).grab_focus()

## Build one upgrade card: a Kenney panel Button with a number badge, weapon/passive
## icon, and title/description. Inner controls ignore the mouse so the whole card is
## the click target and keyboard focus still highlights the selection.
func _make_card(index: int, opt: Dictionary) -> Button:
	var id := str(opt.get("id", ""))
	var is_evo := bool(opt.get("evolution", false))
	var card := Button.new()
	card.custom_minimum_size = Vector2(460, 96)
	card.text = ""
	card.add_theme_stylebox_override("normal", _panel_style(false, is_evo))
	card.add_theme_stylebox_override("hover", _panel_style(true, is_evo))
	card.add_theme_stylebox_override("pressed", _panel_style(true, is_evo))
	card.add_theme_stylebox_override("focus", _panel_style(true, is_evo))
	card.pressed.connect(_choose.bind(index))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 16)
	card.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	var badge := Label.new()
	badge.text = str(index + 1)
	badge.custom_minimum_size = Vector2(26, 0)
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 24)
	row.add_child(badge)

	if ICONS.has(id) and ResourceLoader.exists(ICONS[id]):
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(64, 64)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = load(ICONS[id])
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text_col)

	# Evolution cards get a loud gold "EVOLVED!" banner above the title so the one-shot
	# signature moment is unmistakable (the gold panel tint reinforces it at a glance).
	if is_evo:
		var evo_label := Label.new()
		evo_label.text = "★ EVOLVED! ★"
		evo_label.add_theme_font_size_override("font_size", 15)
		evo_label.modulate = Color(1.0, 0.85, 0.25)
		text_col.add_child(evo_label)

	var title := Label.new()
	title.text = str(opt.get("title", "?"))
	title.add_theme_font_size_override("font_size", 22)
	text_col.add_child(title)

	# Show the level this pick advances to (e.g. "Lv 2 → 3", or "→ 3 MAX" at the cap) so
	# the player reads the choice as progression toward maxing a weapon/passive.
	if opt.has("level"):
		var lvl := int(opt.get("level", 0))
		var mx := int(opt.get("max", 0))
		var next := lvl + 1
		var lvl_label := Label.new()
		lvl_label.text = "Lv %d → %d  (MAX)" % [lvl, next] if next >= mx else "Lv %d → %d" % [lvl, next]
		lvl_label.add_theme_font_size_override("font_size", 13)
		lvl_label.modulate = Color(0.9, 0.85, 0.55)
		text_col.add_child(lvl_label)

	var desc := Label.new()
	desc.text = str(opt.get("desc", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 15)
	text_col.add_child(desc)

	return card

## `evo` gives evolution cards a gold tint so the signature moment stands apart from
## the brown/blue normal panels even before you read the "EVOLVED!" label.
func _panel_style(selected: bool, evo: bool = false) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(PANEL_TEX_SEL if selected else PANEL_TEX)
	sb.texture_margin_left = 15
	sb.texture_margin_right = 15
	sb.texture_margin_top = 15
	sb.texture_margin_bottom = 15
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	if evo:
		sb.modulate_color = Color(1.0, 0.82, 0.28) if selected else Color(1.0, 0.78, 0.2)
	return sb

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
