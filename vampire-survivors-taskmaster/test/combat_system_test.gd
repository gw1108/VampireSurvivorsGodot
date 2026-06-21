extends GdUnitTestSuite

## Tests CombatSystem: projectile movement, hit detection via the spatial index,
## Might/crit damage, pierce, hit-dedup across frames, knockback (and boss
## immunity), AoE zones (single-hit + periodic + player-follow), and enemy-death
## gem spawns (with double-kill dedup).

func _enemy(pos: Vector2, hp: float, resist := 0.0, xp := 1.0) -> Enemy:
	var e := Enemy.new()
	e.pos = pos
	e.hp = hp
	var d := EnemyDef.new()
	d.knockback_resist = resist
	d.xp_value = xp
	e.def = d
	return e


func _proj(pos: Vector2, damage: float, pierce := 1, vel := Vector2.ZERO) -> Projectile:
	var p := Projectile.new()
	p.pos = pos
	p.damage = damage
	p.pierce_left = pierce
	p.velocity = vel
	p.lifetime = 5.0
	return p


func _zone(pos: Vector2, damage: float, radius := 50.0, tick_interval := 0.0) -> DamageZone:
	var z := DamageZone.new()
	z.anchor = DamageZone.Anchor.WORLD
	z.pos = pos
	z.damage = damage
	z.radius = radius
	z.tick_interval = tick_interval
	z.lifetime = 5.0
	return z


func _rebuild(state: GameState) -> void:
	state.index = SpatialIndex.new()
	SpatialIndex.rebuild(state.index, state.enemies, state.gems, state.pickups)


# --- projectile movement / lifetime ---

func test_projectile_moves_by_velocity() -> void:
	var gs := GameState.new()
	gs.projectiles = [_proj(Vector2.ZERO, 10.0, 1, Vector2(100.0, 0.0))]
	_rebuild(gs)
	CombatSystem.step(gs, 0.1)
	assert_vector(gs.projectiles[0].pos).is_equal(Vector2(10.0, 0.0))


func test_projectile_expires_and_is_removed() -> void:
	var gs := GameState.new()
	var p := _proj(Vector2.ZERO, 10.0)
	p.lifetime = 0.05
	gs.projectiles = [p]
	_rebuild(gs)
	CombatSystem.step(gs, 0.1)
	assert_int(gs.projectiles.size()).is_equal(0)


# --- hit detection / damage ---

func test_projectile_hits_enemy_applies_damage() -> void:
	var gs := GameState.new()
	gs.enemies = [_enemy(Vector2(10.0, 0.0), 100.0)]
	gs.projectiles = [_proj(Vector2(10.0, 0.0), 10.0)]
	_rebuild(gs)
	CombatSystem.step(gs, 0.016)
	assert_float(gs.enemies[0].hp).is_equal(90.0)
	assert_int(gs.projectiles.size()).is_equal(0)  # pierce 1 exhausted


func test_might_scales_damage() -> void:
	var gs := GameState.new()
	gs.player.derived.might = 2.0
	gs.enemies = [_enemy(Vector2.ZERO, 100.0)]
	gs.projectiles = [_proj(Vector2.ZERO, 10.0)]
	_rebuild(gs)
	CombatSystem.step(gs, 0.016)
	assert_float(gs.enemies[0].hp).is_equal(80.0)


func test_guaranteed_crit_multiplies_damage() -> void:
	var gs := GameState.new()
	gs.enemies = [_enemy(Vector2.ZERO, 100.0)]
	var p := _proj(Vector2.ZERO, 10.0)
	p.crit_chance = 1.0
	p.crit_mult = 2.0
	gs.projectiles = [p]
	_rebuild(gs)
	CombatSystem.step(gs, 0.016)
	assert_float(gs.enemies[0].hp).is_equal(80.0)


# --- pierce ---

func test_pierce_hits_multiple_enemies() -> void:
	var gs := GameState.new()
	gs.enemies = [_enemy(Vector2(10.0, 0.0), 100.0), _enemy(Vector2(10.0, 5.0), 100.0)]
	gs.projectiles = [_proj(Vector2(10.0, 0.0), 10.0, 2)]
	_rebuild(gs)
	CombatSystem.step(gs, 0.016)
	assert_float(gs.enemies[0].hp).is_equal(90.0)
	assert_float(gs.enemies[1].hp).is_equal(90.0)
	assert_int(gs.projectiles.size()).is_equal(0)  # pierce 2 fully consumed


func test_pierce_limit_caps_hits() -> void:
	var gs := GameState.new()
	gs.enemies = [
		_enemy(Vector2(10.0, 0.0), 100.0),
		_enemy(Vector2(10.0, 4.0), 100.0),
		_enemy(Vector2(10.0, 8.0), 100.0),
	]
	gs.projectiles = [_proj(Vector2(10.0, 0.0), 10.0, 1)]  # pierce 1 -> only one hit
	_rebuild(gs)
	CombatSystem.step(gs, 0.016)
	var hit_count := 0
	for e in gs.enemies:
		if e.hp < 100.0:
			hit_count += 1
	assert_int(hit_count).is_equal(1)
	assert_int(gs.projectiles.size()).is_equal(0)


func test_hit_ids_prevent_rehit_across_frames() -> void:
	var gs := GameState.new()
	gs.enemies = [_enemy(Vector2.ZERO, 100.0)]
	gs.projectiles = [_proj(Vector2.ZERO, 10.0, 5)]  # pierce 5, stays put
	_rebuild(gs)
	CombatSystem.step(gs, 0.016)
	_rebuild(gs)
	CombatSystem.step(gs, 0.016)
	assert_float(gs.enemies[0].hp).is_equal(90.0)  # hit once, not twice
	assert_int(gs.projectiles[0].hit_ids.size()).is_equal(1)


# --- knockback ---

func test_knockback_applied_away_from_source() -> void:
	var gs := GameState.new()
	gs.enemies = [_enemy(Vector2(10.0, 0.0), 100.0)]
	gs.projectiles = [_proj(Vector2.ZERO, 1.0)]  # source left of enemy
	_rebuild(gs)
	CombatSystem.step(gs, 0.016)
	assert_vector(gs.enemies[0].knockback).is_equal(Vector2(CombatMath.BASE_KNOCKBACK_FORCE, 0.0))
	assert_float(gs.enemies[0].knockback_timer).is_equal(CombatMath.KNOCKBACK_DURATION)


func test_boss_is_knockback_immune_but_takes_damage() -> void:
	var gs := GameState.new()
	gs.enemies = [_enemy(Vector2(10.0, 0.0), 100.0, 1.0)]  # resist 1.0
	gs.projectiles = [_proj(Vector2.ZERO, 10.0)]
	_rebuild(gs)
	CombatSystem.step(gs, 0.016)
	assert_vector(gs.enemies[0].knockback).is_equal(Vector2.ZERO)
	assert_float(gs.enemies[0].knockback_timer).is_equal(0.0)
	assert_float(gs.enemies[0].hp).is_equal(90.0)


# --- enemy death ---

func test_enemy_death_spawns_gem_and_counts_kill() -> void:
	var gs := GameState.new()
	gs.enemies = [_enemy(Vector2(3.0, 4.0), 5.0, 0.0, 2.0)]
	gs.projectiles = [_proj(Vector2(3.0, 4.0), 10.0)]
	_rebuild(gs)
	CombatSystem.step(gs, 0.016)
	assert_int(gs.enemies.size()).is_equal(0)  # reaped
	assert_int(gs.kills).is_equal(1)
	assert_int(gs.gems.size()).is_equal(1)
	assert_float(gs.gems[0].xp).is_equal(2.0)
	assert_vector(gs.gems[0].pos).is_equal(Vector2(3.0, 4.0))


func test_high_xp_death_drops_red_gem() -> void:
	var gs := GameState.new()
	gs.enemies = [_enemy(Vector2.ZERO, 5.0, 0.0, 25.0)]  # boss-tier xp
	gs.projectiles = [_proj(Vector2.ZERO, 10.0)]
	_rebuild(gs)
	CombatSystem.step(gs, 0.016)
	assert_int(gs.gems[0].tier).is_equal(Gem.Tier.RED)


func test_double_kill_same_frame_dedups_to_one_gem() -> void:
	var gs := GameState.new()
	gs.enemies = [_enemy(Vector2.ZERO, 5.0)]
	# Two projectiles both over the same low-hp enemy in one step.
	gs.projectiles = [_proj(Vector2.ZERO, 10.0), _proj(Vector2.ZERO, 10.0)]
	_rebuild(gs)
	CombatSystem.step(gs, 0.016)
	assert_int(gs.kills).is_equal(1)
	assert_int(gs.gems.size()).is_equal(1)
	assert_int(gs.enemies.size()).is_equal(0)


# --- zones ---

func test_zone_damages_enemy_once_over_lifetime() -> void:
	var gs := GameState.new()
	gs.enemies = [_enemy(Vector2(20.0, 0.0), 100.0)]
	gs.zones = [_zone(Vector2.ZERO, 10.0, 50.0, 0.0)]  # single-hit
	_rebuild(gs)
	CombatSystem.step(gs, 0.016)
	assert_float(gs.enemies[0].hp).is_equal(90.0)
	# Second tick within the zone's lifetime must not re-hit (hit_ids).
	_rebuild(gs)
	CombatSystem.step(gs, 0.016)
	assert_float(gs.enemies[0].hp).is_equal(90.0)


func test_zone_outside_radius_misses() -> void:
	var gs := GameState.new()
	gs.enemies = [_enemy(Vector2(100.0, 0.0), 100.0)]
	gs.zones = [_zone(Vector2.ZERO, 10.0, 50.0, 0.0)]
	_rebuild(gs)
	CombatSystem.step(gs, 0.016)
	assert_float(gs.enemies[0].hp).is_equal(100.0)


func test_follow_player_zone_tracks_player() -> void:
	var gs := GameState.new()
	gs.player.pos = Vector2(100.0, 0.0)
	var z := _zone(Vector2.ZERO, 10.0, 50.0, 0.0)
	z.anchor = DamageZone.Anchor.FOLLOW_PLAYER
	z.offset = Vector2(40.0, 0.0)
	gs.zones = [z]
	gs.enemies = [_enemy(Vector2(140.0, 0.0), 100.0)]  # at player.pos + offset
	_rebuild(gs)
	CombatSystem.step(gs, 0.016)
	assert_vector(gs.zones[0].pos).is_equal(Vector2(140.0, 0.0))
	assert_float(gs.enemies[0].hp).is_equal(90.0)


func test_periodic_zone_rehits_after_interval() -> void:
	var gs := GameState.new()
	gs.enemies = [_enemy(Vector2.ZERO, 100.0)]
	gs.zones = [_zone(Vector2.ZERO, 10.0, 50.0, 0.5)]  # damage every 0.5s
	_rebuild(gs)
	CombatSystem.step(gs, 0.1)  # tick_timer 0 -> fires
	assert_float(gs.enemies[0].hp).is_equal(90.0)
	_rebuild(gs)
	CombatSystem.step(gs, 0.1)  # 0.4 left, no fire
	assert_float(gs.enemies[0].hp).is_equal(90.0)
	_rebuild(gs)
	CombatSystem.step(gs, 0.5)  # crosses interval -> fires again
	assert_float(gs.enemies[0].hp).is_equal(80.0)


func test_zone_expires_and_is_removed() -> void:
	var gs := GameState.new()
	var z := _zone(Vector2.ZERO, 10.0)
	z.lifetime = 0.05
	gs.zones = [z]
	gs.enemies = [_enemy(Vector2.ZERO, 100.0)]
	_rebuild(gs)
	CombatSystem.step(gs, 0.1)
	assert_int(gs.zones.size()).is_equal(0)
	assert_float(gs.enemies[0].hp).is_equal(100.0)  # expired before dealing damage


# --- safety ---

func test_step_without_index_does_not_hit() -> void:
	var gs := GameState.new()
	gs.enemies = [_enemy(Vector2.ZERO, 100.0)]
	gs.projectiles = [_proj(Vector2.ZERO, 10.0, 1, Vector2(50.0, 0.0))]
	gs.index = null
	CombatSystem.step(gs, 0.1)
	assert_float(gs.enemies[0].hp).is_equal(100.0)  # no broadphase -> no hits
	assert_vector(gs.projectiles[0].pos).is_equal(Vector2(5.0, 0.0))  # still moved
