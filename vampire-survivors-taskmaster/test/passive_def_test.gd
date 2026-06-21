extends GdUnitTestSuite

## Verifies PassiveDef construction, defaults, and exported field access.

func test_defaults() -> void:
	var p := PassiveDef.new()
	assert_str(p.id).is_empty()
	assert_str(p.name).is_empty()
	assert_str(p.description).is_empty()
	assert_int(p.max_level).is_equal(5)
	assert_dict(p.stat_bonuses).is_empty()


func test_is_resource() -> void:
	assert_bool(PassiveDef.new() is Resource).is_true()


func test_field_assignment() -> void:
	var p := PassiveDef.new()
	p.id = "spinach"
	p.name = "Spinach"
	p.stat_bonuses = {"might": [0.1, 0.2, 0.3, 0.4, 0.5]}
	assert_str(p.id).is_equal("spinach")
	assert_int(p.stat_bonuses["might"].size()).is_equal(5)
	assert_float(p.stat_bonuses["might"][0]).is_equal(0.1)
