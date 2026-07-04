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

const RANGE := 620.0                 # a strike may reach any enemy within this of the player
## Base damage + per-level growth live in res://data/balance.csv ("lightning_base_damage" /
## "lightning_damage_per_level") so a designer can retune them without touching this script.
## Lv1 = 15 (wiki base), Lv8 = 50 — a hard, bursty hit.
static var BASE_DAMAGE := BalanceData.get_value("lightning_base_damage", 10.0)
static var DAMAGE_PER_LEVEL := BalanceData.get_value("lightning_damage_per_level", 5.0)
const BASE_STRIKES := 2              # bolts per volley (wiki Amount 2)…
const MAX_STRIKES := 6              # …growing by one every three levels, capped here
const EVO_BONUS_STRIKES := 3        # Thunder Loop rains extra bolts on top of the level count…
const EVO_MAX_STRIKES := 10         # …raising the per-volley cap so a maxed evolved ring saturates
const EVO_SPLASH_MULT := 1.6        # Thunder Loop's blast is wider than the base ring's
const STRIKE_RADIUS := 46.0          # AoE splash around each bolt's impact
## Base cooldown + per-level shrink live in res://data/balance.csv ("lightning_base_interval" /
## "lightning_interval_per_level") so a designer can retune fire rate without touching this script.
static var BASE_INTERVAL := BalanceData.get_value("lightning_base_interval", 4.5)
static var INTERVAL_PER_LEVEL := BalanceData.get_value("lightning_interval_per_level", 0.3)
const MIN_INTERVAL := 1.8

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

## Bolts per volley: base two, plus one for every three levels, capped so a maxed ring rains
## a satisfying cluster without smiting the entire screen for free. Thunder Loop (evolved) adds
## a flat bonus and lifts the cap so the whole horde lights up.
func _strike_count(lvl: int) -> int:
	if run != null and run.lightning_evolved:
		return clampi(BASE_STRIKES + lvl / 3 + EVO_BONUS_STRIKES, BASE_STRIKES, EVO_MAX_STRIKES)
	return clampi(BASE_STRIKES + lvl / 3, BASE_STRIKES, MAX_STRIKES)

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
	var dmg := (BASE_DAMAGE + DAMAGE_PER_LEVEL * float(lvl)) * run.might_mult() * run.power_mult()
	var splash := STRIKE_RADIUS * run.area_mult   # Candelabrador passive widens each bolt's splash
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
