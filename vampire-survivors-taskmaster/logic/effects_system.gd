class_name EffectsSystem extends RefCounted

## Pure logic for consumable pickup effects and timed run-effects. The controller
## feeds it the CollisionResult.collected_effects ({kind, value}) one at a time
## via apply_pickup, and calls tick_effects every frame to age freeze/fire-breath.
## No scene dependency.
##
## Reconciliations with the task sketch:
##   * Fire-breath damage is stored PRE-Might (20), not 20*might — CollisionSystem
##     multiplies projectile damage by stats.might at hit time (double-counting
##     otherwise).
##   * ProjectilePool's real API is spawn(position, velocity, params); the sketch's
##     spawn()-then-assign form does not exist.
##   * AoE pierce is -1 (pool convention), not 999.
##   * Chicken heal / durations are named constants here (mirroring the
##     GameDatabase values) so apply_pickup keeps the {state, kind, value} shape.

const CHICKEN_HEAL := 30.0          # mirrors GameDatabase.CHICKEN_HEAL
const FREEZE_DURATION := 10.0       # Orologion freeze
const FIREBREATH_DURATION := 10.0   # Nduja fire-breath
const FIREBREATH_DMG := 20.0        # pre-Might; collision scales
const FIREBREATH_AREA := 1.5
const FIREBREATH_LIFETIME := 0.1    # one short pulse per tick

## Apply a single collected consumable to the run state.
static func apply_pickup(state: RunState, kind: int, value: float) -> void:
	var player: PlayerState = state.player
	match kind:
		PickupPool.Kind.CHICKEN:
			var cap: float = player.stats.max_health if player.stats != null else player.max_hp
			player.hp = minf(player.hp + CHICKEN_HEAL, cap)
		PickupPool.Kind.GOLD:
			var greed: float = player.stats.greed if player.stats != null else 1.0
			player.gold += int(value * greed)
		PickupPool.Kind.ROSARY:
			_screen_clear(state)
		PickupPool.Kind.OROLOGION:
			state.freeze_timer = FREEZE_DURATION
		PickupPool.Kind.VACUUM:
			_magnetize_all_gems(state)
		PickupPool.Kind.NDUJA:
			state.firebreath_timer = FIREBREATH_DURATION
		PickupPool.Kind.REROLLO:
			player.reroll_charges += 1

## Rosary: clear every non-immune enemy off the field. Grants no gems (per VS),
## so enemies are despawned directly rather than routed through a death.
static func _screen_clear(state: RunState) -> void:
	var enemies: EnemyPool = state.enemies
	for i in EnemyPool.CAPACITY:
		if not enemies.alive[i]:
			continue
		if enemies.type_id[i] == &"reaper":  # the only immune unit in the slice
			continue
		enemies.despawn(i)

## Vacuum: magnetize every XP gem so they fly to the player.
static func _magnetize_all_gems(state: RunState) -> void:
	var pickups: PickupPool = state.pickups
	for i in PickupPool.CAPACITY:
		if pickups.alive[i] and pickups.kind[i] == PickupPool.Kind.GEM:
			pickups.magnetized[i] = true

## Age timed run-effects. While fire-breath is active, emit its aura each tick.
static func tick_effects(state: RunState, delta: float) -> void:
	if state.freeze_timer > 0.0:
		state.freeze_timer = maxf(0.0, state.freeze_timer - delta)

	if state.firebreath_timer > 0.0:
		state.firebreath_timer = maxf(0.0, state.firebreath_timer - delta)
		_emit_firebreath(state)

## Short-lived AoE aura around the player (Nduja). Damage is pre-Might.
static func _emit_firebreath(state: RunState) -> void:
	state.projectiles.spawn(state.player.pos, Vector2.ZERO, {
		damage = FIREBREATH_DMG,
		pierce = -1,
		lifetime = FIREBREATH_LIFETIME,
		area_scale = FIREBREATH_AREA,
		behavior = ProjectilePool.Behavior.AURA,
		owner_weapon = &"nduja",
	})
