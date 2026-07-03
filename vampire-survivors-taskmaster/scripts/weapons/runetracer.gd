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

const BASE_DAMAGE := 10.0             # wiki base
const DAMAGE_PER_LEVEL := 3.0         # Lv1 = 10, Lv8 = 31 — a steady bouncing chip
const BASE_INTERVAL := 3.0            # wiki cooldown; tightens a little per level so it keeps pace
const INTERVAL_PER_LEVEL := 0.15
const MIN_INTERVAL := 1.4
const BASE_AMOUNT := 1                # runes per volley (wiki Amount 1)…
const MAX_AMOUNT := 3                 # …growing by one every three levels, capped here
const BASE_SPEED := 260.0             # px/sec — a brisk carom, not a bullet
const BASE_LIFE := 4.0               # seconds a rune bounces before dissipating…
const LIFE_PER_LEVEL := 0.4          # …lasting longer as it levels so late runes cover more ground

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
	return maxf(MIN_INTERVAL, BASE_INTERVAL - INTERVAL_PER_LEVEL * float(lvl - 1))

## Runes per volley: base one, plus one for every three levels, capped so the arena never fills
## with a free lattice of bouncing runes.
func _amount(lvl: int) -> int:
	return clampi(BASE_AMOUNT + lvl / 3, BASE_AMOUNT, MAX_AMOUNT)

## One volley: launch `amount` runes from the player in evenly-spread directions so multiple runes
## fan out to different corners of the arena rather than overlapping.
func _fire(lvl: int) -> void:
	var dmg := (BASE_DAMAGE + DAMAGE_PER_LEVEL * float(lvl - 1)) * run.might_mult()
	var speed := BASE_SPEED * run.projectile_speed_mult   # Bracer passive speeds the carom up
	var life := BASE_LIFE + LIFE_PER_LEVEL * float(lvl - 1)
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
		run.add_child(b)
	AgentBridge.emit_event("sfx_played", {"name": "runetracer"})


## The bouncing rune projectile. Lives in world space as a child of the run (not the player) so it
## caroms independently, reflecting off the arena bounds and piercing every enemy it overlaps. A
## per-enemy re-hit cooldown lets one rune strike the same enemy repeatedly as it passes back through.
class Bolt:
	extends Node2D

	const RADIUS := 9.0             # rune's own hit radius
	const REHIT := 0.45            # seconds before a rune may strike the same enemy again
	const SPRITE_SCALE := 0.9

	var vel := Vector2.RIGHT
	var damage := 10.0
	var life := 4.0
	var life0 := 4.0
	var run: VSRun
	var _hit_cd := {}              # enemy -> seconds until it can be struck again
	var _sprite: Sprite2D
	var _spin := 0.0

	func _ready() -> void:
		add_to_group("projectiles")
		z_index = 1
		_sprite = Sprite2D.new()
		_sprite.texture = load("res://art/weapon_runetracer.png")
		_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
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
			if (e.position - position).length() < RADIUS + er:
				if float(_hit_cd.get(e, 0.0)) > 0.0:
					continue
				e.hit(damage, position)
				_hit_cd[e] = REHIT
		# Spin the polyhedron as it flies, and fade it out over its final half-second.
		_spin += delta * 6.0
		_sprite.rotation = _spin
		_sprite.modulate = Color(1, 1, 1, clampf(life / 0.5, 0.0, 1.0))
