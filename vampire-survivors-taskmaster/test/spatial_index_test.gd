extends GdUnitTestSuite

## Comprehensive tests for SpatialIndex: rebuild, query_radius, nearest_enemy,
## random_enemy. Uses the real Enemy/Gem/Pickup data classes (each has `.pos`).

func _enemy(p: Vector2) -> Enemy:
	var e := Enemy.new()
	e.pos = p
	return e


func _gem(p: Vector2) -> Gem:
	var g := Gem.new()
	g.pos = p
	return g


func _pickup(p: Vector2) -> Pickup:
	var k := Pickup.new()
	k.pos = p
	return k


# Collect the source-array ids of a given Type from a list of combined entries.
func _ids_of_type(index: SpatialIndex, entries: PackedInt32Array, type: int) -> Array:
	var out: Array = []
	for entry: int in entries:
		if SpatialIndex.get_entity_type(index, entry) == type:
			out.append(SpatialIndex.get_entity_local_id(index, entry))
	out.sort()
	return out


func test_rebuild_counts_and_arrays() -> void:
	var idx := SpatialIndex.new()
	var enemies := [_enemy(Vector2(0, 0)), _enemy(Vector2(100, 0))]
	var gems := [_gem(Vector2(10, 10))]
	var pickups := [_pickup(Vector2(-50, -50)), _pickup(Vector2(5, 5)), _pickup(Vector2(7, 7))]
	SpatialIndex.rebuild(idx, enemies, gems, pickups)
	assert_int(idx.enemy_count).is_equal(2)
	assert_int(idx.gem_count).is_equal(1)
	assert_int(idx.pickup_count).is_equal(3)
	assert_int(idx.entity_positions.size()).is_equal(6)
	assert_int(idx.entity_types.size()).is_equal(6)
	assert_int(idx.entity_ids.size()).is_equal(6)
	# Enemies come first; their combined index equals their source id.
	assert_int(idx.entity_types[0]).is_equal(SpatialIndex.Type.ENEMY)
	assert_int(idx.entity_types[2]).is_equal(SpatialIndex.Type.GEM)
	assert_int(idx.entity_types[3]).is_equal(SpatialIndex.Type.PICKUP)
	assert_bool(idx.buckets.is_empty()).is_false()


func test_rebuild_clears_previous_state() -> void:
	var idx := SpatialIndex.new()
	SpatialIndex.rebuild(idx, [_enemy(Vector2(0, 0)), _enemy(Vector2(500, 500))], [], [])
	SpatialIndex.rebuild(idx, [_enemy(Vector2(0, 0))], [], [])
	assert_int(idx.enemy_count).is_equal(1)
	assert_int(idx.entity_positions.size()).is_equal(1)
	# Only the single occupied cell remains.
	assert_int(idx.buckets.size()).is_equal(1)


func test_query_radius_basic() -> void:
	var idx := SpatialIndex.new()
	var enemies := [_enemy(Vector2(0, 0)), _enemy(Vector2(200, 0)), _enemy(Vector2(30, 40))]
	SpatialIndex.rebuild(idx, enemies, [], [])
	# r=50 from origin: enemy 0 (d=0) and enemy 2 (d=50) in; enemy 1 (d=200) out.
	var res := SpatialIndex.query_radius(idx, Vector2(0, 0), 50.0)
	assert_array(_ids_of_type(idx, res, SpatialIndex.Type.ENEMY)).is_equal([0, 2])


func test_query_radius_boundary_inclusive() -> void:
	var idx := SpatialIndex.new()
	SpatialIndex.rebuild(idx, [_enemy(Vector2(50, 0))], [], [])
	# Distance exactly equals r -> included (<=).
	var res := SpatialIndex.query_radius(idx, Vector2(0, 0), 50.0)
	assert_int(res.size()).is_equal(1)


func test_query_radius_excludes_far() -> void:
	var idx := SpatialIndex.new()
	SpatialIndex.rebuild(idx, [_enemy(Vector2(1000, 1000))], [], [])
	var res := SpatialIndex.query_radius(idx, Vector2(0, 0), 64.0)
	assert_int(res.size()).is_equal(0)


func test_query_radius_negative_coords() -> void:
	var idx := SpatialIndex.new()
	# Spread across the origin so multiple negative/positive cells are involved.
	var enemies := [_enemy(Vector2(-70, -70)), _enemy(Vector2(-10, -10)), _enemy(Vector2(80, 80))]
	SpatialIndex.rebuild(idx, enemies, [], [])
	var res := SpatialIndex.query_radius(idx, Vector2(-10, -10), 30.0)
	# Only enemy 1 is within 30 of (-10,-10); the floori bucketing must not miss it.
	assert_array(_ids_of_type(idx, res, SpatialIndex.Type.ENEMY)).is_equal([1])


func test_query_radius_mixed_types() -> void:
	var idx := SpatialIndex.new()
	SpatialIndex.rebuild(idx, [_enemy(Vector2(5, 0))], [_gem(Vector2(0, 5))], [_pickup(Vector2(0, 0))])
	var res := SpatialIndex.query_radius(idx, Vector2(0, 0), 20.0)
	assert_array(_ids_of_type(idx, res, SpatialIndex.Type.ENEMY)).is_equal([0])
	assert_array(_ids_of_type(idx, res, SpatialIndex.Type.GEM)).is_equal([0])
	assert_array(_ids_of_type(idx, res, SpatialIndex.Type.PICKUP)).is_equal([0])


func test_nearest_enemy_returns_closest() -> void:
	var idx := SpatialIndex.new()
	# Closest is id 1 (d=10); ids ordered so it isn't index 0.
	var enemies := [_enemy(Vector2(100, 0)), _enemy(Vector2(10, 0)), _enemy(Vector2(0, 30))]
	SpatialIndex.rebuild(idx, enemies, [], [])
	assert_int(SpatialIndex.nearest_enemy(idx, Vector2(0, 0))).is_equal(1)


func test_nearest_enemy_ignores_other_types() -> void:
	var idx := SpatialIndex.new()
	# A gem/pickup sit closer than any enemy, but must be ignored.
	SpatialIndex.rebuild(idx, [_enemy(Vector2(50, 0))], [_gem(Vector2(1, 0))], [_pickup(Vector2(2, 0))])
	assert_int(SpatialIndex.nearest_enemy(idx, Vector2(0, 0))).is_equal(0)


func test_nearest_enemy_none() -> void:
	var idx := SpatialIndex.new()
	SpatialIndex.rebuild(idx, [], [_gem(Vector2(0, 0))], [])
	assert_int(SpatialIndex.nearest_enemy(idx, Vector2(0, 0))).is_equal(-1)


func test_random_enemy_in_range_and_deterministic() -> void:
	var idx := SpatialIndex.new()
	SpatialIndex.rebuild(idx, [_enemy(Vector2(0, 0)), _enemy(Vector2(64, 0)), _enemy(Vector2(128, 0))], [], [])
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 99
	b.seed = 99
	for i in 30:
		var ra := SpatialIndex.random_enemy(idx, a)
		var rb := SpatialIndex.random_enemy(idx, b)
		assert_int(ra).is_between(0, 2)
		assert_int(ra).is_equal(rb)  # same seed -> same sequence


func test_random_enemy_none() -> void:
	var idx := SpatialIndex.new()
	SpatialIndex.rebuild(idx, [], [], [_pickup(Vector2(0, 0))])
	var rng := RandomNumberGenerator.new()
	assert_int(SpatialIndex.random_enemy(idx, rng)).is_equal(-1)


func test_cell_size_constant() -> void:
	assert_float(SpatialIndex.CELL_SIZE).is_equal(64.0)
