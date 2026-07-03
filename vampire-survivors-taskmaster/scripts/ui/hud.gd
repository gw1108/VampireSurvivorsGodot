class_name VSHud
extends CanvasLayer
## Minimal heads-up display: HP / time / kills / level, plus a game-over banner.
## Built in code; replace with the Kenney UI pack art as the UI lane matures.

var _stat: Label
var _build: Label
var _meta: Label
var _reroll: Label
var _reaper: Label
var _slain: Label
var _over: Label

# XP progress bar: a thin full-width track across the very top of the screen that fills toward
# the next level — VS's iconic level-loop feedback, so the player reads their progress to the
# next upgrade at a glance rather than parsing the "(N xp)" text. Two anchored ColorRects (a
# dark track + a cyan fill whose right anchor tracks xp / xp-to-next) so it stays full-width at
# any resolution. Purely cosmetic; driven each frame from refresh().
var _xp_bg: ColorRect
var _xp_fill: ColorRect
const XP_BAR_H := 8.0
const XP_FILL_COLOR := Color(0.35, 0.8, 1.0)   # bright cyan = the XP/level identity

# Reaper boss health bar: a top-center crimson track that drains as the finale Reaper takes
# damage, so the (celebrated) kill-win path reads as visible progress rather than a mystery.
# Three stacked ColorRects — border, empty track, draining fill — shown only during the finale.
var _boss_border: ColorRect
var _boss_bg: ColorRect
var _boss_fill: ColorRect
const BOSS_BAR_W := 560.0
const BOSS_BAR_H := 18.0
const BOSS_BAR_X := 360.0    # centered under the "THE REAPER COMES" banner in the 1280-wide viewport
const BOSS_BAR_Y := 116.0

# Orologion freeze feedback: a full-screen icy vignette + centered "FROZEN n" countdown that
# reads the run's time-stop (VSRun.is_frozen) so the breather is unmistakable. Purely cosmetic.
var _freeze_vig: ColorRect
var _freeze_label: Label
# Matches VSFrozenClock.ICE so the overlay reads as the same icy event as the pickup bloom.
const FREEZE_TINT := Color(0.6, 0.85, 1.15)
# Full-screen vignette shader: transparent-ish center, icy edges, alpha scaled by `strength`.
const FREEZE_SHADER := """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.6, 0.85, 1.15, 1.0);
uniform float strength = 0.0;
void fragment() {
	float d = length(UV - vec2(0.5)) * 1.41421356;
	float vig = smoothstep(0.15, 0.95, d);
	float a = strength * mix(0.10, 0.55, vig);
	COLOR = vec4(tint.rgb, a);
}
"""

# Swarm-surge telegraph: when the spawner marches a directional wall in from a flank it calls
# telegraph_surge(dir); we flash a crimson arrow near the screen edge pointing at the flank the
# wall is coming from, so the player can juke perpendicular before it closes. Purely cosmetic —
# a Polygon2D dart rotated to `dir`, held bright then faded over SURGE_TELEGRAPH_HOLD+FADE.
var _surge_arrow: Polygon2D
var _surge_time := 0.0     # seconds of telegraph remaining (hold + fade)
const SURGE_TELEGRAPH_HOLD := 0.8    # seconds at full alpha before it starts fading
const SURGE_TELEGRAPH_FADE := 1.0    # seconds to fade out after the hold
const SURGE_ARROW_COLOR := Color(1.0, 0.42, 0.18)   # danger orange-crimson, reads as "incoming"
# Local arrow geometry, pointing +X; telegraph_surge rotates it to the flank direction.
const SURGE_ARROW_POLY: PackedVector2Array = [
	Vector2(24, 0), Vector2(-8, -20), Vector2(0, 0), Vector2(-8, 20),
]

# Active permanent PowerUps are fixed for the whole run (applied once at start), so we read
# MetaSave + build the line a single time and cache that it's been done.
var _meta_built := false

# Top-right "build" panel: one row per owned upgrade (icon + "Lv N/max"), like VS's
# weapon/accessory rows. Rebuilt only when the level signature changes so it costs
# nothing on the common frame. Split into a WEAPONS section and an ITEMS (passive stat)
# section so the player can read their weapons apart from the stat boosts stacking behind
# them, mirroring VS's two-row build readout.
var _loadout: VBoxContainer
var _loadout_sig := ""
# Which UPGRADE_POOL ids are weapons; everything else in the pool is a passive stat item.
const WEAPON_IDS := ["garlic", "whip", "bible", "lightning", "knife"]

func _ready() -> void:
	# XP bar first so it hugs the very top edge. It's added before the freeze vignette (which is
	# moved to the back below), so it draws on top of the icy overlay and stays readable.
	_xp_bg = ColorRect.new()
	_xp_bg.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_xp_bg.offset_left = 0
	_xp_bg.offset_right = 0
	_xp_bg.offset_top = 0
	_xp_bg.offset_bottom = XP_BAR_H
	_xp_bg.color = Color(0.06, 0.08, 0.12, 0.85)
	_xp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_xp_bg)

	# Fill: anchored to the top-left, its right anchor driven each frame to the xp fraction so its
	# width is always that fraction of the viewport (offsets stay 0 except the fixed bar height).
	_xp_fill = ColorRect.new()
	_xp_fill.anchor_left = 0.0
	_xp_fill.anchor_top = 0.0
	_xp_fill.anchor_right = 0.0
	_xp_fill.anchor_bottom = 0.0
	_xp_fill.offset_left = 0
	_xp_fill.offset_right = 0
	_xp_fill.offset_top = 0
	_xp_fill.offset_bottom = XP_BAR_H
	_xp_fill.color = XP_FILL_COLOR
	_xp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_xp_fill)

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

	# Third line: permanent PowerUps bought between runs, so the player can see their
	# meta-investment paying off this run. Amber to read as distinct from the run stats.
	_meta = Label.new()
	_meta.position = Vector2(12, 48)
	_meta.add_theme_font_size_override("font_size", 14)
	_meta.modulate = Color(1.0, 0.82, 0.35)
	_meta.visible = false
	add_child(_meta)

	# Fourth line: remaining level-up rerolls, so the player can plan when to spend one
	# without opening the picker. Violet to read as the reroll token, distinct from run/meta
	# stats. Positioned below the (optionally hidden) PowerUps line.
	_reroll = Label.new()
	_reroll.position = Vector2(12, 66)
	_reroll.add_theme_font_size_override("font_size", 14)
	_reroll.modulate = Color(0.72, 0.6, 1.0)
	add_child(_reroll)

	# Build panel, anchored to the top-right corner and growing downward.
	_loadout = VBoxContainer.new()
	_loadout.add_theme_constant_override("separation", 4)
	_loadout.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_loadout.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_loadout.offset_left = -168
	_loadout.offset_right = -12
	_loadout.offset_top = 10
	add_child(_loadout)

	# Finale banner: while the Reaper is loose (the last stand before victory), a crimson
	# centered countdown so the timer flip reads as a climactic survive-check, not a silent win.
	_reaper = Label.new()
	_reaper.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reaper.position = Vector2(300, 60)
	_reaper.size = Vector2(400, 0)
	_reaper.add_theme_font_size_override("font_size", 22)
	_reaper.modulate = Color(1.0, 0.3, 0.32)
	_reaper.visible = false
	add_child(_reaper)

	# Kill-win banner: when the player actually SLAYS the Reaper (not just outlasts it), a large
	# gold banner crowns the climactic payout above the run summary, distinct from the timeout win.
	_slain = Label.new()
	_slain.text = "YOU SLEW THE REAPER"
	_slain.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_slain.position = Vector2(150, 190)
	_slain.size = Vector2(700, 0)
	_slain.add_theme_font_size_override("font_size", 34)
	_slain.modulate = Color(1.0, 0.85, 0.3)
	_slain.visible = false
	add_child(_slain)

	# Reaper boss health bar (top-center), hidden until the finale summons the Reaper. Added
	# border -> track -> fill so the draining fill draws on top; driven each frame in _refresh_boss.
	_boss_border = ColorRect.new()
	_boss_border.color = Color(0, 0, 0, 0.75)
	_boss_border.position = Vector2(BOSS_BAR_X - 3.0, BOSS_BAR_Y - 3.0)
	_boss_border.size = Vector2(BOSS_BAR_W + 6.0, BOSS_BAR_H + 6.0)
	_boss_border.visible = false
	add_child(_boss_border)

	_boss_bg = ColorRect.new()
	_boss_bg.color = Color(0.18, 0.02, 0.02, 0.9)
	_boss_bg.position = Vector2(BOSS_BAR_X, BOSS_BAR_Y)
	_boss_bg.size = Vector2(BOSS_BAR_W, BOSS_BAR_H)
	_boss_bg.visible = false
	add_child(_boss_bg)

	_boss_fill = ColorRect.new()
	_boss_fill.color = Color(0.88, 0.14, 0.14)
	_boss_fill.position = Vector2(BOSS_BAR_X, BOSS_BAR_Y)
	_boss_fill.size = Vector2(BOSS_BAR_W, BOSS_BAR_H)
	_boss_fill.visible = false
	add_child(_boss_fill)

	# Icy freeze vignette, stretched over the whole viewport and kept behind the HUD text.
	# Starts invisible (strength 0) and is driven each frame from refresh() while frozen.
	_freeze_vig = ColorRect.new()
	_freeze_vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	_freeze_vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = FREEZE_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	_freeze_vig.material = mat
	_freeze_vig.visible = false
	add_child(_freeze_vig)
	move_child(_freeze_vig, 0)   # behind all the stat/build labels

	# Centered "FROZEN n" countdown so the time-stop reads as a deliberate breather.
	_freeze_label = Label.new()
	_freeze_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_freeze_label.position = Vector2(300, 96)
	_freeze_label.size = Vector2(400, 0)
	_freeze_label.add_theme_font_size_override("font_size", 24)
	_freeze_label.modulate = FREEZE_TINT
	_freeze_label.visible = false
	add_child(_freeze_label)

	# Surge telegraph arrow: a screen-space dart parented to the HUD layer, hidden until a
	# wall marches in. telegraph_surge() positions/rotates it toward the flank and _process
	# fades it out. Drawn above the world but under the stat text is fine — it's an edge marker.
	_surge_arrow = Polygon2D.new()
	_surge_arrow.polygon = SURGE_ARROW_POLY
	_surge_arrow.color = SURGE_ARROW_COLOR
	_surge_arrow.visible = false
	add_child(_surge_arrow)

	_over = Label.new()
	_over.text = "YOU DIED\nPress Enter to retry"
	_over.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_over.position = Vector2(300, 280)
	_over.add_theme_font_size_override("font_size", 28)
	_over.visible = false
	add_child(_over)

## Flash the swarm-surge telegraph toward `dir` — the flank the wall is marching in from
## (dir points from the player out to the wall's spawn point). Places the arrow near the
## screen edge in that direction and rotates it to point outward at the threat, then _process
## holds it bright and fades it. Called by the spawner when _spawn_surge fires.
func telegraph_surge(dir: Vector2) -> void:
	if _surge_arrow == null or dir == Vector2.ZERO:
		return
	var d := dir.normalized()
	var screen := get_viewport().get_visible_rect().size if get_viewport() else Vector2(1280, 720)
	var center := screen * 0.5
	# Sit the arrow near the edge on the flank side (leave a margin so it stays fully on-screen).
	var radius := minf(center.x, center.y) * 0.82
	_surge_arrow.position = center + d * radius
	_surge_arrow.rotation = d.angle()
	_surge_arrow.visible = true
	_surge_time = SURGE_TELEGRAPH_HOLD + SURGE_TELEGRAPH_FADE

## Drive the surge telegraph's fade. Holds full alpha for SURGE_TELEGRAPH_HOLD, then eases to
## zero over SURGE_TELEGRAPH_FADE and hides. A subtle pulse keeps the eye drawn while held.
func _process(delta: float) -> void:
	if _surge_arrow == null or not _surge_arrow.visible:
		return
	_surge_time -= delta
	if _surge_time <= 0.0:
		_surge_arrow.visible = false
		return
	var fade := clampf(_surge_time / SURGE_TELEGRAPH_FADE, 0.0, 1.0)
	# Gentle pulse (0.75..1.0) so the marker throbs rather than sitting flat while it holds.
	var pulse := 0.75 + 0.25 * absf(sin(_surge_time * 9.0))
	_surge_arrow.color = Color(SURGE_ARROW_COLOR.r, SURGE_ARROW_COLOR.g, SURGE_ARROW_COLOR.b, fade * pulse)

func refresh(run: VSRun) -> void:
	if _stat == null:
		return
	var hp := 0
	var max_hp := 0
	if run.player:
		hp = int(ceil(run.player.health))
		max_hp = int(round(run.player.max_health))
	# Survival clock counts UP toward the run's goal (VS-style), so the player can read how
	# close they are to outlasting the waves and winning.
	_stat.text = "HP %d/%d    Time %s / %s    Kills %d    Lv %d (%d xp)    Gold %d" % [hp, max_hp, _mmss(run.elapsed), _mmss(VSRun.RUN_DURATION), run.kills, run.level, run.xp, run.gold]
	var fire_rate := 1.0 / run.weapon_fire_interval if run.weapon_fire_interval > 0.0 else 0.0
	var move_speed := int(round(VSPlayer.SPEED * run.player_speed_mult))
	_build.text = "DMG %.0f    Rate %.2f/s    Speed %d    Shots %d" % [run.weapon_damage, fire_rate, move_speed, run.weapon_count]
	if run.garlic_level > 0:
		_build.text += "    Garlic Lv %d" % run.garlic_level
	if run.whip_level > 0:
		_build.text += "    Whip Lv %d" % run.whip_level
	_refresh_meta()
	# Persistent reroll budget readout. Greys out at zero so a spent-out budget reads at a
	# glance and the player knows Skip is their only free-out.
	if _reroll:
		_reroll.text = "Rerolls  %d" % run.rerolls_left
		_reroll.modulate = Color(0.72, 0.6, 1.0) if run.rerolls_left > 0 else Color(0.5, 0.5, 0.55)
	_refresh_loadout(run)
	_refresh_xp(run)
	_refresh_freeze(run)
	# Reaper finale countdown, live only during the last stand (Reaper summoned, run not yet won).
	var in_finale := run.reaper_active and run.phase == "playing"
	_reaper.visible = in_finale
	if in_finale:
		var left := int(ceil(maxf(0.0, run.reaper_deadline - run.elapsed)))
		_reaper.text = "THE REAPER COMES\nSURVIVE  %ds" % left
	_refresh_boss(run)
	var won := run.phase == "victory"
	# The extra kill-win banner rides above the summary only when the Reaper was actually slain.
	if _slain:
		_slain.visible = won and run.reaper_slain
	_over.visible = run.phase == "game_over" or won
	if _over.visible:
		# Run summary: give the run's end some closure by showing what it achieved. The gold
		# was banked into the persisted purse (VSRun._on_player_died / _on_victory) before this
		# refresh, so MetaSave.load_coins() reflects the post-deposit total. A survived run leads
		# with a golden "YOU SURVIVED!"; a death leads with the crimson "YOU DIED".
		var banked := MetaSave.load_coins()
		var heading := "YOU DIED"
		if won:
			heading = "YOU SLEW THE REAPER!" if run.reaper_slain else "YOU SURVIVED!"
		_over.modulate = Color(1.0, 0.9, 0.4) if won else Color(1, 1, 1)
		_over.text = "%s\n\nTime Survived  %s\nKills  %d\nLevel Reached  %d\nGold This Run  %d\nCoins Banked  %d\n\nPress B for the PowerUp shop\nPress Enter to retry" % [heading, _mmss(run.elapsed), run.kills, run.level, run.gold, banked]

## Drive the Reaper boss health bar. Shown only while the finale Reaper is loose (summoned,
## run still playing, node alive with HP left); the fill width tracks its health fraction so
## the player can see the kill-win path advancing as they whittle the boss down. Once the Reaper
## dies (node freed) or the run ends, the bar hides.
func _refresh_boss(run: VSRun) -> void:
	if _boss_fill == null:
		return
	var boss := run.reaper_enemy
	var show := run.reaper_active and run.phase == "playing" \
		and boss != null and is_instance_valid(boss) and boss.health > 0.0
	_boss_border.visible = show
	_boss_bg.visible = show
	_boss_fill.visible = show
	if not show:
		return
	var frac := clampf(boss.health / maxf(boss.max_health, 1.0), 0.0, 1.0)
	_boss_fill.size = Vector2(BOSS_BAR_W * frac, BOSS_BAR_H)

## Drive the top XP progress bar from the run's xp toward the next level. The fill's right anchor
## is set to xp / xp-to-next so its width is that fraction of the viewport; it empties and refills
## each time a level is gained. Reads VSRun's per-level requirement so it stays in step with the
## level curve (early levels fill fast, late ones slowly).
func _refresh_xp(run: VSRun) -> void:
	if _xp_fill == null:
		return
	var need := run._xp_to_next(run.level)
	var frac := 0.0
	if need > 0:
		frac = clampf(float(run.xp) / float(need), 0.0, 1.0)
	_xp_fill.anchor_right = frac

## Drive the Orologion freeze feedback from the run's time-stop. While VSRun.is_frozen() the
## icy vignette and "FROZEN n" countdown show; the vignette's strength (and the label's fade)
## ease out over the final second so the breather visibly winds down as freeze_until approaches.
func _refresh_freeze(run: VSRun) -> void:
	if _freeze_vig == null:
		return
	var frozen := run.is_frozen() and run.phase == "playing"
	_freeze_vig.visible = frozen
	_freeze_label.visible = frozen
	if not frozen:
		return
	var remaining := maxf(0.0, run.freeze_until - run.elapsed)
	# Hold full strength through the freeze, then ease to zero across the last second so the
	# icy tint reads as thawing rather than snapping off.
	var strength := clampf(remaining, 0.0, 1.0)
	(_freeze_vig.material as ShaderMaterial).set_shader_parameter("strength", strength)
	_freeze_label.text = "FROZEN  %d" % int(ceil(remaining))
	_freeze_label.modulate = Color(FREEZE_TINT.r, FREEZE_TINT.g, FREEZE_TINT.b, strength)

## Format a seconds count as m:ss for the survival clock and run summaries.
func _mmss(seconds: float) -> String:
	var s := int(seconds)
	return "%d:%02d" % [s / 60, s % 60]

## Build the active-PowerUp line once (they're fixed for the run). Reads persisted levels
## from MetaSave and names them via the VSRun.POWERUPS catalog, in catalog order, e.g.
## "PowerUps:  Might Lv 2   Armor Lv 1". Stays hidden if no PowerUps are owned.
func _refresh_meta() -> void:
	if _meta == null or _meta_built:
		return
	_meta_built = true
	var levels := MetaSave.load_powerups()
	var parts := PackedStringArray()
	for opt in VSRun.POWERUPS:
		var lvl := int(levels.get(opt["id"], 0))
		if lvl > 0:
			parts.append("%s Lv %d" % [str(opt["title"]), lvl])
	if parts.is_empty():
		_meta.visible = false
		return
	_meta.text = "PowerUps:  " + "   ".join(parts)
	_meta.visible = true

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
	# Fold evolution state into the signature: evolving flips a flag without changing the
	# upgrade level, so the level-only signature above would otherwise never rebuild and the
	# panel would keep the pre-evolution name.
	sig += "e%s%s%s%s" % [run.whip_evolved, run.garlic_evolved, run.bible_evolved, run.knife_evolved]
	if sig == _loadout_sig:
		return
	_loadout_sig = sig
	for c in _loadout.get_children():
		c.queue_free()
	# Weapons first, then passive stat items — each section skipped when empty so an
	# early-game build (whip only, no passives yet) shows just the one header.
	_add_loadout_section(run, "WEAPONS", true)
	_add_loadout_section(run, "ITEMS", false)

## Append one build-panel section: a dim header plus a row per owned upgrade whose
## weapon/passive class matches `weapons`, in UPGRADE_POOL order. Nothing is added when
## the section has no owned upgrades yet.
func _add_loadout_section(run: VSRun, header: String, weapons: bool) -> void:
	var rows: Array = []
	for opt in VSRun.UPGRADE_POOL:
		var id := str(opt["id"])
		if WEAPON_IDS.has(id) != weapons:
			continue
		var lvl: int = run.upgrade_levels.get(id, 0)
		if lvl <= 0:
			continue
		rows.append(_make_loadout_row(id, str(opt["title"]), lvl, int(opt["max"]), run))
	if rows.is_empty():
		return
	var head := Label.new()
	head.text = header
	head.add_theme_font_size_override("font_size", 11)
	head.modulate = Color(0.7, 0.72, 0.8)
	_loadout.add_child(head)
	for r in rows:
		_loadout.add_child(r)

## One build-panel row: the upgrade's icon (skipped if missing) plus a two-line name +
## "Lv N/max" column. A weapon whose evolution flag is set on the run shows its evolved name
## in crimson, so the player sees the evolution persist beyond the in-world aura/lash tint;
## the level line turns gold at the cap so a maxed upgrade reads at a glance.
func _make_loadout_row(id: String, title: String, lvl: int, mx: int, run: VSRun) -> HBoxContainer:
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

	# Relabel evolved weapons to their evolved form. Evolution lives as a flag on the run
	# (the weapon reads it for its boosted profile), not as a distinct upgrade level, so the
	# name has to be resolved here from those flags.
	var disp_name := title
	var evolved := false
	match id:
		"whip":
			evolved = run.whip_evolved
			if evolved:
				disp_name = "Bloody Tear"
		"garlic":
			evolved = run.garlic_evolved
			if evolved:
				disp_name = "Soul Eater"
		"bible":
			evolved = run.bible_evolved
			if evolved:
				disp_name = "Unholy Vespers"
		"knife":
			evolved = run.knife_evolved
			if evolved:
				disp_name = "Thousand Edges"

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)

	var name_lbl := Label.new()
	name_lbl.text = disp_name
	name_lbl.add_theme_font_size_override("font_size", 13)
	if evolved:
		name_lbl.modulate = Color(1.0, 0.5, 0.55)   # crimson = evolved weapon
	col.add_child(name_lbl)

	var label := Label.new()
	label.text = "Lv %d/%d" % [lvl, mx]
	label.add_theme_font_size_override("font_size", 12)
	if lvl >= mx:
		label.modulate = Color(0.95, 0.82, 0.35)   # gold = maxed
	col.add_child(label)

	row.add_child(col)
	return row
