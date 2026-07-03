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
const BASE_INTERVAL := 4.5           # wiki cooldown; shrinks a little per level so it keeps pace
const INTERVAL_PER_LEVEL := 0.3
const MIN_INTERVAL := 1.8
const FLASH_TIME := 0.18             # how long a drawn bolt lingers before fading out
const BOLT_TOP := 460.0              # how far above the impact the bolt appears to fall from
const BOLT_COLOR := Color(0.82, 0.92, 1.0)
const GLOW_COLOR := Color(0.55, 0.7, 1.0)

var run: VSRun
var _cd := 0.0
## Active bolt visuals, each { "pos": Vector2 (local to the player), "t": float seconds left }.
## Faded down in _process and rendered in _draw so a strike reads as a bright flash of lightning.
var _bolts: Array = []

func _process(delta: float) -> void:
	if run == null:
		return
	# Fade any lingering bolt visuals every frame (even while paused, so they don't hang).
	if not _bolts.is_empty():
		var still := []
		for b in _bolts:
			b["t"] -= delta
			if b["t"] > 0.0:
				still.append(b)
		_bolts = still
		queue_redraw()
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
## within STRIKE_RADIUS of the impact. Records a bolt visual per strike.
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
		_bolts.append({"pos": at - global_position, "t": FLASH_TIME})
	if hit_any:
		run.add_camera_shake(0.12)   # a small jolt so the smite lands with weight
		AgentBridge.emit_event("sfx_played", {"name": "lightning"})
	queue_redraw()

## Render each active bolt: a jagged streak falling from above onto the impact, plus a fading
## glow disc. Drawn in local space (the node rides the player); bolts are brief so the small
## drift as the player moves reads fine, matching how the other weapons self-draw.
func _draw() -> void:
	for b in _bolts:
		var p: Vector2 = b["pos"]
		var frac: float = clampf(b["t"] / FLASH_TIME, 0.0, 1.0)
		var top := Vector2(p.x, p.y - BOLT_TOP)
		var pts := PackedVector2Array()
		var segs := 7
		for i in segs + 1:
			var f := float(i) / float(segs)
			var base := top.lerp(p, f)
			# Deterministic zigzag (no RNG in _draw so the bolt doesn't jitter each frame).
			var jitter := 0.0 if i == 0 or i == segs else sin(f * 23.0 + p.x * 0.5) * 12.0
			pts.append(base + Vector2(jitter, 0.0))
		var glow := STRIKE_RADIUS * run.area_mult
		if run.lightning_evolved:
			glow *= EVO_SPLASH_MULT   # match the wider Thunder Loop blast the damage now covers
		draw_polyline(pts, Color(BOLT_COLOR.r, BOLT_COLOR.g, BOLT_COLOR.b, frac), 2.5)
		draw_circle(p, glow * (0.45 + 0.55 * frac), Color(GLOW_COLOR.r, GLOW_COLOR.g, GLOW_COLOR.b, 0.5 * frac))
