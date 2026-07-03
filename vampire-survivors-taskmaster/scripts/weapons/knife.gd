class_name VSKnife
extends Node2D
## A directional fast-fire weapon — the classic Vampire Survivors "Knife": on a short cooldown
## it hurls fast VSProjectiles straight in the direction the player is FACING, no aiming. Unlike
## the Magic Wand (auto-aims the nearest enemy), the Whip (melee arc), the Garlic (static aura),
## the King Bible (orbit), and the Lightning Ring (random smites), the Knife rewards steering the
## player into the horde: it fires where you point, fast and hard, punching a lane through whatever
## you run toward. Facing follows the Whip's persistent horizontal axis plus the current vertical
## input, so it always throws forward-and-slightly-up/down as you move. Mounted on the player,
## enabled/scaled by run.knife_level (0 = not yet picked: no throws, inert). The slice's sixth,
## mechanically-distinct weapon.

const BASE_DAMAGE := 6.5
const DAMAGE_PER_LEVEL := 2.0
const BASE_INTERVAL := 1.0            # seconds between throws — a fast, steady stream
const INTERVAL_PER_LEVEL := 0.05      # tightens a little per level so it keeps pace late
const MIN_INTERVAL := 0.55
const BASE_AMOUNT := 1                # knives per throw at Lv1…
const MAX_AMOUNT := 5                 # …growing by one every two levels, capped here (VS convention)
const KNIFE_SPEED := 540.0            # faster than the aimed wand's bolt — the Knife's signature
const KNIFE_LIFE := 1.1
const SPREAD := 0.10                  # radians between stacked knives when amount > 1

# Evolved (Thousand Edges) profile — applied when run.knife_evolved: the Knife's cadence
# collapses toward a continuous stream (interval scaled right down, floor lowered far), it
# hurls a wider fan of knives per throw, and each blade bites much harder. The payoff for
# maxing the Knife alongside Haste. Mirrors the Whip / King Bible / Holy Wand evolution pattern.
const EVOLVED_INTERVAL_MULT := 0.30   # ~a third the cadence — a near-solid stream of blades
const EVOLVED_MIN_INTERVAL := 0.14    # far lower floor so late Thousand Edges barely pauses
const EVOLVED_AMOUNT_BONUS := 3       # +3 knives per throw over the base fan
const EVOLVED_DAMAGE_MULT := 1.7      # each blade bites much deeper

var run: VSRun
var _cd := 0.0
var _facing := 1          # persistent horizontal facing: +1 right, -1 left (mirrors VSWhip)

func _process(delta: float) -> void:
	if run == null:
		return
	var lvl: int = run.knife_level
	if lvl <= 0:
		return
	if run.phase != "playing":
		return
	# Track facing from horizontal input so the knife throws the way the player moves, exactly
	# like the Whip — the last non-neutral horizontal press wins and persists while standing still.
	var h := Input.get_axis("move_left", "move_right")
	if absf(h) > 0.1:
		_facing = 1 if h > 0.0 else -1
	_cd -= delta
	if _cd <= 0.0:
		_throw(lvl)
		_cd = _interval(lvl)

## Cooldown between throws, shrinking modestly with level (never below MIN_INTERVAL so it stays
## a fast stream rather than a solid wall of blades).
func _interval(lvl: int) -> float:
	var base := maxf(MIN_INTERVAL, BASE_INTERVAL - INTERVAL_PER_LEVEL * float(lvl - 1))
	if _is_evolved():
		return maxf(EVOLVED_MIN_INTERVAL, base * EVOLVED_INTERVAL_MULT)
	return base

## True once the run has evolved Knife into Thousand Edges.
func _is_evolved() -> bool:
	return run != null and run.knife_evolved

## Knives per throw: base one, plus one for every two levels, capped so a maxed Knife throws a
## satisfying fan without blanketing the screen for free.
func _amount(lvl: int) -> int:
	var amount := clampi(BASE_AMOUNT + lvl / 2, BASE_AMOUNT, MAX_AMOUNT)
	if _is_evolved():
		amount += EVOLVED_AMOUNT_BONUS
	return amount

## One throw: hurl `amount` fast bolts in the current facing direction (persistent horizontal axis
## + current vertical input), fanned symmetrically so extra knives read as a tight spread.
func _throw(lvl: int) -> void:
	var mv := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# Persistent horizontal facing + instantaneous vertical: always throws forward, angled up/down
	# as the player steers. Standing still (mv.y == 0) throws dead ahead.
	var base := Vector2(float(_facing), mv.y).normalized()
	var dmg := (BASE_DAMAGE + DAMAGE_PER_LEVEL * float(lvl - 1)) * run.might_mult()
	if _is_evolved():
		dmg *= EVOLVED_DAMAGE_MULT
	var count := _amount(lvl)
	for i in count:
		var offset := (i - (count - 1) * 0.5) * SPREAD
		var p := VSProjectile.new()
		p.position = global_position
		p.dir = base.rotated(offset)
		p.speed = KNIFE_SPEED * run.projectile_speed_mult   # Bracer passive speeds the knife up
		p.life = KNIFE_LIFE
		p.damage = dmg
		p.run = run
		run.add_child(p)
	AgentBridge.emit_event("sfx_played", {"name": "knife"})
