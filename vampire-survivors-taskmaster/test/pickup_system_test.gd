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


func test_pickup_special_effect_flagged() -> void:
	var gs := GameState.new()
	gs.pickups = [_pickup(Vector2(0, 0), Pickup.Type.OROLOGION)]
	PickupSystem.step(gs, 0.1)
	assert_bool(gs.global_effects.get("orologion", false)).is_true()
	assert_int(gs.pickups.size()).is_equal(0)


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
