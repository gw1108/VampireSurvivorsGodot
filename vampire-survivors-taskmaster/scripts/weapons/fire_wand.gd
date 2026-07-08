class_name VSFireWand
extends Node2D
## A random-target burst weapon — the classic Vampire Survivors "Fire Wand": on its cooldown it
## hurls a fat fireball at a RANDOM enemy (not the nearest, unlike the aimed Magic Wand), which
## flies across the field and DETONATES on impact — hitting its victim hard and splashing every
## enemy caught in the blast. Where the Magic Wand snipes the closest threat, the Knife throws
## where you face, the Lightning Ring smites from above, and the Runetracer caroms the walls, the
## Fire Wand lobs a heavy, unpredictable bomb into the horde — high single-target damage plus a
## small area burst wherever chaos sends it. Mounted on the player, enabled/scaled by
## run.fire_wand_level (0 = not yet picked: inert). The slice's eighth and final weapon, completing
## the GDD's designed roster.

## Lv1 base damage lives in res://data/balance.csv ("fire_wand_base_damage", wiki base 20); the flat
## per-level bonus on top of it lives per-level in data/fire_wand_levels.csv (see LEVELS_CSV below).
static var BASE_DAMAGE := BalanceData.get_value("fire_wand_base_damage", 20.0)
## Base cooldown + per-level tighten live in res://data/balance.csv ("fire_wand_base_interval" /
## "fire_wand_interval_per_level") so a designer can retune fire rate without touching this script.
static var BASE_INTERVAL := BalanceData.get_value("fire_wand_base_interval", 3.0)
static var INTERVAL_PER_LEVEL := BalanceData.get_value("fire_wand_interval_per_level", 0.18)
static var MIN_INTERVAL := BalanceData.get_value("fire_wand_min_interval", 1.4)

## Per-level level-up table (wiki Fire_Wand.md "Levels"), editable in res://data/fire_wand_levels.csv —
## one row per level with independently-tunable columns so a designer can retune ANY single level without
## touching this script. Values are cumulative absolutes (each row fully describes the wand at that level):
## bonus_damage (flat added on top of BASE_DAMAGE), speed_mult (scales projectile travel speed, relative to
## Lv1). The wiki pattern is: L2..L8 +10 damage each; L3/L5/L7 +20% speed (max = +70 damage → base-20 wand
## peaks at 90 damage, 160% speed). Amount is a constant 3 (wiki base 3, no per-level amount growth).
const LEVELS_CSV := "res://data/fire_wand_levels.csv"
static var _levels: Dictionary = {}   # int level -> {"bonus_damage": float, "speed_mult": float}
static var _levels_loaded := false
const AMOUNT := 3                    # fireballs per volley (wiki Amount, constant at every level)
const BASE_SPEED := 300.0             # px/sec at Lv1 — a lobbed bomb, slower than a bolt; scaled by the per-level speed_mult
const BASE_LIFE := 2.2               # seconds a fireball flies before self-detonating if it hits nothing
const BLAST_RADIUS := 58.0           # AoE splash around the detonation point

## Hellfire (Fire Wand + Might/Spinach EVOLVED): the fireball stops detonating and instead PIERCES,
## tearing straight through the horde and searing everything in its widened swath as it flies. Faithful
## to the wiki's non-detonating, piercing evolution. Applied on top of the level-scaled base profile.
const HELLFIRE_DAMAGE_MULT := 1.6    # each searing pass hits far harder than a plain fireball
const HELLFIRE_BLAST_MULT := 1.55    # a wider trail of flame reaches enemies it doesn't graze
const HELLFIRE_LIFE_MULT := 1.7      # flies longer, since it no longer stops on the first body

var run: VSRun
var _cd := 0.0

func _process(delta: float) -> void:
	if run == null:
		return
	var lvl: int = run.fire_wand_level
	if lvl <= 0:
		return
	if run.phase != "playing":
		return
	_cd -= delta
	if _cd <= 0.0:
		_fire(lvl)
		_cd = _interval(lvl)

## Cooldown between volleys, shrinking modestly with level (never below MIN_INTERVAL so a maxed
## Fire Wand stays a periodic bomb rather than a constant stream of explosions).
func _interval(lvl: int) -> float:
	return maxf(MIN_INTERVAL, BASE_INTERVAL - INTERVAL_PER_LEVEL * float(lvl - 1)) * run.haste_mult()

## One volley: pick up to `amount` DISTINCT random enemies and lob a fireball at each. Aim is
## locked at launch (the target may die mid-flight), so the ball flies to where the enemy was and
## detonates there — chaotic, unlike the Magic Wand's homing-nearest snipe. With no enemies on
## screen the volley is skipped (nothing to bomb).
func _fire(lvl: int) -> void:
	var enemies := []
	for e in get_tree().get_nodes_in_group("enemies"):
		# The "enemies" group also holds destructible props (candelabra); only bomb real enemies.
		if not e is VSEnemy:
			continue
		enemies.append(e)
	if enemies.is_empty():
		return
	enemies.shuffle()
	var evolved: bool = run.fire_wand_evolved
	var row := _row(lvl)
	var dmg_base := BASE_DAMAGE * run.damage_variance() + float(row["bonus_damage"])
	# Per-level speed_mult scales the lob; Bracer (run.projectile_speed_mult) then speeds it further.
	var speed := BASE_SPEED * float(row["speed_mult"]) * run.projectile_speed_mult
	var blast := BLAST_RADIUS * run.area_mult             # Candelabrador passive widens the blast
	var life := BASE_LIFE
	if evolved:                                           # Hellfire: harder, wider, longer-lived, piercing
		dmg_base *= HELLFIRE_DAMAGE_MULT
		blast *= HELLFIRE_BLAST_MULT
		life *= HELLFIRE_LIFE_MULT
	var dmg := dmg_base * run.might_mult() * run.power_mult()
	var count := mini(AMOUNT, enemies.size())
	for i in count:
		var target: VSEnemy = enemies[i]
		var dir := (target.position - global_position)
		if dir.length() < 1.0:
			dir = Vector2.RIGHT
		var b := Fireball.new()
		b.position = global_position
		b.vel = dir.normalized() * speed
		b.damage = dmg
		b.blast = blast
		b.life = life
		b.pierce = evolved
		b.run = run
		run.add_child(b)
	AgentBridge.emit_event("sfx_played", {"name": "fire_wand"})


## The per-level tuning row for `lvl`, from data/fire_wand_levels.csv. Levels past the table (Limit
## Break) clamp to the highest defined level; a missing CSV reconstructs the wiki deltas so the wand
## never breaks.
static func _row(lvl: int) -> Dictionary:
	_ensure_levels()
	if _levels.has(lvl):
		return _levels[lvl]
	if _levels.is_empty():
		var bonus := maxf(0.0, float(lvl - 1)) * 10.0                      # +10 from Lv2 on
		var speed := 1.0 + 0.2 * float((clampi(lvl, 1, 8) - 1) / 2)        # +20% at Lv3, Lv5, Lv7
		return {"bonus_damage": bonus, "speed_mult": speed}
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
		push_warning("VSFireWand: cannot open %s (err %d)" % [LEVELS_CSV, FileAccess.get_open_error()])
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
			"speed_mult": r[int(col.get("speed_mult", 2))].strip_edges().to_float(),
		}
	f.close()


## The flying fireball. Lives in world space as a child of the run (not the player) so it travels
## independently, detonating on the first enemy it overlaps — or self-detonating when its life runs
## out — and dealing its full damage to every enemy within `blast` of the impact.
##
## VFX: SourceArt/sheets/ExplosionSheet.png, a yellow-to-grey smoke/ember burst sheet (5 variants
## x 8 frames, cells already an integer 854x480 — no non-integer-cell resize forced, but each frame
## was still cropped from column 0 (one variant; the other 4 are unused) and downscaled 854x480 ->
## 160x90 offline (premultiplied-alpha resize, so no dark fringing at the soft smoke edges) to keep
## the sheet a sane in-project size, then repacked as fire_explosion.png, 2 cols x 4 rows, reading
## left->right top->bottom in the sheet's own time order. Frame 1 (row0 col1) is a plain glowing
## disc — used AS-IS for the ball's in-flight sprite, so no separate ember asset was needed; all 8
## frames play in order as the "detonate" burst on impact.
class Fireball:
	extends Node2D

	const RADIUS := 10.0             # the ball's own contact radius (gameplay hitbox, not visual)
	const VFX_TEX := "res://art/fire_explosion.png"
	const VFX_COLS := 2
	const VFX_ROWS := 4
	const VFX_DETONATE_FPS := 20.0   # 8 frames / 20fps = 0.4s blast
	## Diameter (px, in the baked sheet's own pixels) of frame 1's (the flight disc) alpha bounding
	## box — calibrates the flight sprite's scale so it matches the ball's own contact RADIUS.
	const VFX_FLIGHT_RADIUS_PX := 38.0
	## Half-width (px) of the burst's DENSE/bright core — measured on the yellow detonation frame
	## (the punchy body, halfW ~44px), NOT the full faint-wisp bbox (frame 7, ~55px). Calibrating
	## against the dense core makes the visible burst FILL the fireball's actual `blast` footprint
	## (the faint outer wisps then spill a little past it, which reads naturally) instead of the old
	## under-fill that made the AoE feel weaker than it hits.
	const VFX_BLAST_REFERENCE_RADIUS_PX := 44.0
	## A brief hot over-bright pop on the first ~0.1s of the detonation, so a cluster of bursts
	## flashes and pops against Mad Forest's muted grass and dark bat sprites before settling to
	## normal smoke. Overbright modulate (>1) drives the already-yellow core toward hot white-yellow.
	const DETONATE_FLASH_TIME := 0.1
	const DETONATE_FLASH_TINT := Color(1.9, 1.75, 1.25)
	const HELLFIRE_TINT := Color(1.3, 1.2, 1.0)  # Hellfire's comet burns hotter/whiter than the flame

	var vel := Vector2.RIGHT
	var damage := 20.0
	var blast := 58.0
	var life := 2.2
	var pierce := false              # Hellfire: sear through enemies instead of detonating on the first
	var run: VSRun
	var _flicker := 0.0
	var _exploding := false
	var _flash := 0.0                # remaining time on the detonation's hot over-bright flash
	var _seared := {}                # ids of enemies a piercing ball has already burned (hit each once)
	var _vfx: AnimatedSprite2D

	func _ready() -> void:
		add_to_group("projectiles")
		z_index = 1
		_vfx = AnimatedSprite2D.new()
		_vfx.sprite_frames = _build_vfx_frames()
		_vfx.animation_finished.connect(func() -> void: queue_free())
		add_child(_vfx)
		_vfx.play(&"flight")
		_update_flight_vfx()

	func _process(delta: float) -> void:
		if run == null:
			return
		# Freeze with the game during level-up / after the run ends (mirrors every other weapon).
		if run.phase != "playing":
			return
		if _exploding:
			# The detonation burst is playing (queue_free() fires on its animation_finished). Decay the
			# hot over-bright flash back to normal white over the first couple of frames so the burst pops.
			if _flash > 0.0:
				_flash = maxf(0.0, _flash - delta)
				_vfx.modulate = Color.WHITE.lerp(DETONATE_FLASH_TINT, _flash / DETONATE_FLASH_TIME)
			return
		life -= delta
		if life <= 0.0:
			# Hellfire never detonates — it simply burns out at the end of its long flight.
			if pierce:
				queue_free()
			else:
				_detonate()
			return
		position += vel * delta
		# On contact: a plain fireball detonates on the first enemy; Hellfire sears through it and
		# keeps going, burning everything in its widened swath (each enemy only once).
		for e in get_tree().get_nodes_in_group("enemies"):
			if not e is VSEnemy:
				continue
			var er: float = e.radius if "radius" in e else VSEnemy.RADIUS
			if (e.position - position).length() < RADIUS + er:
				if pierce:
					_sear()
					break
				else:
					_detonate()
					return
		_flicker += delta * 18.0
		_update_flight_vfx()

	## Scales/tints the flight disc to the ball's live contact radius, with the same flicker pulse
	## and Hellfire swell/heat the old procedural draw used.
	func _update_flight_vfx() -> void:
		var pulse := 1.0 + 0.15 * sin(_flicker)
		var r := RADIUS * (1.5 if pierce else 1.0) * pulse
		_vfx.scale = Vector2.ONE * (r / VFX_FLIGHT_RADIUS_PX)
		_vfx.modulate = HELLFIRE_TINT if pierce else Color.WHITE

	## Hellfire's pass: burn every not-yet-seared enemy within `blast` of the ball and remember them
	## so a piercing ball damages each enemy exactly once as it tears through the horde.
	func _sear() -> void:
		for e in get_tree().get_nodes_in_group("enemies"):
			if not e is VSEnemy:
				continue
			var er: float = e.radius if "radius" in e else VSEnemy.RADIUS
			if (e.position - position).length() <= blast + er and not _seared.has(e.get_instance_id()):
				_seared[e.get_instance_id()] = true
				e.hit(damage, position)

	## Explode: deal full damage to every enemy within `blast`, kick a little camera trauma, and
	## switch to the "detonate" burst VFX (queue_free() fires on its animation_finished). Guarded
	## so a fireball detonates exactly once.
	func _detonate() -> void:
		if _exploding:
			return
		_exploding = true
		for e in get_tree().get_nodes_in_group("enemies"):
			if not e is VSEnemy:
				continue
			var er: float = e.radius if "radius" in e else VSEnemy.RADIUS
			if (e.position - position).length() <= blast + er:
				e.hit(damage, position)
		if run:
			run.add_camera_shake(0.16)   # a small jolt so the blast lands with weight
		_flash = DETONATE_FLASH_TIME
		_vfx.modulate = DETONATE_FLASH_TINT
		_vfx.scale = Vector2.ONE * (blast / VFX_BLAST_REFERENCE_RADIUS_PX)
		_vfx.play(&"detonate")

	## Builds the "flight" (frame 1: a plain glowing disc, looping) and "detonate" (all 8 frames in
	## order, once) animations from fire_explosion.png's 2x4 grid (read left->right top->bottom).
	func _build_vfx_frames() -> SpriteFrames:
		var sf := SpriteFrames.new()
		var tex := load(VFX_TEX) as Texture2D
		var fw := tex.get_width() / VFX_COLS
		var fh := tex.get_height() / VFX_ROWS
		sf.add_animation(&"flight")
		sf.set_animation_loop(&"flight", true)
		sf.add_frame(&"flight", _vfx_cell(tex, fw, fh, 0, 1))
		sf.add_animation(&"detonate")
		sf.set_animation_loop(&"detonate", false)
		sf.set_animation_speed(&"detonate", VFX_DETONATE_FPS)
		for frame_i in 8:
			sf.add_frame(&"detonate", _vfx_cell(tex, fw, fh, frame_i / VFX_COLS, frame_i % VFX_COLS))
		sf.remove_animation(&"default")
		return sf

	func _vfx_cell(tex: Texture2D, fw: int, fh: int, row: int, col: int) -> AtlasTexture:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(col * fw, row * fh, fw, fh)
		return at
