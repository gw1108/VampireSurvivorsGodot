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
const RANGE_PER_LEVEL := 18.0
const ARC_HALF_ANGLE := deg_to_rad(50.0)   # half-width of the damage wedge
const ATTACK_INTERVAL := 1.2               # seconds between swings
const SWEEP_TIME := 0.25                   # how long the arc stays visible per swing
const BASE_DAMAGE := 5.0
const DAMAGE_PER_LEVEL := 4.0

# Evolved (Bloody Tear) profile — applied when run.whip_evolved: a longer, wider, far deadlier
# lash that always covers both flanks. Gated on Whip already being maxed, so this is the run's
# payoff for maxing Whip + owning Vitality (Hollow Heart).
const EVOLVED_DAMAGE_MULT := 2.2
const EVOLVED_RANGE_BONUS := 60.0                 # px added to reach
const EVOLVED_ARC_BONUS := deg_to_rad(20.0)       # widens each wedge's half-angle

var run: VSRun
var _cd := 0.0
var _sweep := 0.0          # remaining time on the current swing's visual
var _facing := 1           # last horizontal facing: +1 right, -1 left
var _swing_facing := 1     # facing captured at the moment of the swing (drives _draw)
var _swing_both := false   # whether the current swing lashed both sides

func _process(delta: float) -> void:
	if run == null:
		return
	var lvl: int = run.whip_level
	if lvl <= 0:
		return
	if _sweep > 0.0:
		_sweep = maxf(0.0, _sweep - delta)
		queue_redraw()
	if run.phase != "playing":
		return
	# Track facing from horizontal input so the whip lashes the way the player moves.
	var h := Input.get_axis("move_left", "move_right")
	if absf(h) > 0.1:
		_facing = 1 if h > 0.0 else -1
	_cd -= delta
	if _cd <= 0.0:
		_swing(lvl)
		_cd = ATTACK_INTERVAL

## One swing: damage every enemy inside the facing-side wedge (both sides from level 2, or
## always once evolved into Bloody Tear).
func _swing(lvl: int) -> void:
	_swing_facing = _facing
	_swing_both = lvl >= 2 or _is_evolved()
	_sweep = SWEEP_TIME
	queue_redraw()
	var r := _range(lvl)
	var arc := _arc_half()
	var dmg := (BASE_DAMAGE + DAMAGE_PER_LEVEL * float(lvl)) * run.might_mult()
	if _is_evolved():
		dmg *= EVOLVED_DAMAGE_MULT
	var hit_any := false
	for s in _sides():
		var facing_vec := Vector2(s, 0)
		for e in get_tree().get_nodes_in_group("enemies"):
			var to: Vector2 = e.position - global_position
			var er: float = e.radius if "radius" in e else VSEnemy.RADIUS
			var d := to.length()
			if d > r + er:
				continue
			# On top of us, or inside the angular wedge on this side.
			if d < 1.0 or absf(to.angle_to(facing_vec)) <= arc:
				e.hit(dmg, global_position)
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
	var r := BASE_RANGE + RANGE_PER_LEVEL * float(lvl - 1)
	if _is_evolved():
		r += EVOLVED_RANGE_BONUS
	return r * run.area_mult   # Candelabrador passive extends the lash's reach

func _draw() -> void:
	if run == null or run.whip_level <= 0 or _sweep <= 0.0:
		return
	var r := _range(run.whip_level)
	var arc := _arc_half()
	var t := _sweep / SWEEP_TIME               # 1 at swing start -> 0 as it fades
	# Bloody Tear tints the lash a deep crimson so the evolution reads at a glance.
	var fill := Color(1.0, 0.35, 0.35, 0.28 * t) if _is_evolved() else Color(1.0, 0.95, 0.7, 0.22 * t)
	var edge := Color(1.0, 0.55, 0.55, 0.8 * t) if _is_evolved() else Color(1.0, 1.0, 0.85, 0.7 * t)
	for s in _sides():
		var center := 0.0 if s > 0 else PI
		_draw_wedge(center, r, arc, fill)
		# Bright leading edge sweeps across the wedge as the swing plays out.
		var edge_ang: float = center + lerp(arc, -arc, t)
		draw_line(Vector2.ZERO, Vector2(cos(edge_ang), sin(edge_ang)) * r, edge, 3.0)

func _draw_wedge(center: float, r: float, arc: float, col: Color) -> void:
	var pts := PackedVector2Array([Vector2.ZERO])
	var segs := 12
	for i in segs + 1:
		var a := center - arc + (2.0 * arc) * float(i) / float(segs)
		pts.append(Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, col)
