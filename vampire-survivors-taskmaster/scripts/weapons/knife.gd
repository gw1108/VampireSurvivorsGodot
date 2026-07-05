class_name VSKnife
extends Node2D
## A directional fast-fire weapon — the classic Vampire Survivors "Knife": on a short cooldown
## it hurls fast VSProjectiles straight in the direction the player is MOVING, no aiming. Unlike
## the Magic Wand (auto-aims the nearest enemy), the Whip (melee arc), the Garlic (static aura),
## the King Bible (orbit), and the Lightning Ring (random smites), the Knife rewards steering the
## player into the horde: it fires where you point, fast and hard, punching a lane through whatever
## you run toward. Facing tracks the full movement heading — 8 directions with WASD (straight up on
## W, down-left on A+S, …) or the precise angle for analog stick/mouse steering — and persists
## while standing still, so an idle player throws the way they last ran. Mounted on the player,
## enabled/scaled by run.knife_level (0 = not yet picked: no throws, inert). The slice's sixth,
## mechanically-distinct weapon.

## Base damage + per-level growth live in res://data/balance.csv ("knife_base_damage" /
## "knife_damage_per_level") so a designer can retune them without touching this script.
static var BASE_DAMAGE := BalanceData.get_value("knife_base_damage", 6.5)
static var DAMAGE_PER_LEVEL := BalanceData.get_value("knife_damage_per_level", 2.0)
## Base cooldown + per-level tighten live in res://data/balance.csv ("knife_base_interval" /
## "knife_interval_per_level") so a designer can retune fire rate without touching this script.
static var BASE_INTERVAL := BalanceData.get_value("knife_base_interval", 1.0)
static var INTERVAL_PER_LEVEL := BalanceData.get_value("knife_interval_per_level", 0.05)
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
var _facing := Vector2.RIGHT   # latched full movement heading (unit vector); throws travel along it

func _process(delta: float) -> void:
	if run == null:
		return
	var lvl: int = run.knife_level
	if lvl <= 0:
		return
	if run.phase != "playing":
		return
	# Track the full movement heading so the knife throws exactly the way the player moves — 8
	# directions with WASD (straight up on W alone, down-left on A+S, …), or the precise angle
	# for analog stick/mouse steering. get_vector is already normalized + deadzoned. The last
	# non-zero heading wins and persists while standing still, so an idle player still throws the
	# direction they last ran.
	var mv := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if mv.length_squared() > 0.01:
		_facing = mv.normalized()
	_cd -= delta
	if _cd <= 0.0:
		_throw(lvl)
		_cd = _interval(lvl)

## Cooldown between throws, shrinking modestly with level (never below MIN_INTERVAL so it stays
## a fast stream rather than a solid wall of blades).
func _interval(lvl: int) -> float:
	var base := maxf(MIN_INTERVAL, BASE_INTERVAL - INTERVAL_PER_LEVEL * float(lvl - 1))
	if _is_evolved():
		return maxf(EVOLVED_MIN_INTERVAL, base * EVOLVED_INTERVAL_MULT) * run.haste_mult()
	return base * run.haste_mult()

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

## One throw: hurl `amount` fast bolts along the latched movement heading (the way the player is —
## or last was — moving), fanned symmetrically so extra knives read as a tight spread.
func _throw(lvl: int) -> void:
	var base := _facing
	var dmg := (BASE_DAMAGE * run.damage_variance() + DAMAGE_PER_LEVEL * float(lvl - 1)) * run.might_mult() * run.power_mult()
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
