class_name VSShopScreen
extends CanvasLayer
## Between-run PowerUp shop, VS-style: spend banked meta-coins (user://meta_save.json) on
## PERMANENT starting-stat boosts that apply at the start of every future run.
##
## The slice boots straight into a run with no main menu, so the shop lives on the game-over
## screen: you die, this run's gold banks into the meta purse, then you can pour those coins
## into PowerUps before pressing Enter to retry. Opened with B from VSRun._unhandled_input.
##
## Reads its rows from VSRun.POWERUPS (title/desc/cost/max) exactly as the level-up picker
## reads UPGRADE_POOL, and buys through MetaSave.buy_powerup (atomic coin-debit + level-bump).
## Built in code to match the rest of the UI; swap in Kenney art as the UI lane matures.

const PANEL_TEX := "res://art/ui_panel.png"
const PANEL_TEX_SEL := "res://art/ui_panel_sel.png"

var _root: Control
var _coins_label: Label
var _rows: VBoxContainer
var _buy_buttons: Array[Button] = []

func _ready() -> void:
	layer = 11                       # above the level-up picker (10) and HUD
	visible = false

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	center.add_child(col)

	var title := Label.new()
	title.text = "POWER UP SHOP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	col.add_child(title)

	_coins_label = Label.new()
	_coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coins_label.add_theme_font_size_override("font_size", 18)
	_coins_label.modulate = Color(0.95, 0.82, 0.35)   # coin gold
	col.add_child(_coins_label)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 6)
	col.add_child(_rows)

	var hint := Label.new()
	hint.text = "Buy with the button or number keys · Esc / B to return to retry"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.modulate = Color(0.8, 0.8, 0.8)
	col.add_child(hint)

## Show the shop and (re)build its rows from the current persisted balance/levels.
func open() -> void:
	visible = true
	_refresh()
	if not _buy_buttons.is_empty():
		_buy_buttons[0].grab_focus()

func close() -> void:
	visible = false

## Rebuild every PowerUp row against the freshly-loaded coins + purchased levels so the
## display always mirrors what's actually on disk after each buy.
func _refresh() -> void:
	var coins := MetaSave.load_coins()
	var levels := MetaSave.load_powerups()
	_coins_label.text = "Coins  %d" % coins
	for c in _rows.get_children():
		c.queue_free()
	_buy_buttons.clear()
	for i in VSRun.POWERUPS.size():
		var opt: Dictionary = VSRun.POWERUPS[i]
		var lvl := int(levels.get(opt["id"], 0))
		_rows.add_child(_make_row(i, opt, lvl, coins))

## One shop row: title, "Lv N/max", description, and a Buy button showing the cost. The
## button disables at the cap ("MAX") or when the coins won't cover the next level.
func _make_row(index: int, opt: Dictionary, lvl: int, coins: int) -> Control:
	var mx := int(opt["max"])
	var cost := VSRun.powerup_cost(int(opt["cost"]), lvl)   # next-level price, scales with level
	var maxed := lvl >= mx
	var affordable := coins >= cost

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _panel_style(false))
	card.custom_minimum_size = Vector2(560, 0)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 10)
	card.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var badge := Label.new()
	badge.text = str(index + 1)
	badge.custom_minimum_size = Vector2(22, 0)
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 22)
	row.add_child(badge)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_col)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	text_col.add_child(name_row)

	var title := Label.new()
	title.text = str(opt.get("title", "?"))
	title.add_theme_font_size_override("font_size", 20)
	name_row.add_child(title)

	var lvl_label := Label.new()
	lvl_label.text = "Lv %d/%d" % [lvl, mx]
	lvl_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lvl_label.add_theme_font_size_override("font_size", 14)
	if maxed:
		lvl_label.modulate = Color(0.95, 0.82, 0.35)   # gold = maxed
	name_row.add_child(lvl_label)

	var desc := Label.new()
	desc.text = str(opt.get("desc", ""))
	desc.add_theme_font_size_override("font_size", 13)
	desc.modulate = Color(0.85, 0.9, 1.0)
	text_col.add_child(desc)

	var buy := Button.new()
	buy.custom_minimum_size = Vector2(120, 40)
	buy.focus_mode = Control.FOCUS_ALL
	if maxed:
		buy.text = "MAX"
		buy.disabled = true
	else:
		buy.text = "Buy  %d" % cost
		buy.disabled = not affordable
	buy.pressed.connect(_buy.bind(index))
	row.add_child(buy)
	_buy_buttons.append(buy)

	return card

func _panel_style(selected: bool) -> StyleBoxTexture:
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
	return sb

## Attempt to buy the PowerUp at `index`. MetaSave.buy_powerup is the gatekeeper — it
## rejects the purchase (returns false, no change) if the coins won't cover it or the
## level is already maxed — so we just refresh to reflect whatever actually happened.
func _buy(index: int) -> void:
	if index < 0 or index >= VSRun.POWERUPS.size():
		return
	var opt: Dictionary = VSRun.POWERUPS[index]
	var lvl := MetaSave.powerup_level(str(opt["id"]))
	var cost := VSRun.powerup_cost(int(opt["cost"]), lvl)   # price for the level being bought
	MetaSave.buy_powerup(str(opt["id"]), cost, int(opt["max"]))
	_refresh()
	# Keep a sensible focus target after the rows were rebuilt.
	if index < _buy_buttons.size():
		_buy_buttons[index].grab_focus()
	elif not _buy_buttons.is_empty():
		_buy_buttons[0].grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("open_shop") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
		return
	for i in VSRun.POWERUPS.size():
		var action := "upgrade_%d" % (i + 1)
		if InputMap.has_action(action) and event.is_action_pressed(action):
			get_viewport().set_input_as_handled()
			_buy(i)
			return
