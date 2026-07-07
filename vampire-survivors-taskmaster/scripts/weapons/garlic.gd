class_name VSGarlic
extends Node2D
## A close-range damaging aura — the classic Vampire Survivors "Garlic": a translucent
## ring around the player that periodically damages every enemy inside it. Unlike the
## projectile weapon it needs no aiming; it rewards wading *through* the swarm. Mounted on
## the player and enabled/scaled by the run's garlic_level (0 = not yet picked: invisible
## and inert). This is the slice's second, mechanically-distinct weapon so level-up
## "weapon choices" become real, not just stat buffs.

const BASE_RADIUS := 74.0         # Lv1 aura radius; per-level Area growth lives in the CSV below
## Per-level level-up table (wiki Garlic.md "Levels"), editable in res://data/garlic_levels.csv —
## one row per level with independently-tunable columns so a designer can retune ANY single level
## without touching this script. Values are cumulative absolutes (each row fully describes the
## Garlic at that level): bonus_damage (flat added on top of BASE_DAMAGE), area_mult (scales the
## aura's reach), cooldown (seconds between damage pulses). The wiki pattern is:
## L1 +0 / 100% / 1.3s; L2 +2 & 140%; L3 +1 & 1.2s; L4 +1 & 160%; L5 +2 & 1.1s; L6 +1 & 180%;
## L7 +1 & 1.0s; L8 +2 & 200% (max = +10 damage, 200% area, 1.0s → base-5 Garlic peaks at 15 damage).
const LEVELS_CSV := "res://data/garlic_levels.csv"
static var _levels: Dictionary = {}   # int level -> {"bonus_damage": float, "area_mult": float, "cooldown": float}
static var _levels_loaded := false
const FLASH_TIME := 0.18          # aura brightens briefly on each pulse

## Aura VFX: SourceArt/sheets/Poof.png, a puff that blooms into a solid ring then cracks
## apart into fragments — reads as a ground aura, unlike the warrior pack's claw-slash VFX
## (used by the whip) which has no ring-shaped frame to offer. Copied in as garlic_aura.png
## and resized 512x512 -> 510x510 (3x3 grid: 170.67px/cell -> 170px) per VISUAL_RULES.md's
## non-integer-cell rule, which calls this exact sheet out by name. Row 1 col 0 is the
## solid full ring (used as the idle frame); cols 0->2->0 of that row crack it apart and
## back, which doubles as the pulse VFX played on every damage tick.
const VFX_TEX := "res://art/garlic_aura.png"
const VFX_COLS := 3
const VFX_ROWS := 3
const VFX_RING_ROW := 1
## Diameter (px, in the sheet's own pixels) of the solid ring frame, measured directly from
## its alpha bounding box — calibrates _vfx.scale so the sprite's rim lines up with the
## aura's actual hit radius.
const VFX_RING_DIAMETER_PX := 129.0
const VFX_PULSE_FPS := 28.0       # 5 frames over ~FLASH_TIME
const BASE_TINT := Color(0.65, 1.0, 0.55)     # base Garlic reads green
const EVOLVED_TINT := Color(0.85, 0.55, 1.0)  # Soul Eater burns violet

## Lv1 base damage lives in res://data/balance.csv ("garlic_base_damage", wiki base 5); the flat
## per-level bonus on top of it lives per-level in data/garlic_levels.csv (see LEVELS_CSV above).
static var BASE_DAMAGE := BalanceData.get_value("garlic_base_damage", 5.0)

# Evolved (Soul Eater) profile — applied when run.garlic_evolved: a wider, far deadlier
# devouring aura. Gated on Garlic already being maxed, so this is the run's payoff for
# maxing Garlic + owning Swift Boots.
const EVOLVED_DAMAGE_MULT := 2.5
const EVOLVED_RADIUS_BONUS := 40.0   # px added to the aura radius

var run: VSRun
var _cd := 0.0
var _flash := 0.0
var _vfx: AnimatedSprite2D

func _ready() -> void:
	_vfx = AnimatedSprite2D.new()
	_vfx.sprite_frames = _build_vfx_frames()
	_vfx.visible = false
	_vfx.animation_finished.connect(func() -> void:
		if _vfx.animation == &"pulse":
			_vfx.play(&"idle"))
	add_child(_vfx)

func _process(delta: float) -> void:
	if run == null:
		return
	var lvl: int = run.garlic_level
	if lvl <= 0:
		_vfx.visible = false
		return
	if not _vfx.visible:
		_vfx.visible = true
		_vfx.play(&"idle")
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
	var r := _radius(lvl)
	_vfx.scale = Vector2.ONE * (2.0 * r / VFX_RING_DIAMETER_PX)
	var pulse := _flash / FLASH_TIME
	var tint := EVOLVED_TINT if _is_evolved() else BASE_TINT
	_vfx.modulate = Color(tint.r, tint.g, tint.b, 0.55 + 0.35 * pulse)
	if run.phase != "playing":
		return
	_cd -= delta
	if _cd <= 0.0:
		_pulse(lvl)
		_cd = float(_row(lvl)["cooldown"]) * run.haste_mult()
		_flash = FLASH_TIME
		_vfx.play(&"pulse")

## True once the run has evolved Garlic into Soul Eater.
func _is_evolved() -> bool:
	return run != null and run.garlic_evolved

## Damage every enemy currently inside the aura. Damage scales with garlic level.
func _pulse(lvl: int) -> void:
	var r := _radius(lvl)
	var dmg := (BASE_DAMAGE * run.damage_variance() + float(_row(lvl)["bonus_damage"])) * run.might_mult() * run.power_mult()
	if _is_evolved():
		dmg *= EVOLVED_DAMAGE_MULT
	var hit_any := false
	for e in get_tree().get_nodes_in_group("enemies"):
		var er: float = e.radius if "radius" in e else VSEnemy.RADIUS
		if (e.position - global_position).length() < r + er:
			e.hit(dmg, global_position)
			hit_any = true
	if hit_any:
		AgentBridge.emit_event("sfx_played", {"name": "garlic"})

func _radius(lvl: int) -> float:
	# The Garlic's own reach grows only via its per-level Area column (wiki: 100% -> 200%);
	# run.area_mult (Candelabrador) then extends it further on top.
	var r := BASE_RADIUS * float(_row(lvl)["area_mult"])
	if _is_evolved():
		r += EVOLVED_RADIUS_BONUS
	return r * run.area_mult   # Candelabrador passive widens the aura

## The per-level tuning row for `lvl`, from data/garlic_levels.csv. Levels past the table (Limit
## Break) clamp to the highest defined level; a missing CSV reconstructs the wiki deltas so the
## Garlic never breaks.
static func _row(lvl: int) -> Dictionary:
	_ensure_levels()
	if _levels.has(lvl):
		return _levels[lvl]
	if _levels.is_empty():
		return _fallback_row(lvl)
	var keys := _levels.keys()
	keys.sort()
	return _levels[keys[keys.size() - 1]]

## Wiki Garlic.md deltas reconstructed as cumulative absolutes, used only if the CSV is missing.
static func _fallback_row(lvl: int) -> Dictionary:
	var bonus_by := [0.0, 0.0, 2.0, 3.0, 4.0, 6.0, 7.0, 8.0, 10.0]
	var area_by := [1.0, 1.0, 1.4, 1.4, 1.6, 1.6, 1.8, 1.8, 2.0]
	var cd_by := [1.3, 1.3, 1.3, 1.2, 1.2, 1.1, 1.1, 1.0, 1.0]
	var i := clampi(lvl, 1, 8)
	return {"bonus_damage": bonus_by[i], "area_mult": area_by[i], "cooldown": cd_by[i]}

## Parse the per-level table once. Column-name driven (falls back to fixed positions) so the CSV
## can carry extra tuning columns without breaking the loader.
static func _ensure_levels() -> void:
	if _levels_loaded:
		return
	_levels_loaded = true
	var f := FileAccess.open(LEVELS_CSV, FileAccess.READ)
	if f == null:
		push_warning("VSGarlic: cannot open %s (err %d)" % [LEVELS_CSV, FileAccess.get_open_error()])
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
			"bonus_damage": r[int(col.get("bonus_damage", 1))].strip_edges().to_float(),
			"area_mult": r[int(col.get("area_mult", 2))].strip_edges().to_float(),
			"cooldown": r[int(col.get("cooldown", 3))].strip_edges().to_float(),
		}
	f.close()

## Builds the two aura animations from garlic_aura.png's 3x3 grid (read left->right
## top->bottom): "idle" is the single solid-ring frame; "pulse" cracks that ring apart
## across its row and back (col 0->1->2->1->0), played once per damage tick.
func _build_vfx_frames() -> SpriteFrames:
	var tex := load(VFX_TEX) as Texture2D
	var fw := tex.get_width() / VFX_COLS
	var fh := tex.get_height() / VFX_ROWS
	var sf := SpriteFrames.new()
	sf.add_animation(&"idle")
	sf.set_animation_loop(&"idle", true)
	sf.add_frame(&"idle", _vfx_cell(tex, fw, fh, VFX_RING_ROW, 0))
	sf.add_animation(&"pulse")
	sf.set_animation_loop(&"pulse", false)
	sf.set_animation_speed(&"pulse", VFX_PULSE_FPS)
	for col in [0, 1, 2, 1, 0]:
		sf.add_frame(&"pulse", _vfx_cell(tex, fw, fh, VFX_RING_ROW, col))
	sf.remove_animation(&"default")
	return sf

func _vfx_cell(tex: Texture2D, fw: int, fh: int, row: int, col: int) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(col * fw, row * fh, fw, fh)
	return at
