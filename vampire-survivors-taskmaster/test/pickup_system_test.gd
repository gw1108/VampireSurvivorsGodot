extends GdUnitTestSuite

## Tests PickupSystem: magnet behavior, collection, XP routing, pickup effects,
## chest collection, and the 400-gem cap merge.

func _gem(pos: Vector2, xp: float, tier := Gem.Tier.BLUE) -> Gem:
	var g := Gem.new()
	g.pos = pos
	g.xp = xp
	g.tier = tier
	return g


func _pickup(pos: Vector2, type: int, value := 0.0) -> Pickup:
	var p := Pickup.new()
	p.pos = pos
	p.type = type
	p.value = value
	return p


func _enemy(pos: Vector2, is_boss := false) -> Enemy:
	var e := Enemy.new()
	e.pos = pos
	e.hp = 1.0
	e.is_boss = is_boss
	return e


# --- gems: magnet + collection ---

func test_gem_within_magnet_homes_toward_player() -> void:
	var gs := GameState.new()  # player at origin, magnet 64
	gs.gems = [_gem(Vector2(50, 0), 1.0)]
	PickupSystem.step(gs, 0.1)
	# Moved MAGNET_SPEED(300)*0.1 = 30 toward origin.
	assert_vector(gs.gems[0].pos).is_equal_approx(Vector2(20, 0), Vector2(0.01, 0.01))


func test_gem_outside_magnet_does_not_move() -> void:
	var gs := GameState.new()
	gs.gems = [_gem(Vector2(100, 0), 1.0)]  # > magnet 64
	PickupSystem.step(gs, 0.1)
	assert_vector(gs.gems[0].pos).is_equal(Vector2(100, 0))


func test_gem_collected_within_radius() -> void:
	var gs := GameState.new()
	gs.gems = [_gem(Vector2(10, 0), 3.0)]  # within COLLECTION_RADIUS 16
	PickupSystem.step(gs, 0.1)
	assert_int(gs.gems.size()).is_equal(0)  # removed
	assert_float(gs.player.xp).is_equal(3.0)  # routed to progression


func test_gem_xp_scaled_by_growth() -> void:
	var gs := GameState.new()
	gs.player.derived.growth = 2.0
	gs.gems = [_gem(Vector2(5, 0), 2.0)]
	PickupSystem.step(gs, 0.1)
	assert_float(gs.player.xp).is_equal(4.0)  # 2 xp * 2 growth


func test_collecting_gem_can_trigger_level_up() -> void:
	var gs := GameState.new()  # xp_to_next 5
	gs.gems = [_gem(Vector2(0, 0), 5.0)]
	PickupSystem.step(gs, 0.1)
	assert_int(gs.player.level).is_equal(2)
	assert_int(gs.pending_levelups).is_equal(1)


func test_multiple_gems_mixed() -> void:
	var gs := GameState.new()
	gs.gems = [_gem(Vector2(0, 0), 1.0), _gem(Vector2(50, 0), 1.0), _gem(Vector2(200, 0), 1.0)]
	PickupSystem.step(gs, 0.1)
	# One collected (at origin), one magnetized (still present), one untouched.
	assert_int(gs.gems.size()).is_equal(2)
	assert_float(gs.player.xp).is_equal(1.0)


# --- pickups ---

func test_pickup_chicken_heals_clamped() -> void:
	var gs := GameState.new()
	gs.player.hp = 90.0  # derived.max_health defaults to 100
	gs.pickups = [_pickup(Vector2(0, 0), Pickup.Type.CHICKEN, 30.0)]
	PickupSystem.step(gs, 0.1)
	assert_float(gs.player.hp).is_equal(100.0)  # clamped to max
	assert_int(gs.pickups.size()).is_equal(0)


func test_pickup_coin_adds_gold_with_greed() -> void:
	var gs := GameState.new()
	gs.player.derived.greed = 2.0
	gs.pickups = [_pickup(Vector2(0, 0), Pickup.Type.COIN, 10.0)]
	PickupSystem.step(gs, 0.1)
	assert_int(gs.gold).is_equal(20)  # 10 * 2 greed


func test_pickup_vacuum_collects_all_gems() -> void:
	var gs := GameState.new()
	# Total 3 XP stays under the level-1 threshold (5), so xp is observable.
	gs.gems = [_gem(Vector2(500, 0), 1.0), _gem(Vector2(-500, 0), 2.0)]  # far away
	gs.pickups = [_pickup(Vector2(0, 0), Pickup.Type.VACUUM)]
	PickupSystem.step(gs, 0.1)
	assert_int(gs.gems.size()).is_equal(0)
	assert_float(gs.player.xp).is_equal(3.0)  # 1 + 2, all collected


# --- special pickups: board effects ---

func test_pickup_rosary_kills_non_boss_enemies() -> void:
	var gs := GameState.new()
	gs.index = SpatialIndex.new()
	gs.enemies = [_enemy(Vector2(100, 0)), _enemy(Vector2(50, 0), true)]  # 1 normal, 1 boss
	SpatialIndex.rebuild(gs.index, gs.enemies, gs.gems, gs.pickups)
	gs.pickups = [_pickup(Vector2(0, 0), Pickup.Type.ROSARY)]
	PickupSystem.step(gs, 0.1)
	assert_int(gs.enemies.size()).is_equal(1)        # only the boss remains
	assert_bool(gs.enemies[0].is_boss).is_true()
	assert_int(gs.kills).is_equal(1)                 # the non-boss was credited
	assert_int(gs.gems.size()).is_equal(1)           # and dropped its XP gem


func test_pickup_rosary_no_enemies_is_safe() -> void:
	var gs := GameState.new()
	gs.pickups = [_pickup(Vector2(0, 0), Pickup.Type.ROSARY)]
	PickupSystem.step(gs, 0.1)
	assert_int(gs.enemies.size()).is_equal(0)
	assert_int(gs.kills).is_equal(0)


func test_pickup_orologion_freezes_all_enemies() -> void:
	var gs := GameState.new()
	gs.enemies = [_enemy(Vector2(100, 0)), _enemy(Vector2(-100, 0), true)]
	gs.pickups = [_pickup(Vector2(0, 0), Pickup.Type.OROLOGION)]
	PickupSystem.step(gs, 0.1)
	for e in gs.enemies:
		assert_float(e.freeze_timer).is_equal(PickupSystem.OROLOGION_FREEZE_DURATION)
	assert_int(gs.pickups.size()).is_equal(0)


# --- special pickups: timed stat buffs ---

func test_pickup_nduja_buffs_might() -> void:
	var gs := GameState.new()
	StatSystem.resolve(gs.player)
	var base_might: float = gs.player.derived.might
	gs.pickups = [_pickup(Vector2(0, 0), Pickup.Type.NDUJA)]
	PickupSystem.step(gs, 0.1)
	assert_int(gs.player.buffs.size()).is_equal(1)
	StatSystem.resolve(gs.player)  # re-resolve with the buff active
	assert_float(gs.player.derived.might).is_equal(base_might * PickupSystem.NDUJA_MIGHT_MULT)


func test_pickup_clover_buffs_luck() -> void:
	var gs := GameState.new()
	StatSystem.resolve(gs.player)
	var base_luck: float = gs.player.derived.luck
	gs.pickups = [_pickup(Vector2(0, 0), Pickup.Type.CLOVER)]
	PickupSystem.step(gs, 0.1)
	StatSystem.resolve(gs.player)
	assert_float(gs.player.derived.luck).is_equal(base_luck * PickupSystem.CLOVER_LUCK_MULT)


func test_pickup_sorbetto_buffs_move_speed() -> void:
	var gs := GameState.new()
	StatSystem.resolve(gs.player)
	var base_speed: float = gs.player.derived.move_speed
	gs.pickups = [_pickup(Vector2(0, 0), Pickup.Type.SORBETTO)]
	PickupSystem.step(gs, 0.1)
	StatSystem.resolve(gs.player)
	assert_float(gs.player.derived.move_speed).is_equal(base_speed * PickupSystem.SORBETTO_SPEED_MULT)


func test_temp_buff_expires_after_duration() -> void:
	var gs := GameState.new()
	StatSystem.resolve(gs.player)
	var base_might: float = gs.player.derived.might
	gs.pickups = [_pickup(Vector2(0, 0), Pickup.Type.NDUJA)]
	PickupSystem.step(gs, 0.1)  # collect -> buff added (full duration)
	# Tick past the buff duration; the empty pickup list makes this a pure buff tick.
	PickupSystem.step(gs, PickupSystem.TEMP_BUFF_DURATION + 1.0)
	assert_int(gs.player.buffs.size()).is_equal(0)
	StatSystem.resolve(gs.player)
	assert_float(gs.player.derived.might).is_equal(base_might)


func test_temp_buff_recollect_refreshes_not_stacks() -> void:
	var gs := GameState.new()
	gs.pickups = [_pickup(Vector2(0, 0), Pickup.Type.NDUJA)]
	PickupSystem.step(gs, 0.1)
	gs.pickups = [_pickup(Vector2(0, 0), Pickup.Type.NDUJA)]  # collect a second one
	PickupSystem.step(gs, 0.1)
	assert_int(gs.player.buffs.size()).is_equal(1)  # refreshed, not stacked


# --- chests ---

func test_chest_collected_increments_count() -> void:
	var gs := GameState.new()
	var c := Chest.new()
	c.pos = Vector2(0, 0)
	gs.chests = [c]
	PickupSystem.step(gs, 0.1)
	assert_int(gs.chest_count).is_equal(1)
	assert_int(gs.chests.size()).is_equal(0)


# --- gem cap ---

func test_gem_cap_merges_excess_into_red_gem() -> void:
	var gs := GameState.new()
	# 405 far-away gems (no collection/magnet), xp 1 each.
	for i in 405:
		gs.gems.append(_gem(Vector2(10000 + i, 0), 1.0))
	PickupSystem.step(gs, 0.1)
	assert_int(gs.gems.size()).is_equal(PickupSystem.GEM_CAP)  # exactly 400, not 401
	var red = gs.gems[gs.gems.size() - 1]
	assert_int(red.tier).is_equal(Gem.Tier.RED)
	assert_float(red.xp).is_equal(6.0)  # 405 - 399 = 6 merged


func test_gem_cap_no_op_under_cap() -> void:
	var gs := GameState.new()
	for i in 10:
		gs.gems.append(_gem(Vector2(10000 + i, 0), 1.0))
	PickupSystem.step(gs, 0.1)
	assert_int(gs.gems.size()).is_equal(10)
