extends GdUnitTestSuite

## Verifies CharacterDef construction, defaults, and exported field access.

func test_defaults() -> void:
	var c := CharacterDef.new()
	assert_str(c.id).is_empty()
	assert_str(c.name).is_empty()
	assert_str(c.starting_weapon_id).is_empty()
	assert_dict(c.base_stats).is_empty()
	assert_dict(c.growth_bonuses).is_empty()
	assert_int(c.growth_interval).is_equal(1)
	assert_dict(c.growth_cap).is_empty()
	assert_float(c.max_health).is_equal(100.0)
	assert_float(c.move_speed).is_equal(1.0)


func test_is_resource() -> void:
	assert_bool(CharacterDef.new() is Resource).is_true()


func test_field_assignment() -> void:
	var c := CharacterDef.new()
	c.id = "antonio"
	c.name = "Antonio Belpaese"
	c.starting_weapon_id = "whip"
	c.base_stats = {"might": 1.0}
	c.growth_bonuses = {"might": 0.1}  # +10% Might per level
	assert_str(c.id).is_equal("antonio")
	assert_str(c.starting_weapon_id).is_equal("whip")
	assert_float(c.base_stats["might"]).is_equal(1.0)
	assert_float(c.growth_bonuses["might"]).is_equal(0.1)
