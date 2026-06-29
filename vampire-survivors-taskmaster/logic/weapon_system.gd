class_name WeaponSystem extends RefCounted

## Pure stateless firing logic: each tick it ages every owned weapon's cooldown
## and, when one elapses, resolves that weapon's level + the player's stats and
## spawns its pattern into the ProjectilePool. No scene dependency; `db` is the
## GameDatabase (autoload Node or its script class), left untyped like the other
## systems so it is headless-testable.
##
## IMPORTANT — damage is stored PRE-Might. CollisionSystem multiplies
## `projectiles.damage * stats.might` at hit time, so applying Might here too
## would double-count it. The task sketch's `base_dmg * stats.might` is wrong for
## this codebase; we store the level-resolved base damage and let collision scale.
##
## Other reconciliations with the sketch:
##   * ProjectilePool's real API is `spawn(position, velocity, params)`; the
##     sketch's `spawn()`-then-assign-fields form does not exist.
##   * Infinite / AoE pierce is `-1` (the pool's convention), not `999`.
##   * Per-level deltas ARE applied (`_resolve_weapon`) — leveling a weapon must
##     change its damage/amount/area/speed/cooldown/pierce; the sketch ignored it.
##   * Whip "stays in place" -> STRAIGHT with zero velocity. AURA behavior pins a
##     projectile to the player each tick (MovementSystem), which is what Garlic
##     wants, not the directional Whip slash.

const BASE_PROJ_SPEED := 300.0      # px/s for a 1.0-speed projectile (sketch baseline)
const WHIP_RANGE := 32.0            # slash offset from the player along facing
const WHIP_LIFETIME := 0.3
const KNIFE_LIFETIME := 2.0
const KNIFE_SPACING := 12.0         # perpendicular gap between multiple knives
const BOLT_LIFETIME := 2.0          # magic wand / fire wand bolts
const GARLIC_PULSE_LIFETIME := 0.25 # one damage pulse per cooldown
const GARLIC_AREA_MULT := 2.5       # garlic aura is wider than a bolt's hit radius
const BIBLE_RADIUS := 60.0          # orbit radius (scaled by area)
const BIBLE_HIT_COOLDOWN := 0.5     # re-tick interval so an orbiting bible re-hits
const LIGHTNING_LIFETIME := 0.15    # instant strike flash
const LIGHTNING_AREA_MULT := 2.0    # strike covers an area around the target

static func step(state: RunState, db, delta: float) -> void:
	var player: PlayerState = state.player
	if player == null:
		return
	var stats: StatBlock = player.stats if player.stats != null else StatBlock.new()
	for weapon in player.weapons:
		var def: Dictionary = db.weapon(weapon.id)
		if def.is_empty():
			continue
		var resolved := _resolve_weapon(def, weapon.level)
		var scaled_cooldown := maxf(0.05, float(resolved.cooldown) * stats.cooldown)

		weapon.cooldown_timer -= delta
		if weapon.cooldown_timer > 0.0:
			continue

		weapon.cooldown_timer = scaled_cooldown
		_fire_weapon(state, weapon, resolved, stats)

## Merge a weapon's level-1 base with the per-level deltas in `levels[1 ..
## level-1]` (GameDatabase convention). Returns the resolved firing stats.
## Pierce stays infinite (-1) if the base is infinite; otherwise deltas add.
static func _resolve_weapon(def: Dictionary, level: int) -> Dictionary:
	var dmg: float = def.get("base_dmg", 0.0)
	var amount: int = int(def.get("amount", 1))
	var area: float = def.get("area", 1.0)
	var speed: float = def.get("speed", 1.0)
	var cooldown: float = def.get("cooldown", 1.0)
	var duration: float = def.get("duration", 0.0)
	var base_pierce: int = int(def.get("pierce", 1))
	var pierce_add := 0

	var levels: Array = def.get("levels", [])
	var cap: int = mini(level, levels.size())
	for i in range(1, cap):
		var d: Dictionary = levels[i]
		dmg += d.get("dmg", 0.0)
		amount += int(d.get("amount", 0))
		area += d.get("area", 0.0)
		speed += d.get("speed", 0.0)
		cooldown += d.get("cooldown", 0.0)
		duration += d.get("duration", 0.0)
		pierce_add += int(d.get("pierce", 0))

	var pierce := -1 if base_pierce < 0 else base_pierce + pierce_add
	return {
		dmg = dmg, amount = amount, area = area, speed = speed,
		cooldown = cooldown, duration = duration, pierce = pierce,
	}

static func _fire_weapon(state: RunState, weapon: WeaponInstance, r: Dictionary, stats: StatBlock) -> void:
	var amount: int = maxi(1, int(r.amount) + int(stats.amount))
	var damage: float = r.dmg                       # pre-Might (collision scales)
	var area: float = float(r.area) * stats.area
	var speed: float = BASE_PROJ_SPEED * float(r.speed) * stats.speed
	var pierce: int = int(r.pierce)
	var duration: float = float(r.duration)

	match weapon.id:
		&"whip":
			_fire_whip(state, damage, area, amount)
		&"knife":
			_fire_knife(state, damage, speed, amount, pierce)
		&"magic_wand":
			_fire_magic_wand(state, damage, speed, amount, pierce)
		&"runetracer":
			_fire_runetracer(state, damage, area, amount, speed, duration)
		&"garlic":
			_fire_garlic(state, damage, area)
		&"king_bible":
			_fire_king_bible(state, damage, area, amount, duration)
		&"fire_wand":
			_fire_fire_wand(state, damage, speed, amount, pierce)
		&"lightning_ring":
			_fire_lightning_ring(state, damage, area, amount)

# --- patterns ----------------------------------------------------------------

## Stationary slashes that pierce everything in the arc, alternating front/back.
static func _fire_whip(state: RunState, damage: float, area: float, amount: int) -> void:
	var facing := state.player.facing
	if facing == Vector2.ZERO:
		facing = Vector2.RIGHT
	for i in range(amount):
		var dir := facing if i % 2 == 0 else -facing
		state.projectiles.spawn(state.player.pos + dir * WHIP_RANGE, Vector2.ZERO, {
			damage = damage, pierce = -1, lifetime = WHIP_LIFETIME, area_scale = area,
			behavior = ProjectilePool.Behavior.STRAIGHT, owner_weapon = &"whip",
		})

## Straight knives along facing, fanned perpendicular when there are several.
static func _fire_knife(state: RunState, damage: float, speed: float, amount: int, pierce: int) -> void:
	var dir := state.player.facing
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var perp := Vector2(-dir.y, dir.x)
	for i in range(amount):
		var offset := perp * (float(i) - float(amount - 1) * 0.5) * KNIFE_SPACING
		state.projectiles.spawn(state.player.pos + offset, dir * speed, {
			damage = damage, pierce = pierce, lifetime = KNIFE_LIFETIME,
			behavior = ProjectilePool.Behavior.STRAIGHT, owner_weapon = &"knife",
		})

## Bolts aimed at the nearest enemies (distinct targets, repeating if fewer).
static func _fire_magic_wand(state: RunState, damage: float, speed: float, amount: int, pierce: int) -> void:
	var targets := _find_nearest_enemies(state, amount)
	if targets.is_empty():
		return
	var enemies: EnemyPool = state.enemies
	for i in range(amount):
		var tgt: int = targets[i % targets.size()]
		var dir := (enemies.pos[tgt] - state.player.pos).normalized()
		if dir == Vector2.ZERO:
			dir = state.player.facing
		state.projectiles.spawn(state.player.pos, dir * speed, {
			damage = damage, pierce = pierce, lifetime = BOLT_LIFETIME,
			behavior = ProjectilePool.Behavior.STRAIGHT, owner_weapon = &"magic_wand",
		})

## Bouncing AoE shots fired in random directions; bounce off the camera rect.
static func _fire_runetracer(state: RunState, damage: float, area: float, amount: int, speed: float, duration: float) -> void:
	for i in range(amount):
		var ang := state.rng.randf_range(0.0, TAU) if state.rng != null else float(i) / float(amount) * TAU
		state.projectiles.spawn(state.player.pos, Vector2.from_angle(ang) * speed, {
			damage = damage, pierce = -1, lifetime = maxf(0.1, duration), area_scale = area,
			behavior = ProjectilePool.Behavior.BOUNCE, owner_weapon = &"runetracer",
		})

## One persistent-following damage pulse around the player (single, not amount-
## based: Garlic's base amount is 0).
static func _fire_garlic(state: RunState, damage: float, area: float) -> void:
	state.projectiles.spawn(state.player.pos, Vector2.ZERO, {
		damage = damage, pierce = -1, lifetime = GARLIC_PULSE_LIFETIME,
		area_scale = area * GARLIC_AREA_MULT,
		behavior = ProjectilePool.Behavior.AURA, owner_weapon = &"garlic",
	})

## Orbiting bibles spread evenly around the player; re-tick so they keep hitting.
static func _fire_king_bible(state: RunState, damage: float, area: float, amount: int, duration: float) -> void:
	var radius := BIBLE_RADIUS * area
	for i in range(amount):
		var ang := float(i) / float(amount) * TAU
		var pos := state.player.pos + Vector2.from_angle(ang) * radius
		state.projectiles.spawn(pos, Vector2.ZERO, {
			damage = damage, pierce = -1, lifetime = maxf(0.1, duration), area_scale = area,
			behavior = ProjectilePool.Behavior.ORBIT, hit_cooldown = BIBLE_HIT_COOLDOWN,
			owner_weapon = &"king_bible",
		})

## Fireballs hurled toward random enemies (random spread when none are present).
static func _fire_fire_wand(state: RunState, damage: float, speed: float, amount: int, pierce: int) -> void:
	var enemies: EnemyPool = state.enemies
	for i in range(amount):
		var tgt := _random_alive_enemy(state)
		var dir: Vector2
		if tgt >= 0:
			dir = (enemies.pos[tgt] - state.player.pos).normalized()
		elif state.rng != null:
			dir = Vector2.from_angle(state.rng.randf_range(0.0, TAU))
		else:
			dir = state.player.facing
		if dir == Vector2.ZERO:
			dir = Vector2.RIGHT
		state.projectiles.spawn(state.player.pos, dir * speed, {
			damage = damage, pierce = pierce, lifetime = BOLT_LIFETIME,
			behavior = ProjectilePool.Behavior.STRAIGHT, owner_weapon = &"fire_wand",
		})

## Instant AoE strikes at random enemy locations (near the player if none).
static func _fire_lightning_ring(state: RunState, damage: float, area: float, amount: int) -> void:
	var enemies: EnemyPool = state.enemies
	for i in range(amount):
		var tgt := _random_alive_enemy(state)
		var pos: Vector2
		if tgt >= 0:
			pos = enemies.pos[tgt]
		elif state.rng != null:
			pos = state.player.pos + Vector2.from_angle(state.rng.randf_range(0.0, TAU)) * 120.0
		else:
			pos = state.player.pos
		state.projectiles.spawn(pos, Vector2.ZERO, {
			damage = damage, pierce = -1, lifetime = LIGHTNING_LIFETIME,
			area_scale = area * LIGHTNING_AREA_MULT,
			behavior = ProjectilePool.Behavior.STRAIGHT, owner_weapon = &"lightning_ring",
		})

# --- targeting helpers -------------------------------------------------------

static func _find_nearest_enemy(state: RunState) -> int:
	var enemies: EnemyPool = state.enemies
	var nearest := -1
	var best := INF
	for i in EnemyPool.CAPACITY:
		if not enemies.alive[i]:
			continue
		var d := state.player.pos.distance_squared_to(enemies.pos[i])
		if d < best:
			best = d
			nearest = i
	return nearest

## Up to `k` nearest alive enemy indices, ascending by distance.
static func _find_nearest_enemies(state: RunState, k: int) -> Array:
	var enemies: EnemyPool = state.enemies
	var pairs: Array = []
	for i in EnemyPool.CAPACITY:
		if enemies.alive[i]:
			pairs.append([state.player.pos.distance_squared_to(enemies.pos[i]), i])
	pairs.sort_custom(func(a, b): return a[0] < b[0])
	var out: Array = []
	for i in range(mini(k, pairs.size())):
		out.append(pairs[i][1])
	return out

static func _random_alive_enemy(state: RunState) -> int:
	var enemies: EnemyPool = state.enemies
	var alive_idx: Array = []
	for i in EnemyPool.CAPACITY:
		if enemies.alive[i]:
			alive_idx.append(i)
	if alive_idx.is_empty():
		return -1
	if state.rng != null:
		return alive_idx[state.rng.randi_range(0, alive_idx.size() - 1)]
	return alive_idx[0]
