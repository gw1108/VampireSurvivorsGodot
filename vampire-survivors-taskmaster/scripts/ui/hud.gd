class_name VSHud
extends CanvasLayer
## Minimal heads-up display: HP / time / kills / level, plus a game-over banner.
## Built in code; replace with the Kenney UI pack art as the UI lane matures.

var _stat: Label
var _build: Label
var _over: Label

# Top-right "build" panel: one row per owned upgrade (icon + "Lv N/max"), like VS's
# weapon/accessory rows. Rebuilt only when the level signature changes so it costs
# nothing on the common frame.
var _loadout: VBoxContainer
var _loadout_sig := ""

func _ready() -> void:
	_stat = Label.new()
	_stat.position = Vector2(12, 8)
	_stat.add_theme_font_size_override("font_size", 16)
	add_child(_stat)

	# Second line: the run's mutable combat stats, so the player can read what
	# their level-up picks actually did.
	_build = Label.new()
	_build.position = Vector2(12, 30)
	_build.add_theme_font_size_override("font_size", 14)
	_build.modulate = Color(0.8, 0.9, 1.0)
	add_child(_build)

	# Build panel, anchored to the top-right corner and growing downward.
	_loadout = VBoxContainer.new()
	_loadout.add_theme_constant_override("separation", 4)
	_loadout.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_loadout.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_loadout.offset_left = -168
	_loadout.offset_right = -12
	_loadout.offset_top = 10
	add_child(_loadout)

	_over = Label.new()
	_over.text = "YOU DIED\nPress Enter to retry"
	_over.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_over.position = Vector2(300, 280)
	_over.add_theme_font_size_override("font_size", 28)
	_over.visible = false
	add_child(_over)

func refresh(run: VSRun) -> void:
	if _stat == null:
		return
	var hp := 0
	var max_hp := 0
	if run.player:
		hp = int(ceil(run.player.health))
		max_hp = int(round(run.player.max_health))
	_stat.text = "HP %d/%d    Time %ds    Kills %d    Lv %d (%d xp)    Gold %d" % [hp, max_hp, int(run.elapsed), run.kills, run.level, run.xp, run.gold]
	var fire_rate := 1.0 / run.weapon_fire_interval if run.weapon_fire_interval > 0.0 else 0.0
	var move_speed := int(round(VSPlayer.SPEED * run.player_speed_mult))
	_build.text = "DMG %.0f    Rate %.2f/s    Speed %d    Shots %d" % [run.weapon_damage, fire_rate, move_speed, run.weapon_count]
	if run.garlic_level > 0:
		_build.text += "    Garlic Lv %d" % run.garlic_level
	if run.whip_level > 0:
		_build.text += "    Whip Lv %d" % run.whip_level
	_refresh_loadout(run)
	_over.visible = run.phase == "game_over"
	if _over.visible:
		# Run summary: give the death some closure by showing what the run achieved.
		# The run's gold was banked into the persisted purse in VSRun._on_player_died
		# before this refresh, so MetaSave.load_coins() reflects the post-deposit total.
		var secs := int(run.elapsed)
		var mmss := "%d:%02d" % [secs / 60, secs % 60]
		var banked := MetaSave.load_coins()
		_over.text = "YOU DIED\n\nTime Survived  %s\nKills  %d\nLevel Reached  %d\nGold This Run  %d\nCoins Banked  %d\n\nPress Enter to retry" % [mmss, run.kills, run.level, run.gold, banked]

## Show each owned upgrade as an icon + "Lv N/max" row, ordered by VSRun.UPGRADE_POOL so
## the layout is stable as picks come in. Rebuilds only when the levels change (cheap
## signature check) since the panel is otherwise static frame to frame.
func _refresh_loadout(run: VSRun) -> void:
	if _loadout == null:
		return
	var sig := ""
	for opt in VSRun.UPGRADE_POOL:
		var lvl: int = run.upgrade_levels.get(opt["id"], 0)
		if lvl > 0:
			sig += "%s%d," % [opt["id"], lvl]
	if sig == _loadout_sig:
		return
	_loadout_sig = sig
	for c in _loadout.get_children():
		c.queue_free()
	for opt in VSRun.UPGRADE_POOL:
		var id := str(opt["id"])
		var lvl: int = run.upgrade_levels.get(id, 0)
		if lvl <= 0:
			continue
		_loadout.add_child(_make_loadout_row(id, lvl, int(opt["max"])))

## One build-panel row: the upgrade's icon (falls back to a bullet if missing) plus a
## "Lv N/max" label that turns gold at the cap so a maxed weapon reads at a glance.
func _make_loadout_row(id: String, lvl: int, mx: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var icon_path: String = VSUpgradeScreen.ICONS.get(id, "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(28, 28)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = load(icon_path)
		row.add_child(icon)

	var label := Label.new()
	label.text = "Lv %d/%d" % [lvl, mx]
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	if lvl >= mx:
		label.modulate = Color(0.95, 0.82, 0.35)   # gold = maxed
	row.add_child(label)
	return row
