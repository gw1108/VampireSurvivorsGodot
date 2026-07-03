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

## Base damage + per-level growth live in res://data/balance.csv ("fire_wand_base_damage" /
## "fire_wand_damage_per_level") so a designer can retune them without touching this script.
## Lv1 = 20, Lv8 = 62 — the roster's heaviest single hit.
static var BASE_DAMAGE := BalanceData.get_value("fire_wand_base_damage", 20.0)
static var DAMAGE_PER_LEVEL := BalanceData.get_value("fire_wand_damage_per_level", 6.0)
const BASE_INTERVAL := 3.0            # wiki cooldown; tightens a little per level so it keeps pace
const INTERVAL_PER_LEVEL := 0.18
const MIN_INTERVAL := 1.4
const BASE_AMOUNT := 1                # fireballs per volley at Lv1…
const MAX_AMOUNT := 3                 # …growing by one every three levels, capped at the wiki Amount 3
const BASE_SPEED := 300.0             # px/sec — a lobbed bomb, slower than a bolt
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
	return maxf(MIN_INTERVAL, BASE_INTERVAL - INTERVAL_PER_LEVEL * float(lvl - 1))

## Fireballs per volley: base one, plus one for every three levels, capped at the wiki Amount 3
## so the arena never fills with a free wall of explosions.
func _amount(lvl: int) -> int:
	return clampi(BASE_AMOUNT + lvl / 3, BASE_AMOUNT, MAX_AMOUNT)

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
	var dmg_base := BASE_DAMAGE + DAMAGE_PER_LEVEL * float(lvl - 1)
	var speed := BASE_SPEED * run.projectile_speed_mult   # Bracer passive speeds the lob up
	var blast := BLAST_RADIUS * run.area_mult             # Candelabrador passive widens the blast
	var life := BASE_LIFE
	if evolved:                                           # Hellfire: harder, wider, longer-lived, piercing
		dmg_base *= HELLFIRE_DAMAGE_MULT
		blast *= HELLFIRE_BLAST_MULT
		life *= HELLFIRE_LIFE_MULT
	var dmg := dmg_base * run.might_mult()
	var count := mini(_amount(lvl), enemies.size())
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


## The flying fireball. Lives in world space as a child of the run (not the player) so it travels
## independently, detonating on the first enemy it overlaps — or self-detonating when its life runs
## out — and dealing its full damage to every enemy within `blast` of the impact. Drawn as a glowing
## fiery orb with a bright core so it reads at a glance without a dedicated sprite.
class Fireball:
	extends Node2D

	const RADIUS := 10.0             # the ball's own contact radius
	const CORE_COLOR := Color(1.0, 0.95, 0.6)   # white-hot centre
	const FLAME_COLOR := Color(1.0, 0.5, 0.12)  # orange body
	const BLAST_FLASH := 0.22        # seconds the detonation flash lingers before the node frees

	var vel := Vector2.RIGHT
	var damage := 20.0
	var blast := 58.0
	var life := 2.2
	var pierce := false              # Hellfire: sear through enemies instead of detonating on the first
	var run: VSRun
	var _flicker := 0.0
	var _exploding := false
	var _flash := 0.0                # seconds of detonation flash remaining while _exploding
	var _seared := {}                # ids of enemies a piercing ball has already burned (hit each once)

	func _ready() -> void:
		add_to_group("projectiles")
		z_index = 1

	func _process(delta: float) -> void:
		if run == null:
			return
		# Freeze with the game during level-up / after the run ends (mirrors every other weapon).
		if run.phase != "playing":
			return
		if _exploding:
			# Hold the blast flash briefly, then clean up.
			_flash -= delta
			queue_redraw()
			if _flash <= 0.0:
				queue_free()
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
		queue_redraw()

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
	## switch to the brief flash state before freeing. Guarded so a fireball detonates exactly once.
	func _detonate() -> void:
		if _exploding:
			return
		_exploding = true
		_flash = BLAST_FLASH
		for e in get_tree().get_nodes_in_group("enemies"):
			if not e is VSEnemy:
				continue
			var er: float = e.radius if "radius" in e else VSEnemy.RADIUS
			if (e.position - position).length() <= blast + er:
				e.hit(damage, position)
		if run:
			run.add_camera_shake(0.16)   # a small jolt so the blast lands with weight
		queue_redraw()

	## Render the fireball in flight as a flickering fiery orb, or the detonation as an expanding
	## fading blast disc. Drawn in local space (the node's origin is the ball / blast centre).
	func _draw() -> void:
		if _exploding:
			var frac: float = clampf(_flash / BLAST_FLASH, 0.0, 1.0)
			var r := blast * (0.6 + 0.4 * (1.0 - frac))   # disc grows as it fades
			draw_circle(Vector2.ZERO, r, Color(FLAME_COLOR.r, FLAME_COLOR.g, FLAME_COLOR.b, 0.45 * frac))
			draw_circle(Vector2.ZERO, r * 0.55, Color(CORE_COLOR.r, CORE_COLOR.g, CORE_COLOR.b, 0.6 * frac))
			return
		# Flickering orb: an orange body with a jittering white-hot core so it reads as live fire.
		# Hellfire burns bigger and hotter — a swollen, whiter comet so its piercing pass reads at a glance.
		var pulse := 1.0 + 0.15 * sin(_flicker)
		var r := RADIUS * (1.5 if pierce else 1.0) * pulse
		draw_circle(Vector2.ZERO, r, Color(FLAME_COLOR.r, FLAME_COLOR.g, FLAME_COLOR.b, 0.9))
		draw_circle(Vector2.ZERO, r * (0.62 if pierce else 0.5), CORE_COLOR)
