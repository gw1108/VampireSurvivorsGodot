class_name VSEnemy
extends Node2D
## A basic enemy: walks straight at the player and deals periodic contact damage.
## Distance-based contact (no physics) — robust and cheap with many on screen.

const RADIUS := 12.0
const FLASH_DURATION := 0.1
## REAPER "immune to freeze" shimmer: a red pulse layered over the boss while an Orologion
## time-stop is active, so its exemption reads as a deliberate design, not a stuck sprite.
const IMMUNE_SHIMMER_FREQ := 9.0     # rad/s of the sine pulse — a fast, alarming flicker
const IMMUNE_SHIMMER_AMOUNT := 0.7   # how far the pulse lerps toward the hot red at its peak
## Enemy colliders: every enemy carries a solid circular body (RADIUS, or its per-type
## `radius`), so two units can never occupy the same space. Each enemy homes STRAIGHT at the
## player; after moving, a positional overlap-resolution pass (see _overlap_correction) shoves
## any interpenetrating pair apart until their circles just touch. The horde therefore packs into
## the VS-style crush wall as a mass of solid bodies pressing on the player — no steering force
## bends the beeline the way the old boid-separation blend did. Heavy units barely budge (the shove
## is scaled by knock_resist), so the finale REAPER ploughs through the pack instead of getting
## mired in it.
## COLLIDE_CELL sizes the shared spatial grid: it is >= twice the largest enemy radius (REAPER's
## 30), so any neighbour whose body could overlap this one is always inside the 3x3 block of cells
## scanned per enemy (see _ensure_grid) — keeping the whole-horde cost ~O(n), not O(n²).
const COLLIDE_CELL := 60.0
## Cap on the number of neighbour bodies each enemy examines per frame while resolving overlaps.
## The uniform grid is only ~O(n) while per-cell density is bounded; when the horde COLLAPSES into a
## few COLLIDE_CELL cells (a stationary crush), one enemy's 3x3 block can hold most of the horde and
## the scan reverts toward O(n²) — the density blowup that craters late-game FPS. Bounding the scan
## keeps the per-frame cost linear in the enemy count no matter how tightly they pack. This costs
## almost no correctness: in 2D a circle can be tangent to at most six equal circles (the kissing
## number), so only a handful of neighbours ever *truly* overlap a given body; the cap only bites
## when many bodies stack at nearly one point (deep interpenetration mid-collapse), and there the
## separation is a per-frame relaxation that converges over successive frames anyway. Own cell is
## scanned first (see _CELL_OFFSETS) so the budget is always spent on the nearest, deepest overlaps.
const MAX_OVERLAP_CHECKS := 16
## Enemies at or above this max health (mini-bosses like ELITE) get a health bar
## once damaged, so their long HP pool reads as visible progress.
const HEALTH_BAR_MIN_MAX_HEALTH := 40.0
## Enemy recycling: a base-trickle enemy the player has outrun by more than this distance is
## teleported back onto the spawn ring around the player rather than left stranded far offscreen.
## Without it a fleeing player (the game's core kiting verb) strands units at the far edge of the
## bounded arena forever; since those stragglers still count against the spawner's concurrent-enemy
## cap, the field *around* the player thins out — the swarm stops surrounding you. This is VS's own
## enemy recycling. The live threshold is the max of this floor and the (zoom-aware) off-screen spawn
## ring (VSSpawner.offscreen_radius) plus RECYCLE_HYSTERESIS, so a straggler is always past the visible
## corner at ANY camera zoom before it recycles, and a freshly spawned / just-recycled enemy sitting on
## that ring is never immediately re-recycled. Mini-bosses/Reaper are exempt (GDD: bosses don't despawn).
const DESPAWN_RADIUS := 1000.0
## Gap between the off-screen spawn ring and the recycle threshold, so an enemy re-entering exactly on
## the ring stays comfortably inside the keep-alive band instead of ping-ponging back out on frame one.
const RECYCLE_HYSTERESIS := 160.0

## Enemy archetypes. Each maps to a distinct pixel-art sprite plus stat tuning so
## waves have visual and mechanical variety. The spawner sets `type` before the
## node enters the tree; `_ready` applies the matching sprite + stats.
## ELITE is a periodic mini-boss: a much larger sprite, far more health, a bigger
## contact hit, and a big XP payout to break up the wave rhythm. The spawner
## injects it on a timer rather than through the normal weighted roll.
## REAPER is the run's finale: at the survival time limit VSRun summons a single
## fast, enormous-HP, huge-contact Reaper (VS's death-at-the-clock enemy) that the
## player must outlast for the final ~15s dash to the win — not killed, survived.
## MANTIS is a fast insect skirmisher: the quickest non-boss archetype, homing in
## from later waves with modest HP but a sharp contact bite, so the horde gains an
## agile "outrun you" threat distinct from the slow tanky MUMMY.
## MANTIS_WARRIOR is the bug faction's mini-elite: an armored, upscaled Mantis with a
## deep HP pool (enough to show its health bar) and a heavy contact bite, so it reads
## as a fast-but-tanky striker rather than a slow wall. It
## surfaces in the late (t>=9min) band to deepen the insect threat without a full boss.
## It scatters its 10 XP across a 5-gem ring (small green gems) so felling this tanky
## mini-elite reads as a jackpot burst like the ELITE — but without the boss camera shake.
## MUDMAN is Mad Forest's signature slow bruiser: a hulking mound of earth even tankier
## and harder-hitting than the MUMMY, with its own distinct sprite. It anchors the mid-run
## bands where the wiki's Green/Gray Mudman variants march in, replacing the role-mapped
## MUMMY stand-in so the horde reads as the real Mad Forest roster.
## WEREWOLF is the wiki's fast, heavy melee bruiser introduced from the 12:00 band: quicker
## than a MUDMAN and hitting harder than a MANTIS, with a deep-enough HP pool that it shrugs
## off chip damage — a distinct sprite replacing the MANTIS role-map so the late waves gain a
## genuine lycan threat rather than reusing the insect skirmisher.
## GLOW_BAT is Mad Forest's early "Giant Bat" mini-boss beat (spawned by the spawner at 0:30 and
## 3:00, not the weighted roll): the regular bat art scaled up with a deep HP pool and a pulsing
## blue outline shader (the "glowing" bit). It is NOT the death-reaper — the wiki's Mad Forest has
## no Death enemy until the finale — so it drops gems (not a chest) and pops without a boss camera
## shake. Appended to the enum so every existing Type ordinal stays put.
## The final six are the wiki's NAMED Mad Forest treasure bosses (res://data/mad_forest_bosses.csv),
## each given a distinct look so it reads as a real boss rather than a re-skinned trash mob:
## SILVER_BAT is the pale, steel-rimmed cousin of the blue GLOW_BAT (9:00/14:00/18:00/23:00 beats);
## GIANT_MUMMY / GIANT_WEREWOLF / GIANT_MANTICHANA are up-scaled, tinted versions of their base art
## (the wiki's 20:00 / 15:00 / 10:00 "Giant" bosses); VENUS is a carnivorous-flower boss on its own
## piranha-plant sprite (21:00/24:00), and GIANT_BLUE_VENUS is the biggest, blue-glowing plant — the
## 25:00 hyper-mode unlock boss. All are appended so existing Type ordinals stay put.
enum Type { BAT, ZOMBIE, SKELETON, GHOST, MUMMY, MANTIS, MANTIS_WARRIOR, MUDMAN, WEREWOLF, ELITE, REAPER, GLOW_BAT, SILVER_BAT, GIANT_MUMMY, GIANT_WEREWOLF, GIANT_MANTICHANA, VENUS, GIANT_BLUE_VENUS }

## Canvas_item outline shader + transparent-margin (texels) for "glowing" variants (see
## _make_glow_texture / the GLOW_BAT type). Margin gives the outward rim room so it is never
## clipped where the art touches the texture edge (the bat's wingtips do).
const GLOW_SHADER := "res://shaders/glow_outline.gdshader"
const GLOW_TEX_MARGIN := 5
## Cache of padded "glow" textures keyed by base texture path — a run spawns only a couple of
## glow bats, but caching keeps a repeat spawn from re-blitting the same image.
static var _glow_tex_cache: Dictionary = {}

const TYPES := {
	Type.BAT:      {"tex": "res://art/enemy_bat.png",      "speed": 62.0, "health": 3.0,   "damage": 8.0,  "xp": 1},
	Type.ZOMBIE:   {"tex": "res://art/enemy_zombie.png",   "speed": 42.0, "health": 6.0,   "damage": 10.0, "xp": 2},
	Type.SKELETON: {"tex": "res://art/enemy_skeleton.png", "speed": 58.0, "health": 4.0,   "damage": 9.0,  "xp": 2},
	Type.GHOST:    {"tex": "res://art/enemy_ghost.png",    "speed": 78.0, "health": 2.0,   "damage": 7.0,  "xp": 1},
	Type.MUMMY:    {"tex": "res://art/enemy_mummy.png",    "speed": 34.0, "health": 10.0,  "damage": 12.0, "xp": 3},
	Type.MANTIS:   {"tex": "res://art/enemy_mantis.png",   "speed": 96.0, "health": 5.0,   "damage": 11.0, "xp": 3},
	Type.MANTIS_WARRIOR: {"tex": "res://art/enemy_mantis_warrior.png", "speed": 84.0, "health": 45.0, "damage": 16.0, "xp": 10, "scale": 1.4, "radius": 16.0, "gems": 5, "knock": 0.4, "tint": Color(0.68, 0.74, 0.82)},
	Type.MUDMAN:   {"tex": "res://art/enemy_mudman.png",   "speed": 30.0, "health": 15.0,  "damage": 14.0, "xp": 4, "radius": 14.0, "knock": 0.7},
	Type.WEREWOLF: {"tex": "res://art/enemy_werewolf.png", "speed": 92.0, "health": 16.0,  "damage": 15.0, "xp": 5, "radius": 14.0, "knock": 0.85},
	Type.ELITE:    {"tex": "res://art/enemy_elite.png",    "speed": 40.0, "health": 140.0, "damage": 20.0, "xp": 25, "scale": 2.0, "radius": 22.0, "gems": 5, "knock": 0.25},
	Type.REAPER:   {"tex": "res://art/enemy_reaper.png",   "speed": 130.0, "health": 600.0, "damage": 34.0, "xp": 60, "scale": 2.6, "radius": 30.0, "gems": 10, "knock": 0.06},
	# Glow bat: bat art, upscaled 1.5x (the wiki's Giant Bat is 1.5x) with a deep HP pool so it
	# shows a health bar and reads as a beefy mini-boss, plus the pulsing blue outline shader.
	# The wiki Giant Bat is 270 HP against a normal bat's handful; scaled into this game's
	# compressed economy (base bat 3, ELITE 140) that lands at ~60 — clearly "extra health",
	# still killable with an early weapon. Semi-KB-resistant like the real Giant Bat.
	Type.GLOW_BAT: {"tex": "res://art/enemy_bat.png",      "speed": 68.0, "health": 60.0,  "damage": 12.0, "xp": 5, "scale": 1.5, "radius": 16.0, "gems": 3, "knock": 0.3, "outline": Color(0.30, 0.60, 1.0)},
	# Named treasure bosses (spawned by _spawn_boss with is_boss=true, which floors HP/gems to the
	# ELITE tier — the stats below set only the art size, speed, damage and resting look). Each reads
	# distinctly from the trash mob it borrows: SILVER_BAT wears a pale steel tint + near-white rim so
	# it never reads as the blue GLOW_BAT; the three "Giant" bosses up-scale their base sprite with a
	# subtle cast; VENUS uses its own piranha-plant art; GIANT_BLUE_VENUS is the biggest, blue-glowing
	# 25:00 hyper-mode boss.
	Type.SILVER_BAT:       {"tex": "res://art/enemy_bat.png",           "speed": 74.0, "health": 70.0,  "damage": 13.0, "xp": 6,  "scale": 1.7, "radius": 17.0, "gems": 4, "knock": 0.28, "tint": Color(0.82, 0.86, 0.95), "outline": Color(0.90, 0.94, 1.0)},
	Type.GIANT_MUMMY:      {"tex": "res://art/enemy_mummy.png",         "speed": 32.0, "health": 24.0,  "damage": 17.0, "xp": 8,  "scale": 2.2, "radius": 24.0, "gems": 4, "knock": 0.18, "tint": Color(1.0, 0.94, 0.78)},
	Type.GIANT_WEREWOLF:   {"tex": "res://art/enemy_werewolf.png",      "speed": 98.0, "health": 26.0,  "damage": 18.0, "xp": 8,  "scale": 2.0, "radius": 21.0, "gems": 4, "knock": 0.35, "tint": Color(0.88, 0.84, 0.96)},
	Type.GIANT_MANTICHANA: {"tex": "res://art/enemy_mantis_warrior.png","speed": 88.0, "health": 55.0,  "damage": 18.0, "xp": 10, "scale": 2.0, "radius": 21.0, "gems": 5, "knock": 0.32, "tint": Color(0.78, 0.86, 0.66)},
	Type.VENUS:            {"tex": "res://art/enemy_venus.png",         "speed": 58.0, "health": 45.0,  "damage": 16.0, "xp": 10, "scale": 1.4, "radius": 17.0, "gems": 5, "knock": 0.4,  "tint": Color(1.0, 0.9, 0.95)},
	Type.GIANT_BLUE_VENUS: {"tex": "res://art/enemy_venus.png",         "speed": 64.0, "health": 90.0,  "damage": 20.0, "xp": 12, "scale": 2.1, "radius": 24.0, "gems": 6, "knock": 0.2,  "tint": Color(0.55, 0.72, 1.25), "outline": Color(0.32, 0.62, 1.0)},
}

## Per-type visual-scale CSV overrides. Each enemy's base art size (its TYPES `scale`, default 1.0)
## can be retuned per archetype in res://data/balance.csv without touching code, keyed here; the
## global `enemy_scale` still multiplies on top. Only archetypes with a non-default size are listed —
## the rest sit at 1.0 and gain nothing from a row. The TYPES `scale` is the fallback default, so a
## missing/blank row leaves the hardcoded size unchanged.
const SCALE_KEYS := {
	Type.MANTIS_WARRIOR: "enemy_mantis_warrior_scale",
	Type.ELITE:          "enemy_elite_scale",
	Type.REAPER:         "enemy_reaper_scale",
	Type.GLOW_BAT:       "enemy_glow_bat_scale",
}

## Knockback: a weapon hit shoves the enemy directly away from the hit source with an
## impulse (px/s) that decays fast, so a strike reads as a real shove that buys the player
## a sliver of breathing room without launching enemies across the arena. `knock` per-type
## scales it (heavy ELITE/REAPER barely budge, staying the relentless threat they should be).
const KNOCKBACK_IMPULSE := 230.0   # px/s velocity added on a normal-weight enemy hit
const KNOCKBACK_DECAY := 1500.0    # px/s^2 the impulse bleeds off — stops in ~0.15s
## Hit-stop: on a weapon hit the enemy freezes in place for a sliver of a second (a couple of
## frames at 60fps) before resuming its march, so each impact reads as a weighty CRUNCH rather
## than a frictionless nudge — the classic freeze-frame juice, complementing knockback. Kept
## tiny so it's felt, not seen as a stutter, even when an AoE sweep freezes a whole pack at once.
const HITSTOP_DURATION := 0.045    # seconds the enemy holds on hit — ~2-3 frames
## Crit damage numbers pop bigger and gold so a spike reads instantly against the white regular hits.
const CRIT_TEXT_COLOR := Color(1.0, 0.82, 0.18)
const CRIT_TEXT_FONT_SIZE := 22

var type: int = Type.BAT
var speed := 62.0
var health := 3.0
var max_health := 3.0
var _show_health_bar := false
var contact_damage := 8.0
var xp_value := 1
var radius := RADIUS
var base_scale := 1.0
## How many gems this enemy scatters on death. Elites drop a burst so the big
## payout reads as a jackpot instead of one lone gem.
var gem_drops := 1
## Set by the spawner when this enemy is a scheduled treasure boss (the wiki's per-minute
## "Bosses & Treasure" beat, see res://data/mad_forest_bosses.csv). A boss drops a chest,
## shakes the camera, and gets its HP/gem burst floored to the ELITE tier so it reads as a
## real boss no matter which enemy art it borrows.
var is_boss := false
## Per-type knockback resistance (1.0 = full shove, 0 = immovable); read from TYPES.
var knock_resist := 1.0
## Resting sprite tint (default white = untinted). MANTIS_WARRIOR wears a cool
## gunmetal cast so the armored mini-elite reads at a glance — distinct from the
## green base Mantis and the ELITE. All modulate logic (freeze-clear, hit-flash)
## returns the sprite to this colour rather than a hardcoded white.
var _base_tint := Color(1, 1, 1)
## Current knockback velocity (px/s), decaying to zero in _process; set by hit().
var _knockback := Vector2.ZERO
## Remaining hit-stop freeze time (s), counting down in _process; set by hit().
var _hitstop := 0.0
var run: VSRun
var target: VSPlayer
var _contact_cd := 0.0
var _flash_time := 0.0
var _dying := false
## Tracks whether an Orologion freeze was active last frame, so the REAPER can fire its
## one-shot "IMMUNE" telegraph exactly on the frame a freeze begins (not every frame it lasts).
var _was_frozen := false

var _sprite: Sprite2D
## World-space half-extent of this enemy's sprite (texture size * 0.5 * node scale). Cached in
## _ready and read by the occlusion cull (_covers / _overlap_correction): a body whose sprite rect
## sits entirely inside a larger, on-top enemy's rect contributes nothing but overdraw, so its
## Sprite2D is skipped that frame.
var _half_extent := Vector2.ZERO

## Uniform spatial grid shared across every enemy, rebuilt at most once per process frame,
## so _overlap_correction() only scans the handful of neighbours in nearby cells instead of the
## whole 'enemies' group. This turns the horde's per-frame collision cost from O(n²) (every enemy
## walking every other enemy) into ~O(n), which is what lets the concurrent-enemy cap climb to
## the GDD's 300-alive late-game crush without the quadratic scan eating the frame.
## Cell size = COLLIDE_CELL (>= twice the largest radius): two bodies that overlap have centres
## within their combined radius, so their cells differ by at most one on each axis — scanning the
## 3×3 block of cells around an enemy covers every possible colliding neighbour.
## Static, so it persists across frames; each rebuild clears and repopulates from the live group,
## so a torn-down scene's stale entries are never queried (the next query rebuilds — see below).
static var _grid: Dictionary = {}
static var _grid_frame: int = -1

## Grid cell a world position falls into (integer cell coords at COLLIDE_CELL spacing).
static func _cell_key(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / COLLIDE_CELL), floori(pos.y / COLLIDE_CELL))

## The 3x3 block of cell offsets scanned around an enemy, ordered OWN CELL FIRST, then the four
## edge-adjacent cells, then the diagonals. Two things ride on this order: (1) when the per-frame
## MAX_OVERLAP_CHECKS budget is hit, the bodies already examined are the nearest ones — the deepest,
## most important overlaps — rather than an arbitrary corner of the block; (2) the edge cells are
## listed in opposing pairs (L,R,U,D) so a partial scan doesn't systematically bias the correction
## toward one direction and slide the whole crush sideways.
const _CELL_OFFSETS: Array[Vector2i] = [
	Vector2i(0, 0),
	Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1),
	Vector2i(-1, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1),
]

## Ensure the shared grid is current for this frame. The first enemy to resolve overlaps each
## frame rebuilds it (frame counter advanced); the rest reuse it. Also rebuilds if THIS enemy isn't
## in the cached grid — a bulletproof staleness guard so a grid left over from a prior scene or
## a direct test call (where the process frame may not advance between cases) can never linger.
func _ensure_grid() -> void:
	var frame := Engine.get_process_frames()
	if frame == _grid_frame:
		var bucket: Variant = _grid.get(_cell_key(position))
		if bucket != null and bucket.has(self):
			return
	_grid_frame = frame
	_grid.clear()
	for other in get_tree().get_nodes_in_group("enemies"):
		var key := _cell_key(other.position)
		var b: Variant = _grid.get(key)
		if b == null:
			b = []
			_grid[key] = b
		b.append(other)

func _ready() -> void:
	add_to_group("enemies")
	var cfg: Dictionary = TYPES.get(type, TYPES[Type.BAT])
	speed = cfg["speed"]
	# Escalating-threat ramp: enemies spawned later in the run are tougher, so the
	# player's growing level-up power doesn't trivialize every wave — the run keeps
	# a real sense of mounting danger (see GOAL: escalating waves). HP ramps steeply,
	# contact damage gently (a late bat should tank hits, not one-shot the player).
	var t: float = run.elapsed if run else 0.0
	# Ramp reaches its ceiling exactly at RUN_DURATION (Mad Forest's 30:00) rather than a
	# hardcoded minute count, so the ~3.1x HP / ~1.48x damage terminal multipliers this was
	# originally tuned to (reached at the old 5-minute run's ~6 min cap) now land smoothly
	# right as the finale timer runs out instead of saturating a fifth of the way in.
	var minutes := minf(t / 60.0, VSRun.RUN_DURATION / 60.0)
	var hp_mult := 1.0 + minutes * 0.07                # +7% HP per minute, up to ~+210% by minute 30
	var dmg_mult := 1.0 + minutes * 0.016              # +1.6% damage per minute, up to ~+48% by minute 30
	health = cfg["health"] * hp_mult
	max_health = health
	_show_health_bar = max_health >= HEALTH_BAR_MIN_MAX_HEALTH
	contact_damage = cfg["damage"] * dmg_mult
	xp_value = cfg["xp"]
	# Per-type art size (editable per archetype via an enemy_<name>_scale row in
	# res://data/balance.csv, falling back to the hardcoded TYPES `scale`), times a global
	# visual multiplier a designer can retune (default 1.0 = per-type size). Folded into
	# base_scale so the node scale, cached half-extent, and death tween all inherit it.
	var cfg_scale: float = cfg.get("scale", 1.0)
	var type_scale: float = BalanceData.get_value(SCALE_KEYS.get(type, ""), cfg_scale)
	base_scale = type_scale * BalanceData.get_value("enemy_scale", 1.0)
	# The collision radius rides along with the visual scale so the solid body always matches the
	# sprite a designer sees: a scale row (enemy_<name>_scale or global enemy_scale) grows/shrinks
	# the hitbox by the same factor it grows/shrinks the art. cfg_scale is the hardcoded baseline the
	# per-type `radius` was hand-tuned against, so at the default CSV values (base_scale == cfg_scale)
	# the radius is exactly the tuned value — this only moves the hitbox when a scale row is edited.
	radius = cfg.get("radius", RADIUS) * (base_scale / cfg_scale)
	gem_drops = cfg.get("gems", 1)
	# Scheduled treasure bosses (spawner sets is_boss) read as real bosses regardless of the
	# art type they borrow: floor their HP and gem burst to the ELITE tier and force a health
	# bar, so a Glowing-Bat- or Mummy-skinned boss is as tanky and rewarding as the armored
	# elite it replaces on the wiki's per-minute boss beat (res://data/mad_forest_bosses.csv).
	if is_boss:
		health = maxf(health, TYPES[Type.ELITE]["health"] * hp_mult)
		max_health = health
		_show_health_bar = max_health >= HEALTH_BAR_MIN_MAX_HEALTH
		gem_drops = maxi(gem_drops, int(TYPES[Type.ELITE]["gems"]))
	knock_resist = cfg.get("knock", 1.0)
	_base_tint = cfg.get("tint", Color(1, 1, 1))
	scale = Vector2(base_scale, base_scale)
	_sprite = Sprite2D.new()
	var base_tex: Texture2D = load(cfg["tex"])
	_sprite.texture = base_tex
	_sprite.modulate = _base_tint
	# Sprite is centered (default) and unrotated, so its world rect is position +/- this half-extent.
	# Captured from the BASE texture (the true silhouette) before any glow padding swaps in a larger,
	# mostly-transparent texture below — so occlusion still uses the real body size, not the margin.
	_half_extent = base_tex.get_size() * 0.5 * base_scale
	# "Glowing" variants (GLOW_BAT) wear a pulsing blue rim via the outline shader. The body art is
	# unchanged — literally the base sprite, re-centered inside a transparent margin so the outward
	# outline has room and never clips where the art touches the texture edge.
	if cfg.has("outline"):
		_sprite.texture = _make_glow_texture(base_tex)
		var mat := ShaderMaterial.new()
		mat.shader = load(GLOW_SHADER)
		mat.set_shader_parameter("outline_color", cfg["outline"])
		_sprite.material = mat
	add_child(_sprite)
	# Tinted mini-elites (MANTIS_WARRIOR) flare with a brief bright spawn glint —
	# reusing the hit-flash channel — so their arrival pops before settling to the
	# resting armour tint, clocking the elite instantly if they spawn on-screen.
	if _base_tint != Color(1, 1, 1):
		_flash_time = FLASH_DURATION

## Build (and cache) a copy of `base_tex` re-centered inside a transparent margin, so the outline
## shader has room to draw the rim OUTWARD without clipping where the art touches the texture edge.
## The visible pixels are identical to the base sprite — this only adds empty border. Converts to
## RGBA8 first so blit_rect always has a matching, alpha-capable format.
func _make_glow_texture(base_tex: Texture2D) -> Texture2D:
	var key := base_tex.resource_path
	var cached: Variant = _glow_tex_cache.get(key)
	if cached != null:
		return cached
	var src := base_tex.get_image()
	src.convert(Image.FORMAT_RGBA8)
	var m := GLOW_TEX_MARGIN
	var padded := Image.create(src.get_width() + m * 2, src.get_height() + m * 2, false, Image.FORMAT_RGBA8)
	padded.fill(Color(0, 0, 0, 0))
	padded.blit_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), Vector2i(m, m))
	var tex := ImageTexture.create_from_image(padded)
	_glow_tex_cache[key] = tex
	return tex

func _process(delta: float) -> void:
	# On a run restart the scene is torn down while enemies are mid-flight; a _process tick
	# landing on an already-detached enemy makes _overlap_correction()'s get_tree() call fault with
	# "Parameter data.tree is null" (harmless but ~12 lines of console noise, one per live
	# enemy). Bail out the moment we're outside the tree — there is nothing to move anyway.
	if not is_inside_tree():
		return
	# Occlusion cull is refreshed every frame: default to VISIBLE here, then _overlap_correction hides
	# this sprite if a larger enemy drawn on top fully covers it. Resetting up front (before the
	# freeze / hit-stop / dying early-returns below) guarantees a body is never left stale-hidden after
	# its occluder moves away — worst case a frozen/hit-stopped body just isn't culled for a few frames.
	if _sprite and not _sprite.visible:
		_sprite.visible = true
	if _flash_time > 0.0:
		_flash_time = maxf(0.0, _flash_time - delta)
		_update_flash()
	if _dying:
		return
	if run and run.phase != "playing":
		return
	if target == null or not is_instance_valid(target):
		return
	# Orologion time-stop: while a Freeze Clock is active every enemy halts in place and deals
	# no contact damage — a breather for the player to reposition (weapons still hit them). An
	# icy tint (when not mid hit-flash) makes the frozen state read at a glance.
	# The finale REAPER is exempt (faithful to VS, where the Orologion never freezes the boss):
	# freezing it would let a player stockpile a clock, drop it on the summon, and beat on a
	# motionless, harmless boss — draining all tension from the run's climax.
	if run and run.is_frozen():
		if type != Type.REAPER:
			if _flash_time <= 0.0 and _sprite:
				_sprite.modulate = Color(0.55, 0.8, 1.3)
			return
		# The REAPER shrugs the freeze off. Telegraph it so the boss ploughing through a fully
		# iced horde reads as intentional, not a bug: a one-shot floating "IMMUNE" label the frame
		# the freeze lands, plus a pulsing red shimmer for as long as it's active — a hot, unfrozen
		# counterpoint to the icy blue tint on everything around it. The reaper does NOT halt.
		if not _was_frozen:
			_was_frozen = true
			_spawn_immune_label()
		if _flash_time <= 0.0 and _sprite:
			var t2: float = run.elapsed if run else 0.0
			var pulse := 0.5 + 0.5 * sin(t2 * IMMUNE_SHIMMER_FREQ)
			_sprite.modulate = _base_tint.lerp(Color(1.7, 0.25, 0.25), pulse * IMMUNE_SHIMMER_AMOUNT)
	else:
		_was_frozen = false
		if _flash_time <= 0.0 and _sprite and _sprite.modulate != _base_tint:
			_sprite.modulate = _base_tint   # clear any lingering freeze/shimmer tint back to resting
	# Hit-stop: a freshly-struck enemy holds in place for a couple of frames before resuming, so
	# the impact lands with weight. While it's active it costs no ground, no knockback decay and
	# no contact. It absorbs only its own slice of the frame's delta — if the freeze ends partway
	# through a frame the leftover time still drives movement, so long frames never lose motion
	# (and the knockback test's single big _process step still advances the enemy).
	if _hitstop > 0.0:
		if _hitstop >= delta:
			_hitstop -= delta
			return
		delta -= _hitstop
		_hitstop = 0.0
	var to := target.position - position
	var d := to.length()
	# Recycle a straggler the player has outrun: teleport it back onto the spawn ring around the
	# player instead of leaving it stranded far offscreen eating the spawner's concurrent-enemy
	# budget (which would thin the horde near a fleeing player). Mini-bosses/Reaper never recycle.
	# Threshold sits beyond the zoom-aware off-screen ring (+ hysteresis) so it holds at any zoom.
	var despawn := maxf(DESPAWN_RADIUS, VSSpawner.offscreen_radius(self) + RECYCLE_HYSTERESIS)
	if d > despawn and type != Type.ELITE and type != Type.REAPER:
		_recycle()
		return
	var desired := to / d if d > 0.5 else Vector2.ZERO
	# Enemies home STRAIGHT at the player — no steering force bends the beeline. Bodies that
	# would overlap are pushed apart AFTER moving by the collider pass below, so the horde still
	# packs into a surrounding crush wall rather than one overlapping column, but every unit's
	# intent is the direct line at the player.
	var move := desired
	var step := Vector2.ZERO
	if move.length() > 0.001:
		step = move.normalized() * speed * delta
	# Layer any active knockback on top of the homing step and bleed it off, so a weapon
	# hit visibly shoves the enemy back for a moment before it resumes its march.
	if _knockback != Vector2.ZERO:
		step += _knockback * delta
		_knockback = _knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)
	position += step
	# Solid enemy colliders: after homing straight in, shove this body out of any neighbour it
	# now overlaps so no two enemies occupy the same space — the crush wall forms from bodies
	# pressing on bodies, not a steering force. Scaled by knock_resist so heavy units barely give
	# ground (the finale REAPER ploughs through the pack).
	position += _overlap_correction() * knock_resist
	# Solid body vs the player: the same combined radius that gates contact damage also
	# caps how close an enemy's sprite can get, so a wall of enemies packs into a ring right
	# at the player's edge instead of visually marching inside the avatar sprite. Checked
	# against the post-move (pre-clamp) distance so a horde pressed against this rim still
	# chips the player on every contact tick, not just on the approach frame.
	var min_dist := radius + target.radius
	var from_player := position - target.position
	var d_after := from_player.length()
	var contact := d_after < min_dist
	if contact:
		var push_dir := from_player / d_after if d_after > 0.001 else Vector2.RIGHT.rotated(randf() * TAU)
		position = target.position + push_dir * min_dist
	_contact_cd -= delta
	if contact and _contact_cd <= 0.0 and target.alive:
		target.take_damage(contact_damage)
		_contact_cd = 0.5

## Positional correction that separates this enemy's body from every neighbour it currently
## overlaps: for each other enemy whose centre is nearer than the combined radii, add a shove
## along the line between them equal to HALF the overlap (the other enemy corrects its own half in
## its _process pass, so a pair meeting head-on splits the gap symmetrically). Summed across all
## overlapping neighbours and applied to `position`, this is the solid-body collider — bodies can't
## interpenetrate. Backed by the shared uniform grid
## (see _ensure_grid): only the 3×3 block of cells around this enemy is scanned, so the per-frame
## cost across the whole horde is ~O(n) instead of O(n²) — what lets the spawner's concurrent-enemy
## cap sit at the GDD's 300-alive late-game crush.
func _overlap_correction() -> Vector2:
	_ensure_grid()
	var correction := Vector2.ZERO
	var base := _cell_key(position)
	# Bodies examined this frame. Capped at MAX_OVERLAP_CHECKS so a collapsed horde (most of the
	# horde packed into this enemy's 3x3 block) can't drive the scan back to O(n²). Own cell is
	# scanned first (see _CELL_OFFSETS) so the budget lands on the nearest, deepest overlaps.
	var checked := 0
	# Occlusion cull, piggybacked on this same neighbour scan (no extra grid pass): if a larger enemy
	# drawn ON TOP of this one (higher sibling index → drawn later) fully covers this sprite's rect,
	# this body is pure overdraw and its Sprite2D is skipped. Only small bodies can be fully covered
	# (the solid collider keeps equal-size sprites' centres apart, so they never fully occlude each
	# other) — so mini-bosses that show a health bar skip the test entirely.
	var occluded := false
	var scan_occlusion := not _show_health_bar
	var my_index := get_index()
	for offset in _CELL_OFFSETS:
		var bucket: Variant = _grid.get(base + offset)
		if bucket == null:
			continue
		for other in bucket:
			# The 'enemies' group also holds non-enemy bodies (e.g. breakable candelabras) that
			# lack a collider radius; only solid VSEnemy bodies collide.
			if other == self or not (other is VSEnemy):
				continue
			if scan_occlusion and not occluded and other.get_index() > my_index and other._covers(self):
				occluded = true
			checked += 1
			if checked > MAX_OVERLAP_CHECKS:
				if occluded and _sprite:
					_sprite.visible = false
				return correction
			var min_d: float = radius + other.radius
			var away: Vector2 = position - other.position
			var dist := away.length()
			if dist > 0.001 and dist < min_d:
				correction += away / dist * (min_d - dist) * 0.5
	if occluded and _sprite:
		_sprite.visible = false
	return correction

## True iff this enemy's sprite rect fully contains `victim`'s — i.e. `victim` is entirely hidden
## behind this sprite when this one is drawn on top, so drawing `victim` is pure overdraw. Sprites are
## centered and unrotated, so each world rect is centre +/- _half_extent and containment is the exact
## axis-aligned test below. Equal-size sprites never satisfy it (the collider keeps their centres
## apart), so only a strictly larger sprite (ELITE / REAPER) ever covers a smaller body.
func _covers(victim: VSEnemy) -> bool:
	var d := (position - victim.position).abs()
	return d.x + victim._half_extent.x <= _half_extent.x and d.y + victim._half_extent.y <= _half_extent.y

## Teleport an outrun straggler back onto the spawn ring around the player (VS enemy recycling),
## so the concurrent-enemy budget stays spent on units that can actually threaten the player rather
## than on bodies abandoned at the far edge of the arena. Reuses the spawner's ring radius + arena
## clamp so a recycled enemy re-enters exactly like a fresh spawn; clears its knockback and contact
## cooldown so it arrives as a clean pursuer.
func _recycle() -> void:
	if target == null:
		return
	# Bias re-entry toward the player's heading so an outrun straggler mostly reappears in *front*
	# of a fleeing player (faithful VS recycling): a kite keeps running INTO fresh pressure rather
	# than shaking the horde by simply outrunning it. Sample within +/-90deg of the flee direction;
	# falls back to fully random-feeling spread only when the player has never moved (heading RIGHT).
	var heading := target.move_dir if target.move_dir.length_squared() > 0.0001 else Vector2.RIGHT
	# Sample within +/-90deg of the flee heading, but let ring_spawn_point reject any angle whose
	# arena-clamped point would land on screen (the player may be fleeing straight into an edge), so
	# a straggler re-enters ahead of the player yet still from off screen. arena_half falls back to a
	# generous box when there is no run (bare-state tests) so no clamp shortens the ring there.
	var half := run.arena_half if run else Vector2(1.0e9, 1.0e9)
	position = VSSpawner.ring_spawn_point(self, target.position, half, heading.angle(), PI)
	_knockback = Vector2.ZERO
	_contact_cd = 0.0

func hit(amount: float, from: Vector2) -> void:
	if _dying:
		return
	# Critical hits (GDD combat rule). Every weapon funnels through hit(), so rolling crit here
	# applies it uniformly to all eight weapons at once. The chance scales with the run's Luck.
	var is_crit := false
	if run:
		var rolled: Dictionary = run.roll_crit(amount)
		amount = rolled["amount"]
		is_crit = rolled["crit"]
	health -= amount
	_flash_time = FLASH_DURATION
	_update_flash()
	# Freeze-frame juice: hold the enemy for a couple of frames so the hit reads as a real crunch.
	# Skipped during an Orologion time-stop — enemies are already halted, so a hit-stop would be
	# invisible and could linger a beat past the thaw.
	if not (run and run.is_frozen()):
		_hitstop = HITSTOP_DURATION
	# Shove away from the hit source, scaled by this enemy's knockback resistance so
	# heavy mini-bosses barely flinch. Impulses stack (rapid hits push harder) but decay
	# fast in _process. A dead-centre hit (from == position) has no direction, so no shove.
	if knock_resist > 0.0:
		var away := position - from
		if away.length() > 0.001:
			_knockback += away.normalized() * KNOCKBACK_IMPULSE * knock_resist
	# Floating white damage number so rising power (Might, Power picks, weapon levels)
	# reads frame-to-frame even when a hit doesn't cross an HP breakpoint. Cosmetic:
	# spawned into the parent's space with a little x jitter so stacked hits stay legible.
	var parent := get_parent()
	if parent != null:
		var at := position + Vector2(randf_range(-6.0, 6.0), -radius)
		# A crit pops as a bigger gold number so the damage spike reads instantly against the swarm.
		if is_crit:
			VSFloatText.spawn(parent, at, str(int(round(amount))), CRIT_TEXT_COLOR, CRIT_TEXT_FONT_SIZE)
		else:
			VSFloatText.spawn(parent, at, str(int(round(amount))), Color(1, 1, 1))
	if _show_health_bar:
		queue_redraw()
	if health <= 0.0:
		_die()

func _die() -> void:
	_dying = true
	if run:
		var big := type == Type.ELITE or type == Type.REAPER or is_boss
		run.add_kill(position, xp_value, gem_drops, big, max_health)
		if big:
			run.add_camera_shake(0.8)   # elite/reaper pop lands harder than a player hit
		if type == Type.REAPER:
			run.on_reaper_slain()       # overpowering the finale wins the run instantly
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(base_scale * 1.4, base_scale * 1.4), 0.08)
	tw.tween_property(self, "scale", Vector2.ZERO, 0.1)
	tw.tween_callback(queue_free)

## Draw a small health bar above mini-boss enemies once they've taken damage.
## Coordinates are local, so the node's scale sizes the bar to the sprite.
func _draw() -> void:
	if not _show_health_bar or _dying or health <= 0.0 or health >= max_health:
		return
	var frac := clampf(health / max_health, 0.0, 1.0)
	var w := radius * 2.0
	var h := 3.0
	var top := -radius - 8.0
	var bg := Rect2(-w * 0.5, top, w, h)
	draw_rect(bg, Color(0, 0, 0, 0.7))
	draw_rect(Rect2(bg.position, Vector2(w * frac, h)), Color(0.85, 0.15, 0.15))

## Pop a red "IMMUNE" label above the REAPER the instant a Freeze Clock activates, spelling out
## that the boss ignores the time-stop. Spawned into the parent's space (like the damage numbers)
## so it rises and fades in world coordinates rather than dragging along with the advancing boss.
func _spawn_immune_label() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var at := position + Vector2(0.0, -radius - 10.0)
	VSFloatText.spawn(parent, at, "IMMUNE", Color(1.0, 0.35, 0.3))

## Brighten the sprite toward white for the duration of a hit flash.
func _update_flash() -> void:
	if _sprite == null:
		return
	var flash := _flash_time / FLASH_DURATION
	_sprite.modulate = _base_tint.lerp(Color(4, 4, 4), flash)
