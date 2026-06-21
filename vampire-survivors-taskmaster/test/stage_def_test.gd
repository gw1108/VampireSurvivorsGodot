extends GdUnitTestSuite

## Verifies StageDef construction, defaults, and exported field access.

func test_defaults() -> void:
	var s := StageDef.new()
	assert_str(s.id).is_empty()
	assert_float(s.duration).is_equal(1800.0)
	assert_dict(s.stat_modifiers).is_empty()
	assert_array(s.waves).is_empty()
	assert_array(s.bosses).is_empty()
	assert_array(s.events).is_empty()
	assert_array(s.brazier_positions).is_empty()
	assert_float(s.brazier_interval).is_equal(0.0)
	assert_int(s.starting_spawn_count).is_equal(10)
	assert_int(s.max_alive_soft).is_equal(300)
	assert_int(s.max_alive_hard).is_equal(500)
	assert_int(s.reaper_minute).is_equal(30)


func test_is_resource() -> void:
	assert_bool(StageDef.new() is Resource).is_true()


func test_field_assignment() -> void:
	var s := StageDef.new()
	s.id = "mad_forest"
	s.waves.append({"minute": 0, "enemy_ids": ["bat"], "min_alive": 10, "interval": 1.0})
	s.brazier_positions.append(Vector2(100, 100))
	assert_str(s.id).is_equal("mad_forest")
	assert_int(s.waves.size()).is_equal(1)
	assert_int(s.waves[0]["min_alive"]).is_equal(10)
	assert_vector(s.brazier_positions[0]).is_equal(Vector2(100, 100))
