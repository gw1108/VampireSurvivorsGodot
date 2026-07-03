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
signal rerolled           ## player asked for a fresh hand (VSRun spends a reroll + re-presents)
signal skipped            ## player waved off the level-up (VSRun resumes with no pick)

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
	"lightning": "res://art/up_lightning.png",
	"area": "res://art/candelabra.png",            # Candelabrador reuses the in-world Candelabrador pickup sprite
	"projspeed": "res://art/up_projspeed.png",     # Bracer (bracelet sprite)
	"attract": "res://art/magnet.png",             # Attractorb reuses the in-world Magnet sprite
	"growth": "res://art/gem.png",                 # Growth reuses the XP gem sprite
	"armor": "res://art/up_armor.png",             # Armor passive
	"knife": "res://art/projectile_dagger.png",   # reuse the in-world dagger bolt as the Knife icon
	"runetracer": "res://art/weapon_runetracer.png",  # the bouncing rune polyhedron sprite
	"fire_wand": "res://art/up_fire_wand.png",    # the flaming wand sprite (fireball weapon)
	"unholy_vespers": "res://art/up_bible.png",   # King Bible evolution reuses the tome icon
	"thunder_loop": "res://art/up_lightning.png", # Lightning Ring evolution reuses the ring icon
	"no_future": "res://art/weapon_runetracer.png", # Runetracer evolution reuses the rune sprite
	"bonus_gold": "res://art/gold_coin.png",       # consolation coin bag (pool exhausted)
	"bonus_chicken": "res://art/food_chicken.png", # consolation Floor Chicken heal (pool exhausted)
}
const PANEL_TEX := "res://art/ui_panel.png"       # Kenney RPG panel (brown)
const PANEL_TEX_SEL := "res://art/ui_panel_sel.png"  # highlighted (blue) for hover/focus

var _root: Control
var _cards: VBoxContainer
var _options: Array = []
var _reroll_btn: Button
var _skip_btn: Button
var _rerolls_left := 0
## Left build rail: the GDD's "full live stat readout and inventory grid" beside the choices.
## The picker's dim covers the top-right HUD loadout, so without this the player can't see their
## current build while weighing a pick; the rail restores that readout. Populated in present().
var _rail_panel: PanelContainer
var _rail_body: VBoxContainer
## Live run kept from present() so a card's focus/hover can re-render the rail with a
## before -> after preview of that pick's impact (the picker's dim hides the HUD readout).
var _run: VSRun
## Id of the currently keyboard-focused card; the rail falls back to previewing this when the
## mouse leaves a hovered card, so the readout tracks the pick you're actually about to commit.
var _focused_id := ""

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

	# Left build rail — a compact dark panel pinned to the far-left edge (clear of the centered
	# cards), populated each present() from the run's live stats + owned items. Mouse-ignored so
	# it never eats a card click; sized to its content so it grows with the build.
	_rail_panel = PanelContainer.new()
	_rail_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rail_panel.position = Vector2(16, 120)
	_rail_panel.visible = false
	_root.add_child(_rail_panel)

	_rail_body = VBoxContainer.new()
	_rail_body.custom_minimum_size = Vector2(196, 0)
	_rail_body.add_theme_constant_override("separation", 2)
	_rail_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rail_panel.add_child(_rail_body)

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

	# Build-agency row: Reroll (limited, spends a per-run budget) and Skip (always available)
	# so a weak hand is never forced. Buttons are small and sit under the cards; keys R / F
	# drive them too (see _unhandled_input).
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	col.add_child(actions)

	_reroll_btn = Button.new()
	_reroll_btn.custom_minimum_size = Vector2(220, 40)
	_reroll_btn.pressed.connect(_on_reroll_pressed)
	actions.add_child(_reroll_btn)

	_skip_btn = Button.new()
	_skip_btn.text = "Skip (+XP)  [F]"
	_skip_btn.custom_minimum_size = Vector2(160, 40)
	_skip_btn.pressed.connect(_on_skip_pressed)
	actions.add_child(_skip_btn)

## options: Array of { "id": String, "title": String, "desc": String }.
## rerolls_left: remaining reroll budget; the Reroll button disables at 0.
## run: the live VSRun, so the left rail can show the current stat readout + owned items
##      (the picker's dim hides the HUD, so this is the only build readout while choosing).
func present(options: Array, rerolls_left: int = 0, run: VSRun = null) -> void:
	_options = options
	_rerolls_left = rerolls_left
	_run = run
	_focused_id = ""
	for c in _cards.get_children():
		c.queue_free()
	for i in options.size():
		_cards.add_child(_make_card(i, options[i]))
	_refresh_action_buttons()
	_refresh_stat_rail(run)
	visible = true
	if _cards.get_child_count() > 0:
		(_cards.get_child(0) as Button).grab_focus()

## Populate the left build rail from the run's live stats and owned upgrades — the GDD's
## "full live stat readout and inventory grid" beside the choices. Hidden when no run is passed
## (backward-compatible callers). Rebuilt each present() so it always reflects the latest picks.
## preview_id: an upgrade option id (or "") — when set, the rail line(s) that pick would change
## render "before -> after" and highlight, so the impact reads before you commit (driven by card
## focus/hover). The preview map is keyed by the exact rail-line/item label it affects.
func _refresh_stat_rail(run: VSRun, preview_id := "") -> void:
	if _rail_panel == null:
		return
	if run == null:
		_rail_panel.visible = false
		return
	_rail_panel.visible = true
	for c in _rail_body.get_children():
		c.queue_free()
	var pv := _compute_preview(run, preview_id) if preview_id != "" else {}
	_add_rail_header("YOUR BUILD")
	var hp := 0
	var mhp := 0
	if run.player:
		hp = int(ceil(run.player.health))
		mhp = int(round(run.player.max_health))
	_add_rail_line("HP", "%d/%d" % [hp, mhp], pv.get("HP", ""))
	_add_rail_line("Damage", "%.0f" % run.weapon_damage, pv.get("Damage", ""))
	var rate := 1.0 / run.weapon_fire_interval if run.weapon_fire_interval > 0.0 else 0.0
	_add_rail_line("Fire Rate", "%.2f/s" % rate, pv.get("Fire Rate", ""))
	_add_rail_line("Move Speed", "%d%%" % int(round(run.player_speed_mult * 100.0)), pv.get("Move Speed", ""))
	_add_rail_line("Shots", "%d" % run.weapon_count, pv.get("Shots", ""))
	_add_rail_line("Area", "%d%%" % int(round(run.area_mult * 100.0)), pv.get("Area", ""))
	_add_rail_line("Proj Speed", "%d%%" % int(round(run.projectile_speed_mult * 100.0)), pv.get("Proj Speed", ""))
	_add_rail_line("Pickup", "%d%%" % int(round(run.pickup_range_mult * 100.0)), pv.get("Pickup", ""))
	_add_rail_line("XP Gain", "%d%%" % int(round(run.xp_gain_mult * 100.0)), pv.get("XP Gain", ""))
	_add_rail_line("Armor", "%d" % run.armor, pv.get("Armor", ""))
	_add_rail_line("Might", "%d%%" % int(round(run.might_mult() * 100.0)))
	# Owned inventory, in UPGRADE_POOL order so the list stays stable as picks come in.
	var owned := 0
	for opt in VSRun.UPGRADE_POOL:
		var lvl: int = run.upgrade_levels.get(opt["id"], 0)
		if lvl > 0:
			if owned == 0:
				_add_rail_header("ITEMS")
			owned += 1
			_add_rail_line(str(opt["title"]), "Lv %d" % lvl, pv.get(str(opt["title"]), ""))
	# A brand-new weapon/passive pick owns no line above, so synthesize one ("Whip  + NEW",
	# "Lv 0 → 1", green) — every card should give the rail some feedback, not read as "no impact".
	var new_item := str(pv.get("__new_item__", ""))
	if new_item != "":
		if owned == 0:
			_add_rail_header("ITEMS")
		_add_rail_line("%s  + NEW" % new_item, "Lv 0", "Lv 1")

## Map an upgrade option id to the rail line(s) it would change, keyed by the exact label the
## rail renders, valued with the "after" string in that line's own format. Mirrors _apply_upgrade
## in run.gd (+1 damage, x0.85 fire interval, x1.12 speed, ...) — keep the two in sync. Weapons/
## passives also bump their ITEMS "Lv N" line. Returns {} for ids with no rail impact.
func _compute_preview(run: VSRun, id: String) -> Dictionary:
	var out := {}
	match id:
		"damage":
			out["Damage"] = "%.0f" % (run.weapon_damage + 1.0)
		"firerate":
			var ni := maxf(0.12, run.weapon_fire_interval * 0.85)
			out["Fire Rate"] = "%.2f/s" % (1.0 / ni if ni > 0.0 else 0.0)
		"speed":
			out["Move Speed"] = "%d%%" % int(round(run.player_speed_mult * 1.12 * 100.0))
		"health":
			var mhp := 0.0
			var hp := 0.0
			if run.player:
				mhp = run.player.max_health + 20.0
				hp = minf(mhp, run.player.health + 20.0)
			out["HP"] = "%d/%d" % [int(ceil(hp)), int(round(mhp))]
		"multishot":
			out["Shots"] = "%d" % (run.weapon_count + 1)
		"area":
			out["Area"] = "%d%%" % int(round(run.area_mult * 1.10 * 100.0))
		"projspeed":
			out["Proj Speed"] = "%d%%" % int(round(run.projectile_speed_mult * 1.15 * 100.0))
		"attract":
			out["Pickup"] = "%d%%" % int(round(run.pickup_range_mult * 1.30 * 100.0))
		"growth":
			out["XP Gain"] = "%d%%" % int(round(run.xp_gain_mult * 1.08 * 100.0))
		"armor":
			out["Armor"] = "%d" % (run.armor + 1)
	# Owned weapons/passives also advance their ITEMS "Lv N" line (only rendered when owned).
	# A not-yet-owned pick (lvl == 0) with no dedicated stat row above (i.e. a weapon/passive, not a
	# stat boost like Power/Haste) has nothing on the rail to change, so flag it under __new_item__ so
	# the rail can synthesize a "+ NEW" row — otherwise a brand-new weapon/passive reads as no impact.
	var has_stat_preview := not out.is_empty()
	for opt in VSRun.UPGRADE_POOL:
		if str(opt["id"]) == id:
			var lvl: int = run.upgrade_levels.get(id, 0)
			out[str(opt["title"])] = "Lv %d" % (lvl + 1)
			if lvl == 0 and not has_stat_preview:
				out["__new_item__"] = str(opt["title"])
	return out

## A dim section header row for the build rail (e.g. "YOUR BUILD", "ITEMS"), with a little
## top padding on any header after the first so the sections read apart.
func _add_rail_header(text: String) -> void:
	if _rail_body.get_child_count() > 0:
		var pad := Control.new()
		pad.custom_minimum_size = Vector2(0, 6)
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rail_body.add_child(pad)
	var head := Label.new()
	head.text = text
	head.add_theme_font_size_override("font_size", 12)
	head.modulate = Color(0.7, 0.72, 0.8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rail_body.add_child(head)

## One name/value row on the build rail: the label left, the value right-aligned so the
## column of numbers reads cleanly. When `after` is a non-empty value different from the
## current one, the row renders "before -> after" and turns green to flag the focused/hovered
## pick's impact on that stat.
func _add_rail_line(name: String, value: String, after := "") -> void:
	var changed := after != "" and after != value
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_lbl := Label.new()
	name_lbl.text = name
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if changed:
		name_lbl.modulate = Color(0.55, 1.0, 0.55)
	row.add_child(name_lbl)
	var val_lbl := Label.new()
	val_lbl.text = "%s → %s" % [value, after] if changed else value
	val_lbl.add_theme_font_size_override("font_size", 13)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.modulate = Color(0.55, 1.0, 0.55) if changed else Color(0.85, 0.92, 1.0)
	val_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(val_lbl)
	_rail_body.add_child(row)

func _refresh_action_buttons() -> void:
	_reroll_btn.text = "Reroll (%d)  [R]" % _rerolls_left
	_reroll_btn.disabled = _rerolls_left <= 0

func has_rerolls() -> bool:
	return _rerolls_left > 0

func _on_reroll_pressed() -> void:
	if _rerolls_left <= 0:
		return
	rerolled.emit()

func _on_skip_pressed() -> void:
	visible = false
	skipped.emit()

## Keyboard focus landed on card `index` — make it the sticky preview (restored when a
## hovered card is left) and re-render the rail with this pick's before -> after.
func _on_card_focus(index: int) -> void:
	_focused_id = _option_id(index)
	_refresh_stat_rail(_run, _focused_id)

## Mouse hovered card `index` — preview it without disturbing the focused card.
func _on_card_hover(index: int) -> void:
	_refresh_stat_rail(_run, _option_id(index))

## Mouse left a hovered card — fall back to previewing the keyboard-focused card.
func _on_card_unhover() -> void:
	_refresh_stat_rail(_run, _focused_id)

func _option_id(index: int) -> String:
	if index < 0 or index >= _options.size():
		return ""
	return str(_options[index].get("id", ""))

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
	# Drive the rail's before -> after preview from this card: keyboard focus sets the sticky
	# preview, mouse hover overrides it, and leaving the hover falls back to the focused card.
	card.focus_entered.connect(_on_card_focus.bind(index))
	card.mouse_entered.connect(_on_card_hover.bind(index))
	card.mouse_exited.connect(_on_card_unhover)

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
	if event.is_action_pressed("upgrade_reroll") and _rerolls_left > 0:
		get_viewport().set_input_as_handled()
		rerolled.emit()
		return
	if event.is_action_pressed("upgrade_skip"):
		get_viewport().set_input_as_handled()
		visible = false
		skipped.emit()
		return

func _choose(index: int) -> void:
	if index < 0 or index >= _options.size():
		return
	var id := str(_options[index].get("id", ""))
	visible = false
	picked.emit(id)
