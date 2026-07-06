class_name VSWhip
extends Node2D
## A melee sweep weapon — the classic Vampire Survivors "Whip": a short, wide arc that
## lashes out to the side the player is facing, damaging every enemy caught in the wedge.
## Unlike the projectile (aimed, ranged) and the Garlic (persistent aura around you), the
## whip is a directional burst: it rewards facing into the swarm and hits hard but briefly.
## From level 2 it lashes BOTH sides at once (faithful to VS, where the second whip covers
## your back). Mounted on the player, enabled/scaled by the run's whip_level (0 = not yet
## picked: invisible and inert). This is the slice's third, mechanically-distinct weapon.

const BASE_RANGE := 140.0
const ARC_HALF_ANGLE := deg_to_rad(50.0)   # half-width of the damage wedge

## Per-level level-up table (wiki Whip.md "Levels"), editable in res://data/whip_levels.csv —
## one row per level with independently-tunable columns so a designer can retune ANY single level
## without touching this script. Values are cumulative absolutes (each row fully describes the
## whip at that level): projectiles (1 = facing side only, 2 = both flanks), bonus_damage (flat
## added on top of BASE_DAMAGE), area_mult (scales the lash's reach). The wiki pattern is:
## L1 1 proj / +0 / 100%; L2 2 proj; L3 +5; L4 +5 & 110%; L5 +5; L6 +5 & 120%; L7 +5; L8 +5
## (max = +30 damage, 120% area, +1 projectile → base-10 whip peaks at 40 damage, matching the wiki).
const LEVELS_CSV := "res://data/whip_levels.csv"
static var _levels: Dictionary = {}   # int level -> {"projectiles": int, "bonus_damage": float, "area_mult": float}
static var _levels_loaded := false
## Swing cooldown lives in res://data/balance.csv ("whip_base_interval") so a designer can
## retune fire rate without touching this script.
static var ATTACK_INTERVAL := BalanceData.get_value("whip_base_interval", 1.2)

## Lash VFX: SourceArt/pixel_art-animations-warrior "VFX 3", a claw-like slash swipe. Its
## smooth curl sits near the art's local origin and its impact burst flares out toward the
## far tip once rotated -135°, which is why -135°/+135° (mirrored) reads as a whip cracking
## outward to the right/left rather than a vertical chop — confirmed by rendering both sides
## side-by-side (see whip VFX rotation check) before landing on this value.
const VFX_TEX := "res://art/whip_slash.png"
const VFX_COLS := 2
const VFX_ROWS := 5
const VFX_FPS := 40.0                      # 10 frames / 40fps = 0.25s, matching the old sweep time
const VFX_ROTATION := deg_to_rad(-135.0)
const VFX_OFFSET_FRAC := 0.55              # how far out along the lash the VFX sits, as a fraction of range
## Lv1 base damage lives in res://data/balance.csv ("whip_base_damage", wiki base 10); the flat
## per-level bonus on top of it lives per-level in data/whip_levels.csv (see LEVELS_CSV above).
static var BASE_DAMAGE := BalanceData.get_value("whip_base_damage", 10.0)

# Evolved (Bloody Tear) profile — applied when run.whip_evolved: a longer, wider, far deadlier
# lash that always covers both flanks. Gated on Whip already being maxed, so this is the run's
# payoff for maxing Whip + owning Vitality (Hollow Heart).
const EVOLVED_DAMAGE_MULT := 2.2
const EVOLVED_RANGE_BONUS := 60.0                 # px added to reach
const EVOLVED_ARC_BONUS := deg_to_rad(20.0)       # widens each wedge's half-angle

var run: VSRun
var _cd := 0.0
var _facing := 1           # last horizontal facing: +1 right, -1 left
var _swing_facing := 1     # facing captured at the moment of the swing (drives the lash VFX)
var _swing_both := false   # whether the current swing lashed both sides
var _vfx_r: AnimatedSprite2D   # lash VFX for the right-facing side
var _vfx_l: AnimatedSprite2D   # lash VFX for the left-facing side (mirrored)

func _ready() -> void:
	var frames := _build_vfx_frames()
	_vfx_r = _make_vfx(frames, false)
	_vfx_l = _make_vfx(frames, true)
	add_child(_vfx_r)
	add_child(_vfx_l)

func _process(delta: float) -> void:
	if run == null:
		return
	var lvl: int = run.whip_level
	if lvl <= 0:
		return
	if run.phase != "playing":
		return
	# Track facing from horizontal input so the whip lashes the way the player moves.
	var h := Input.get_axis("move_left", "move_right")
	if absf(h) > 0.1:
		_facing = 1 if h > 0.0 else -1
	_cd -= delta
	if _cd <= 0.0:
		_swing(lvl)
		_cd = ATTACK_INTERVAL * run.haste_mult()

## One swing: damage every enemy inside the facing-side wedge (both sides from level 2, or
## always once evolved into Bloody Tear).
func _swing(lvl: int) -> void:
	var row := _row(lvl)
	_swing_facing = _facing
	# From level 2 the whip fires a second projectile covering the opposite flank (both sides);
	# Bloody Tear always lashes both. Driven by the per-level "projectiles" column.
	_swing_both = int(row["projectiles"]) >= 2 or _is_evolved()
	var r := _range(lvl)
	var arc := _arc_half()
	_play_vfx(r)
	var dmg := (BASE_DAMAGE * run.damage_variance() + float(row["bonus_damage"])) * run.might_mult() * run.power_mult()
	if _is_evolved():
		dmg *= EVOLVED_DAMAGE_MULT
	var hit_any := false
	var hit_enemies := {}  # enemies already damaged this swing (both sides share one set)
	for s in _sides():
		var facing_vec := Vector2(s, 0)
		for e in get_tree().get_nodes_in_group("enemies"):
			if hit_enemies.has(e):
				continue
			var to: Vector2 = e.position - global_position
			var er: float = e.radius if "radius" in e else VSEnemy.RADIUS
			var d := to.length()
			if d > r + er:
				continue
			# On top of us, or inside the angular wedge on this side.
			if d < 1.0 or absf(to.angle_to(facing_vec)) <= arc:
				e.hit(dmg, global_position)
				hit_enemies[e] = true
				hit_any = true
	if hit_any:
		AgentBridge.emit_event("sfx_played", {"name": "whip"})

## True once the run has evolved Whip into Bloody Tear.
func _is_evolved() -> bool:
	return run != null and run.whip_evolved

## Half-width of the damage/visual wedge, widened once evolved into Bloody Tear.
func _arc_half() -> float:
	return ARC_HALF_ANGLE + (EVOLVED_ARC_BONUS if _is_evolved() else 0.0)

## The facing signs this swing covers: just the facing side, or both from level 2.
func _sides() -> Array:
	return [1, -1] if _swing_both else [_swing_facing]

func _range(lvl: int) -> float:
	# The whip's own reach grows only via its per-level Area column (wiki: +10% at Lv4 & Lv6);
	# run.area_mult (Candelabrador) then extends it further on top.
	var r := BASE_RANGE * float(_row(lvl)["area_mult"])
	if _is_evolved():
		r += EVOLVED_RANGE_BONUS
	return r * run.area_mult

## The per-level tuning row for `lvl`, from data/whip_levels.csv. Levels past the table (Limit
## Break) clamp to the highest defined level; a missing CSV reconstructs the wiki deltas so the
## whip never breaks.
static func _row(lvl: int) -> Dictionary:
	_ensure_levels()
	if _levels.has(lvl):
		return _levels[lvl]
	if _levels.is_empty():
		var bonus := maxf(0.0, float(lvl - 2)) * 5.0                     # +5 from Lv3 on
		var area := 1.0 + (0.1 if lvl >= 4 else 0.0) + (0.1 if lvl >= 6 else 0.0)
		return {"projectiles": (1 if lvl <= 1 else 2), "bonus_damage": bonus, "area_mult": area}
	var keys := _levels.keys()
	keys.sort()
	return _levels[keys[keys.size() - 1]]

## Parse the per-level table once. Column-name driven (falls back to fixed positions) so the CSV
## can carry extra tuning columns without breaking the loader.
static func _ensure_levels() -> void:
	if _levels_loaded:
		return
	_levels_loaded = true
	var f := FileAccess.open(LEVELS_CSV, FileAccess.READ)
	if f == null:
		push_warning("VSWhip: cannot open %s (err %d)" % [LEVELS_CSV, FileAccess.get_open_error()])
		return
	var header := f.get_csv_line()
	var col := {}
	for i in header.size():
		col[header[i].strip_edges()] = i
	while not f.eof_reached():
		var r := f.get_csv_line()
		if r.size() < 2 or r[0].strip_edges() == "":
			continue
		var lvl := r[int(col.get("level", 0))].strip_edges().to_int()
		_levels[lvl] = {
			"projectiles": r[int(col.get("projectiles", 1))].strip_edges().to_int(),
			"bonus_damage": r[int(col.get("bonus_damage", 2))].strip_edges().to_float(),
			"area_mult": r[int(col.get("area_mult", 3))].strip_edges().to_float(),
		}
	f.close()

## Fire the lash VFX on every side this swing covers, positioned out along the lash at
## VFX_OFFSET_FRAC * range. Bloody Tear tints it a deeper crimson so the evolution reads
## at a glance (mirrors the old procedural fill's evolved tint).
func _play_vfx(r: float) -> void:
	_vfx_r.visible = false
	_vfx_l.visible = false
	var tint := Color(1.3, 0.55, 0.55) if _is_evolved() else Color(1, 1, 1)
	for s in _sides():
		var vfx := _vfx_r if s > 0 else _vfx_l
		vfx.position = Vector2(s, 0) * r * VFX_OFFSET_FRAC
		vfx.modulate = tint
		vfx.visible = true
		vfx.play("default")

## Builds the lash VFX's frames from the VFX3 sprite sheet (2 cols x 5 rows, read left->right
## top->bottom), per the import_sprite_sheet_animation skill's in-code SpriteFrames pattern.
func _build_vfx_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", VFX_FPS)
	sf.set_animation_loop("default", false)
	var tex := load(VFX_TEX) as Texture2D
	var fw := tex.get_width() / VFX_COLS
	var fh := tex.get_height() / VFX_ROWS
	for row in VFX_ROWS:
		for col in VFX_COLS:
			var frame := AtlasTexture.new()
			frame.atlas = tex
			frame.region = Rect2(col * fw, row * fh, fw, fh)
			sf.add_frame("default", frame)
	return sf

## One lash VFX node: hidden until the first swing, self-hiding when its one-shot finishes.
## `flipped` mirrors it for the left side — flip_h + negated rotation keeps the impact burst
## flaring outward away from the player on both sides (see VFX_ROTATION above).
func _make_vfx(frames: SpriteFrames, flipped: bool) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = frames
	s.flip_h = flipped
	s.rotation = -VFX_ROTATION if flipped else VFX_ROTATION
	s.visible = false
	s.animation_finished.connect(func() -> void: s.visible = false)
	return s
