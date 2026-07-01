class_name VSHud
extends CanvasLayer
## Minimal heads-up display: time / kills / level, plus a game-over banner.
## (HP now reads from the diegetic health bar under the player — see VSPlayer._draw_health_bar.)
## Built in code; replace with the Kenney UI pack art as the UI lane matures.

const XP_BAR_H := 10.0   # height of the top-of-screen XP progress bar
const XP_FILL_COLOR := Color(0.40, 0.78, 1.0, 0.95)   # cyan-blue, reads as XP (matches the gem)
const XP_FLASH_HZ := 1.5   # full-rainbow hue cycles/sec while the level-up picker is up

const WARN_FLASH_HZ := 3.0   # "DEATH APPROACHES" pulses/sec in the seconds before the Reaper

# Reaper boss HP bar — a wide gauge under the "THE REAPER COMES" banner. It spans the centre
# 60% of the viewport and drains from full to empty as Death is chipped down, so the finale
# duel against the 400-HP wall reads as real progress instead of a featureless slog.
const BOSS_BAR_TOP := 82.0   # y-offset under the banner (banner sits at offset_top 44, ~26px tall)
const BOSS_BAR_H := 16.0
const BOSS_BAR_LEFT := 0.2    # anchors: bar occupies the centre 60% so it stays centred at any width
const BOSS_BAR_RIGHT := 0.8
const BOSS_BAR_TRACK := Color(0.10, 0.04, 0.06, 0.9)    # dark track — reads as drained health
const BOSS_BAR_FILL := Color(0.80, 0.12, 0.16, 0.96)    # blood-red — Death's life draining away

# Loadout icons — the SAME item art the level-up picker shows (see VSLevelUpScreen.ICONS), keyed by the
# VSRun.UPGRADES key, so the owned-build corner readout reads visually at a glance, matching the picker.
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
const LOADOUT_ICON_PX := 16   # 64->16 (x4) and 256->16 (x16) are integer downscales — crisp on NEAREST

var _stat: Label
var _over: Label
var _win: Label
var _boss: Label
var _warning: Label
var _loadout: VBoxContainer
var _xp_bg: ColorRect
var _xp_fill: ColorRect
var _boss_bar_bg: ColorRect
var _boss_bar_fill: ColorRect

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
	_xp_fill.color = XP_FILL_COLOR   # cyan-blue, reads as XP (matches the gem); flashes during level_up
	_xp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_xp_fill)

	_stat = Label.new()
	_stat.position = Vector2(12, XP_BAR_H + 4.0)   # sit just below the XP bar
	_stat.add_theme_font_size_override("font_size", 16)
	add_child(_stat)

	# Loadout readout: owned weapons/passives as small icon + "LvN" rows, pinned to the bottom-left
	# corner and growing upward. Only rebuilt on upgrade_chosen (see refresh_loadout). A VBox of HBox
	# rows so each owned upgrade shows its picker icon beside its level, reading visually at a glance.
	_loadout = VBoxContainer.new()
	_loadout.add_theme_constant_override("separation", 2)
	_loadout.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_loadout.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_loadout.offset_left = 12
	_loadout.offset_bottom = -10
	_loadout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_loadout)

	_over = Label.new()
	_over.text = "YOU DIED"   # refresh() rewrites this with the run recap once it becomes visible
	_over.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Anchor to the viewport centre (instead of a fixed position) so the banner stays
	# centred at any resolution — a hardcoded (300,280) drifts left once the viewport widens.
	_over.set_anchors_preset(Control.PRESET_CENTER)
	_over.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_over.grow_vertical = Control.GROW_DIRECTION_BOTH
	_over.add_theme_font_size_override("font_size", 28)
	_over.visible = false
	add_child(_over)

	# Victory banner — the counterpart to the death banner, shown when the run is won by
	# slaying the summoned Reaper. Gold to read as triumph (vs the default-white "YOU DIED");
	# centred the same way. Headline names the deed so the finale reads faithfully.
	_win = Label.new()
	_win.text = "YOU SLEW DEATH!"   # refresh() rewrites this with the run recap once it becomes visible
	_win.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_win.set_anchors_preset(Control.PRESET_CENTER)
	_win.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_win.grow_vertical = Control.GROW_DIRECTION_BOTH
	_win.add_theme_font_size_override("font_size", 28)
	_win.add_theme_color_override("font_color", Color(1.0, 0.85, 0.30))
	_win.visible = false
	add_child(_win)

	# Reaper telegraph — a warning pinned near the top (out of the action) while Death is on the
	# field, so the time-limit finale reads as a deliberate climax, not just a big enemy. Dark
	# wraith-purple with a heavy outline so it stays legible over the busy field.
	_boss = Label.new()
	_boss.text = "THE REAPER COMES — SLAY DEATH"
	_boss.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_boss.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_boss.offset_top = 44
	_boss.add_theme_font_size_override("font_size", 26)
	_boss.add_theme_color_override("font_color", Color(0.82, 0.24, 0.90))
	_boss.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_boss.add_theme_constant_override("outline_size", 5)
	_boss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss.visible = false
	add_child(_boss)

	# Reaper foreshadow — a flashing "DEATH APPROACHES" warning shown in the last seconds BEFORE
	# Death descends (paired with run.gd's rising rumble), occupying the same top slot the boss
	# banner takes over once the Reaper is up — so the build-up reads as one escalating beat.
	# Blood-red dread with a heavy outline so it stays legible over the busy field; the alpha is
	# pulsed each frame in refresh() so it flashes urgently.
	_warning = Label.new()
	_warning.text = "DEATH APPROACHES"
	_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_warning.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_warning.offset_top = 44
	_warning.add_theme_font_size_override("font_size", 30)
	_warning.add_theme_color_override("font_color", Color(0.95, 0.10, 0.12))
	_warning.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_warning.add_theme_constant_override("outline_size", 6)
	_warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warning.visible = false
	add_child(_warning)

	# Reaper boss HP bar — a dark track with a blood-red fill, centred under the banner. The
	# fill's right edge is driven each frame in refresh() toward BOSS_BAR_LEFT as Death drains,
	# so the climactic duel reads as real progress. Hidden until the Reaper is on the field.
	_boss_bar_bg = ColorRect.new()
	_boss_bar_bg.anchor_left = BOSS_BAR_LEFT
	_boss_bar_bg.anchor_right = BOSS_BAR_RIGHT
	_boss_bar_bg.offset_top = BOSS_BAR_TOP
	_boss_bar_bg.offset_bottom = BOSS_BAR_TOP + BOSS_BAR_H
	_boss_bar_bg.color = BOSS_BAR_TRACK
	_boss_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_bar_bg.visible = false
	add_child(_boss_bar_bg)

	_boss_bar_fill = ColorRect.new()
	_boss_bar_fill.anchor_left = BOSS_BAR_LEFT
	_boss_bar_fill.anchor_right = BOSS_BAR_RIGHT   # set to the HP ratio each frame in refresh()
	_boss_bar_fill.offset_top = BOSS_BAR_TOP
	_boss_bar_fill.offset_bottom = BOSS_BAR_TOP + BOSS_BAR_H
	_boss_bar_fill.color = BOSS_BAR_FILL
	_boss_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_bar_fill.visible = false
	add_child(_boss_bar_fill)

func refresh(run: VSRun) -> void:
	if _stat == null:
		return
	# HP now reads from the diegetic health bar under the player (VSPlayer._draw_health_bar),
	# so it's dropped from this corner readout.
	# Show the survival goal beside the clock so the run has a legible destination.
	_stat.text = "Time %ds / %ds    Kills %d    Lv %d (%d xp)" % [int(run.elapsed), int(VSRun.SURVIVE_SECONDS), run.kills, run.level, run.xp]
	# Fill the top XP bar toward the next level. Threshold mirrors VSRun._check_level_up (level*5).
	# During the level-up picker the leftover xp has already been subtracted (so the bar would
	# sit near-empty) — instead show it FULL and flash its hue, celebrating the level you just hit
	# until you pick an upgrade and the run resumes.
	if _xp_fill:
		if run.phase == "level_up":
			_xp_fill.anchor_right = 1.0
			var hue := fmod(float(Time.get_ticks_msec()) / 1000.0 * XP_FLASH_HZ, 1.0)
			_xp_fill.color = Color.from_hsv(hue, 0.8, 1.0, 0.95)
		else:
			var need := maxi(1, run.level * 5)
			_xp_fill.anchor_right = clampf(float(run.xp) / float(need), 0.0, 1.0)
			_xp_fill.color = XP_FILL_COLOR   # restore the steady cyan-blue once the picker closes
	# Close each run with its own summary so a finished run reads as an achievement, not a bare
	# banner. Composed only while the banner is up (a static screen until Enter reloads).
	if run.phase == "game_over":
		_over.text = "YOU DIED\n\n%s\n\nPress Enter to retry" % _recap(run)
	elif run.phase == "victory":
		_win.text = "YOU SLEW DEATH!\n\n%s\n\nPress Enter to play again" % _recap(run)
	_over.visible = run.phase == "game_over"
	_win.visible = run.phase == "victory"
	# Telegraph Death while the Reaper is on the field (the finale duel is within the "playing" phase).
	var reaper_alive := run.phase == "playing" and run.reaper != null and is_instance_valid(run.reaper)
	_boss.visible = reaper_alive
	# Foreshadow it in the seconds just BEFORE the summon: flash "DEATH APPROACHES" while we're in
	# the warning window and Death hasn't descended yet. Hands off to the boss banner at the summon
	# (elapsed >= SURVIVE_SECONDS, reaper_alive), so the two never show together.
	if _warning:
		var warn_active := run.phase == "playing" and not reaper_alive \
			and run.elapsed < VSRun.SURVIVE_SECONDS \
			and run.elapsed >= VSRun.SURVIVE_SECONDS - VSRun.REAPER_WARN_SECONDS
		_warning.visible = warn_active
		if warn_active:
			var pulse := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) / 1000.0 * WARN_FLASH_HZ * TAU)
			_warning.modulate = Color(1, 1, 1, 0.25 + 0.75 * pulse)
	# Drain the boss HP bar from full (BOSS_BAR_RIGHT) toward empty (BOSS_BAR_LEFT) as Death is
	# chipped down, so the 400-HP duel reads as real progress. Hidden whenever no Reaper is up.
	if _boss_bar_bg and _boss_bar_fill:
		_boss_bar_bg.visible = reaper_alive
		_boss_bar_fill.visible = reaper_alive
		if reaper_alive:
			var hp_ratio := clampf(run.reaper.health / VSSpawner.REAPER_HP, 0.0, 1.0)
			_boss_bar_fill.anchor_right = BOSS_BAR_LEFT + (BOSS_BAR_RIGHT - BOSS_BAR_LEFT) * hp_ratio

func refresh_loadout(run: VSRun) -> void:
	# Rebuild the owned-upgrades list as icon + "LvN" rows. Keys iterate in acquisition order
	# (Dictionaries preserve insertion order), so the readout grows as the player's build does.
	if _loadout == null:
		return
	for child in _loadout.get_children():
		child.queue_free()
	for key in run.upgrade_levels.keys():
		var lvl := int(run.upgrade_levels[key])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Picker icon to the LEFT of the level. Square sources (64/256px) downscale to LOADOUT_ICON_PX
		# by an integer ratio; KEEP_ASPECT_CENTERED holds that, and we leave texture_filter at the
		# project's NEAREST default (no per-node override — see VISUAL_RULES.md) so it stays crisp.
		var icon: Texture2D = ICONS.get(str(key), null)
		if icon != null:
			var tex := TextureRect.new()
			tex.texture = icon
			tex.custom_minimum_size = Vector2(LOADOUT_ICON_PX, LOADOUT_ICON_PX)
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(tex)
		# "LvN" beside the icon; when an upgrade has no icon, prefix its title so it still reads.
		var lbl := Label.new()
		lbl.text = "Lv%d" % lvl if icon != null else "%s  Lv%d" % [_title_for(str(key)), lvl]
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		lbl.add_theme_constant_override("outline_size", 4)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(lbl)
		_loadout.add_child(row)

func _title_for(key: String) -> String:
	for u in VSRun.UPGRADES:
		if str(u.get("key", "")) == key:
			return str(u.get("title", key))
	return key

func _recap(run: VSRun) -> String:
	# The end-of-run summary line shown on the death/victory banners: how long you lasted, how
	# many you felled, how far your build climbed. Spacing/wording match the top stat readout
	# (see refresh) so the recap reads as the same run's final tally.
	return "Survived %s    Kills %d    Lv %d" % [_format_time(run.elapsed), run.kills, run.level]

func _format_time(secs: float) -> String:
	# Seconds -> M:SS, matching how a survival timer reads (e.g. 154.0 -> "2:34").
	var s := int(secs)
	return "%d:%02d" % [s / 60, s % 60]
