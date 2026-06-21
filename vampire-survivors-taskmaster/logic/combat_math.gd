class_name CombatMath extends RefCounted

## Shared, pure combat math: damage scaling, crit rolls, armor mitigation,
## knockback vectors, and range checks. Stateless static helpers used by the
## Weapon/Combat systems so the rules live in exactly one place.

const KNOCKBACK_DURATION: float = 0.1  # seconds the knockback slide lasts
const BASE_KNOCKBACK_FORCE: float = 100.0


## Base weapon damage scaled by the player's Might multiplier.
static func calc_damage(base_damage: float, might: float) -> float:
	return base_damage * might


## Roll for a critical hit. Returns {is_crit, multiplier} where multiplier is
## crit_mult on a crit, else 1.0. Uses the run's seeded rng for determinism.
static func roll_crit(rng: RandomNumberGenerator, crit_chance: float, crit_mult: float) -> Dictionary:
	var is_crit := rng.randf() < crit_chance
	return {
		"is_crit": is_crit,
		"multiplier": crit_mult if is_crit else 1.0,
	}


## Flat armor mitigation. Every hit deals at least 1 damage (VS rule).
static func apply_armor(damage: float, armor: float) -> float:
	return maxf(damage - armor, 1.0)


## Knockback vector pushing `to_pos` away from `from_pos`. Resist >= 1 (bosses)
## is immune; partial resist scales the force down. Coincident points -> zero.
static func calc_knockback(from_pos: Vector2, to_pos: Vector2, force: float, resist: float) -> Vector2:
	if resist >= 1.0:
		return Vector2.ZERO  # boss / knockback-immune
	var dir := (to_pos - from_pos).normalized()
	return dir * force * (1.0 - resist)


## True when a and b are within the (squared) range. Squared to avoid sqrt.
static func is_in_range(a: Vector2, b: Vector2, range_sq: float) -> bool:
	return a.distance_squared_to(b) <= range_sq
