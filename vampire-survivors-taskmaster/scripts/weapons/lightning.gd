class_name VSLightning
extends Node2D
## A random-strike weapon — the classic Vampire Survivors "Lightning Ring": on its cooldown
## it calls bolts down on random enemies scattered across the field, each dealing a burst of
## damage in a small radius at the impact point. Unlike the aimed Magic Wand, the melee Whip,
## the static Garlic aura, and the orbiting King Bible, the Lightning Ring reaches out and
## smites targets ANYWHERE on screen at once — unaimable area denial that thins the whole horde
## rather than the pack pressing on the player. Mounted on the player, enabled/scaled by
## run.lightning_level (0 = not yet picked: no strikes, inert). The slice's fifth,
## mechanically-distinct weapon.

static var RANGE := BalanceData.get_value("lightning_range", 620.0)   # a strike may reach any enemy within this of the player

## Lv1 base damage lives in res://data/balance.csv ("lightning_base_damage", wiki base 15); the flat
## per-level bonus on top of it lives per-level in data/lightning_levels.csv (see LEVELS_CSV below).
## Lv1 = 15 (wiki base), Lv8 = 65 — a hard, bursty hit.
static var BASE_DAMAGE := BalanceData.get_value("lightning_base_damage", 15.0)

## Per-level level-up table (wiki Lightning_Ring.md "Levels"), editable in res://data/lightning_levels.csv
## — one row per level with independently-tunable columns so a designer can retune ANY single level
## without touching this script. Values are cumulative absolutes (each row fully describes the ring at
## that level): amount (bolts per volley, wiki base 2), bonus_damage (flat added on top of BASE_DAMAGE),
## area_mult (scales each bolt's splash radius, wiki 100%). The wiki pattern is: amount 2→6 (+1 on
## L2/4/6/8), +10 damage L3 / +20 L5 / +20 L7 (base-15 ring peaks at 65), and area 100%→400% (+100%
## on L3/5/7).
const LEVELS_CSV := "res://data/lightning_levels.csv"
static var _levels: Dictionary = {}   # int level -> {"amount": int, "bonus_damage": float, "area_mult": float}
static var _levels_loaded := false

static var MAX_STRIKES: int = int(BalanceData.get_value("lightning_max_strikes", 6.0))              # per-volley cap for the base ring (wiki Amount peaks at 6)
static var EVO_BONUS_STRIKES: int = int(BalanceData.get_value("lightning_evo_bonus_strikes", 3.0))        # Thunder Loop rains extra bolts on top of the level count…
static var EVO_MAX_STRIKES: int = int(BalanceData.get_value("lightning_evo_max_strikes", 10.0))         # …raising the per-volley cap so a maxed evolved ring saturates
static var EVO_SPLASH_MULT := BalanceData.get_value("lightning_evo_splash_mult", 1.6)        # Thunder Loop's blast is wider than the base ring's
static var STRIKE_RADIUS := BalanceData.get_value("lightning_strike_radius", 46.0)  # AoE splash around each bolt's impact (before the per-level area_mult)
## Base cooldown + per-level shrink live in res://data/balance.csv ("lightning_base_interval" /
## "lightning_interval_per_level") so a designer can retune fire rate without touching this script.
static var BASE_INTERVAL := BalanceData.get_value("lightning_base_interval", 4.5)
static var INTERVAL_PER_LEVEL := BalanceData.get_value("lightning_interval_per_level", 0.3)
static var MIN_INTERVAL := BalanceData.get_value("lightning_min_interval", 1.8)

## Strike VFX: SourceArt/pixel_art-animations-warrior "VFX 5", a jagged burst of spikes radiating
## from a point and fading — reads as a crackling discharge, unlike VFX3's smooth claw arc (used
## by the whip). All 8 cells are populated (unlike VFX2/VFX4, which have an empty cell), so no
## blank frame ever plays. VFX5 is natively red/orange, which a plain modulate tint can't turn
## blue (multiplying a near-zero blue channel by any tint still leaves it near zero — confirmed
## by an in-game screenshot check: the tinted burst still read as dark maroon). Baked instead as
## lightning_bolt.png: every pixel replaced by its own luminance times an electric-blue tint (hue-
## agnostic, so the shape/gradient survive but the color is genuinely blue-white), then copied in.
const VFX_TEX := "res://art/lightning_bolt.png"
const VFX_COLS := 2
const VFX_ROWS := 4
const VFX_FPS := 40.0                     # 8 frames / 40fps = 0.2s, a punchy flash
const VFX_TINT := Color(1.0, 1.0, 1.0)    # the baked texture is already electric blue-white
const EVO_VFX_TINT := Color(1.3, 1.2, 1.4)  # Thunder Loop's crack burns brighter/whiter
## Radius (px, in the sheet's own pixels) the burst's alpha bounding box reaches at its widest
## frame (measured directly: row2/col1 used_rect ~100x85, row3/col0 ~112x73) — calibrates
## _vfx_pool scale so the sprite's visual reach lines up with each strike's actual splash radius.
const VFX_REFERENCE_RADIUS_PX := 55.0

var run: VSRun
var _cd := 0.0
## Pooled strike VFX, one per possible simultaneous bolt (sized to the evolved cap so a maxed
## Thunder Loop volley never runs out). Positioned and played per strike in _strike().
var _vfx_pool: Array = []

func _ready() -> void:
	var frames := _build_vfx_frames()
	for i in EVO_MAX_STRIKES:
		var vfx := AnimatedSprite2D.new()
		vfx.sprite_frames = frames
		vfx.visible = false
		vfx.animation_finished.connect(func() -> void: vfx.visible = false)
		add_child(vfx)
		_vfx_pool.append(vfx)

func _process(delta: float) -> void:
	if run == null:
		return
	var lvl: int = run.lightning_level
	if lvl <= 0:
		return
	if run.phase != "playing":
		return
	_cd -= delta
	if _cd <= 0.0:
		_strike(lvl)
		_cd = _interval(lvl)

## Cooldown between volleys, shrinking modestly with level so the ring keeps firing as the run
## escalates (never below MIN_INTERVAL so it stays a burst weapon, not a stream).
func _interval(lvl: int) -> float:
	return maxf(MIN_INTERVAL, BASE_INTERVAL - INTERVAL_PER_LEVEL * float(lvl - 1)) * run.haste_mult()

## Bolts per volley: the per-level table's amount (wiki 2→6), capped so a maxed ring rains a
## satisfying cluster without smiting the entire screen for free. Thunder Loop (evolved) adds a
## flat bonus and lifts the cap so the whole horde lights up.
func _strike_count(lvl: int) -> int:
	var amount := int(_row(lvl)["amount"])
	if run != null and run.lightning_evolved:
		return mini(amount + EVO_BONUS_STRIKES, EVO_MAX_STRIKES)
	return mini(amount, MAX_STRIKES)

## The per-level tuning row for `lvl`, from data/lightning_levels.csv. Levels past the table (Limit
## Break) clamp to the highest defined level; a missing CSV reconstructs the wiki deltas so the ring
## never breaks.
static func _row(lvl: int) -> Dictionary:
	_ensure_levels()
	if _levels.has(lvl):
		return _levels[lvl]
	if _levels.is_empty():
		# Reconstruct the wiki deltas: +1 amount on L2/4/6/8, +10 damage L3 / +20 L5 / +20 L7,
		# area 100% +100% on L3/5/7.
		var amount := 2
		for al in [2, 4, 6, 8]:
			if lvl >= al:
				amount += 1
		var bonus := (10.0 if lvl >= 3 else 0.0) + (20.0 if lvl >= 5 else 0.0) + (20.0 if lvl >= 7 else 0.0)
		var area := 1.0 + (1.0 if lvl >= 3 else 0.0) + (1.0 if lvl >= 5 else 0.0) + (1.0 if lvl >= 7 else 0.0)
		return {"amount": amount, "bonus_damage": bonus, "area_mult": area}
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
		push_warning("VSLightning: cannot open %s (err %d)" % [LEVELS_CSV, FileAccess.get_open_error()])
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
			"amount": r[int(col.get("amount", 1))].strip_edges().to_int(),
			"bonus_damage": r[int(col.get("bonus_damage", 2))].strip_edges().to_float(),
			"area_mult": r[int(col.get("area_mult", 3))].strip_edges().to_float(),
		}
	f.close()

## One volley: pick a random subset of in-range enemies and smite each, splashing every enemy
## within STRIKE_RADIUS of the impact. Plays a pooled strike VFX per bolt.
func _strike(lvl: int) -> void:
	var targets := []
	for e in get_tree().get_nodes_in_group("enemies"):
		# The "enemies" group also holds destructible props (candelabra); the ring only smites
		# real enemies so it never wastes a bolt on scenery.
		if not e is VSEnemy:
			continue
		if (e.position - global_position).length() <= RANGE:
			targets.append(e)
	if targets.is_empty():
		return
	targets.shuffle()
	var evolved: bool = run.lightning_evolved
	var row := _row(lvl)
	var dmg := (BASE_DAMAGE * run.damage_variance() + float(row["bonus_damage"])) * run.might_mult() * run.power_mult()
	# Per-level area_mult widens each bolt's splash (wiki 100%→400%); Candelabrador stacks on top.
	var splash := STRIKE_RADIUS * float(row["area_mult"]) * run.area_mult
	if evolved:
		splash *= EVO_SPLASH_MULT                 # Thunder Loop's blast reaches wider
	# Thunder Loop re-cracks each bolt: every impact lands its damage twice, so a maxed evolved
	# ring smites each point for double the base ring's toll.
	var strikes_per_bolt := 2 if evolved else 1
	var n := mini(_strike_count(lvl), targets.size())
	var hit_any := false
	var tint := EVO_VFX_TINT if evolved else VFX_TINT
	for i in n:
		var at: Vector2 = targets[i].position
		for other in get_tree().get_nodes_in_group("enemies"):
			if not other is VSEnemy:
				continue
			var er: float = other.radius if "radius" in other else VSEnemy.RADIUS
			if (other.position - at).length() <= splash + er:
				for _s in strikes_per_bolt:
					other.hit(dmg, at)
				hit_any = true
		var vfx: AnimatedSprite2D = _vfx_pool[i]
		vfx.position = at - global_position
		vfx.rotation = randf() * TAU   # a fixed orientation would look mechanically repetitive
		vfx.scale = Vector2.ONE * (splash / VFX_REFERENCE_RADIUS_PX)
		vfx.modulate = tint
		vfx.visible = true
		vfx.play("default")
	if hit_any:
		run.add_camera_shake(0.12)   # a small jolt so the smite lands with weight
		AgentBridge.emit_event("sfx_played", {"name": "lightning"})

## Builds the strike VFX's frames from lightning_bolt.png (2 cols x 4 rows, read left->right
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
