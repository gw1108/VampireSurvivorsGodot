class_name VSGarlic
extends Node2D
## A close-range damaging aura — the classic Vampire Survivors "Garlic": a translucent
## ring around the player that periodically damages every enemy inside it. Unlike the
## projectile weapon it needs no aiming; it rewards wading *through* the swarm. Mounted on
## the player and enabled/scaled by the run's garlic_level (0 = not yet picked: invisible
## and inert). This is the slice's second, mechanically-distinct weapon so level-up
## "weapon choices" become real, not just stat buffs.

const BASE_RADIUS := 74.0
const RADIUS_PER_LEVEL := 20.0
## Seconds between damage pulses lives in res://data/balance.csv ("garlic_tick_interval")
## so a designer can retune fire rate without touching this script.
static var TICK_INTERVAL := BalanceData.get_value("garlic_tick_interval", 0.5)
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

## Base damage + per-level growth live in res://data/balance.csv ("garlic_base_damage" /
## "garlic_damage_per_level") so a designer can retune them without touching this script.
static var BASE_DAMAGE := BalanceData.get_value("garlic_base_damage", 0.0)
static var DAMAGE_PER_LEVEL := BalanceData.get_value("garlic_damage_per_level", 1.0)

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
		_cd = TICK_INTERVAL * run.haste_mult()
		_flash = FLASH_TIME
		_vfx.play(&"pulse")

## True once the run has evolved Garlic into Soul Eater.
func _is_evolved() -> bool:
	return run != null and run.garlic_evolved

## Damage every enemy currently inside the aura. Damage scales with garlic level.
func _pulse(lvl: int) -> void:
	var r := _radius(lvl)
	var dmg := (BASE_DAMAGE + DAMAGE_PER_LEVEL * float(lvl)) * run.might_mult() * run.power_mult()
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
	var r := BASE_RADIUS + RADIUS_PER_LEVEL * float(lvl - 1)
	if _is_evolved():
		r += EVOLVED_RADIUS_BONUS
	return r * run.area_mult   # Candelabrador passive widens the aura

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
