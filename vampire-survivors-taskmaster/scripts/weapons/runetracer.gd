class_name VSRunetracer
extends Node2D
## A ricochet weapon — the classic Vampire Survivors "Runetracer": on its cooldown it hurls a
## spinning rune polyhedron that BOUNCES off the edges of the arena and ping-pongs straight through
## the horde, striking every enemy it passes (with a short per-enemy re-hit delay so a single rune
## racks up many hits as it caroms around). Unlike the aimed Magic Wand, the melee Whip, the static
## Garlic aura, the orbiting King Bible, the field-wide Lightning smites, and the forward-thrown
## Knife, the Runetracer is fire-and-forget area denial that owns the WHOLE playfield for its lifetime
## — a bouncing hazard that thins the swarm from angles nothing else covers. Mounted on the player,
## enabled/scaled by run.runetracer_level (0 = not yet picked: inert). The slice's seventh,
## mechanically-distinct weapon (per the GDD's designed 8-weapon set).

## Base damage + per-level growth live in res://data/balance.csv ("runetracer_base_damage" /
## "runetracer_damage_per_level") so a designer can retune them without touching this script.
## Lv1 = 10, Lv8 = 31 — a steady bouncing chip.
static var BASE_DAMAGE := BalanceData.get_value("runetracer_base_damage", 10.0)
static var DAMAGE_PER_LEVEL := BalanceData.get_value("runetracer_damage_per_level", 3.0)
const BASE_INTERVAL := 3.0            # wiki cooldown; tightens a little per level so it keeps pace
const INTERVAL_PER_LEVEL := 0.15
const MIN_INTERVAL := 1.4
const BASE_AMOUNT := 1                # runes per volley (wiki Amount 1)…
const MAX_AMOUNT := 3                 # …growing by one every three levels, capped here
const BASE_SPEED := 260.0             # px/sec — a brisk carom, not a bullet
const BASE_LIFE := 4.0               # seconds a rune bounces before dissipating…
const LIFE_PER_LEVEL := 0.4          # …lasting longer as it levels so late runes cover more ground

# NO FUTURE (evolved): the same bouncing rune, but MORE of them, caroming faster and longer,
# each a bigger, harder-hitting hazard — set once run.runetracer_evolved flips (see run.gd).
const EVO_BONUS_AMOUNT := 2          # extra runes per volley on top of the level count…
const EVO_MAX_AMOUNT := 6            # …raising the cap so a maxed NO FUTURE saturates the arena
const EVO_DAMAGE_MULT := 1.6         # each rune bites noticeably harder
const EVO_SPEED_MULT := 1.35         # a faster carom covers the field quicker
const EVO_LIFE_BONUS := 2.0          # runes linger far longer, ping-ponging through more of the horde
const EVO_RADIUS := 14.0             # a fatter rune (base 9) sweeps a wider lane through the swarm

var run: VSRun
var _cd := 0.0

func _process(delta: float) -> void:
	if run == null:
		return
	var lvl: int = run.runetracer_level
	if lvl <= 0:
		return
	if run.phase != "playing":
		return
	_cd -= delta
	if _cd <= 0.0:
		_fire(lvl)
		_cd = _interval(lvl)

## Cooldown between volleys, shrinking modestly with level (never below MIN_INTERVAL so a maxed
## Runetracer stays a periodic hazard rather than a constant screen-full of runes).
func _interval(lvl: int) -> float:
	return maxf(MIN_INTERVAL, BASE_INTERVAL - INTERVAL_PER_LEVEL * float(lvl - 1)) * run.haste_mult()

## Runes per volley: base one, plus one for every three levels, capped so the arena never fills
## with a free lattice of bouncing runes. NO FUTURE (evolved) throws extra runes and lifts the cap.
func _amount(lvl: int) -> int:
	var evolved: bool = run != null and run.runetracer_evolved
	var bonus := EVO_BONUS_AMOUNT if evolved else 0
	var cap := EVO_MAX_AMOUNT if evolved else MAX_AMOUNT
	return clampi(BASE_AMOUNT + lvl / 3 + bonus, BASE_AMOUNT, cap)

## One volley: launch `amount` runes from the player in evenly-spread directions so multiple runes
## fan out to different corners of the arena rather than overlapping.
func _fire(lvl: int) -> void:
	var evolved: bool = run.runetracer_evolved
	var dmg := (BASE_DAMAGE + DAMAGE_PER_LEVEL * float(lvl - 1)) * run.might_mult() * run.power_mult()
	var speed := BASE_SPEED * run.projectile_speed_mult   # Bracer passive speeds the carom up
	var life := BASE_LIFE + LIFE_PER_LEVEL * float(lvl - 1)
	if evolved:
		dmg *= EVO_DAMAGE_MULT
		speed *= EVO_SPEED_MULT
		life += EVO_LIFE_BONUS
	var count := _amount(lvl)
	var base_ang := randf() * TAU
	for i in count:
		var ang := base_ang + TAU * float(i) / float(count)
		var b := Bolt.new()
		b.position = global_position
		b.vel = Vector2(cos(ang), sin(ang)) * speed
		b.damage = dmg
		b.life = life
		b.life0 = life
		b.run = run
		if evolved:
			b.radius = EVO_RADIUS
		run.add_child(b)
	AgentBridge.emit_event("sfx_played", {"name": "runetracer"})


## The bouncing rune projectile. Lives in world space as a child of the run (not the player) so it
## caroms independently, reflecting off the arena bounds and piercing every enemy it overlaps. A
## per-enemy re-hit cooldown lets one rune strike the same enemy repeatedly as it passes back through.
class Bolt:
	extends Node2D

	const BASE_RADIUS := 9.0        # rune's own hit radius (NO FUTURE runes set a fatter one)
	const REHIT := 0.45            # seconds before a rune may strike the same enemy again
	const SPRITE_SCALE := 0.9

	var vel := Vector2.RIGHT
	var damage := 10.0
	var life := 4.0
	var life0 := 4.0
	var radius := BASE_RADIUS      # hit radius; the evolved weapon enlarges it per-rune
	var run: VSRun
	var _hit_cd := {}              # enemy -> seconds until it can be struck again
	var _sprite: Sprite2D
	var _spin := 0.0

	func _ready() -> void:
		add_to_group("projectiles")
		z_index = 1
		_sprite = Sprite2D.new()
		_sprite.texture = load("res://art/weapon_runetracer.png")
		# Scale the sprite with the hit radius so a fatter NO FUTURE rune also reads bigger.
		var s := SPRITE_SCALE * (radius / BASE_RADIUS)
		_sprite.scale = Vector2(s, s)
		add_child(_sprite)

	func _process(delta: float) -> void:
		if run == null:
			return
		# Freeze with the game during level-up / after the run ends (mirrors every other weapon).
		if run.phase != "playing":
			return
		life -= delta
		if life <= 0.0:
			queue_free()
			return
		position += vel * delta
		# Reflect off the arena bounds so the rune stays in play and ping-pongs across the field.
		var h: Vector2 = run.arena_half
		if position.x < -h.x:
			position.x = -h.x
			vel.x = absf(vel.x)
		elif position.x > h.x:
			position.x = h.x
			vel.x = -absf(vel.x)
		if position.y < -h.y:
			position.y = -h.y
			vel.y = absf(vel.y)
		elif position.y > h.y:
			position.y = h.y
			vel.y = -absf(vel.y)
		# Tick down each enemy's re-hit timer.
		for e in _hit_cd.keys():
			_hit_cd[e] = float(_hit_cd[e]) - delta
		# Pierce: strike every overlapping enemy that's off its re-hit cooldown.
		for e in get_tree().get_nodes_in_group("enemies"):
			# The "enemies" group also holds destructible props (candelabra); only strike real enemies.
			if not e is VSEnemy:
				continue
			var er: float = e.radius if "radius" in e else VSEnemy.RADIUS
			if (e.position - position).length() < radius + er:
				if float(_hit_cd.get(e, 0.0)) > 0.0:
					continue
				e.hit(damage, position)
				_hit_cd[e] = REHIT
		# Spin the polyhedron as it flies, and fade it out over its final half-second.
		_spin += delta * 6.0
		_sprite.rotation = _spin
		_sprite.modulate = Color(1, 1, 1, clampf(life / 0.5, 0.0, 1.0))
