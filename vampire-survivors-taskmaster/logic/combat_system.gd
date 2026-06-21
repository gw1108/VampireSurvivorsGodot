class_name CombatSystem extends RefCounted

## Resolves weapon emissions against enemies each tick: moves projectiles, ticks
## AoE zones, applies Might-scaled + crit damage (CombatMath), knocks back
## non-immune enemies, and on death spawns an XP gem and bumps kills. Pure.
## Reads state.index for broadphase (the caller rebuilds it before this runs).
##
## Corrections / additions vs the task sketch (kept consistent with this codebase):
##  - query_radius returns *combined* indices (enemies+gems+pickups); we filter to
##    Type.ENEMY and map back via get_entity_local_id. The sketch indexed
##    state.enemies directly with a combined index — that reads the wrong slot.
##  - hit-dedup keys on enemy.get_instance_id() (stable, unique per object), NOT the
##    array index: swap-remove reshuffles indices, so an index-keyed hit_ids would
##    skip/re-hit the wrong enemy across the frames a piercing shot lives.
##  - enemies are NOT removed mid-step (that invalidates the shared index for the
##    rest of this tick); deaths are deduped via a set and reaped once at the end.
##  - magic numbers 100.0 / 0.1 use CombatMath.BASE_KNOCKBACK_FORCE / KNOCKBACK_DURATION.
##  - _step_zones (omitted in the sketch) resolves AoE: FOLLOW_PLAYER zones track the
##    player each tick; single-hit zones (tick_interval 0, e.g. Whip) hit each enemy
##    once over their lifetime via hit_ids; periodic zones clear hit_ids per tick.

const PROJECTILE_HIT_RADIUS: float = 16.0


static func step(state: GameState, dt: float) -> void:
	var dead: Dictionary = {}  # enemy ref -> true; deduped deaths, reaped at end
	_step_projectiles(state, dt, dead)
	_step_zones(state, dt, dead)
	_reap_dead(state, dead)


const BOOMERANG_CATCH_RADIUS: float = 12.0  # a returning Cross is caught this close to the player


static func _step_projectiles(state: GameState, dt: float, dead: Dictionary) -> void:
	var player_pos: Vector2 = state.player.pos
	var to_remove: Array[int] = []
	for i in state.projectiles.size():
		var proj = state.projectiles[i]
		proj.lifetime -= dt
		if proj.lifetime <= 0.0:
			to_remove.append(i)
			continue
		# Acceleration (Axe's gravity arc); ZERO for straight-line shots.
		if proj.accel != Vector2.ZERO:
			proj.velocity += proj.accel * dt
		# Boomerang (Cross): fly out to boomerang_range, then home back to the player
		# and despawn when caught.
		if proj.is_boomerang:
			if not proj.is_returning and proj.pos.distance_to(player_pos) >= proj.boomerang_range:
				proj.is_returning = true
			if proj.is_returning:
				var to_player: Vector2 = player_pos - proj.pos
				if to_player.length_squared() > 0.0:
					proj.velocity = to_player.normalized() * proj.velocity.length()
				if proj.pos.distance_to(player_pos) <= BOOMERANG_CATCH_RADIUS:
					to_remove.append(i)
					continue
		proj.pos += proj.velocity * dt
		if state.index == null:
			continue
		var nearby := SpatialIndex.query_radius(state.index, proj.pos, PROJECTILE_HIT_RADIUS)
		for entry in nearby:
			if SpatialIndex.get_entity_type(state.index, entry) != SpatialIndex.Type.ENEMY:
				continue
			var enemy = state.enemies[SpatialIndex.get_entity_local_id(state.index, entry)]
			if dead.has(enemy):
				continue
			var eid: int = enemy.get_instance_id()  # explicit: enemy is Variant (untyped array)
			if eid in proj.hit_ids:
				continue  # already hit this enemy with this projectile
			_damage_enemy(state, enemy, proj.damage, proj.crit_chance, proj.crit_mult, proj.pos, dead, proj.source_weapon)
			proj.hit_ids.append(eid)
			proj.pierce_left -= 1
			if proj.pierce_left <= 0:
				to_remove.append(i)
				break
	_remove_indices(state.projectiles, to_remove)


static func _step_zones(state: GameState, dt: float, dead: Dictionary) -> void:
	var player: PlayerState = state.player
	var to_remove: Array[int] = []
	for i in state.zones.size():
		var zone = state.zones[i]
		zone.lifetime -= dt
		if zone.lifetime <= 0.0:
			to_remove.append(i)
			continue
		if zone.anchor == DamageZone.Anchor.FOLLOW_PLAYER:
			zone.pos = player.pos + zone.offset
		elif zone.anchor == DamageZone.Anchor.ORBIT:
			# King Bible: spin the offset around the player, then follow it.
			zone.offset = zone.offset.rotated(zone.orbit_speed * dt)
			zone.pos = player.pos + zone.offset
		# Decide whether this zone deals damage this tick.
		var do_tick := false
		if zone.tick_interval <= 0.0:
			do_tick = true  # continuous; hit_ids prevents repeats over the lifetime
		else:
			zone.tick_timer -= dt
			if zone.tick_timer <= 0.0:
				zone.tick_timer += zone.tick_interval
				zone.hit_ids.clear()  # a fresh damage tick may re-hit everyone
				do_tick = true
		if not do_tick or state.index == null:
			continue
		var nearby := SpatialIndex.query_radius(state.index, zone.pos, zone.radius)
		for entry in nearby:
			if SpatialIndex.get_entity_type(state.index, entry) != SpatialIndex.Type.ENEMY:
				continue
			var enemy = state.enemies[SpatialIndex.get_entity_local_id(state.index, entry)]
			if dead.has(enemy):
				continue
			var eid: int = enemy.get_instance_id()  # explicit: enemy is Variant (untyped array)
			if eid in zone.hit_ids:
				continue
			_damage_enemy(state, enemy, zone.damage, 0.0, 1.0, zone.pos, dead, zone.source_weapon)
			zone.hit_ids.append(eid)
	_remove_indices(state.zones, to_remove)


## Apply one hit to an enemy: Might-scaled + crit damage, knockback, and death.
## Credits the final damage to source_weapon.damage_dealt (results-screen DPS table).
static func _damage_enemy(state: GameState, enemy, base_damage: float, crit_chance: float, crit_mult: float, source_pos: Vector2, dead: Dictionary, source_weapon = null) -> void:
	var damage := CombatMath.calc_damage(base_damage, state.player.derived.might)
	var crit := CombatMath.roll_crit(state.rng, crit_chance, crit_mult)
	damage *= float(crit["multiplier"])
	enemy.hp -= damage
	if source_weapon != null:
		source_weapon.damage_dealt += damage

	var resist: float = enemy.def.knockback_resist if enemy.def != null else 0.0
	var kb := CombatMath.calc_knockback(source_pos, enemy.pos, CombatMath.BASE_KNOCKBACK_FORCE, resist)
	if kb.length_squared() > 0.0:
		enemy.knockback = kb
		enemy.knockback_timer = CombatMath.KNOCKBACK_DURATION

	if enemy.hp <= 0.0 and not dead.has(enemy):
		dead[enemy] = true  # dedup: another hit this frame must not re-kill it
		_on_enemy_death(state, enemy)


static func _on_enemy_death(state: GameState, enemy) -> void:
	state.kills += 1
	var gem := Gem.new()
	gem.pos = enemy.pos
	gem.xp = enemy.def.xp_value if enemy.def != null else 1.0
	gem.tier = _gem_tier_for_xp(gem.xp)
	state.gems.append(gem)
	# Pickup (chicken/coin) drops come from braziers, not normal kills, so none here.


## Bracket the dropped gem's color by XP value. Thresholds are placeholder/cosmetic.
static func _gem_tier_for_xp(xp: float) -> int:
	if xp < 2.0:
		return Gem.Tier.BLUE
	if xp < 25.0:
		return Gem.Tier.GREEN
	return Gem.Tier.RED


## Swap-remove all enemies flagged dead, high index -> low so indices stay valid.
static func _reap_dead(state: GameState, dead: Dictionary) -> void:
	if dead.is_empty():
		return
	for i in range(state.enemies.size() - 1, -1, -1):
		if dead.has(state.enemies[i]):
			state.enemies[i] = state.enemies[state.enemies.size() - 1]
			state.enemies.pop_back()


## Swap-remove a set of ascending indices (processed high->low to stay valid).
static func _remove_indices(arr: Array, indices: Array) -> void:
	for j in range(indices.size() - 1, -1, -1):
		var idx: int = indices[j]
		arr[idx] = arr[arr.size() - 1]
		arr.pop_back()
