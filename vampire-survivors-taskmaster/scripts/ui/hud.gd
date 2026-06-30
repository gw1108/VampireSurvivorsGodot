class_name VSHud
extends CanvasLayer
## Minimal heads-up display: HP / time / kills / level, plus a game-over banner.
## Built in code; replace with the Kenney UI pack art as the UI lane matures.

const XP_BAR_H := 10.0   # height of the top-of-screen XP progress bar

var _stat: Label
var _over: Label
var _loadout: Label
var _xp_bg: ColorRect
var _xp_fill: ColorRect

func _ready() -> void:
	# Top-of-screen XP bar — the iconic VS pacing meter. A dark full-width track with a
	# blue fill (matching the XP gem) that grows toward the next level, so progress reads
	# at a glance instead of only as the "(N xp)" number. Anchored TOP_WIDE so it spans
	# any viewport width; the fill's width is driven each frame via anchor_right in refresh().
	_xp_bg = ColorRect.new()
	_xp_bg.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_xp_bg.offset_bottom = XP_BAR_H
	_xp_bg.color = Color(0.06, 0.05, 0.10, 0.85)
	_xp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_xp_bg)

	_xp_fill = ColorRect.new()
	_xp_fill.anchor_left = 0.0
	_xp_fill.anchor_top = 0.0
	_xp_fill.anchor_right = 0.0   # set to the fill ratio each frame in refresh()
	_xp_fill.anchor_bottom = 0.0
	_xp_fill.offset_bottom = XP_BAR_H
	_xp_fill.color = Color(0.40, 0.78, 1.0, 0.95)   # cyan-blue, reads as XP (matches the gem)
	_xp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_xp_fill)

	_stat = Label.new()
	_stat.position = Vector2(12, XP_BAR_H + 4.0)   # sit just below the XP bar
	_stat.add_theme_font_size_override("font_size", 16)
	add_child(_stat)

	# Loadout readout: owned weapons/passives + their level, pinned to the bottom-left
	# corner and growing upward. Only rebuilt on upgrade_chosen (see refresh_loadout).
	# An outline keeps it legible over the busy lower field.
	_loadout = Label.new()
	_loadout.add_theme_font_size_override("font_size", 13)
	_loadout.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_loadout.add_theme_constant_override("outline_size", 4)
	_loadout.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_loadout.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_loadout.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_loadout.offset_left = 12
	_loadout.offset_bottom = -10
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
	if run.player:
		hp = int(ceil(run.player.health))
	_stat.text = "HP %d    Time %ds    Kills %d    Lv %d (%d xp)" % [hp, int(run.elapsed), run.kills, run.level, run.xp]
	# Fill the top XP bar toward the next level. Threshold mirrors VSRun._check_level_up (level*5).
	if _xp_fill:
		var need := maxi(1, run.level * 5)
		_xp_fill.anchor_right = clampf(float(run.xp) / float(need), 0.0, 1.0)
	_over.visible = run.phase == "game_over"

func refresh_loadout(run: VSRun) -> void:
	# Rebuild the owned-upgrades list. Keys iterate in acquisition order (Dictionaries
	# preserve insertion order), so the readout grows as the player's build does.
	if _loadout == null:
		return
	var lines := PackedStringArray()
	for key in run.upgrade_levels.keys():
		lines.append("%s  Lv%d" % [_title_for(str(key)), int(run.upgrade_levels[key])])
	_loadout.text = "\n".join(lines)

func _title_for(key: String) -> String:
	for u in VSRun.UPGRADES:
		if str(u.get("key", "")) == key:
			return str(u.get("title", key))
	return key
