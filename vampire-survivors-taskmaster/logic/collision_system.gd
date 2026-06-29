class_name CollisionSystem extends RefCounted

## Pure resolution of every overlap interaction for one tick via data lookup
## (no physics engine): weapon hits (damage/crit/knockback/pierce, deaths ->
## free slot + kill + gem + boss flag), contact damage (i-frame gated), and
## pickup magnetize + collect. Returns a CollisionResult the controller dispatches
## to Leveling/Effects/Chest. No scene dependency.

const PROJECTILE_HIT_RADIUS := 16.0
const PLAYER_RADIUS := 20.0
const COLLECT_RADIUS := 16.0
const KNOCKBACK_SPEED := 200.0
const KNOCKBACK_TIME := 0.12
const HIT_FLASH_TIME := 0.1
const IFRAME_TIME := 0.24       # 240 ms
const GEM_BLUE_MAX := 2.0       # matches GameDatabase gem tiers
const GEM_GREEN_MAX := 9.0

## Carries the tick's collection outcomes for the controller to dispatch.
## boss_deaths: markers (one chest per boss death). collected_chests: chest seed
## values (NOT freed slot indices). collected_effects: {kind, value} captured
## before despawn.
class CollisionResult extends RefCounted:
	var xp_gained: float = 0.0
	var boss_deaths: Array[int] = []
	var collected_chests: Array[float] = []
	var collected_effects: Array[Dictionary] = []

static func resolve(state: RunState, _db, delta: float) -> CollisionResult:
	var result := CollisionResult.new()
	var stats: StatBlock = state.player.stats
	if stats == null:
		stats = StatBlock.new()
	_decay_hit_flash(state.enemies, delta)
	_decay_recent_hits(state.projectiles, delta)
	_resolve_weapon_hits(state, delta, result, stats)
	_resolve_contact_damage(state, stats)
	_resolve_pickup_collection(state, stats, result)
	return result

## Brief per-enemy hit flash fades each tick (ViewSync reads hit_flash > 0).
static func _decay_hit_flash(enemies: EnemyPool, delta: float) -> void:
	for i in EnemyPool.CAPACITY:
		if enemies.alive[i] and enemies.hit_flash[i] > 0.0:
			enemies.hit_flash[i] = maxf(0.0, enemies.hit_flash[i] - delta)

## Age the per-projectile re-hit cooldowns. Permanent entries (single-hit pierce)
## are stored as INF and never expire; re-tick weapons (auras) store their
## hit_cooldown and free the enemy back up when it runs out.
static func _decay_recent_hits(projectiles: ProjectilePool, delta: float) -> void:
	for p in ProjectilePool.CAPACITY:
		if not projectiles.alive[p]:
			continue
		var rh: Dictionary = projectiles.recent_hits[p]
		if rh.is_empty():
			continue
		var expired: Array = []
		for k in rh:
			rh[k] -= delta
			if rh[k] <= 0.0:
				expired.append(k)
		for k in expired:
			rh.erase(k)

static func _resolve_weapon_hits(state: RunState, _delta: float, result: CollisionResult, stats: StatBlock) -> void:
	var projectiles: ProjectilePool = state.projectiles
	var enemies: EnemyPool = state.enemies
	for p in ProjectilePool.CAPACITY:
		if not projectiles.alive[p]:
			continue
		var hit_radius := PROJECTILE_HIT_RADIUS * projectiles.area_scale[p]
		var candidates := SpatialIndex.query_circle(state.grid, enemies, projectiles.pos[p], hit_radius)
		for enemy_idx in candidates:
			# skip enemies still on this projectile's re-hit cooldown
			if projectiles.recent_hits[p].has(enemy_idx):
				continue
			var base_dmg := projectiles.damage[p] * stats.might
			var is_crit := projectiles.crit_chance[p] > 0.0 and state.rng != null \
				and state.rng.randf() < projectiles.crit_chance[p] * stats.luck
			var final_dmg := base_dmg * (projectiles.crit_mult[p] if is_crit else 1.0)
			enemies.hp[enemy_idx] -= final_dmg
			enemies.hit_flash[enemy_idx] = HIT_FLASH_TIME
			# knockback, unless fully resistant
			if enemies.knockback_resist[enemy_idx] < 1.0:
				var kb_dir := (enemies.pos[enemy_idx] - projectiles.pos[p]).normalized()
				if kb_dir == Vector2.ZERO:
					kb_dir = Vector2.RIGHT
				enemies.vel[enemy_idx] = kb_dir * KNOCKBACK_SPEED * (1.0 - enemies.knockback_resist[enemy_idx])
				enemies.knockback_timer[enemy_idx] = KNOCKBACK_TIME
			# record the hit: re-tick weapons use hit_cooldown, others stay hit (INF)
			var cd: float = projectiles.hit_cooldown[p] if projectiles.hit_cooldown[p] > 0.0 else INF
			projectiles.recent_hits[p][enemy_idx] = cd
			if enemies.hp[enemy_idx] <= 0.0:
				_on_enemy_death(state, enemy_idx, result)
			# only finite pierce despawns the projectile; -1 == infinite (AoE/aura)
			if projectiles.pierce_left[p] >= 0:
				projectiles.pierce_left[p] -= 1
				if projectiles.pierce_left[p] <= 0:
					projectiles.despawn(p)
					break

static func _on_enemy_death(state: RunState, idx: int, result: CollisionResult) -> void:
	var enemies: EnemyPool = state.enemies
	var pickups: PickupPool = state.pickups
	var xp := enemies.xp_value[idx]
	state.player.kills += 1
	# XP gem tier by value (matches GameDatabase: blue <=2, green <=9, red above)
	var tier := PickupPool.GemTier.BLUE
	if xp > GEM_GREEN_MAX:
		tier = PickupPool.GemTier.RED
	elif xp > GEM_BLUE_MAX:
		tier = PickupPool.GemTier.GREEN
	pickups.spawn(PickupPool.Kind.GEM, enemies.pos[idx], xp, tier)
	if enemies.is_boss[idx]:
		result.boss_deaths.push_back(idx)
	enemies.despawn(idx)

static func _resolve_contact_damage(state: RunState, stats: StatBlock) -> void:
	if state.player.iframe_timer > 0.0:
		return
	var enemies: EnemyPool = state.enemies
	var candidates := SpatialIndex.query_circle(state.grid, enemies, state.player.pos, PLAYER_RADIUS)
	for enemy_idx in candidates:
		var damage := maxf(1.0, enemies.power[enemy_idx] - stats.armor)
		state.player.hp -= damage
		state.player.iframe_timer = IFRAME_TIME
		break  # one hit per tick; i-frames gate the rest

static func _resolve_pickup_collection(state: RunState, stats: StatBlock, result: CollisionResult) -> void:
	var pickups: PickupPool = state.pickups
	var player_pos := state.player.pos
	var magnet_radius := stats.magnet
	for i in PickupPool.CAPACITY:
		if not pickups.alive[i]:
			continue
		var dist := player_pos.distance_to(pickups.pos[i])
		if dist <= magnet_radius:
			pickups.magnetized[i] = true
		if dist <= COLLECT_RADIUS:
			match pickups.kind[i]:
				PickupPool.Kind.GEM:
					result.xp_gained += pickups.value[i]
				PickupPool.Kind.CHEST:
					result.collected_chests.push_back(pickups.value[i])
				_:
					result.collected_effects.push_back({ kind = pickups.kind[i], value = pickups.value[i] })
			pickups.despawn(i)
