class_name WeaponSystem extends RefCounted

## Ticks each owned weapon's cooldown and, when ready, emits projectiles/zones
## per its pattern. Pure. Emitted damage is the weapon's level-scaled BASE damage;
## Might is applied later by CombatSystem (single place), so it is NOT folded in
## here. Per-level scaling comes from the authored WeaponDef.levels deltas (not a
## generic per-level formula).

const WHIP_REACH: float = 40.0  # offset of the slash center from the torso
const WHIP_BASE_RADIUS: float = 60.0  # at area 1.0
const WHIP_LIFETIME: float = 0.15  # brief slash

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
