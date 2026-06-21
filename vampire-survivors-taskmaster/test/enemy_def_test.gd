extends GdUnitTestSuite

## Verifies EnemyDef construction, defaults, and exported field access.

func test_defaults() -> void:
	var e := EnemyDef.new()
	assert_str(e.id).is_empty()
	assert_str(e.name).is_empty()
	assert_float(e.hp).is_equal(0.0)
	assert_float(e.power).is_equal(0.0)
	assert_float(e.speed).is_equal(0.0)
	assert_float(e.knockback_resist).is_equal(0.0)
	assert_float(e.xp_value).is_equal(1.0)
	assert_bool(e.is_boss).is_false()


func test_is_resource() -> void:
	assert_bool(EnemyDef.new() is Resource).is_true()


func test_field_assignment() -> void:
	var e := EnemyDef.new()
	e.id = "bat"
	e.hp = 1.0
	e.power = 4.0
	e.speed = 90.0
	e.is_boss = true
	assert_str(e.id).is_equal("bat")
	assert_float(e.hp).is_equal(1.0)
	assert_float(e.power).is_equal(4.0)
	assert_float(e.speed).is_equal(90.0)
	assert_bool(e.is_boss).is_true()
