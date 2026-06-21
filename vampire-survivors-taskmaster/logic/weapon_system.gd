class_name WeaponSystem extends RefCounted

## Ticks each owned weapon's cooldown and, when ready, emits projectiles/zones
## per its pattern. Pure. Emitted damage is the weapon's level-scaled BASE damage;
## Might is applied later by CombatSystem (single place), so it is NOT folded in
## here. Per-level scaling comes from the authored WeaponDef.levels deltas (not a
## generic per-level formula).

const WHIP_REACH: float = 40.0  # offset of the slash center from the torso
const WHIP_BASE_RADIUS: float = 60.0  # at area 1.0
const WHIP_LIFETIME: float = 0.15  # brief slash

# Per-pattern tuning for the projectile/zone weapons (task 28).
const DEFAULT_PROJ_LIFETIME: float = 2.0
const PROJ_FAN_SPREAD: float = 0.14  # radians between fanned projectiles (Knife/Magic Wand)
const AXE_HORIZONTAL_SPEED: float = 70.0  # sideways drift folded onto facing
const AXE_UPWARD_SPEED: float = 280.0  # initial upward launch speed
const AXE_GRAVITY: float = 360.0  # downward acceleration (px/sec^2)
const CROSS_RANGE: float = 180.0  # outward travel before the boomerang returns
const BIBLE_ORBIT_RADIUS: float = 72.0  # at area 1.0
const BIBLE_ORBIT_SPEED: float = 3.2  # rad/sec
const BIBLE_RADIUS: float = 28.0  # damage radius of one orbiter, at area 1.0
const BIBLE_TICK: float = 0.4  # periodic damage interval
const FIRE_RADIUS: float = 52.0  # explosion radius at area 1.0
const FIRE_LIFETIME: float = 0.4  # brief explosion
const GARLIC_RADIUS: float = 60.0  # aura radius at area 1.0
const GARLIC_TICK: float = 0.5
const WATER_RADIUS: float = 44.0  # puddle radius at area 1.0
const WATER_TICK: float = 0.5
const WATER_SCATTER: float = 90.0  # puddles land within this distance of the player

# Stat keys that a WeaponDef.levels entry may add to.
const _SCALABLE := [
	"damage", "area", "amount", "pierce", "duration", "projectile_speed",
	"cooldown", "crit_chance", "crit_mult", "knockback",
]


static func step(state: GameState, dt: float) -> void:
	var derived: ResolvedStats = state.player.derived
	for weapon in state.player.weapons:
		if weapon.def == null:
			continue
		weapon.cooldown_timer -= dt
		if weapon.cooldown_timer <= 0.0:
			var ws := _resolve_weapon_stats(weapon)
			cast(state, weapon, ws)
			weapon.cooldown_timer = float(ws["cooldown"]) * derived.cooldown


## Emit one weapon's pattern. `ws` is the resolved (level-scaled) stat dict;
## computed by step, but recomputed here if omitted so cast() can be called
## directly (e.g. in tests).
static func cast(state: GameState, weapon: WeaponInstance, ws: Dictionary = {}) -> void:
	if weapon.def == null:
		return
	if ws.is_empty():
		ws = _resolve_weapon_stats(weapon)
	match weapon.def.id:
		"whip":
			_cast_whip(state, weapon, ws)
		"magic_wand":
			_cast_magic_wand(state, weapon, ws)
		"knife":
			_cast_knife(state, weapon, ws)
		"axe":
			_cast_axe(state, weapon, ws)
		"cross":
			_cast_cross(state, weapon, ws)
		"king_bible":
			_cast_king_bible(state, weapon, ws)
		"fire_wand":
			_cast_fire_wand(state, weapon, ws)
		"garlic":
			_cast_garlic(state, weapon, ws)
		"santa_water":
			_cast_santa_water(state, weapon, ws)
		_:
			pass  # other weapon patterns are added incrementally


## Whip: a horizontal slash (FOLLOW_PLAYER zone) in the facing direction. Extra
## Amount adds slashes that alternate toward/away from facing; the starting side
## flips each cast so successive whips swing both ways.
static func _cast_whip(state: GameState, weapon: WeaponInstance, ws: Dictionary) -> void:
	var player: PlayerState = state.player
	var area: float = float(ws["area"]) * player.derived.area
	var damage: float = float(ws["damage"])
	var radius: float = WHIP_BASE_RADIUS * area
	var amount: int = int(ws["amount"]) + player.derived.amount
	var base_side: int = int(weapon.scratch.get("side", 1))
	for i in maxi(amount, 1):
		var side: int = base_side if i % 2 == 0 else -base_side
		var offset: Vector2 = player.facing * WHIP_REACH * side
		var zone := DamageZone.new()
		zone.source_weapon = weapon
		zone.anchor = DamageZone.Anchor.FOLLOW_PLAYER
		zone.offset = offset
		zone.pos = player.pos + offset
		zone.radius = radius
		zone.damage = damage
		zone.lifetime = WHIP_LIFETIME
		zone.tick_interval = 0.0  # single hit (tracked via hit_ids in CombatSystem)
		state.zones.append(zone)
	weapon.scratch["side"] = -base_side


## Magic Wand: one projectile per Amount toward the nearest enemy (fanned).
static func _cast_magic_wand(state: GameState, weapon: WeaponInstance, ws: Dictionary) -> void:
	var player: PlayerState = state.player
	var amount := _total_amount(ws, player.derived)
	var speed := float(ws["projectile_speed"])
	var base_dir := _aim_nearest(state, player.facing)
	for i in amount:
		var p := _new_projectile(state, weapon, ws)
		p.velocity = base_dir.rotated(_fan_offset(i, amount, PROJ_FAN_SPREAD)) * speed
		state.projectiles.append(p)


## Knife: fast piercing shots in the facing direction (fanned by Amount).
static func _cast_knife(state: GameState, weapon: WeaponInstance, ws: Dictionary) -> void:
	var player: PlayerState = state.player
	var amount := _total_amount(ws, player.derived)
	var speed := float(ws["projectile_speed"])
	for i in amount:
		var p := _new_projectile(state, weapon, ws)
		p.velocity = player.facing.rotated(_fan_offset(i, amount, PROJ_FAN_SPREAD)) * speed
		state.projectiles.append(p)


## Axe: high-damage lob — launched upward in the facing direction with gravity
## pulling it back down (CombatSystem integrates proj.accel).
static func _cast_axe(state: GameState, weapon: WeaponInstance, ws: Dictionary) -> void:
	var player: PlayerState = state.player
	var amount := _total_amount(ws, player.derived)
	var side := signf(player.facing.x) if absf(player.facing.x) > 0.001 else 1.0
	for i in amount:
		var p := _new_projectile(state, weapon, ws)
		var hspeed := AXE_HORIZONTAL_SPEED + float(i) * 30.0  # spread successive axes
		p.velocity = Vector2(side * hspeed, -AXE_UPWARD_SPEED)
		p.accel = Vector2(0.0, AXE_GRAVITY)
		state.projectiles.append(p)


## Cross: boomerang toward the nearest enemy; flies out CROSS_RANGE then homes
## back to the player (CombatSystem handles the turn-around).
static func _cast_cross(state: GameState, weapon: WeaponInstance, ws: Dictionary) -> void:
	var player: PlayerState = state.player
	var amount := _total_amount(ws, player.derived)
	var speed := float(ws["projectile_speed"])
	var base_dir := _aim_nearest(state, player.facing)
	for i in amount:
		var p := _new_projectile(state, weapon, ws)
		p.velocity = base_dir.rotated(_fan_offset(i, amount, PROJ_FAN_SPREAD)) * speed
		p.is_boomerang = true
		p.boomerang_range = CROSS_RANGE * player.derived.area
		state.projectiles.append(p)


## King Bible: Amount orbiters evenly spaced around the player, spinning and
## ticking damage for the weapon's duration.
static func _cast_king_bible(state: GameState, weapon: WeaponInstance, ws: Dictionary) -> void:
	var player: PlayerState = state.player
	var area := float(ws["area"]) * player.derived.area
	var count := _total_amount(ws, player.derived)
	var orbit_r := BIBLE_ORBIT_RADIUS * area
	var dur := float(ws["duration"])
	var lifetime := dur if dur > 0.0 else 3.0
	for i in count:
		var z := DamageZone.new()
		z.source_weapon = weapon
		z.anchor = DamageZone.Anchor.ORBIT
		z.offset = Vector2.RIGHT.rotated(TAU * float(i) / float(count)) * orbit_r
		z.pos = player.pos + z.offset
		z.orbit_speed = BIBLE_ORBIT_SPEED
		z.radius = BIBLE_RADIUS * area
		z.damage = float(ws["damage"])
		z.lifetime = lifetime
		z.tick_interval = BIBLE_TICK
		state.zones.append(z)


## Fire Wand: a brief explosion (WORLD zone) on a random enemy per Amount.
static func _cast_fire_wand(state: GameState, weapon: WeaponInstance, ws: Dictionary) -> void:
	var player: PlayerState = state.player
	var area := float(ws["area"]) * player.derived.area
	var amount := _total_amount(ws, player.derived)
	for i in amount:
		var z := DamageZone.new()
		z.source_weapon = weapon
		z.anchor = DamageZone.Anchor.WORLD
		z.pos = _random_enemy_pos(state, player.pos + player.facing * 120.0)
		z.radius = FIRE_RADIUS * area
		z.damage = float(ws["damage"])
		z.lifetime = FIRE_LIFETIME
		z.tick_interval = 0.0  # single hit over its brief life (hit_ids dedup)
		state.zones.append(z)


## Garlic: a persistent aura (FOLLOW_PLAYER zone) ticking damage to everything in
## range. Re-cast each cooldown; lifetime spans the cooldown so it stays continuous.
static func _cast_garlic(state: GameState, weapon: WeaponInstance, ws: Dictionary) -> void:
	var player: PlayerState = state.player
	var area := float(ws["area"]) * player.derived.area
	var cd := float(ws["cooldown"]) * player.derived.cooldown
	var z := DamageZone.new()
	z.source_weapon = weapon
	z.anchor = DamageZone.Anchor.FOLLOW_PLAYER
	z.offset = Vector2.ZERO
	z.pos = player.pos
	z.radius = GARLIC_RADIUS * area
	z.damage = float(ws["damage"])
	z.lifetime = maxf(cd, GARLIC_TICK)
	z.tick_interval = GARLIC_TICK
	state.zones.append(z)


## Santa Water: drops Amount puddles (WORLD zones) scattered near the player that
## persist and tick for the weapon's duration.
static func _cast_santa_water(state: GameState, weapon: WeaponInstance, ws: Dictionary) -> void:
	var player: PlayerState = state.player
	var area := float(ws["area"]) * player.derived.area
	var amount := _total_amount(ws, player.derived)
	var dur := float(ws["duration"])
	var lifetime := dur if dur > 0.0 else 3.0
	for i in amount:
		var ang := state.rng.randf() * TAU
		var dist := state.rng.randf_range(0.0, WATER_SCATTER)
		var z := DamageZone.new()
		z.source_weapon = weapon
		z.anchor = DamageZone.Anchor.WORLD
		z.pos = player.pos + Vector2(cos(ang), sin(ang)) * dist
		z.radius = WATER_RADIUS * area
		z.damage = float(ws["damage"])
		z.lifetime = lifetime
		z.tick_interval = WATER_TICK
		state.zones.append(z)


# --- shared pattern helpers ---

## Total emissions = the weapon's (level-scaled) Amount plus the global Amount stat.
static func _total_amount(ws: Dictionary, derived: ResolvedStats) -> int:
	return maxi(int(ws["amount"]) + derived.amount, 1)


## Angular offset of the i-th of `count` fanned emissions (centered on 0).
static func _fan_offset(i: int, count: int, spread: float) -> float:
	return (float(i) - float(count - 1) * 0.5) * spread


## A projectile pre-filled with the weapon's resolved damage/crit/pierce/lifetime,
## spawned at the player. Caller sets velocity (and any accel/boomerang fields).
static func _new_projectile(state: GameState, weapon: WeaponInstance, ws: Dictionary) -> Projectile:
	var p := Projectile.new()
	p.source_weapon = weapon
	p.pos = state.player.pos
	p.damage = float(ws["damage"])
	p.crit_chance = float(ws["crit_chance"])
	p.crit_mult = float(ws["crit_mult"])
	p.pierce_left = maxi(int(ws["pierce"]), 1)
	var dur := float(ws["duration"])
	p.lifetime = dur if dur > 0.0 else DEFAULT_PROJ_LIFETIME
	return p


## Unit direction to the nearest enemy, or `fallback` if the index is empty/absent.
static func _aim_nearest(state: GameState, fallback: Vector2) -> Vector2:
	if state.index == null:
		return fallback
	var idx := SpatialIndex.nearest_enemy(state.index, state.player.pos)
	if idx < 0:
		return fallback
	var target = state.enemies[idx]
	var d: Vector2 = target.pos - state.player.pos
	return d.normalized() if d.length_squared() > 0.0 else fallback


## Position of a uniformly-random enemy, or `fallback` if the index is empty/absent.
static func _random_enemy_pos(state: GameState, fallback: Vector2) -> Vector2:
	if state.index == null:
		return fallback
	var idx := SpatialIndex.random_enemy(state.index, state.rng)
	if idx < 0:
		return fallback
	var target = state.enemies[idx]
	return target.pos


## Apply WeaponDef.levels deltas up to the instance's current level onto the base
## stats, returning the effective values. Empty levels -> base (level 1).
static func _resolve_weapon_stats(weapon: WeaponInstance) -> Dictionary:
	var def = weapon.def  # untyped: WeaponInstance.def is a Variant
	var s := {
		"damage": def.base_damage,
		"area": def.area,
		"amount": def.amount,
		"pierce": def.pierce,
		"duration": def.duration,
		"projectile_speed": def.projectile_speed,
		"cooldown": def.cooldown,
		"crit_chance": def.crit_chance,
		"crit_mult": def.crit_mult,
		"knockback": def.knockback,
	}
	for entry in def.levels:
		if int(entry.get("level", 1 << 30)) <= weapon.level:
			for key in _SCALABLE:
				if entry.has(key):
					s[key] += entry[key]
	return s
