class_name MovementSystem extends RefCounted

## Pure kinematics integration for one tick: player, enemies (AI + freeze +
## knockback + separation), projectiles (per behavior + lifetime), and
## magnetized pickups. Frame-rate independent — all motion is delta-scaled.
## No scene dependency.
##
## Convention: `player.vel` holds the 8-dir move INTENT (a unit direction or
## zero) written by PlayerShell; the actual displacement is
## normalized(intent) * PLAYER_BASE_SPEED * move_speed. Enemy `vel` is the real
## velocity used for knockback slide and FIXED-direction heading.

const PLAYER_BASE_SPEED := 200.0        # px/s before the move_speed multiplier
const MAGNET_SPEED := 400.0             # px/s pull on magnetized pickups
const SEPARATION_RADIUS := 12.0         # enemies closer than this push apart
const ORBIT_ANGULAR_SPEED := TAU / 3.0  # rad/s for ORBIT projectiles
const HOMING_SEARCH_RADIUS := 300.0     # how far a HOMING projectile looks for a target

static func step(state: RunState, delta: float) -> void:
	_move_player(state, delta)
	_move_enemies(state, delta)
	_apply_separation(state, delta)
	_move_projectiles(state, delta)
	_move_pickups(state, delta)

static func _move_player(state: RunState, delta: float) -> void:
	var player: PlayerState = state.player
	var move_mult := 1.0
	if player.stats != null:
		move_mult = player.stats.move_speed
	var intent := player.vel
	if intent.length_squared() > 0.0001:
		var dir := intent.normalized()
		player.pos += dir * (PLAYER_BASE_SPEED * move_mult) * delta
		player.facing = dir
	player.iframe_timer = maxf(0.0, player.iframe_timer - delta)

static func _move_enemies(state: RunState, delta: float) -> void:
	var enemies: EnemyPool = state.enemies
	var player_pos: Vector2 = state.player.pos
	var frozen := state.freeze_timer > 0.0
	for i in EnemyPool.CAPACITY:
		if not enemies.alive[i]:
			continue
		# knockback overrides AI: decay timer and slide along the knockback velocity
		if enemies.knockback_timer[i] > 0.0:
			enemies.knockback_timer[i] = maxf(0.0, enemies.knockback_timer[i] - delta)
			enemies.pos[i] += enemies.vel[i] * delta
			continue
		if frozen:
			continue
		var dir := Vector2.ZERO
		match enemies.ai_kind[i]:
			EnemyPool.Ai.HOMING:
				dir = (player_pos - enemies.pos[i]).normalized()
			EnemyPool.Ai.FIXED:
				dir = enemies.vel[i].normalized()
			EnemyPool.Ai.WAVY:
				dir = (player_pos - enemies.pos[i]).normalized().rotated(sin(state.elapsed * 3.0) * 0.5)
			EnemyPool.Ai.NONE:
				dir = Vector2.ZERO
		enemies.vel[i] = dir * enemies.move_speed[i]
		enemies.pos[i] += enemies.vel[i] * delta

## Gentle two-phase separation so dense swarms spread instead of stacking. Phase
## one reads original positions for every push (order-independent / symmetric);
## phase two applies them, each bounded by the enemy's per-tick travel distance.
## Uses the spatial grid (rebuilt earlier in the tick); skipped if absent.
static func _apply_separation(state: RunState, delta: float) -> void:
	var enemies: EnemyPool = state.enemies
	var grid = state.grid
	if grid == null:
		return
	var pushes := PackedVector2Array()
	pushes.resize(EnemyPool.CAPACITY)
	for i in EnemyPool.CAPACITY:
		if not enemies.alive[i] or enemies.knockback_timer[i] > 0.0:
			continue
		var push := Vector2.ZERO
		var neighbors := SpatialIndex.query_circle(grid, enemies, enemies.pos[i], SEPARATION_RADIUS)
		for j in neighbors:
			if j == i:
				continue
			var off: Vector2 = enemies.pos[i] - enemies.pos[j]
			var d := off.length()
			if d > 0.001 and d < SEPARATION_RADIUS:
				push += (off / d) * (SEPARATION_RADIUS - d)
		pushes[i] = push
	for i in EnemyPool.CAPACITY:
		if not enemies.alive[i] or pushes[i] == Vector2.ZERO:
			continue
		enemies.pos[i] += pushes[i].limit_length(enemies.move_speed[i] * delta)

static func _move_projectiles(state: RunState, delta: float) -> void:
	var proj: ProjectilePool = state.projectiles
	var player_pos: Vector2 = state.player.pos
	for i in ProjectilePool.CAPACITY:
		if not proj.alive[i]:
			continue
		match proj.behavior[i]:
			ProjectilePool.Behavior.STRAIGHT:
				proj.pos[i] += proj.vel[i] * delta
			ProjectilePool.Behavior.HOMING:
				_home(state, i)
				proj.pos[i] += proj.vel[i] * delta
			ProjectilePool.Behavior.BOUNCE:
				proj.pos[i] += proj.vel[i] * delta
				_bounce(proj, state.camera_world_rect, i)
			ProjectilePool.Behavior.ORBIT:
				_orbit(proj, i, player_pos, delta)
			ProjectilePool.Behavior.AURA:
				proj.pos[i] = player_pos
		# lifetime > 0 means time-limited; lifetime <= 0 means "no time limit"
		# (despawn handled by pierce / CollisionSystem) so it is left untouched.
		if proj.lifetime[i] > 0.0:
			proj.lifetime[i] -= delta
			if proj.lifetime[i] <= 0.0:
				proj.despawn(i)

## Reflect a projectile off the camera world rect edges (Runetracer bounce).
static func _bounce(proj: ProjectilePool, rect: Rect2, i: int) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var p: Vector2 = proj.pos[i]
	var v: Vector2 = proj.vel[i]
	if p.x < rect.position.x:
		p.x = rect.position.x
		v.x = absf(v.x)
	elif p.x > rect.end.x:
		p.x = rect.end.x
		v.x = -absf(v.x)
	if p.y < rect.position.y:
		p.y = rect.position.y
		v.y = absf(v.y)
	elif p.y > rect.end.y:
		p.y = rect.end.y
		v.y = -absf(v.y)
	proj.pos[i] = p
	proj.vel[i] = v

## Advance an ORBIT projectile around the player, preserving its current radius.
static func _orbit(proj: ProjectilePool, i: int, player_pos: Vector2, delta: float) -> void:
	var rel: Vector2 = proj.pos[i] - player_pos
	var radius := rel.length()
	if radius < 0.001:
		return
	var angle := rel.angle() + ORBIT_ANGULAR_SPEED * delta
	proj.pos[i] = player_pos + Vector2.from_angle(angle) * radius

## Steer a HOMING projectile toward the nearest enemy (keeping its speed). Needs
## the spatial grid; without it (or with no target in range) it flies straight.
static func _home(state: RunState, i: int) -> void:
	var proj: ProjectilePool = state.projectiles
	var grid = state.grid
	if grid == null:
		return
	var enemies: EnemyPool = state.enemies
	var speed := proj.vel[i].length()
	if speed < 0.001:
		return
	var cand := SpatialIndex.query_circle(grid, enemies, proj.pos[i], HOMING_SEARCH_RADIUS)
	var target_idx := -1
	var best := INF
	for j in cand:
		var d := proj.pos[i].distance_squared_to(enemies.pos[j])
		if d < best:
			best = d
			target_idx = j
	if target_idx >= 0:
		proj.vel[i] = (enemies.pos[target_idx] - proj.pos[i]).normalized() * speed

static func _move_pickups(state: RunState, delta: float) -> void:
	var pickups: PickupPool = state.pickups
	var player_pos: Vector2 = state.player.pos
	for i in PickupPool.CAPACITY:
		if not pickups.alive[i]:
			continue
		if pickups.magnetized[i]:
			var to_player: Vector2 = player_pos - pickups.pos[i]
			var dist := to_player.length()
			if dist > 0.001:
				var travel := MAGNET_SPEED * delta
				if travel >= dist:
					pickups.pos[i] = player_pos  # arrived; don't overshoot
				else:
					pickups.pos[i] += (to_player / dist) * travel
